// The HTTP surface: the Supabase paths the app calls, answered by our own code (see BACKEND_VPS_PLAN.md).
import { Hono, type Context } from 'hono';
import type { Config } from './config.ts';
import type { Caller, SQL } from './db.ts';
import { authRoutes } from './auth/routes.ts';
import type { Mailer } from './auth/mail.ts';
import { verifyAccessToken } from './auth/tokens.ts';
import { appleToken } from './functions/appleToken.ts';
import { callRpc, loadSignatures } from './rest/rpc.ts';
import { loadColumns, readTable } from './rest/tables.ts';
import { downloadObject, removeObjects, uploadObject } from './storage/files.ts';

export type App = Hono;

type CallerResult = { ok: true; caller: Caller } | { ok: false; reason: 'expired' | 'invalid' };

export function buildApp(config: Config, sql: SQL, mailer: Mailer): App {
  const app = new Hono();
  let signatures: ReturnType<typeof loadSignatures> | undefined;
  let columns: ReturnType<typeof loadColumns> | undefined;

  app.onError((error, c) => {
    console.error('unhandled', error);
    return c.json({ message: 'Internal server error' }, 500);
  });

  app.get('/healthz', c => c.text('ok'));

  // Every API call carries the publishable key as `apikey`, like on Supabase; the browser legs of the auth flows
  // (email links, Google redirects) cannot, and do not need it.
  const browserPaths = new Set(['/auth/v1/verify', '/auth/v1/authorize', '/auth/v1/callback']);
  app.use('/*', async (c, next) => {
    if (c.req.path === '/healthz' || browserPaths.has(c.req.path)) return next();
    if (c.req.header('apikey') !== config.publishableKey) {
      return c.json({ message: 'Invalid API key', hint: 'Double check the apikey header.' }, 401);
    }
    return next();
  });

  app.route('/auth/v1', authRoutes(config, sql, mailer));

  /** Signed out, the SDK sends the publishable key as the bearer; that is the anon role. */
  async function resolveCaller(c: Context): Promise<CallerResult> {
    const header = c.req.header('authorization') ?? '';
    const token = header.replace(/^Bearer\s+/i, '').trim();
    if (!token || token === config.publishableKey) return { ok: true, caller: { role: 'anon' } };
    const check = await verifyAccessToken(config, sql, token);
    if (!check.ok) return { ok: false, reason: check.reason === 'expired' ? 'expired' : 'invalid' };
    return { ok: true, caller: { role: 'authenticated', sub: check.claims.sub, email: check.claims.email } };
  }

  const restAuthError = (c: Context, reason: 'expired' | 'invalid') => reason === 'expired'
    ? c.json({ code: 'PGRST303', message: 'JWT expired', details: null, hint: null }, 401)
    : c.json({ code: 'PGRST301', message: 'No suitable key or wrong key type', details: null, hint: null }, 401);

  app.post('/rest/v1/rpc/:name', async c => {
    const resolved = await resolveCaller(c);
    if (!resolved.ok) return restAuthError(c, resolved.reason);
    const text = await c.req.text();
    let params: unknown = {};
    if (text.trim()) {
      try { params = JSON.parse(text); } catch { return c.json({ code: 'PGRST102', message: 'Empty or invalid json', details: null, hint: null }, 400); }
    }
    signatures ??= loadSignatures(sql);
    const result = await callRpc(sql, await signatures, c.req.param('name'), params, resolved.caller);
    return c.json(result.body as never, result.status as 200);
  });

  app.get('/rest/v1/:table', async c => {
    const resolved = await resolveCaller(c);
    if (!resolved.ok) return restAuthError(c, resolved.reason);
    columns ??= loadColumns(sql);
    const result = await readTable(sql, await columns, c.req.param('table'), new URL(c.req.url).searchParams, resolved.caller);
    return c.json(result.body as never, result.status as 200);
  });

  const storageAuthError = (c: Context, reason: 'expired' | 'invalid') =>
    c.json({ statusCode: '403', error: 'Unauthorized', message: reason === 'expired' ? 'jwt expired' : 'invalid signature' }, 400);

  /** `/storage/v1/object/<bucket>/<path>` (also `/object/authenticated/...`) → bucket and decoded object name. */
  function objectPath(c: Context): { bucket: string; name: string } | null {
    const rest = c.req.path.replace(/^\/storage\/v1\/object\/(authenticated\/)?/, '');
    const [bucket, ...parts] = rest.split('/');
    if (!bucket || !parts.length) return null;
    try {
      return { bucket: decodeURIComponent(bucket), name: parts.map(decodeURIComponent).join('/') };
    } catch {
      return null;
    }
  }

  async function upload(c: Context, upsertByDefault: boolean) {
    const resolved = await resolveCaller(c);
    if (!resolved.ok) return storageAuthError(c, resolved.reason);
    const target = objectPath(c);
    if (!target) return c.json({ statusCode: '400', error: 'Invalid key', message: 'Invalid key' }, 400);
    let bytes: Uint8Array;
    let contentType = c.req.header('content-type') ?? 'application/octet-stream';
    if (contentType.startsWith('multipart/form-data')) {
      // supabase-swift sends the file as a part with an empty field name, next to a cacheControl field.
      const form = await c.req.raw.formData();
      const file = [...form.values()].find((value): value is File => typeof value !== 'string');
      if (!file) return c.json({ statusCode: '400', error: 'Invalid request', message: 'No file in the request' }, 400);
      bytes = new Uint8Array(await file.arrayBuffer());
      contentType = file.type || 'application/octet-stream';
    } else {
      bytes = new Uint8Array(await c.req.arrayBuffer());
    }
    const upsert = (c.req.header('x-upsert') ?? String(upsertByDefault)) === 'true';
    const result = await uploadObject(sql, config.filesDirectory, resolved.caller, target.bucket, target.name, bytes, contentType, upsert);
    if ('status' in result) return c.json(result.body, result.status as 400);
    return c.json({ Key: result.key, Id: result.id });
  }

  app.post('/storage/v1/object/*', c => upload(c, false));
  app.put('/storage/v1/object/*', c => upload(c, true));

  app.get('/storage/v1/object/*', async c => {
    const resolved = await resolveCaller(c);
    if (!resolved.ok) return storageAuthError(c, resolved.reason);
    const target = objectPath(c);
    if (!target) return c.json({ statusCode: '400', error: 'Invalid key', message: 'Invalid key' }, 400);
    const result = await downloadObject(sql, config.filesDirectory, resolved.caller, target.bucket, target.name);
    if ('status' in result) return c.json(result.body, result.status as 400);
    return new Response(Buffer.from(result.bytes), { status: 200, headers: { 'Content-Type': result.contentType, 'Cache-Control': 'private, no-store' } });
  });

  app.delete('/storage/v1/object/:bucket', async c => {
    const resolved = await resolveCaller(c);
    if (!resolved.ok) return storageAuthError(c, resolved.reason);
    const body = await c.req.json().catch(() => ({})) as { prefixes?: unknown };
    const names = Array.isArray(body.prefixes) ? body.prefixes.filter((p): p is string => typeof p === 'string') : [];
    const result = await removeObjects(sql, config.filesDirectory, resolved.caller, c.req.param('bucket'), names);
    if (!Array.isArray(result)) return c.json(result.body, result.status as 400);
    return c.json(result);
  });

  app.post('/functions/v1/apple-token', async c => {
    const resolved = await resolveCaller(c);
    if (!resolved.ok || resolved.caller.role !== 'authenticated' || !resolved.caller.sub) {
      return c.json({ error: 'Authentication required' }, 401);
    }
    const payload = await c.req.json().catch(() => ({})) as { action?: unknown; code?: unknown };
    const result = await appleToken(config, sql, resolved.caller.sub, payload);
    return c.json(result.body as never, result.status as 200);
  });

  app.notFound(c => c.json({ message: 'Not found' }, 404));
  return app;
}
