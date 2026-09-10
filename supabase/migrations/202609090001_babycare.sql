-- BabyCare v1 backend. Run once as the project database owner.
-- All application writes go through authenticated RPCs, not direct table writes.
begin;

create schema if not exists babycare_private;
revoke all on schema babycare_private from public, anon, authenticated;
grant usage on schema babycare_private to authenticated;

create table public.families (
  id uuid primary key,
  name text not null check (length(btrim(name)) between 1 and 120),
  created_by uuid not null references auth.users(id),
  revision bigint not null default 0,
  created_at timestamptz not null default now()
);
create table public.family_members (
  family_id uuid not null references public.families(id),
  user_id uuid not null references auth.users(id),
  role text not null check (role in ('owner','caregiver','viewer')),
  created_at timestamptz not null default now(),
  primary key (family_id,user_id)
);
create index family_members_user on public.family_members(user_id,family_id);

create table public.babies (
  id uuid primary key,
  family_id uuid not null references public.families(id),
  name text not null check (length(btrim(name)) between 1 and 120),
  birth_date timestamptz not null,
  gender text not null default 'unspecified' check (gender in ('girl','boy','unspecified')),
  blood_type text not null default 'Chưa rõ',
  allergies text not null default '', health_notes text not null default '',
  version bigint not null default 1, revision bigint not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (id,family_id)
);
create table public.care_activities (
  id uuid primary key, family_id uuid not null, baby_id uuid not null,
  kind text not null check (kind in ('temperature','medicine','symptom','doctor','allergy','milk','meal','water','sleep','bath','diaper','other')),
  occurred_at timestamptz not null,
  value text not null check (length(btrim(value)) between 1 and 4000),
  unit text not null default '', note text not null default '', detail text not null default '',
  version bigint not null default 1, revision bigint not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  foreign key (baby_id,family_id) references public.babies(id,family_id),
  unique (id,baby_id,family_id)
);
create index activities_baby_date on public.care_activities(baby_id,occurred_at desc,id);
create table public.body_measurements (
  id uuid primary key, family_id uuid not null, baby_id uuid not null,
  measured_at timestamptz not null,
  weight numeric, height numeric, head_circumference numeric,
  method text not null default '', notes text not null default '',
  version bigint not null default 1, revision bigint not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  foreign key (baby_id,family_id) references public.babies(id,family_id),
  check (coalesce(weight,height,head_circumference) is not null),
  check (weight is null or (weight > 0 and weight < 1000)),
  check (height is null or (height > 0 and height < 1000)),
  check (head_circumference is null or (head_circumference > 0 and head_circumference < 1000))
);
create index measurements_baby_date on public.body_measurements(baby_id,measured_at desc,id);
create table public.baby_care_states (
  id uuid primary key, family_id uuid not null, baby_id uuid not null unique,
  is_tracking_illness boolean not null default false,
  illness_title text not null default '', illness_start_date timestamptz,
  sleep_start_date timestamptz,
  version bigint not null default 1, revision bigint not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  foreign key (baby_id,family_id) references public.babies(id,family_id),
  check (id = baby_id),
  check (not is_tracking_illness or illness_start_date is not null)
);
create table public.medication_reminders (
  id uuid primary key, family_id uuid not null, baby_id uuid not null,
  name text not null check (length(btrim(name)) between 1 and 200),
  amount numeric not null check (amount > 0 and amount < 1000000),
  unit text not null check (unit in ('ml','mg','viên','gói','giọt','lần xịt')),
  next_date timestamptz not null, note text not null default '',
  enabled boolean not null default true, episode_only boolean not null default false,
  version bigint not null default 1, revision bigint not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  foreign key (baby_id,family_id) references public.babies(id,family_id)
);
create index reminders_baby_date on public.medication_reminders(baby_id,next_date,id);
create table public.media_assets (
  id uuid primary key, family_id uuid not null, baby_id uuid not null,
  activity_id uuid, purpose text not null check (purpose in ('avatar','activity')),
  object_path text not null unique,
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/heic','image/webp')),
  byte_count bigint not null check (byte_count between 1 and 5242880),
  status text not null default 'pending' check (status in ('pending','ready')),
  version bigint not null default 1, revision bigint not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  foreign key (baby_id,family_id) references public.babies(id,family_id),
  foreign key (activity_id,baby_id,family_id) references public.care_activities(id,baby_id,family_id),
  check ((purpose='avatar' and activity_id is null) or (purpose='activity' and activity_id is not null)),
  check (object_path = family_id::text || '/' || baby_id::text || '/' || id::text)
);
create table public.import_jobs (
  id uuid primary key, family_id uuid not null references public.families(id),
  user_id uuid not null references auth.users(id),
  source_id uuid not null, status text not null default 'pending' check (status in ('pending','uploading','completed','failed')),
  checkpoint jsonb not null default '{}',
  version bigint not null default 1, revision bigint not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  unique(user_id,family_id,source_id)
);
create table public.mutation_receipts (
  operation_id uuid primary key, family_id uuid not null references public.families(id),
  user_id uuid not null references auth.users(id),
  request jsonb not null, result jsonb not null,
  created_at timestamptz not null default now()
);
create index receipts_family_user on public.mutation_receipts(family_id,user_id);

