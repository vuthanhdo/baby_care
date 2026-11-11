// Pieces shared by the auth routes: GoTrue-shaped errors, redirect allow-listing, PKCE codes and email links.
import { createHash } from 'node:crypto';
import type { Config } from '../config.ts';
import type { Transaction } from '../db.ts';
import { hashToken, randomToken } from './tokens.ts';

/** GoTrue's error JSON. `code` must be a string: a number makes supabase-swift unable to read the error. */
export class AuthError extends Error {
  readonly status: number;
  readonly code: string;
  readonly extra?: Record<string, unknown>;
  constructor(status: number, code: string, message: string, extra?: Record<string, unknown>) {
    super(message);
    this.status = status;
    this.code = code;
    this.extra = extra;
  }
  body() {
    return { code: this.code, error_code: this.code, msg: this.message, ...this.extra };
  }
}

export const LINK_LIFETIME = { confirmation: 24 * 3600, recovery: 3600 } as const;
const PKCE_CODE_SECONDS = 5 * 60;
export const EMAIL_INTERVAL_SECONDS = 60;

/** Where an auth flow may send the user back: an allow-listed URL, else the first one (the app's callback). */
export function allowedRedirect(config: Config, requested: string | undefined | null): string {
  const fallback = config.redirectAllowList[0] ?? config.siteURL;
  if (!requested) return fallback;
  return config.redirectAllowList.some(allowed => requested === allowed || requested.startsWith(`${allowed}?`) || requested.startsWith(`${allowed}#`))
    ? requested
    : fallback;
}

export function withParams(url: string, params: Record<string, string>): string {
  const query = new URLSearchParams(params).toString();
  return `${url}${url.includes('?') ? '&' : '?'}${query}`;
}

export interface Challenge { challenge: string; method: string }

/** The app always sends S256 ("s256"); plain challenges are refused. */
export function readChallenge(body: Record<string, unknown>): Challenge | null {
  const challenge = body.code_challenge;
  const method = typeof body.code_challenge_method === 'string' ? body.code_challenge_method.toLowerCase() : '';
  if (typeof challenge !== 'string' || !challenge) return null;
  if (method !== 's256') throw new AuthError(400, 'validation_failed', 'code_challenge_method must be s256');
  if (!/^[A-Za-z0-9_-]{43}$/.test(challenge)) throw new AuthError(400, 'validation_failed', 'Invalid code_challenge');
  return { challenge, method };
}

export function challengeMatches(verifier: string, challenge: string): boolean {
  return createHash('sha256').update(verifier).digest('base64url') === challenge;
}

/** A single-use code the app exchanges at /token?grant_type=pkce, bound to the app's challenge. */
export async function createAuthCode(tx: Transaction, userID: string, challenge: Challenge, flow: string): Promise<string> {
  const code = randomToken(24);
  await tx`insert into auth.one_time_tokens (user_id, kind, token_hash, code_challenge, code_challenge_method, flow, expires_at)
           values (${userID}, 'pkce', ${hashToken(code)}, ${challenge.challenge}, ${challenge.method}, ${flow},
                   now() + make_interval(secs => ${PKCE_CODE_SECONDS}))`;
  return code;
}

/**
 * Creates the token behind an emailed confirmation or reset link, replacing earlier ones of that kind: the app keeps
 * a single PKCE verifier, so only the newest link can complete the exchange on the device anyway.
 */
export async function createEmailLink(config: Config, tx: Transaction, userID: string, kind: 'confirmation' | 'recovery',
                                      redirectTo: string, challenge: Challenge | null): Promise<string> {
  const token = randomToken(32);
  await tx`delete from auth.one_time_tokens where user_id = ${userID} and kind = ${kind}`;
  await tx`insert into auth.one_time_tokens (user_id, kind, token_hash, code_challenge, code_challenge_method, redirect_to, expires_at)
           values (${userID}, ${kind}, ${hashToken(token)}, ${challenge?.challenge ?? null}, ${challenge?.method ?? null}, ${redirectTo},
                   now() + make_interval(secs => ${LINK_LIFETIME[kind]}))`;
  const type = kind === 'confirmation' ? 'signup' : 'recovery';
  return `${config.siteURL}/auth/v1/verify?${new URLSearchParams({ token, type, redirect_to: redirectTo })}`;
}

/** GoTrue refuses to send another email to the same address within a minute. */
export function tooSoon(sentAt: string | Date | null): boolean {
  return sentAt != null && Date.now() - new Date(sentAt).getTime() < EMAIL_INTERVAL_SECONDS * 1000;
}
