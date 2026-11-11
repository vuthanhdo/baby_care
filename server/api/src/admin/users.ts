// Accounts made by the operator rather than through sign-up, such as the App Review demo account: confirmed at
// once, since no confirmation email is involved. An existing account keeps its ID and data and gets the new password.
import type { SQL } from '../db.ts';
import { MIN_PASSWORD_LENGTH, hashPassword, normalizeEmail, type UserRow } from '../auth/users.ts';

export async function ensureConfirmedUser(sql: SQL, rawEmail: unknown, password: unknown): Promise<{ id: string; created: boolean }> {
  const email = normalizeEmail(rawEmail);
  if (!email) throw new Error('invalid email');
  if (typeof password !== 'string' || password.length < MIN_PASSWORD_LENGTH) throw new Error(`password needs at least ${MIN_PASSWORD_LENGTH} characters`);
  const hash = await hashPassword(password);
  return sql.begin(async tx => {
    const [existing] = await tx<UserRow[]>`select * from auth.users where lower(email) = ${email} for update`;
    if (existing) {
      await tx`update auth.users set encrypted_password = ${hash}, email_confirmed_at = coalesce(email_confirmed_at, now()),
                 updated_at = now() where id = ${existing.id}`;
      await tx`update auth.identities set identity_data = identity_data || '{"email_verified": true}'::jsonb
               where user_id = ${existing.id} and provider = 'email'`;
      return { id: existing.id, created: false };
    }
    const [created] = await tx<UserRow[]>`
      insert into auth.users (email, encrypted_password, email_confirmed_at, raw_app_meta_data)
      values (${email}, ${hash}, now(), ${{ provider: 'email', providers: ['email'] } as never}) returning *`;
    await tx`insert into auth.identities (user_id, provider, provider_id, identity_data, email)
             values (${created!.id}, 'email', ${created!.id}, ${{ sub: created!.id, email, email_verified: true } as never}, ${email})`;
    return { id: created!.id, created: true };
  }) as Promise<{ id: string; created: boolean }>;
}
