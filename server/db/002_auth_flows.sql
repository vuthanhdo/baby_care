-- Details the auth flows need beyond 000_platform.sql.
-- A refresh token used again within a few seconds of its rotation is a client retry, not theft; revoked_at
-- tells the two apart. Email links remember where to send the user back; Google sign-in keeps the app's PKCE
-- challenge in a flow state until Google answers, before any user is known.
alter table auth.refresh_tokens add column if not exists revoked_at timestamptz;
alter table auth.one_time_tokens add column if not exists redirect_to text;
-- For PKCE codes: which flow produced it (signup, recovery, google...), so recovery can be told apart.
alter table auth.one_time_tokens add column if not exists flow text;

create table if not exists auth.flow_states (
  id uuid primary key default gen_random_uuid(),
  state_hash text not null unique,
  provider text not null,
  code_challenge text not null,
  code_challenge_method text not null,
  redirect_to text not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

grant select, insert, update, delete on auth.flow_states to babycare_api;
