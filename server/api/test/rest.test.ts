import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';
import { SignJWT } from 'jose';
import { startHarness, type Harness } from './harness.ts';
import { acceptConsent, call, newAccount } from './client.ts';

describe('rest', () => {
  let h: Harness;
  let owner: Awaited<ReturnType<typeof newAccount>>;
  before(async () => {
    h = await startHarness();
    owner = await newAccount(h, 'owner@example.com');
    await acceptConsent(h, owner.access_token);
  });
  after(async () => { await h.close(); });

  test('signed out, an authenticated-only RPC is refused as PostgREST does', async () => {
    const reply = await call(h, 'POST', '/rest/v1/rpc/babycare_my_families');
    assert.equal(reply.status, 401);
    assert.equal(reply.json.code, '42501');
    assert.equal(typeof reply.json.message, 'string');
  });

  test('scalar results come back bare: a uuid as a JSON string, jsonb as itself', async () => {
    const id = owner.user.id.toUpperCase();
    const created = await call(h, 'POST', '/rest/v1/rpc/babycare_create_family', { token: owner.access_token, body: { p_id: id, p_name: 'Hồ sơ của tôi' } });
    assert.equal(created.status, 200);
    assert.equal(created.json, owner.user.id);
    const families = await call(h, 'POST', '/rest/v1/rpc/babycare_my_families', { token: owner.access_token });
    assert.equal(families.status, 200);
    assert.ok(Array.isArray(families.json));
    assert.equal(families.json[0].id, owner.user.id);
    assert.equal(families.json[0].role, 'owner');
  });

  test('an empty body uses the SQL defaults; unknown arguments answer PGRST202', async () => {
    const status = await call(h, 'POST', '/rest/v1/rpc/babycare_consent_status', { token: owner.access_token });
    assert.equal(status.status, 200);
    assert.equal(status.json.valid, true);
    const unknown = await call(h, 'POST', '/rest/v1/rpc/babycare_read_page', { token: owner.access_token, body: { p_family_id: owner.user.id, p_nope: 1 } });
    assert.equal(unknown.status, 404);
    assert.equal(unknown.json.code, 'PGRST202');
    const missing = await call(h, 'POST', '/rest/v1/rpc/babycare_nope', { token: owner.access_token });
    assert.equal(missing.json.code, 'PGRST202');
  });

  test('raised SQL errors keep their SQLSTATE and exact message', async () => {
    const reply = await call(h, 'POST', '/rest/v1/rpc/babycare_leave_family', { token: owner.access_token, body: { p_family_id: owner.user.id.toUpperCase() } });
    assert.equal(reply.status, 400);
    assert.equal(reply.json.code, 'P0001');
    assert.equal(reply.json.message, 'Cannot leave own family');
  });

  test('a write through babycare_apply returns its receipt; read_page sees it', async () => {
    const babyID = crypto.randomUUID().toUpperCase();
    const operation = crypto.randomUUID().toUpperCase();
    const apply = await call(h, 'POST', '/rest/v1/rpc/babycare_apply', { token: owner.access_token, body: {
      p_operation_id: operation, p_family_id: owner.user.id.toUpperCase(), p_api_version: 1,
      p_changes: [{ entity: 'babies', id: babyID, expected_version: 0, deleted: false,
        data: { name: 'Bé Sóc', birth_date: '2026-02-01T00:00:00Z', gender: 'unspecified' } }],
    } });
    assert.equal(apply.status, 200, JSON.stringify(apply.json));
    assert.equal(apply.json.operation_id, operation.toLowerCase());
    assert.equal(apply.json.records[0].version, 1);
    const page = await call(h, 'POST', '/rest/v1/rpc/babycare_read_page', { token: owner.access_token, body: {
      p_family_id: owner.user.id.toUpperCase(), p_entity: 'babies', p_at_revision: apply.json.revision, p_limit: 200, p_api_version: 2,
    } });
    assert.equal(page.status, 200, JSON.stringify(page.json));
    assert.equal(page.json.rows.length, 1);
  });

  // Supabase's PostgREST re-ran a transaction that failed with SQLSTATE 40001 without end: one stale write from
  // 2/11/2026 kept three connections busy around the clock and filled the disk by 4/11. Here it fails once, at once.
  test('a stale write answers 409 with code 40001 at once, without retrying the transaction', async () => {
    const familyID = owner.user.id.toUpperCase();
    const babyID = crypto.randomUUID().toUpperCase();
    const create = (expected: number) => call(h, 'POST', '/rest/v1/rpc/babycare_apply', { token: owner.access_token, body: {
      p_operation_id: crypto.randomUUID().toUpperCase(), p_family_id: familyID, p_api_version: 1,
      p_changes: [{ entity: 'babies', id: babyID, expected_version: expected, deleted: false,
        data: { name: 'Bé Na', birth_date: '2026-03-01T00:00:00Z', gender: 'unspecified' } }],
    } });
    assert.equal((await create(0)).status, 200);
    const started = performance.now();
    const stale = await create(0);
    assert.ok(performance.now() - started < 2000, 'the conflict must not be retried');
    assert.equal(stale.status, 409);
    assert.equal(stale.json.code, '40001');
    assert.equal(stale.json.message, 'Version conflict or deleted record');
  });

  test('array and jsonb arguments arrive intact', async () => {
    const reply = await call(h, 'POST', '/rest/v1/rpc/babycare_send_feedback', { token: owner.access_token, body: {
      p_id: crypto.randomUUID().toUpperCase(), p_kind: 'bug', p_message: 'Biểu đồ trống', p_allow_contact: false,
      p_context: { app_version: '1.4', build: '6', os_version: '27.1', device: 'iPhone18,3', language: 'vi', storage: 'cloud' },
      p_attachments: [],
    } });
    assert.equal(reply.status, 200, JSON.stringify(reply.json));
    const rows = await call(h, 'GET', '/rest/v1/app_feedback?select=attachments', { token: owner.access_token });
    assert.deepEqual(rows.json, [{ attachments: [] }]);
    // An attachment that was never uploaded is refused by the SQL itself.
    const missing = await call(h, 'POST', '/rest/v1/rpc/babycare_send_feedback', { token: owner.access_token, body: {
      p_id: crypto.randomUUID(), p_kind: 'bug', p_message: 'Ảnh', p_allow_contact: false,
      p_attachments: [`${owner.user.id}/${crypto.randomUUID()}/0.jpg`],
    } });
    assert.equal(missing.status, 400);
  });

  test('table reads: eq on an uppercase uuid, order with nullslast, offset and limit', async () => {
    const id = owner.user.id.toUpperCase();
    const one = await call(h, 'GET', `/rest/v1/families?select=*&id=eq.${id}`, { token: owner.access_token });
    assert.equal(one.status, 200);
    assert.equal(one.json.length, 1);
    assert.equal(one.json[0].name, 'Hồ sơ của tôi');
    const page = await call(h, 'GET', `/rest/v1/families?select=id&created_by=eq.${id}&order=id.asc.nullslast&offset=0&limit=500`, { token: owner.access_token });
    assert.deepEqual(page.json, [{ id: owner.user.id }]);
    const bad = await call(h, 'GET', '/rest/v1/families?select=nope', { token: owner.access_token });
    assert.equal(bad.status, 400);
    const unknownTable = await call(h, 'GET', '/rest/v1/babies?select=*', { token: owner.access_token });
    assert.equal(unknownTable.json.code, 'PGRST205');
  });

  test('another account sees nothing of this family', async () => {
    const other = await newAccount(h, 'other@example.com');
    const rows = await call(h, 'GET', `/rest/v1/families?select=*&id=eq.${owner.user.id}`, { token: other.access_token });
    assert.deepEqual(rows.json, []);
    const sharing = await call(h, 'POST', '/rest/v1/rpc/babycare_family_sharing', { token: other.access_token, body: { p_family_id: owner.user.id } });
    assert.equal(sharing.status, 403);
    assert.equal(sharing.json.code, '42501');
  });

  test('forged and expired tokens are refused with PostgREST codes', async () => {
    const forged = await new SignJWT({ role: 'authenticated', session_id: crypto.randomUUID() }).setProtectedHeader({ alg: 'HS256' })
      .setSubject(owner.user.id).setAudience('authenticated').setExpirationTime('1h').sign(new TextEncoder().encode('not-the-secret-not-the-secret-1234'));
    assert.equal((await call(h, 'POST', '/rest/v1/rpc/babycare_my_families', { token: forged })).json.code, 'PGRST301');
    const expired = await new SignJWT({ role: 'authenticated', session_id: crypto.randomUUID() }).setProtectedHeader({ alg: 'HS256' })
      .setSubject(owner.user.id).setAudience('authenticated').setExpirationTime(Math.floor(Date.now() / 1000) - 60).sign(new TextEncoder().encode(h.config.jwtSecret));
    assert.equal((await call(h, 'POST', '/rest/v1/rpc/babycare_my_families', { token: expired })).json.code, 'PGRST303');
  });
});
