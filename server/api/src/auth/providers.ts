// Sign in with Apple (the app's native id_token) and Google (browser OAuth): verify the provider's token, then find
// or create the account. Like GoTrue, a verified email that already has an account links to it instead of creating
// a second one.
import { createHash } from 'node:crypto';
import { createRemoteJWKSet, jwtVerify, type JWTPayload } from 'jose';
import type { Config } from '../config.ts';
import type { Transaction } from '../db.ts';
import { AuthError } from './flows.ts';
import type { UserRow } from './users.ts';

const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));
const googleKeys = createRemoteJWKSet(new URL('https://www.googleapis.com/oauth2/v3/certs'));

export interface ProviderProfile { provider: 'apple' | 'google'; subject: string; email: string | null; emailVerified: boolean; claims: JWTPayload }

/** The app sends the raw nonce; Apple's token carries its lowercase hex SHA-256. */
export async function verifyAppleIDToken(config: Config, idToken: string, rawNonce: string | undefined): Promise<ProviderProfile> {
  let payload: JWTPayload;
  try {
    ({ payload } = await jwtVerify(idToken, appleKeys, { issuer: 'https://appleid.apple.com', audience: config.apple.bundleID }));
  } catch {
    throw new AuthError(400, 'bad_oauth_callback', 'Invalid Apple id_token');
  }
  if (payload.nonce !== undefined || rawNonce) {
    const expected = createHash('sha256').update(rawNonce ?? '').digest('hex');
    if (payload.nonce !== expected) throw new AuthError(400, 'bad_oauth_callback', 'Nonces mismatch');
  }
  if (typeof payload.sub !== 'string') throw new AuthError(400, 'bad_oauth_callback', 'Apple id_token has no subject');
  const email = typeof payload.email === 'string' ? payload.email.toLowerCase() : null;
  return { provider: 'apple', subject: payload.sub, email, emailVerified: payload.email_verified === true || payload.email_verified === 'true', claims: payload };
}

export async function verifyGoogleIDToken(config: Config, idToken: string): Promise<ProviderProfile> {
  if (!config.google) throw new AuthError(400, 'provider_disabled', 'Unsupported provider: Provider is not enabled');
  let payload: JWTPayload;
  try {
    ({ payload } = await jwtVerify(idToken, googleKeys, { issuer: ['https://accounts.google.com', 'accounts.google.com'], audience: config.google.clientID }));
  } catch {
    throw new AuthError(400, 'bad_oauth_callback', 'Invalid Google id_token');
  }
  if (typeof payload.sub !== 'string') throw new AuthError(400, 'bad_oauth_callback', 'Google id_token has no subject');
  const email = typeof payload.email === 'string' ? payload.email.toLowerCase() : null;
  return { provider: 'google', subject: payload.sub, email, emailVerified: payload.email_verified === true, claims: payload };
}

/** The account for a provider identity: existing identity, else the account with the same verified email, else new. */
export async function userForProvider(tx: Transaction, profile: ProviderProfile): Promise<UserRow> {
  const identityData = { sub: profile.subject, email: profile.email, email_verified: profile.emailVerified, iss: profile.claims.iss, provider_id: profile.subject };
  const [linked] = await tx<UserRow[]>`
    select u.* from auth.identities i join auth.users u on u.id = i.user_id
    where i.provider = ${profile.provider} and i.provider_id = ${profile.subject}`;
  if (linked) {
    await tx`update auth.identities set last_sign_in_at = now(), updated_at = now(), identity_data = ${identityData as never}
             where provider = ${profile.provider} and provider_id = ${profile.subject}`;
    return linked;
  }
  let user: UserRow | undefined;
  if (profile.email && profile.emailVerified) {
    [user] = await tx<UserRow[]>`select * from auth.users where lower(email) = ${profile.email}`;
    if (user && !user.email_confirmed_at) {
      // The provider proved the address; an unconfirmed password account with it is confirmed by the same proof.
      [user] = await tx<UserRow[]>`update auth.users set email_confirmed_at = now(), updated_at = now() where id = ${user.id} returning *`;
    }
  }
  if (!user) {
    [user] = await tx<UserRow[]>`
      insert into auth.users (email, email_confirmed_at, raw_app_meta_data, raw_user_meta_data)
      values (${profile.email}, ${profile.emailVerified ? new Date() : null},
              ${{ provider: profile.provider, providers: [profile.provider] } as never}, ${identityData as never})
      returning *`;
  }
  await tx`insert into auth.identities (user_id, provider, provider_id, identity_data, email, last_sign_in_at)
           values (${user!.id}, ${profile.provider}, ${profile.subject}, ${identityData as never}, ${profile.email}, now())`;
  return user!;
}
