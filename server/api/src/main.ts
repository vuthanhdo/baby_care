import { serve } from '@hono/node-server';
import { buildApp } from './app.ts';
import { loadConfig } from './config.ts';
import { connect } from './db.ts';
import { smtpMailer } from './auth/mail.ts';

const config = loadConfig();
const sql = connect(config.databaseURL);
const app = buildApp(config, sql, smtpMailer(config));
const server = serve({ fetch: app.fetch, port: config.port, hostname: '0.0.0.0' });
console.log(`babycare-api listening on ${config.port}`);

for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, () => {
    server.close();
    void sql.end({ timeout: 5 }).finally(() => process.exit(0));
  });
}
