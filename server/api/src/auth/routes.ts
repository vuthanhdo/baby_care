// /auth/v1: the part of GoTrue the app uses through supabase-swift (PKCE flow). See BACKEND_VPS_PLAN.md and the
// wire spec: every email link and the Google callback end at babycare://auth-callback?code=…, which the SDK
// exchanges at /token?grant_type=pkce.
import { Hono, type Context } from 'hono';
import type { Config } from '../config.ts';
import type { SQL } from '../db.ts';
import { composeMail, type Mailer } from './mail.ts';
import {
  AuthError, allowedRedirect, challengeMatches, createAuthCode, createEmailLink, readChallenge, tooSoon, withParams,
  type Challenge,
} from './flows.ts';
import { userForProvider, verifyAppleIDToken, verifyGoogleIDToken } from './providers.ts';
import { hashToken, randomToken, refreshSession, startSession, verifyAccessToken } from './tokens.ts';
import {
  MIN_PASSWORD_LENGTH, checkPassword, hashPassword, normalizeEmail, userJSON, type IdentityRow, type UserRow,
} from './users.ts';

type Body = Record<string, unknown>;

async function readBody(c: Context): Promise<Body> {
  const text = await c.req.text();
  if (!text.trim()) return {};
  try {
    const value = JSON.parse(text);
    return value && typeof value === 'object' && !Array.isArray(value) ? value : {};
  } catch {
    throw new AuthError(400, 'bad_json', 'Could not parse request body as JSON');
  }
}

const isBanned = (user: UserRow) => user.banned_until != null && new Date(user.banned_until) > new Date();

function requirePassword(password: unknown): string {
  if (typeof password !== 'string' || password.length < MIN_PASSWORD_LENGTH) {
    throw new AuthError(422, 'weak_password', `Password should be at least ${MIN_PASSWORD_LENGTH} characters.`, { weak_password: { reasons: ['length'] } });
  }
  return password;
}

