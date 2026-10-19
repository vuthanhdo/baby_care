-- Sign in with Apple refresh tokens, kept only so they can be revoked when the account is deleted
-- (App Store Review Guideline 5.1.1(v)). Written and read exclusively by the apple-token Edge Function
-- with the service role; clients never see this table.
create table public.apple_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  refresh_token text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.apple_tokens enable row level security;
revoke all on public.apple_tokens from anon, authenticated;
