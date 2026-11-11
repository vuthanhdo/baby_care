import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { after, before, describe, test } from 'node:test';
import { startHarness, type Harness } from './harness.ts';
import { call, newAccount } from './client.ts';

/** supabase-swift's upload body: a cacheControl field, then the file in a part with an empty field name. */
function multipart(bytes: Uint8Array, filename: string, mime: string) {
  const boundary = 'alamofire.boundary.0123456789abcdef';
  const head = `--${boundary}\r\nContent-Disposition: form-data; name="cacheControl"\r\n\r\n3600\r\n`
    + `--${boundary}\r\nContent-Disposition: form-data; name=""; filename="${filename}"\r\nContent-Type: ${mime}\r\n\r\n`;
  const tail = `\r\n--${boundary}--\r\n`;
  const body = Buffer.concat([Buffer.from(head), Buffer.from(bytes), Buffer.from(tail)]);
  return { raw: body, headers: { 'Content-Type': `multipart/form-data; boundary=${boundary}`, 'x-upsert': 'false', 'Cache-Control': 'max-age=3600' } };
}

describe('storage', () => {
  let h: Harness;
  let user: Awaited<ReturnType<typeof newAccount>>;
  before(async () => {
    h = await startHarness();
    user = await newAccount(h, 'photos@example.com');
  });
  after(async () => { await h.close(); });

  const jpeg = randomBytes(2048);

  test('upload answers {Key, Id}; download returns the same bytes; size and mimetype are recorded', async () => {
    const path = `${user.user.id}/${crypto.randomUUID()}/0.jpg`;
    const up = await call(h, 'POST', `/storage/v1/object/babycare-feedback/${path}`, { token: user.access_token, ...multipart(jpeg, '0.jpg', 'image/jpeg') });
    assert.equal(up.status, 200, JSON.stringify(up.json));
    assert.equal(up.json.Key, `babycare-feedback/${path}`);
    assert.equal(typeof up.json.Id, 'string');
    const down = await call(h, 'GET', `/storage/v1/object/babycare-feedback/${path}`, { token: user.access_token });
    assert.equal(down.status, 200);
    assert.deepEqual(Buffer.from(down.bytes), jpeg);
    await h.admin.exec('reset role');
    const meta = await h.admin.query<{ size: string; mimetype: string }>(`select metadata->>'size' as size, metadata->>'mimetype' as mimetype from storage.objects where name = '${path}'`);
    await h.admin.exec('set role babycare_api');
    assert.deepEqual(meta.rows[0], { size: '2048', mimetype: 'image/jpeg' });

    const again = await call(h, 'POST', `/storage/v1/object/babycare-feedback/${path}`, { token: user.access_token, ...multipart(jpeg, '0.jpg', 'image/jpeg') });
    assert.equal(again.json.statusCode, '409');
  });

  test('another account cannot write into or read from this folder', async () => {
    const other = await newAccount(h, 'snoop@example.com');
    const path = `${user.user.id}/${crypto.randomUUID()}/0.jpg`;
    const denied = await call(h, 'POST', `/storage/v1/object/babycare-feedback/${path}`, { token: other.access_token, ...multipart(jpeg, '0.jpg', 'image/jpeg') });
    assert.equal(denied.json.statusCode, '403');
    await call(h, 'POST', `/storage/v1/object/babycare-feedback/${path}`, { token: user.access_token, ...multipart(jpeg, '0.jpg', 'image/jpeg') });
    const hidden = await call(h, 'GET', `/storage/v1/object/babycare-feedback/${path}`, { token: other.access_token });
    assert.equal(hidden.status, 400);
    assert.equal(hidden.json.statusCode, '404');
    assert.equal(hidden.json.message, 'Object not found');
  });

  test('bucket rules: type and path checks', async () => {
    const wrongType = await call(h, 'POST', `/storage/v1/object/babycare-feedback/${user.user.id}/x/0.gif`, { token: user.access_token, ...multipart(jpeg, '0.gif', 'image/gif') });
    assert.equal(wrongType.status, 415);
    const escape = await call(h, 'POST', `/storage/v1/object/babycare-feedback/${user.user.id}/..%2F..%2Fetc/0.jpg`, { token: user.access_token, ...multipart(jpeg, '0.jpg', 'image/jpeg') });
    assert.equal(escape.json.statusCode, '400');
  });

  test('media uploads need the current consent, and say so in the message', async () => {
    const path = `${user.user.id}/${crypto.randomUUID()}/${crypto.randomUUID()}`;
    const reply = await call(h, 'POST', `/storage/v1/object/babycare-media/${path}`, { token: user.access_token, ...multipart(jpeg, 'x', 'image/jpeg') });
    assert.notEqual(reply.status, 200);
    assert.match(reply.json.message, /CONSENT_REQUIRED|row-level security/);
  });

  test('remove answers the removed objects as a list and deletes the files', async () => {
    const path = `${user.user.id}/${crypto.randomUUID()}/0.jpg`;
    await call(h, 'POST', `/storage/v1/object/babycare-feedback/${path}`, { token: user.access_token, ...multipart(jpeg, '0.jpg', 'image/jpeg') });
    const removed = await call(h, 'DELETE', '/storage/v1/object/babycare-feedback', { token: user.access_token, body: { prefixes: [path, `${user.user.id}/missing/0.jpg`] } });
    assert.equal(removed.status, 200);
    assert.equal(removed.json.length, 1);
    assert.equal(removed.json[0].name, path);
    assert.match(removed.json[0].created_at, /Z$/);
    const gone = await call(h, 'GET', `/storage/v1/object/babycare-feedback/${path}`, { token: user.access_token });
    assert.equal(gone.json.statusCode, '404');
  });
});
