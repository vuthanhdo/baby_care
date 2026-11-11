// Account rows and GoTrue's JSON for them. Passwords are bcrypt hashes, readable from the Supabase export.
import bcrypt from 'bcryptjs';

export interface UserRow {
  id: string;
  email: string | null;
  encrypted_password: string | null;
  email_confirmed_at: string | Date | null;
  confirmation_sent_at: string | Date | null;
  recovery_sent_at: string | Date | null;
  last_sign_in_at: string | Date | null;
  raw_app_meta_data: Record<string, unknown> | null;
  raw_user_meta_data: Record<string, unknown> | null;
  banned_until: string | Date | null;
  created_at: string | Date;
  updated_at: string | Date;
}

export interface IdentityRow {
  id: string;
  user_id: string;
  provider: string;
  provider_id: string;
  identity_data: Record<string, unknown> | null;
  email: string | null;
  last_sign_in_at: string | Date | null;
  created_at: string | Date;
  updated_at: string | Date;
}

export const MIN_PASSWORD_LENGTH = 6;

export function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 10);
}

export async function checkPassword(password: string, hash: string | null): Promise<boolean> {
  if (!hash) return false;
  return bcrypt.compare(password, hash);
}

export function normalizeEmail(email: unknown): string | null {
  if (typeof email !== 'string') return null;
  const trimmed = email.trim().toLowerCase();
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed) ? trimmed : null;
}

const iso = (value: string | Date | null | undefined) => value == null ? null : new Date(value).toISOString();

export function identityJSON(identity: IdentityRow) {
  return {
    identity_id: identity.id,
    id: identity.provider_id,
    user_id: identity.user_id,
    identity_data: identity.identity_data ?? {},
    provider: identity.provider,
    email: identity.email,
    last_sign_in_at: iso(identity.last_sign_in_at),
    created_at: iso(identity.created_at),
    updated_at: iso(identity.updated_at),
  };
}

/** GoTrue's user object. */
export function userJSON(user: UserRow, identities: readonly unknown[] = []) {
  const providers = [...new Set((identities as IdentityRow[]).map(i => i.provider))];
  return {
    id: user.id,
    aud: 'authenticated',
    role: 'authenticated',
    email: user.email ?? '',
    email_confirmed_at: iso(user.email_confirmed_at),
    phone: '',
    confirmation_sent_at: iso(user.confirmation_sent_at),
    recovery_sent_at: iso(user.recovery_sent_at),
    confirmed_at: iso(user.email_confirmed_at),
    last_sign_in_at: iso(user.last_sign_in_at),
    app_metadata: { provider: providers[0] ?? 'email', providers: providers.length ? providers : ['email'], ...(user.raw_app_meta_data ?? {}) },
    user_metadata: user.raw_user_meta_data ?? {},
    identities: (identities as IdentityRow[]).map(identityJSON),
    created_at: iso(user.created_at),
    updated_at: iso(user.updated_at),
    is_anonymous: false,
  };
}
