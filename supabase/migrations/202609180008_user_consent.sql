-- Additive migration: existing users require consent; no historical acceptance is inferred.
begin;
create table public.consent_requirements (
  singleton boolean primary key default true check(singleton),
  terms_version text not null,
  privacy_version text not null,
  health_version text not null,
  updated_at timestamptz not null default now()
);
insert into public.consent_requirements values(true,'1.0','1.0','1.0',now());
create table public.user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  terms_version text not null,
  privacy_version text not null,
  health_version text not null,
  terms_accepted_at timestamptz not null,
  privacy_accepted_at timestamptz not null,
  health_accepted_at timestamptz not null,
  representative_confirmed boolean not null check(representative_confirmed),
  representative_confirmed_at timestamptz not null,
  created_at timestamptz not null,
  unique(user_id,terms_version,privacy_version,health_version)
);
alter table public.consent_requirements enable row level security;
alter table public.user_consents enable row level security;
revoke all on public.consent_requirements,public.user_consents from anon,authenticated;
-- Audit records are append-only to clients; only RPCs expose the authenticated user's status.

create function babycare_private.has_current_consent() returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.user_consents c cross join public.consent_requirements r
    where c.user_id=auth.uid() and c.terms_version=r.terms_version
      and c.privacy_version=r.privacy_version and c.health_version=r.health_version
      and c.representative_confirmed);
$$;
create function public.babycare_consent_requirements() returns jsonb
language sql stable security definer set search_path='' as $$
  select jsonb_build_object('terms_version',terms_version,'privacy_version',privacy_version,
    'health_version',health_version) from public.consent_requirements where singleton;
$$;
create function public.babycare_consent_status() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare u uuid:=auth.uid(); accepted jsonb;
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select to_jsonb(c)-'user_id'-'id' into accepted from public.user_consents c
    where c.user_id=u order by
      (c.terms_version=(public.babycare_consent_requirements()->>'terms_version')
       and c.privacy_version=(public.babycare_consent_requirements()->>'privacy_version')
       and c.health_version=(public.babycare_consent_requirements()->>'health_version')) desc,
      c.created_at desc limit 1;
  return jsonb_build_object('required',public.babycare_consent_requirements(),
    'accepted',accepted,'valid',babycare_private.has_current_consent());
end $$;
create function babycare_private.require_current_consent() returns void
language plpgsql security definer set search_path='' as $$
begin
  perform 1 from public.consent_requirements where singleton for share;
  if not babycare_private.has_current_consent() then
    raise exception 'CONSENT_REQUIRED' using errcode='P0001',
      detail=public.babycare_consent_requirements()::text;
  end if;
end $$;
create function public.babycare_accept_consent(p_terms_version text,p_privacy_version text,
  p_health_version text,p_terms_accepted boolean,p_health_accepted boolean,p_representative_confirmed boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid:=auth.uid(); r public.consent_requirements; stamp timestamptz:=statement_timestamp();
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  select * into strict r from public.consent_requirements where singleton for share;
  if p_terms_accepted is distinct from true or p_health_accepted is distinct from true
    or p_representative_confirmed is distinct from true then
    raise exception 'All confirmations required' using errcode='22023';
  end if;
  if p_terms_version is distinct from r.terms_version or p_privacy_version is distinct from r.privacy_version
    or p_health_version is distinct from r.health_version then
    raise exception 'CONSENT_REQUIRED' using errcode='P0001',detail=public.babycare_consent_requirements()::text;
  end if;
  insert into public.user_consents(user_id,terms_version,privacy_version,health_version,
    terms_accepted_at,privacy_accepted_at,health_accepted_at,representative_confirmed,
    representative_confirmed_at,created_at)
  values(u,r.terms_version,r.privacy_version,r.health_version,stamp,stamp,stamp,true,stamp,stamp)
  on conflict(user_id,terms_version,privacy_version,health_version) do nothing;
  return public.babycare_consent_status();
end $$;

-- Guard before the existing mutation RPC, including idempotent receipt replay.
alter function public.babycare_apply(uuid,uuid,jsonb,integer) set schema babycare_private;
create function public.babycare_apply(p_operation_id uuid,p_family_id uuid,p_changes jsonb,p_api_version integer default 1)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform babycare_private.require_current_consent();
  return babycare_private.babycare_apply(p_operation_id,p_family_id,p_changes,p_api_version);
end $$;
revoke all on function babycare_private.babycare_apply(uuid,uuid,jsonb,integer) from public,anon,authenticated;

-- Also cover future RPCs and caregiver invitations at the common database boundary.
create function babycare_private.guard_consent_write() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  -- Administrative maintenance without a user session remains possible.
  if auth.uid() is not null or current_setting('role',true) in ('authenticated','anon') then
    perform babycare_private.require_current_consent();
  end if;
  return new;
end $$;
do $$ declare t text; begin
  foreach t in array array['babies','care_activities','body_measurements','baby_care_states',
    'medication_reminders','vaccinations','media_assets','import_jobs','family_members'] loop
    execute format('create trigger consent_required before insert or update on public.%I
      for each row execute function babycare_private.guard_consent_write()',t);
  end loop;
end $$;
-- Restrictive policies compose with existing family/media permissions. Reads and erasure remain allowed.
create function babycare_private.require_media_consent(p_bucket text) returns boolean
language plpgsql security definer set search_path='' as $$
begin
  if p_bucket='babycare-media' then perform babycare_private.require_current_consent(); end if;
  return true;
end $$;
create policy babycare_consent_upload on storage.objects as restrictive for insert to authenticated
with check(babycare_private.require_media_consent(bucket_id));
create policy babycare_consent_overwrite on storage.objects as restrictive for update to authenticated
using(babycare_private.require_media_consent(bucket_id))
with check(babycare_private.require_media_consent(bucket_id));

revoke all on function babycare_private.has_current_consent(),babycare_private.require_current_consent(),
  babycare_private.require_media_consent(text),
  babycare_private.guard_consent_write(),public.babycare_consent_requirements(),public.babycare_consent_status(),
  public.babycare_accept_consent(text,text,text,boolean,boolean,boolean),
  public.babycare_apply(uuid,uuid,jsonb,integer) from public,anon,authenticated;
grant execute on function babycare_private.require_media_consent(text) to authenticated;
grant execute on function public.babycare_consent_requirements() to anon,authenticated;
grant execute on function public.babycare_consent_status(),
  public.babycare_accept_consent(text,text,text,boolean,boolean,boolean),
  public.babycare_apply(uuid,uuid,jsonb,integer) to authenticated;
notify pgrst,'reload schema';
commit;