export function authRoutes(config: Config, sql: SQL, mailer: Mailer) {
  const auth = new Hono();

  auth.onError((error, c) => {
    if (error instanceof AuthError) return c.json(error.body(), error.status as 400);
    console.error('auth error', error);
    return c.json(new AuthError(500, 'unexpected_failure', 'Unexpected failure, please check server logs for more information').body(), 500);
  });

  // supabase-swift reads `code` as the error code only when this header says the API is 2024-01-01 or newer.
  auth.use('*', async (c, next) => {
    await next();
    c.header('X-Supabase-Api-Version', '2024-01-01');
  });

  const identitiesOf = (userID: string) =>
    sql<IdentityRow[]>`select * from auth.identities where user_id = ${userID} order by created_at`;

  async function sendLink(user: UserRow, kind: 'confirmation' | 'recovery', redirectTo: string, challenge: Challenge | null) {
    const link = await sql.begin(async tx => {
      const url = await createEmailLink(config, tx, user.id, kind, redirectTo, challenge);
      const column = kind === 'confirmation' ? 'confirmation_sent_at' : 'recovery_sent_at';
      await tx`update auth.users set ${tx(column)} = now(), updated_at = now() where id = ${user.id}`;
      return url;
    });
    try {
      await mailer.send(composeMail(kind, user.email!, link));
    } catch (error) {
      console.error('mail failed', error);
      throw new AuthError(500, 'unexpected_failure', kind === 'confirmation' ? 'Error sending confirmation email' : 'Error sending recovery email');
    }
  }

  // Sign-up: a new account waits for its confirmation link; an unconfirmed one gets the link again; a confirmed one
  // answers with a user that has no identities, which the app reads as "this email already has an account".
  auth.post('/signup', async c => {
    const body = await readBody(c);
    const email = normalizeEmail(body.email);
    if (!email) throw new AuthError(400, 'validation_failed', 'Unable to validate email address: invalid format');
    const password = requirePassword(body.password);
    const challenge = readChallenge(body);
    const redirectTo = allowedRedirect(config, c.req.query('redirect_to'));
    const [existing] = await sql<UserRow[]>`select * from auth.users where lower(email) = ${email}`;
    if (existing?.email_confirmed_at) {
      return c.json({ ...userJSON({ ...existing, id: crypto.randomUUID(), email, last_sign_in_at: null }), identities: [] });
    }
    if (existing && tooSoon(existing.confirmation_sent_at)) {
      throw new AuthError(429, 'over_email_send_rate_limit', 'For security purposes, you can only request this after 60 seconds.');
    }
    const hash = await hashPassword(password);
    const user = existing
      ? (await sql<UserRow[]>`update auth.users set encrypted_password = ${hash}, updated_at = now() where id = ${existing.id} returning *`)[0]!
      : await sql.begin(async tx => {
          const [created] = await tx<UserRow[]>`
            insert into auth.users (email, encrypted_password, raw_app_meta_data)
            values (${email}, ${hash}, ${{ provider: 'email', providers: ['email'] } as never}) returning *`;
          await tx`insert into auth.identities (user_id, provider, provider_id, identity_data, email)
                   values (${created!.id}, 'email', ${created!.id}, ${{ sub: created!.id, email, email_verified: false } as never}, ${email})`;
          return created!;
        });
    await sendLink(user, 'confirmation', redirectTo, challenge);
    const [fresh] = await sql<UserRow[]>`select * from auth.users where id = ${user.id}`;
    return c.json(userJSON(fresh!, await identitiesOf(user.id)));
  });

  auth.post('/resend', async c => {
    const body = await readBody(c);
    if (body.type !== 'signup') throw new AuthError(400, 'validation_failed', 'Missing one of these types: signup, email_change, sms, phone_change');
    const email = normalizeEmail(body.email);
    if (!email) throw new AuthError(400, 'validation_failed', 'Unable to validate email address: invalid format');
    const [user] = await sql<UserRow[]>`select * from auth.users where lower(email) = ${email}`;
    if (user && !user.email_confirmed_at) {
      if (tooSoon(user.confirmation_sent_at)) throw new AuthError(429, 'over_email_send_rate_limit', 'For security purposes, you can only request this after 60 seconds.');
      await sendLink(user, 'confirmation', allowedRedirect(config, c.req.query('redirect_to')), readChallenge(body));
    }
    return c.json({});
  });

  // Unknown emails get the same answer, so the endpoint does not reveal who has an account.
  auth.post('/recover', async c => {
    const body = await readBody(c);
    const email = normalizeEmail(body.email);
    if (!email) throw new AuthError(400, 'validation_failed', 'Unable to validate email address: invalid format');
    const [user] = await sql<UserRow[]>`select * from auth.users where lower(email) = ${email}`;
    if (user && !isBanned(user)) {
      if (tooSoon(user.recovery_sent_at)) throw new AuthError(429, 'over_email_send_rate_limit', 'For security purposes, you can only request this after 60 seconds.');
      await sendLink(user, 'recovery', allowedRedirect(config, c.req.query('redirect_to')), readChallenge(body));
    }
    return c.json({});
  });

  // The emailed link. The email is confirmed here, even if the app never exchanges the code (another device, or a
  // newer email replaced the device's PKCE verifier): the user can then sign in with the password.
  auth.get('/verify', async c => {
    const token = c.req.query('token') ?? '';
    const type = c.req.query('type');
    const fallback = allowedRedirect(config, c.req.query('redirect_to'));
    const kind = type === 'signup' ? 'confirmation' : type === 'recovery' ? 'recovery' : null;
    const fail = (description: string) => c.redirect(withParams(fallback, {
      error: 'access_denied', error_code: 'otp_expired', error_description: description,
    }), 303);
    if (!kind || !token) return fail('Email link is invalid or has expired');
    const result = await sql.begin(async tx => {
      const [link] = await tx<{ id: string; user_id: string; code_challenge: string | null; code_challenge_method: string | null; redirect_to: string | null }[]>`
        delete from auth.one_time_tokens where token_hash = ${hashToken(token)} and kind = ${kind} and expires_at > now()
        returning id, user_id, code_challenge, code_challenge_method, redirect_to`;
      if (!link) return null;
      if (kind === 'confirmation') {
        await tx`update auth.users set email_confirmed_at = coalesce(email_confirmed_at, now()), updated_at = now() where id = ${link.user_id}`;
        await tx`update auth.identities set identity_data = identity_data || '{"email_verified": true}'::jsonb
                 where user_id = ${link.user_id} and provider = 'email'`;
      }
      const redirectTo = allowedRedirect(config, link.redirect_to);
      if (!link.code_challenge) return { redirectTo, code: null };
      const code = await createAuthCode(tx, link.user_id, { challenge: link.code_challenge, method: link.code_challenge_method ?? 's256' }, kind === 'recovery' ? 'recovery' : 'signup');
      return { redirectTo, code };
    });
    if (!result) return fail('Email link is invalid or has expired');
    if (!result.code) return c.redirect(result.redirectTo, 303);
    // `type=recovery` is ignored by the SDK but lets the app open the new-password screen.
    const params: Record<string, string> = { code: result.code };
    if (kind === 'recovery') params.type = 'recovery';
    return c.redirect(withParams(result.redirectTo, params), 303);
  });

  auth.post('/token', async c => {
    const grant = c.req.query('grant_type');
    const body = await readBody(c);
    const userAgent = c.req.header('user-agent') ?? null;
    switch (grant) {
      case 'password': {
        const email = normalizeEmail(body.email);
        const password = typeof body.password === 'string' ? body.password : '';
        const [user] = email ? await sql<UserRow[]>`select * from auth.users where lower(email) = ${email}` : [];
        if (!user || !(await checkPassword(password, user.encrypted_password))) {
          throw new AuthError(400, 'invalid_credentials', 'Invalid login credentials');
        }
        if (!user.email_confirmed_at) throw new AuthError(400, 'email_not_confirmed', 'Email not confirmed');
        if (isBanned(user)) throw new AuthError(400, 'user_banned', 'User is banned');
        return c.json(await sql.begin(tx => startSession(config, tx, user, 'password', userAgent)));
      }
      case 'refresh_token': {
        const token = typeof body.refresh_token === 'string' ? body.refresh_token : '';
        const outcome = await sql.begin(tx => refreshSession(config, tx, token));
        if (!outcome.ok) {
          const message = outcome.code === 'refresh_token_already_used' ? 'Invalid Refresh Token: Already Used'
            : outcome.code === 'user_banned' ? 'User is banned' : 'Invalid Refresh Token: Refresh Token Not Found';
          throw new AuthError(400, outcome.code, message);
        }
        return c.json(outcome.session);
      }
      case 'id_token': {
        if (body.provider !== 'apple') throw new AuthError(400, 'validation_failed', 'Custom OIDC provider "' + String(body.provider) + '" not allowed');
        if (typeof body.id_token !== 'string') throw new AuthError(400, 'validation_failed', 'id_token required');
        const profile = await verifyAppleIDToken(config, body.id_token, typeof body.nonce === 'string' ? body.nonce : undefined);
        return c.json(await sql.begin(async tx => {
          const user = await userForProvider(tx, profile);
          if (isBanned(user)) throw new AuthError(400, 'user_banned', 'User is banned');
          return startSession(config, tx, user, 'oauth', userAgent);
        }));
      }
      case 'pkce': {
        const code = typeof body.auth_code === 'string' ? body.auth_code : '';
        const verifier = typeof body.code_verifier === 'string' ? body.code_verifier : '';
        return c.json(await sql.begin(async tx => {
          const [row] = await tx<{ user_id: string; code_challenge: string; flow: string | null }[]>`
            delete from auth.one_time_tokens where token_hash = ${hashToken(code)} and kind = 'pkce' and expires_at > now()
            returning user_id, code_challenge, flow`;
          if (!row) throw new AuthError(404, 'flow_state_not_found', 'invalid flow state, no valid flow state found');
          if (!verifier || !challengeMatches(verifier, row.code_challenge)) {
            throw new AuthError(400, 'bad_code_verifier', 'code challenge does not match previously saved code verifier');
          }
          const [user] = await tx<UserRow[]>`select * from auth.users where id = ${row.user_id}`;
          if (!user) throw new AuthError(404, 'user_not_found', 'User not found');
          if (isBanned(user)) throw new AuthError(400, 'user_banned', 'User is banned');
          return startSession(config, tx, user, row.flow === 'recovery' ? 'recovery' : row.flow === 'google' ? 'oauth' : 'email/signup', userAgent);
        }));
      }
      default:
        throw new AuthError(400, 'validation_failed', 'unsupported_grant_type');
    }
  });

  async function signedInUser(c: Context): Promise<{ user: UserRow; sessionID: string }> {
    const token = (c.req.header('authorization') ?? '').replace(/^Bearer\s+/i, '');
    const check = await verifyAccessToken(config, sql, token, true);
    if (!check.ok) {
      if (check.reason === 'session') throw new AuthError(403, 'session_not_found', 'Session from session_id claim in JWT does not exist');
      throw new AuthError(403, 'bad_jwt', check.reason === 'expired' ? 'invalid JWT: unable to parse or verify signature, token has invalid claims: token is expired' : 'invalid JWT: unable to parse or verify signature');
    }
    const [user] = await sql<UserRow[]>`select * from auth.users where id = ${check.claims.sub}`;
    if (!user) throw new AuthError(403, 'user_not_found', 'User from sub claim in JWT does not exist');
    return { user, sessionID: check.claims.session_id };
  }

  auth.get('/user', async c => {
    const { user } = await signedInUser(c);
    return c.json(userJSON(user, await identitiesOf(user.id)));
  });

  // The app only changes the password here (after a recovery link); metadata updates are accepted too.
  auth.put('/user', async c => {
    const { user } = await signedInUser(c);
    const body = await readBody(c);
    if (body.email !== undefined && normalizeEmail(body.email) !== user.email) {
      throw new AuthError(422, 'email_change_not_supported', 'Changing the email is not supported');
    }
    let updated: UserRow = user;
    if (body.password !== undefined) {
      const hash = await hashPassword(requirePassword(body.password));
      const [row] = await sql<UserRow[]>`update auth.users set encrypted_password = ${hash}, updated_at = now() where id = ${user.id} returning *`;
      updated = row ?? updated;
    }
    if (body.data && typeof body.data === 'object') {
      const [row] = await sql<UserRow[]>`update auth.users set raw_user_meta_data = raw_user_meta_data || ${body.data as never}, updated_at = now()
                                         where id = ${user.id} returning *`;
      updated = row ?? updated;
    }
    return c.json(userJSON(updated, await identitiesOf(user.id)));
  });

  // scope=local ends this session, global every session of the user, others all but this one.
  auth.post('/logout', async c => {
    const { user, sessionID } = await signedInUser(c);
    const scope = c.req.query('scope') ?? 'global';
    if (scope === 'local') await sql`delete from auth.sessions where id = ${sessionID}`;
    else if (scope === 'others') await sql`delete from auth.sessions where user_id = ${user.id} and id <> ${sessionID}`;
    else await sql`delete from auth.sessions where user_id = ${user.id}`;
    return c.body(null, 204);
  });

  // Google sign-in through the system browser: /authorize → Google → /callback → babycare://auth-callback?code=…
  auth.get('/authorize', async c => {
    const redirectTo = allowedRedirect(config, c.req.query('redirect_to'));
    if (c.req.query('provider') !== 'google' || !config.google) {
      return c.redirect(withParams(redirectTo, { error: 'invalid_request', error_code: 'provider_disabled', error_description: 'Unsupported provider: Provider is not enabled' }), 303);
    }
    const challenge = readChallenge({ code_challenge: c.req.query('code_challenge'), code_challenge_method: c.req.query('code_challenge_method') });
    if (!challenge) return c.redirect(withParams(redirectTo, { error: 'invalid_request', error_description: 'PKCE code challenge required' }), 303);
    const state = randomToken(24);
    await sql`insert into auth.flow_states (state_hash, provider, code_challenge, code_challenge_method, redirect_to, expires_at)
              values (${hashToken(state)}, 'google', ${challenge.challenge}, ${challenge.method}, ${redirectTo}, now() + interval '10 minutes')`;
    const google = new URL('https://accounts.google.com/o/oauth2/v2/auth');
    google.search = new URLSearchParams({
      client_id: config.google.clientID,
      redirect_uri: `${config.siteURL}/auth/v1/callback`,
      response_type: 'code',
      scope: 'openid email profile',
      state,
    }).toString();
    return c.redirect(google.toString(), 302);
  });

  auth.get('/callback', async c => {
    const state = c.req.query('state') ?? '';
    const [flow] = await sql<{ code_challenge: string; code_challenge_method: string; redirect_to: string }[]>`
      delete from auth.flow_states where state_hash = ${hashToken(state)} and expires_at > now()
      returning code_challenge, code_challenge_method, redirect_to`;
    const redirectTo = flow ? allowedRedirect(config, flow.redirect_to) : allowedRedirect(config, null);
    const fail = (code: string, description: string) => c.redirect(withParams(redirectTo, { error: 'server_error', error_code: code, error_description: description }), 303);
    if (!flow || !config.google) return fail('bad_oauth_state', 'OAuth state is invalid or has expired');
    if (c.req.query('error')) return fail('provider_error', c.req.query('error_description') ?? c.req.query('error')!);
    try {
      const response = await fetch('https://oauth2.googleapis.com/token', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          code: c.req.query('code') ?? '',
          client_id: config.google.clientID,
          client_secret: config.google.clientSecret,
          redirect_uri: `${config.siteURL}/auth/v1/callback`,
          grant_type: 'authorization_code',
        }),
      });
      const tokens = await response.json() as { id_token?: string };
      if (!response.ok || !tokens.id_token) return fail('bad_oauth_callback', 'Unable to exchange external code');
      const profile = await verifyGoogleIDToken(config, tokens.id_token);
      const code = await sql.begin(async tx => {
        const user = await userForProvider(tx, profile);
        if (isBanned(user)) throw new AuthError(400, 'user_banned', 'User is banned');
        return createAuthCode(tx, user.id, { challenge: flow.code_challenge, method: flow.code_challenge_method }, 'google');
      });
      return c.redirect(withParams(redirectTo, { code }), 303);
    } catch (error) {
      if (error instanceof AuthError) return fail(error.code, error.message);
      console.error('google callback failed', error);
      return fail('unexpected_failure', 'Unexpected failure');
    }
  });

  return auth;
}
