// Access tokens (HS256 JWTs with GoTrue's claims) and opaque refresh tokens that rotate on every use.
import { createHash, randomBytes } from 'node:crypto';
import { SignJWT, errors, jwtVerify } from 'jose';
import type { Config } from '../config.ts';
import type { SQL, Transaction } from '../db.ts';
import { userJSON, type UserRow } from './users.ts';

export interface AccessClaims {
  sub: string;
  email?: string;
  session_id: string;
  exp: number;
}

/** A rotated refresh token presented again within this many seconds is a client retry and still works. */
export const REUSE_GRACE_SECONDS = 10;

const key = (config: Config) => new TextEncoder().encode(config.jwtSecret);

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function randomToken(bytes = 32): string {
  return randomBytes(bytes).toString('base64url');
}

export async function signAccessToken(config: Config, user: UserRow, sessionID: string, method: string, now = Date.now()) {
  const issuedAt = Math.floor(now / 1000);
  const expiresAt = issuedAt + config.accessTokenSeconds;
  const token = await new SignJWT({
    email: user.email ?? '',
    phone: '',
    role: 'authenticated',
    aal: 'aal1',
    amr: [{ method, timestamp: issuedAt }],
    session_id: sessionID,
    is_anonymous: false,
    app_metadata: user.raw_app_meta_data ?? {},
    user_metadata: user.raw_user_meta_data ?? {},
  })
    .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
    .setSubject(user.id)
    .setAudience('authenticated')
    .setIssuer(`${config.siteURL}/auth/v1`)
    .setIssuedAt(issuedAt)
    .setExpirationTime(expiresAt)
    .sign(key(config));
  return { token, expiresAt };
}

export type TokenCheck = { ok: true; claims: AccessClaims } | { ok: false; reason: 'expired' | 'invalid' | 'session' };

/**
 * Verifies an access token. REST, Storage and Functions trust the signature and expiry alone, as PostgREST does;
 * the auth endpoints pass `checkSession` so a signed-out session is refused at once.
 */
export async function verifyAccessToken(config: Config, sql: SQL, token: string, checkSession = false): Promise<TokenCheck> {
  try {
    const { payload } = await jwtVerify(token, key(config), { audience: 'authenticated', algorithms: ['HS256'] });
    if (typeof payload.sub !== 'string' || typeof payload.session_id !== 'string') return { ok: false, reason: 'invalid' };
    if (checkSession) {
      const [session] = await sql`select 1 from auth.sessions where id = ${payload.session_id} and user_id = ${payload.sub}`;
      if (!session) return { ok: false, reason: 'session' };
    }
    return { ok: true, claims: { sub: payload.sub, email: payload.email as string | undefined, session_id: payload.session_id, exp: payload.exp ?? 0 } };
  } catch (error) {
    return { ok: false, reason: error instanceof errors.JWTExpired ? 'expired' : 'invalid' };
  }
}

/** A new session for the user, with its first refresh token; returns GoTrue's session JSON. */
export async function startSession(config: Config, tx: Transaction, user: UserRow, method: string, userAgent?: string | null) {
  const [session] = await tx<{ id: string }[]>`
    insert into auth.sessions (user_id, user_agent) values (${user.id}, ${userAgent ?? null}) returning id`;
  const [updated] = await tx<UserRow[]>`update auth.users set last_sign_in_at = now(), updated_at = now() where id = ${user.id} returning *`;
  return issue(config, tx, updated ?? user, session!.id, method);
}

export type RefreshOutcome = { ok: true; session: Awaited<ReturnType<typeof issue>> } | { ok: false; code: 'refresh_token_not_found' | 'refresh_token_already_used' | 'user_banned' };

/**
 * Exchanges a refresh token for a new pair and revokes the old one. Presenting a revoked token again ends the whole
 * session (the token leaked or is being replayed), unless it was revoked moments ago: the SDK retries a POST once
 * when a response is lost, and that retry must not sign the user out.
 */
export async function refreshSession(config: Config, tx: Transaction, refreshToken: string): Promise<RefreshOutcome> {
  const [row] = await tx<{ id: string; session_id: string; revoked: boolean; revoked_at: Date | null; user_id: string }[]>`
    select t.id, t.session_id, t.revoked, t.revoked_at, s.user_id from auth.refresh_tokens t
    join auth.sessions s on s.id = t.session_id where t.token_hash = ${hashToken(refreshToken)} for update of t`;
  if (!row) return { ok: false, code: 'refresh_token_not_found' };
  if (row.revoked) {
    const age = row.revoked_at ? (Date.now() - new Date(row.revoked_at).getTime()) / 1000 : Infinity;
    if (age > REUSE_GRACE_SECONDS) {
      await tx`delete from auth.sessions where id = ${row.session_id}`;
      return { ok: false, code: 'refresh_token_already_used' };
    }
  } else {
    await tx`update auth.refresh_tokens set revoked = true, revoked_at = now() where id = ${row.id}`;
  }
  await tx`update auth.sessions set refreshed_at = now() where id = ${row.session_id}`;
  const [user] = await tx<UserRow[]>`select * from auth.users where id = ${row.user_id}`;
  if (!user) return { ok: false, code: 'refresh_token_not_found' };
  if (user.banned_until && new Date(user.banned_until) > new Date()) return { ok: false, code: 'user_banned' };
  return { ok: true, session: await issue(config, tx, user, row.session_id, 'token_refresh') };
}

async function issue(config: Config, tx: Transaction, user: UserRow, sessionID: string, method: string) {
  const refreshToken = randomToken();
  await tx`insert into auth.refresh_tokens (session_id, token_hash) values (${sessionID}, ${hashToken(refreshToken)})`;
  const { token, expiresAt } = await signAccessToken(config, user, sessionID, method);
  const identities = await tx`select * from auth.identities where user_id = ${user.id} order by created_at`;
  return {
    access_token: token,
    token_type: 'bearer',
    expires_in: config.accessTokenSeconds,
    expires_at: expiresAt,
    refresh_token: refreshToken,
    user: userJSON(user, identities),
  };
}
