// Requests shaped like supabase-swift's (see the wire spec): apikey on every call, the publishable key as bearer
// when signed out, PKCE S256 challenges, uppercase UUIDs.
import { createHash, randomBytes } from 'node:crypto';
import type { Harness } from './harness.ts';

export interface Reply { status: number; json: any; headers: Headers; bytes: Uint8Array }

export async function call(h: Harness, method: string, path: string, options: { token?: string; body?: unknown; raw?: BodyInit; headers?: Record<string, string> } = {}): Promise<Reply> {
  const headers: Record<string, string> = {
    apikey: h.config.publishableKey,
    Authorization: `Bearer ${options.token ?? h.config.publishableKey}`,
    ...options.headers,
  };
  let body: BodyInit | undefined = options.raw;
  if (options.body !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(options.body);
  }
  const response = await h.app.request(path, { method, headers, body });
  const bytes = new Uint8Array(await response.arrayBuffer());
  const text = new TextDecoder().decode(bytes);
  let json: any = undefined;
  try { json = text ? JSON.parse(text) : undefined; } catch { json = undefined; }
  return { status: response.status, json, headers: response.headers, bytes };
}

export function pkce() {
  const verifier = randomBytes(64).toString('base64url');
  const challenge = createHash('sha256').update(verifier).digest('base64url');
  return { verifier, challenge, method: 's256' };
}

/** The link in the last email sent to `to`. */
export function lastLink(h: Harness, to: string): string {
  const mail = [...h.mail].reverse().find(message => message.to === to);
  if (!mail) throw new Error(`no mail to ${to}`);
  return mail.text.split('\n').at(-1)!;
}

/** Opens an emailed link like the browser would, returning the redirect target. */
export async function follow(h: Harness, link: string): Promise<URL> {
  const url = new URL(link);
  const response = await h.app.request(url.pathname + url.search);
  const location = response.headers.get('location');
  if (!location) throw new Error(`no redirect from ${link} (${response.status})`);
  return new URL(location);
}

/** Signs up, confirms through the emailed link and the PKCE exchange, and returns the session. */
export async function newAccount(h: Harness, email: string, password = 'secret-pass-1') {
  const flow = pkce();
  const signup = await call(h, 'POST', '/auth/v1/signup?redirect_to=babycare%3A//auth-callback',
    { body: { email, password, code_challenge: flow.challenge, code_challenge_method: flow.method } });
  if (signup.status !== 200) throw new Error(`signup failed ${signup.status} ${JSON.stringify(signup.json)}`);
  const back = await follow(h, lastLink(h, email));
  const session = await call(h, 'POST', '/auth/v1/token?grant_type=pkce', { body: { auth_code: back.searchParams.get('code'), code_verifier: flow.verifier } });
  if (session.status !== 200) throw new Error(`pkce failed ${session.status} ${JSON.stringify(session.json)}`);
  return session.json as { access_token: string; refresh_token: string; user: { id: string; email: string } };
}

/** Accepts the current consent versions, as the app's onboarding does. */
export async function acceptConsent(h: Harness, token: string) {
  const required = await call(h, 'POST', '/rest/v1/rpc/babycare_consent_requirements', { token });
  const result = await call(h, 'POST', '/rest/v1/rpc/babycare_accept_consent', { token, body: {
    p_terms_version: required.json.terms_version, p_privacy_version: required.json.privacy_version,
    p_health_version: required.json.health_version, p_terms_accepted: true, p_health_accepted: true, p_representative_confirmed: true,
  } });
  if (result.status !== 200) throw new Error(`consent failed ${result.status} ${JSON.stringify(result.json)}`);
}
