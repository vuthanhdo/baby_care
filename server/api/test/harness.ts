// Test database. By default PGlite (Postgres in WebAssembly) with the platform and app migrations applied, served
// over the Postgres wire protocol so the API connects exactly as it does to the real server. With TEST_DATABASE_URL
// (the API role) and TEST_ADMIN_URL (a superuser) set, the same tests run against a real, freshly migrated Postgres:
// scripts/test-api.sh does that on the VPS. No network beyond that, no real data.
import { readFile, readdir, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { PGlite } from '@electric-sql/pglite';
import { PGLiteSocketServer } from '@electric-sql/pglite-socket';
import { connect, type SQL } from '../src/db.ts';
import { buildApp, type App } from '../src/app.ts';
import { loadConfig, type Config } from '../src/config.ts';

const root = new URL('../../../', import.meta.url).pathname;

/** Superuser access for fixtures and assertions. Role switches are only needed on PGlite's single session. */
export interface Admin {
  exec(text: string): Promise<void>;
  query<T>(text: string): Promise<{ rows: T[] }>;
}

export interface Harness {
  app: App;
  config: Config;
  sql: SQL;
  admin: Admin;
  mail: { to: string; subject: string; text: string }[];
  close(): Promise<void>;
}

async function pgliteDatabase(): Promise<{ url: string; admin: Admin; close(): Promise<void> }> {
  const db = await PGlite.create();
  const files = [
    ...(await readdir(join(root, 'server/db'))).filter(f => f.endsWith('.sql')).sort().map(f => join(root, 'server/db', f)),
    ...(await readdir(join(root, 'supabase/migrations'))).filter(f => f.endsWith('.sql')).sort().map(f => join(root, 'supabase/migrations', f)),
  ];
  for (const file of files) await db.exec(await readFile(file, 'utf8'));
  // The API's own connection runs as babycare_api, as in production; PGlite has one session, so set it once.
  await db.exec('set role babycare_api');
  const server = new PGLiteSocketServer({ db, port: 0 });
  await server.start();
  return {
    url: `postgres://babycare_api@${server.getServerConn()}/postgres`,
    admin: { exec: async text => { await db.exec(text); }, query: async <T>(text: string) => ({ rows: (await db.query<T>(text)).rows }) },
    async close() { await server.stop(); await db.close(); },
  };
}

function realDatabase(url: string, adminURL: string): { url: string; admin: Admin; close(): Promise<void> } {
  const superuser = connect(adminURL, { max: 1 });
  const strip = (text: string) => text.replace(/\b(reset role|set role babycare_api)\s*;?/gi, '').trim();
  return {
    url,
    admin: {
      exec: async text => { const statement = strip(text); if (statement) await superuser.unsafe(statement); },
      query: async <T>(text: string) => ({ rows: (await superuser.unsafe(strip(text))) as unknown as T[] }),
    },
    async close() { await superuser.end({ timeout: 1 }); },
  };
}

export async function startHarness(overrides: Record<string, string> = {}): Promise<Harness> {
  const real = process.env.TEST_DATABASE_URL && process.env.TEST_ADMIN_URL;
  const database = real ? realDatabase(process.env.TEST_DATABASE_URL!, process.env.TEST_ADMIN_URL!) : await pgliteDatabase();
  const filesDirectory = await mkdtemp(join(tmpdir(), 'babycare-files-'));
  const config = loadConfig({
    SITE_URL: 'https://api.test',
    DATABASE_URL: database.url,
    JWT_SECRET: 'test-secret-test-secret-test-secret-0123',
    PUBLISHABLE_KEY: 'test-publishable-key',
    FILES_DIRECTORY: filesDirectory,
    ...overrides,
  });
  // One connection on PGlite: it runs a single session, so transactions must not interleave.
  const sql = connect(config.databaseURL, { max: real ? 4 : 1 });
  const mail: Harness['mail'] = [];
  const app = buildApp(config, sql, { send: async message => { mail.push(message); } });
  return {
    app, config, sql, admin: database.admin, mail,
    async close() {
      await sql.end({ timeout: 1 });
      await database.close();
      await rm(filesDirectory, { recursive: true, force: true });
    },
  };
}
