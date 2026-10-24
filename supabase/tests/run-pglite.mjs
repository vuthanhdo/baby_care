// Optional isolated PostgreSQL/WASM smoke runner. No network calls or production data.
// Usage: node supabase/tests/run-pglite.mjs <temporary npm install prefix>
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { readFile, readdir } from 'node:fs/promises';

const require = createRequire(process.argv[2] ? resolve(process.argv[2], 'package.json') : import.meta.url);
const { PGlite } = require('@electric-sql/pglite');
const root = fileURLToPath(new URL('../', import.meta.url));
const db = new PGlite();
try {
  // Minimal Supabase platform shim. Tests exercise actual SQL functions, RLS and
  // triggers, not GoTrue JWT validation, PostgREST or the Storage HTTP service.
  await db.exec(`
    create role anon; create role authenticated; create role service_role;
    create schema auth; create schema storage;
    create table auth.users(id uuid primary key,email text);
    create function auth.uid() returns uuid language sql stable as $$
      select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;
    grant usage on schema auth,storage to anon,authenticated;
    grant execute on function auth.uid() to anon,authenticated;
    create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
    create table storage.objects(id uuid primary key default gen_random_uuid(),bucket_id text,name text,metadata jsonb,unique(bucket_id,name));
    alter table storage.objects enable row level security;
    grant select,insert,update,delete on storage.objects to authenticated;
  `);
  for (const file of (await readdir(`${root}/migrations`)).filter(f => f.endsWith('.sql')).sort()) {
    await db.exec(await readFile(`${root}/migrations/${file}`, 'utf8'));
    console.log(`Applied ${file}`);
  }
  for (const name of ['consent', 'backend']) {
    const results = await db.exec(await readFile(`${root}/tests/${name}.sql`, 'utf8'));
    const summary = results.find(result => result.rows?.[0]?.passed_checks)?.rows[0];
    console.log(`${name}: PASS`, summary);
  }
} catch (error) {
  // Synthetic test errors only; avoid dumping entire SQL inputs in CI output.
  console.error({ message: error.message, code: error.code });
  process.exitCode = 1;
} finally { await db.close(); }
