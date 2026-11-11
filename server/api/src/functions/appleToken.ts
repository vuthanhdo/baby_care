// POST /functions/v1/apple-token, ported from supabase/functions/apple-token: keeps the Sign in with Apple refresh
// token so the app can revoke it when the account is deleted (App Store Review Guideline 5.1.1(v)).
//   {"action":"link","code":"<authorizationCode>"}  right after a native Apple sign-in (code expires in 5 min)
//   {"action":"revoke"}                              right before babycare_delete_account
// public.apple_tokens is service_role only, so this runs as service_role after checking the caller's token.
import { decodeJwt, importPKCS8, SignJWT } from 'jose';
import type { Config } from '../config.ts';
import { asCaller, type SQL } from '../db.ts';

const APPLE = 'https://appleid.apple.com';

export type FunctionResult = { status: number; body: unknown };

async function clientSecret(config: Config): Promise<string> {
  const { teamID, keyID, privateKey, bundleID } = config.apple;
  if (!teamID || !keyID || !privateKey) throw new Error('Apple secrets are not configured');
  const key = await importPKCS8(privateKey, 'ES256');
  return new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: keyID })
    .setIssuer(teamID).setSubject(bundleID).setAudience(APPLE)
    .setIssuedAt().setExpirationTime('1h')
    .sign(key);
}

async function appleForm(config: Config, path: string, params: Record<string, string>): Promise<Response> {
  const body = new URLSearchParams({ client_id: config.apple.bundleID, client_secret: await clientSecret(config), ...params });
  return fetch(`${APPLE}${path}`, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body });
}

export async function appleToken(config: Config, sql: SQL, userID: string, payload: { action?: unknown; code?: unknown }): Promise<FunctionResult> {
  const serviceRole = <T>(work: Parameters<typeof asCaller<T>>[2]) => asCaller<T>(sql, { role: 'service_role', sub: userID }, work);
  try {
    if (payload.action === 'link') {
      if (typeof payload.code !== 'string' || !payload.code) return { status: 400, body: { error: 'code required' } };
      const response = await appleForm(config, '/auth/token', { code: payload.code, grant_type: 'authorization_code' });
      const token = await response.json() as { refresh_token?: string; id_token?: string; error?: string };
      if (!response.ok || !token.refresh_token) {
        console.error('apple-token link: exchange failed', response.status, token.error);
        return { status: 502, body: { error: 'Apple token exchange failed', detail: token.error ?? response.status } };
      }
      // The code must belong to the signed-in user's Apple identity, never to someone else's.
      const [identity] = await sql<{ provider_id: string }[]>`select provider_id from auth.identities where user_id = ${userID} and provider = 'apple'`;
      let subject: string | undefined;
      try { subject = decodeJwt(token.id_token ?? '').sub; } catch { subject = undefined; }
      if (!identity || subject !== identity.provider_id) return { status: 403, body: { error: 'Apple identity does not match this account' } };
      await serviceRole(tx => tx`insert into public.apple_tokens (user_id, refresh_token, updated_at) values (${userID}, ${token.refresh_token!}, now())
                                 on conflict (user_id) do update set refresh_token = excluded.refresh_token, updated_at = now()`);
      return { status: 200, body: { linked: true } };
    }
    if (payload.action === 'revoke') {
      const [row] = await serviceRole(tx => tx<{ refresh_token: string }[]>`select refresh_token from public.apple_tokens where user_id = ${userID}`);
      if (!row) return { status: 200, body: { revoked: false, reason: 'no apple token for this user' } };
      const response = await appleForm(config, '/auth/revoke', { token: row.refresh_token, token_type_hint: 'refresh_token' });
      if (!response.ok) return { status: 502, body: { revoked: false, error: `Apple revoke failed (${response.status})` } };
      await serviceRole(tx => tx`delete from public.apple_tokens where user_id = ${userID}`);
      return { status: 200, body: { revoked: true } };
    }
    return { status: 400, body: { error: 'action must be link or revoke' } };
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error('apple-token', payload.action, 'failed:', message);
    return { status: 500, body: { error: message } };
  }
}
