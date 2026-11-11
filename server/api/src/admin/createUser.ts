// Inside the api container: reads {"email", "password"} as JSON from stdin and makes that a confirmed account.
// Run by server/scripts/create-user.sh; the password never appears in arguments or output.
import { connect } from '../db.ts';
import { ensureConfirmedUser } from './users.ts';

const chunks: Buffer[] = [];
for await (const chunk of process.stdin) chunks.push(chunk as Buffer);
const { email, password } = JSON.parse(Buffer.concat(chunks).toString('utf8')) as { email?: unknown; password?: unknown };
const url = process.env.DATABASE_URL;
if (!url) throw new Error('DATABASE_URL is not set');
const sql = connect(url, { max: 1 });
try {
  const result = await ensureConfirmedUser(sql, email, password);
  console.log(`${result.created ? 'created' : 'updated'} confirmed account ${result.id}`);
} finally {
  await sql.end({ timeout: 1 });
}
