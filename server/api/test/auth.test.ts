import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';
import { startHarness, type Harness } from './harness.ts';
import { call, follow, lastLink, newAccount, pkce } from './client.ts';
import { ensureConfirmedUser } from '../src/admin/users.ts';

const iso = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$/;

describe('auth', () => {
  let h: Harness;
  before(async () => { h = await startHarness(); });
  after(async () => { await h.close(); });

  test('an operator-made account (App Review) signs in at once, and running it again only changes the password', async () => {
    const first = await ensureConfirmedUser(h.sql, 'Review@Example.com', 'review-pass-1');
    assert.equal(first.created, true);
    assert.equal(h.mail.length, 0, 'no confirmation email');
    const signin = await call(h, 'POST', '/auth/v1/token?grant_type=password', { body: { email: 'review@example.com', password: 'review-pass-1' } });
    assert.equal(signin.status, 200, JSON.stringify(signin.json));
    assert.equal(signin.json.user.id, first.id);
    assert.equal(typeof signin.json.user.email_confirmed_at, 'string');
    const again = await ensureConfirmedUser(h.sql, 'review@example.com', 'review-pass-2');
    assert.deepEqual(again, { id: first.id, created: false });
    const old = await call(h, 'POST', '/auth/v1/token?grant_type=password', { body: { email: 'review@example.com', password: 'review-pass-1' } });
    assert.equal(old.status, 400);
    const fresh = await call(h, 'POST', '/auth/v1/token?grant_type=password', { body: { email: 'review@example.com', password: 'review-pass-2' } });
    assert.equal(fresh.status, 200);
    await assert.rejects(ensureConfirmedUser(h.sql, 'review@example.com', '123'));
  });

  test('every call needs the publishable key', async () => {
    const response = await h.app.request('/auth/v1/token?grant_type=password', { method: 'POST', body: '{}' });
    assert.equal(response.status, 401);
  });

  test('sign-up waits for the emailed link, which confirms and returns a PKCE code', async () => {
    const flow = pkce();
    const signup = await call(h, 'POST', '/auth/v1/signup?redirect_to=babycare%3A//auth-callback',
      { body: { email: 'Lan@Example.com', password: 'secret-pass-1', code_challenge: flow.challenge, code_challenge_method: 's256' } });
    assert.equal(signup.status, 200);
    assert.equal(signup.json.email, 'lan@example.com');
    assert.equal(signup.json.identities.length, 1);
    assert.match(signup.json.created_at, iso);
    assert.equal(signup.json.access_token, undefined);

    const early = await call(h, 'POST', '/auth/v1/token?grant_type=password', { body: { email: 'lan@example.com', password: 'secret-pass-1' } });
    assert.equal(early.status, 400);
    assert.equal(early.json.code, 'email_not_confirmed');
    assert.equal(early.headers.get('x-supabase-api-version'), '2024-01-01');

    const back = await follow(h, lastLink(h, 'lan@example.com'));
    assert.equal(`${back.protocol}//${back.host}`, 'babycare://auth-callback');
    const code = back.searchParams.get('code')!;
    const wrong = await call(h, 'POST', '/auth/v1/token?grant_type=pkce', { body: { auth_code: code, code_verifier: pkce().verifier } });
    assert.equal(wrong.json.code, 'bad_code_verifier');

    // A wrong verifier leaves the code for the device that holds the right one.
    const exchanged = await call(h, 'POST', '/auth/v1/token?grant_type=pkce', { body: { auth_code: code, code_verifier: flow.verifier } });
    assert.equal(exchanged.status, 200);
    assert.equal(exchanged.json.user.email, 'lan@example.com');

    const signin = await call(h, 'POST', '/auth/v1/token?grant_type=password', { body: { email: 'lan@example.com', password: 'secret-pass-1' } });
    assert.equal(signin.status, 200);
    assert.equal(signin.json.token_type, 'bearer');
    assert.equal(typeof signin.json.expires_at, 'number');
    assert.match(signin.json.user.email_confirmed_at, iso);
  });

  test('the PKCE code from a link works once', async () => {
    const flow = pkce();
    await call(h, 'POST', '/auth/v1/signup', { body: { email: 'once@example.com', password: 'secret-pass-1', code_challenge: flow.challenge, code_challenge_method: 's256' } });
    const back = await follow(h, lastLink(h, 'once@example.com'));
    const body = { auth_code: back.searchParams.get('code'), code_verifier: flow.verifier };
    assert.equal((await call(h, 'POST', '/auth/v1/token?grant_type=pkce', { body })).status, 200);
    const again = await call(h, 'POST', '/auth/v1/token?grant_type=pkce', { body });
    assert.equal(again.json.code, 'flow_state_not_found');
    // The link itself is single use too.
    const reopened = await follow(h, lastLink(h, 'once@example.com'));
    assert.equal(reopened.searchParams.get('error_code'), 'otp_expired');
  });

  test('signing up with a confirmed email answers a user without identities', async () => {
    const session = await newAccount(h, 'taken@example.com');
    const flow = pkce();
    const again = await call(h, 'POST', '/auth/v1/signup', { body: { email: 'taken@example.com', password: 'other-pass-2', code_challenge: flow.challenge, code_challenge_method: 's256' } });
    assert.equal(again.status, 200);
    assert.deepEqual(again.json.identities, []);
    assert.notEqual(again.json.id, session.user.id);
    const wrong = await call(h, 'POST', '/auth/v1/token?grant_type=password', { body: { email: 'taken@example.com', password: 'other-pass-2' } });
    assert.equal(wrong.json.code, 'invalid_credentials');
  });

  test('short passwords are refused as weak', async () => {
    const reply = await call(h, 'POST', '/auth/v1/signup', { body: { email: 'weak@example.com', password: '123' } });
    assert.equal(reply.status, 422);
    assert.equal(reply.json.code, 'weak_password');
    assert.deepEqual(reply.json.weak_password.reasons, ['length']);
  });

  test('refresh tokens rotate; a quick retry still works, a late replay ends the session', async () => {
    const session = await newAccount(h, 'refresh@example.com');
    const first = await call(h, 'POST', '/auth/v1/token?grant_type=refresh_token', { body: { refresh_token: session.refresh_token } });
    assert.equal(first.status, 200);
    assert.notEqual(first.json.refresh_token, session.refresh_token);
    const retry = await call(h, 'POST', '/auth/v1/token?grant_type=refresh_token', { body: { refresh_token: session.refresh_token } });
    assert.equal(retry.status, 200, 'a retry within the grace window');

    await h.admin.exec(`reset role; update auth.refresh_tokens set revoked_at = now() - interval '1 minute' where revoked; set role babycare_api;`);
    const replay = await call(h, 'POST', '/auth/v1/token?grant_type=refresh_token', { body: { refresh_token: session.refresh_token } });
    assert.equal(replay.json.code, 'refresh_token_already_used');
    const afterReplay = await call(h, 'POST', '/auth/v1/token?grant_type=refresh_token', { body: { refresh_token: first.json.refresh_token } });
    assert.equal(afterReplay.json.code, 'refresh_token_not_found', 'the whole session ended');

    const unknown = await call(h, 'POST', '/auth/v1/token?grant_type=refresh_token', { body: { refresh_token: 'nope' } });
    assert.equal(unknown.json.code, 'refresh_token_not_found');
  });

  test('password recovery: the link signs in, marks itself as recovery, and the password can change', async () => {
    await newAccount(h, 'forgot@example.com', 'old-pass-1');
    const flow = pkce();
    const unknown = await call(h, 'POST', '/auth/v1/recover', { body: { email: 'nobody@example.com', code_challenge: flow.challenge, code_challenge_method: 's256' } });
    assert.equal(unknown.status, 200);
    const recover = await call(h, 'POST', '/auth/v1/recover?redirect_to=babycare%3A//auth-callback', { body: { email: 'forgot@example.com', code_challenge: flow.challenge, code_challenge_method: 's256' } });
    assert.equal(recover.status, 200);
    const back = await follow(h, lastLink(h, 'forgot@example.com'));
    assert.equal(back.searchParams.get('type'), 'recovery');
    const session = await call(h, 'POST', '/auth/v1/token?grant_type=pkce', { body: { auth_code: back.searchParams.get('code'), code_verifier: flow.verifier } });
    assert.equal(session.status, 200);
    const updated = await call(h, 'PUT', '/auth/v1/user', { token: session.json.access_token, body: { password: 'new-pass-2' } });
    assert.equal(updated.status, 200);
    assert.equal(updated.json.email, 'forgot@example.com');
    assert.equal(updated.json.access_token, undefined, 'PUT /user answers a User, not a Session');
    const signin = await call(h, 'POST', '/auth/v1/token?grant_type=password', { body: { email: 'forgot@example.com', password: 'new-pass-2' } });
    assert.equal(signin.status, 200);
  });

  test('a second recovery email within a minute is refused', async () => {
    await newAccount(h, 'twice@example.com');
    const flow = pkce();
    const body = { email: 'twice@example.com', code_challenge: flow.challenge, code_challenge_method: 's256' };
    assert.equal((await call(h, 'POST', '/auth/v1/recover', { body })).status, 200);
    const second = await call(h, 'POST', '/auth/v1/recover', { body });
    assert.equal(second.status, 429);
    assert.equal(second.json.code, 'over_email_send_rate_limit');
  });

  test('local sign-out ends this session only', async () => {
    const one = await newAccount(h, 'signout@example.com');
    const two = (await call(h, 'POST', '/auth/v1/token?grant_type=password', { body: { email: 'signout@example.com', password: 'secret-pass-1' } })).json;
    assert.equal((await call(h, 'POST', '/auth/v1/logout?scope=local', { token: one.access_token })).status, 204);
    const gone = await call(h, 'GET', '/auth/v1/user', { token: one.access_token });
    assert.equal(gone.json.code, 'session_not_found');
    assert.equal((await call(h, 'GET', '/auth/v1/user', { token: two.access_token })).status, 200);
    const refresh = await call(h, 'POST', '/auth/v1/token?grant_type=refresh_token', { body: { refresh_token: one.refresh_token } });
    assert.equal(refresh.json.code, 'refresh_token_not_found');
  });

  test('an unknown redirect falls back to the app callback', async () => {
    const flow = pkce();
    await call(h, 'POST', '/auth/v1/signup?redirect_to=https%3A//evil.example', { body: { email: 'redirect@example.com', password: 'secret-pass-1', code_challenge: flow.challenge, code_challenge_method: 's256' } });
    const back = await follow(h, lastLink(h, 'redirect@example.com'));
    assert.equal(`${back.protocol}//${back.host}`, 'babycare://auth-callback');
  });
});
