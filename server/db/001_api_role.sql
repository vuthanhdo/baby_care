-- The role the API logs in with (its password is set by scripts/migrate.sh from .env). It is not a superuser:
-- it manages the auth tables itself and switches to anon, authenticated or service_role for everything else,
-- so the grants and RLS policies of the app migrations decide what each request may do.
do $$
begin
  if not exists (select from pg_roles where rolname = 'babycare_api') then create role babycare_api noinherit; end if;
end $$;

grant anon, authenticated, service_role to babycare_api;
grant usage on schema auth, storage to babycare_api;
grant select, insert, update, delete on auth.users, auth.identities, auth.sessions, auth.refresh_tokens, auth.one_time_tokens to babycare_api;
grant usage on all sequences in schema auth to babycare_api;
grant select on storage.buckets to babycare_api;