create function babycare_private.has_role(p_family uuid, p_roles text[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.family_members m
    where m.family_id=p_family and m.user_id=(select auth.uid()) and m.role=any(p_roles));
$$;
revoke all on function babycare_private.has_role(uuid,text[]) from public, anon;
grant execute on function babycare_private.has_role(uuid,text[]) to authenticated;

-- No INSERT/UPDATE/DELETE grants or policies for app tables. RPC enforces versions.
do $$ declare t text; begin
  foreach t in array array['families','family_members','babies','care_activities','body_measurements',
    'baby_care_states','medication_reminders','media_assets','import_jobs','mutation_receipts'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on public.%I from anon, authenticated',t);
    execute format('grant select on public.%I to authenticated',t);
    execute format('create policy family_read on public.%I for select to authenticated using
      (babycare_private.has_role(%I,array[''owner'',''caregiver'',''viewer'']))',t,
      case when t='families' then 'id' else 'family_id' end);
    if t in ('babies','care_activities','body_measurements','baby_care_states','medication_reminders','media_assets','import_jobs') then
      execute format('create index %I on public.%I(family_id,revision,id)',t||'_sync',t);
    end if;
  end loop;
end $$;
-- Receipts contain only the caller's own payload, even within the same family.
create policy own_receipt on public.mutation_receipts as restrictive for select to authenticated
  using (user_id=(select auth.uid()));
create policy own_import on public.import_jobs as restrictive for select to authenticated
  using (user_id=(select auth.uid()));

create function public.babycare_create_family(p_id uuid, p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); existing public.families;
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_id is null then raise exception 'Family ID required' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
  select * into existing from public.families where id=p_id;
  if found then
    if existing.created_by<>u or existing.name<>btrim(p_name) then raise exception 'Family conflict' using errcode='40001'; end if;
    return p_id;
  end if;
  insert into public.families(id,name,created_by) values(p_id,btrim(p_name),u);
  insert into public.family_members(family_id,user_id,role) values(p_id,u,'owner');
  return p_id;
end $$;
revoke all on function public.babycare_create_family(uuid,text) from public, anon;
grant execute on function public.babycare_create_family(uuid,text) to authenticated;

-- Bootstrap media permission against an existing metadata row, never path alone.
create function babycare_private.can_access_media(p_path text, p_write boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.media_assets a
    join public.babies b on b.id=a.baby_id and b.family_id=a.family_id
    where a.object_path=p_path and a.deleted_at is null and b.deleted_at is null
      and (not p_write or a.status='pending')
      and babycare_private.has_role(a.family_id,
        case when p_write then array['owner','caregiver'] else array['owner','caregiver','viewer'] end));
$$;
revoke all on function babycare_private.can_access_media(text,boolean) from public, anon;
grant execute on function babycare_private.can_access_media(text,boolean) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('babycare-media','babycare-media',false,5242880,array['image/jpeg','image/png','image/heic','image/webp']);
create policy babycare_media_read on storage.objects for select to authenticated
using(bucket_id='babycare-media' and babycare_private.can_access_media(name,false));
create policy babycare_media_upload on storage.objects for insert to authenticated
with check(bucket_id='babycare-media' and babycare_private.can_access_media(name,true));
-- Immutable uploads: overwrite and delete need a trusted maintenance workflow.

commit;
