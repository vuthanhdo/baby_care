-- What Supabase's platform provided to supabase/migrations, rebuilt for the self-hosted database:
-- the anon/authenticated/service_role roles, auth.users and auth.uid(), and the storage tables the policies sit on.
-- The API runs each request as anon or authenticated with the caller's id in request.jwt.claim.sub, as PostgREST
-- does, so every grant, RLS policy and security definer function in supabase/migrations applies unchanged.
-- Runs before the app migrations, once, as the database owner.

do $$
begin
  if not exists (select from pg_roles where rolname = 'anon') then create role anon nologin noinherit; end if;
  if not exists (select from pg_roles where rolname = 'authenticated') then create role authenticated nologin noinherit; end if;
  if not exists (select from pg_roles where rolname = 'service_role') then create role service_role nologin noinherit bypassrls; end if;
end $$;

create schema if not exists auth;
create schema if not exists storage;

-- Accounts. Column names follow GoTrue so the Supabase export loads as is; passwords stay bcrypt hashes.
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  encrypted_password text,
  email_confirmed_at timestamptz,
  confirmation_sent_at timestamptz,
  recovery_sent_at timestamptz,
  last_sign_in_at timestamptz,
  raw_app_meta_data jsonb not null default '{}',
  raw_user_meta_data jsonb not null default '{}',
  banned_until timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists users_email_key on auth.users (lower(email)) where email is not null;

-- How a user signs in: email, apple or google, with the provider's own subject id.
create table if not exists auth.identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null,
  provider_id text not null,
  identity_data jsonb not null default '{}',
  email text,
  last_sign_in_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (provider, provider_id)
);
create index if not exists identities_user_id on auth.identities (user_id);

-- A signed-in device. Refresh tokens rotate within a session; only their SHA-256 is stored.
create table if not exists auth.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  user_agent text,
  created_at timestamptz not null default now(),
  refreshed_at timestamptz
);
create index if not exists sessions_user_id on auth.sessions (user_id);

create table if not exists auth.refresh_tokens (
  id bigserial primary key,
  session_id uuid not null references auth.sessions(id) on delete cascade,
  token_hash text not null unique,
  revoked boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists refresh_tokens_session_id on auth.refresh_tokens (session_id);

-- Email confirmation and password reset links, and PKCE codes handed back to the app; hashes only, single use.
create table if not exists auth.one_time_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('confirmation', 'recovery', 'pkce')),
  token_hash text not null unique,
  code_challenge text,
  code_challenge_method text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);
create index if not exists one_time_tokens_user_id on auth.one_time_tokens (user_id);

-- Supabase's auth.uid(): the caller's id from the request claims, null for anon.
create or replace function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid
$$;

grant usage on schema auth, storage to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- File metadata. The bytes live on disk; the API inserts or deletes the row as the caller first, so the
-- policies in supabase/migrations decide every upload, read and delete.
create table if not exists storage.buckets (
  id text primary key,
  name text not null,
  public boolean not null default false,
  file_size_limit bigint,
  allowed_mime_types text[],
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null references storage.buckets(id),
  name text not null,
  owner uuid,
  metadata jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (bucket_id, name)
);
alter table storage.objects enable row level security;
grant select, insert, update, delete on storage.objects to authenticated;
grant select on storage.buckets to authenticated;
