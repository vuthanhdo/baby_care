-- Shared care: a parent invites another caregiver into the family, who then reads and writes for every baby
-- in it under the existing family RLS. Additive: 1.0.x and 1.1 keep working and never see an invite.
-- Also makes account deletion and photo deletion safe once a family has more than one member.
begin;

-- Only the hash of an invite code is stored. Codes are single use and expire after 48 hours.
create table babycare_private.family_invites (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  code_hash bytea not null unique,
  role text not null check (role in ('caregiver','viewer')),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  accepted_by uuid references auth.users(id) on delete set null,
  accepted_at timestamptz,
  revoked_at timestamptz
);
create index family_invites_family on babycare_private.family_invites(family_id,expires_at);
-- Wrong codes per user, to stop guessing.
create table babycare_private.invite_attempts (
  user_id uuid not null references auth.users(id) on delete cascade,
  attempted_at timestamptz not null default now()
);
create index invite_attempts_user on babycare_private.invite_attempts(user_id,attempted_at);
-- An owner deleting a baby of a shared family first records the intent; only then may Storage delete its photos.
create table babycare_private.baby_deletions (
  baby_id uuid primary key,
  family_id uuid not null,
  requested_by uuid not null references auth.users(id) on delete cascade,
  requested_at timestamptz not null default now(),
  foreign key (baby_id,family_id) references public.babies(id,family_id) on delete cascade
);
revoke all on babycare_private.family_invites,babycare_private.invite_attempts,babycare_private.baby_deletions
  from public,anon,authenticated;

create function babycare_private.invite_code() returns text
language plpgsql volatile set search_path='' as $$
declare
  -- No I, L, O, 0 or 1: the code is read aloud and typed by hand.
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea := sha256(uuid_send(gen_random_uuid()) || uuid_send(gen_random_uuid()));
  code text := '';
begin
  for i in 0..7 loop code := code || substr(alphabet,get_byte(bytes,i) % 31 + 1,1); end loop;
  return code;
end $$;

create function babycare_private.invite_hash(p_code text) returns bytea
language sql immutable set search_path='' as $$
  select sha256(convert_to(upper(regexp_replace(coalesce(p_code,''),'[^A-Za-z0-9]','','g')),'UTF8'));
$$;

-- Account deletion hands shared families over even if the leaving user has not accepted a newer policy.
-- Clients cannot set this setting: PostgREST only exposes functions of the public schema.
create or replace function babycare_private.guard_consent_write() returns trigger
language plpgsql security definer set search_path='' as $$
begin
  if current_setting('babycare.maintenance',true)='on' then return new; end if;
  -- Administrative maintenance without a user session remains possible.
  if auth.uid() is not null or current_setting('role',true) in ('authenticated','anon') then
    perform babycare_private.require_current_consent();
  end if;
  return new;
end $$;

create function public.babycare_create_invite(p_family_id uuid,p_role text default 'caregiver')
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid := auth.uid(); code text; invite babycare_private.family_invites;
begin
  if u is null or not babycare_private.has_role(p_family_id,array['owner']) then
    raise exception 'Owner access required' using errcode='42501';
  end if;
  if p_role is null or p_role not in ('caregiver','viewer') then raise exception 'Invalid role' using errcode='22023'; end if;
  perform babycare_private.require_current_consent();
  perform 1 from public.families where id=p_family_id for update;
  if (select count(*) from public.family_members where family_id=p_family_id) >= 6 then
    raise exception 'Family is full' using errcode='P0001';
  end if;
  if (select count(*) from babycare_private.family_invites where family_id=p_family_id
      and accepted_at is null and revoked_at is null and expires_at>now()) >= 5 then
    raise exception 'Too many open invites' using errcode='P0001';
  end if;
  loop
    code := babycare_private.invite_code();
    begin
      insert into babycare_private.family_invites(family_id,code_hash,role,created_by,expires_at)
      values (p_family_id,babycare_private.invite_hash(code),p_role,u,now()+interval '48 hours')
      returning * into invite;
      exit;
    exception when unique_violation then
      -- Another live or used invite has this code: draw again.
    end;
  end loop;
  return jsonb_build_object('id',invite.id,'code',code,'role',invite.role,'expires_at',invite.expires_at);
end $$;

-- Answers with a status instead of raising, so that a wrong code is still counted.
create function public.babycare_accept_invite(p_code text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid := auth.uid(); invite babycare_private.family_invites; owner_email text; status text;
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform babycare_private.require_current_consent();
  perform pg_advisory_xact_lock(hashtextextended(u::text,21));
  if (select count(*) from babycare_private.invite_attempts
      where user_id=u and attempted_at>now()-interval '1 hour') >= 10 then
    return jsonb_build_object('status','rate_limited');
  end if;
  select * into invite from babycare_private.family_invites where code_hash=babycare_private.invite_hash(p_code);
  if not found then
    insert into babycare_private.invite_attempts(user_id) values (u);
    return jsonb_build_object('status','invalid');
  end if;
  perform 1 from public.families where id=invite.family_id for update;
  select * into invite from babycare_private.family_invites where id=invite.id for update;
  select a.email into owner_email from public.families f left join auth.users a on a.id=f.created_by where f.id=invite.family_id;
  if exists(select 1 from public.family_members where family_id=invite.family_id and user_id=u) then
    status := 'already_member';
  elsif invite.revoked_at is not null then
    return jsonb_build_object('status','revoked');
  elsif invite.accepted_at is not null then
    return jsonb_build_object('status','used');
  elsif invite.expires_at<=now() then
    return jsonb_build_object('status','expired');
  elsif (select count(*) from public.family_members where family_id=invite.family_id) >= 6 then
    return jsonb_build_object('status','family_full');
  else
    insert into public.family_members(family_id,user_id,role) values (invite.family_id,u,invite.role);
    update babycare_private.family_invites set accepted_by=u,accepted_at=now() where id=invite.id;
    status := 'joined';
  end if;
  return jsonb_build_object('status',status,'family_id',invite.family_id,'owner_email',coalesce(owner_email,''),
    'role',(select role from public.family_members where family_id=invite.family_id and user_id=u));
end $$;

-- Every family the caller belongs to, their own first, with who created it for the family picker.
create function public.babycare_my_families()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',f.id,'name',f.name,'revision',f.revision,'role',m.role,
      'created_by',f.created_by,'owner_email',coalesce(a.email,''),
      'member_count',(select count(*) from public.family_members x where x.family_id=f.id))
      order by (f.created_by=u) desc,m.created_at,f.id)
    from public.family_members m join public.families f on f.id=m.family_id
    left join auth.users a on a.id=f.created_by where m.user_id=u),'[]'::jsonb);
end $$;

-- Members see each other's email (stated in the privacy policy); only owners see open invites.
create function public.babycare_family_sharing(p_family_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid := auth.uid(); my_role text;
begin
  select role into my_role from public.family_members where family_id=p_family_id and user_id=u;
  if u is null or my_role is null then raise exception 'Read access denied' using errcode='42501'; end if;
  return jsonb_build_object('role',my_role,
    'created_by',(select created_by from public.families where id=p_family_id),
    'members',coalesce((select jsonb_agg(jsonb_build_object('user_id',m.user_id,'email',coalesce(a.email,''),
        'role',m.role,'joined_at',m.created_at) order by m.created_at,m.user_id)
      from public.family_members m left join auth.users a on a.id=m.user_id where m.family_id=p_family_id),'[]'::jsonb),
    'invites',case when my_role='owner' then coalesce((select jsonb_agg(jsonb_build_object('id',i.id,'role',i.role,
        'created_at',i.created_at,'expires_at',i.expires_at) order by i.created_at,i.id)
      from babycare_private.family_invites i where i.family_id=p_family_id
        and i.accepted_at is null and i.revoked_at is null and i.expires_at>now()),'[]'::jsonb) else '[]'::jsonb end);
end $$;

create function public.babycare_revoke_invite(p_invite_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare family uuid;
begin
  select family_id into family from babycare_private.family_invites where id=p_invite_id;
  if auth.uid() is null or family is null or not babycare_private.has_role(family,array['owner']) then
    raise exception 'Owner access required' using errcode='42501';
  end if;
  update babycare_private.family_invites set revoked_at=now()
    where id=p_invite_id and accepted_at is null and revoked_at is null;
  return true;
end $$;

-- Owners change caregivers to viewers and back. Owners themselves are never changed or removed here.
create function public.babycare_set_member_role(p_family_id uuid,p_user_id uuid,p_role text)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not babycare_private.has_role(p_family_id,array['owner']) then
    raise exception 'Owner access required' using errcode='42501';
  end if;
  if p_role is null or p_role not in ('caregiver','viewer') then raise exception 'Invalid role' using errcode='22023'; end if;
  perform 1 from public.families where id=p_family_id for update;
  update public.family_members set role=p_role
    where family_id=p_family_id and user_id=p_user_id and user_id<>auth.uid() and role<>'owner';
  if not found then raise exception 'Member not found' using errcode='P0001'; end if;
  return true;
end $$;

create function public.babycare_remove_member(p_family_id uuid,p_user_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not babycare_private.has_role(p_family_id,array['owner']) then
    raise exception 'Owner access required' using errcode='42501';
  end if;
  perform 1 from public.families where id=p_family_id for update;
  delete from public.family_members
    where family_id=p_family_id and user_id=p_user_id and user_id<>auth.uid() and role<>'owner';
  if not found then raise exception 'Member not found' using errcode='P0001'; end if;
  return true;
end $$;

-- A member leaves a family someone else created. Everyone keeps the family of their own account.
create function public.babycare_leave_family(p_family_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare u uuid := auth.uid(); creator uuid;
begin
  if u is null or not babycare_private.has_role(p_family_id,array['owner','caregiver','viewer']) then
    raise exception 'Read access denied' using errcode='42501';
  end if;
  select created_by into creator from public.families where id=p_family_id for update;
  if creator=u then raise exception 'Cannot leave own family' using errcode='P0001'; end if;
  delete from public.family_members where family_id=p_family_id and user_id=u;
  return true;
end $$;

create function public.babycare_begin_baby_deletion(p_family_id uuid,p_baby_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if auth.uid() is null or not babycare_private.has_role(p_family_id,array['owner']) then
    raise exception 'Owner access required' using errcode='42501';
  end if;
  if not exists(select 1 from public.babies where id=p_baby_id and family_id=p_family_id) then
    raise exception 'Baby not found' using errcode='40001';
  end if;
  insert into babycare_private.baby_deletions(baby_id,family_id,requested_by) values (p_baby_id,p_family_id,auth.uid())
  on conflict (baby_id) do update set requested_by=excluded.requested_by,requested_at=now();
  return true;
end $$;

-- Photos of a shared family stay unless an owner is deleting that baby: an older app deleting its account
-- removes every photo of its families before the RPC, which now hands a shared family over instead.
create or replace function babycare_private.can_delete_media(p_path text)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.media_assets a
    where a.object_path=p_path
      and babycare_private.has_role(a.family_id,array['owner'])
      and (not exists(select 1 from public.family_members o where o.family_id=a.family_id and o.user_id<>(select auth.uid()))
        or exists(select 1 from babycare_private.baby_deletions d where d.baby_id=a.baby_id and d.family_id=a.family_id
          and d.requested_at>now()-interval '1 hour')));
$$;

create or replace function public.babycare_delete_account()
returns boolean language plpgsql security definer set search_path='' as $$
declare
  u uuid := auth.uid();
  family_ids uuid[];
  shared record;
  successor uuid;
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text,0));
  perform set_config('babycare.maintenance','on',true);
  -- A family someone else also uses lives on: the longest-standing owner, else caregiver, else viewer takes it over.
  for shared in select f.id,f.created_by from public.families f
      join public.family_members m on m.family_id=f.id and m.user_id=u
      where exists(select 1 from public.family_members o where o.family_id=f.id and o.user_id<>u)
      order by f.id for update of f loop
    if shared.created_by=u or not exists(select 1 from public.family_members o
        where o.family_id=shared.id and o.user_id<>u and o.role='owner') then
      select o.user_id into successor from public.family_members o where o.family_id=shared.id and o.user_id<>u
        order by (o.role='owner') desc,(o.role='caregiver') desc,o.created_at,o.user_id limit 1;
      update public.family_members set role='owner' where family_id=shared.id and user_id=successor;
      if shared.created_by=u then update public.families set created_by=successor where id=shared.id; end if;
    end if;
  end loop;

  -- Families only this account used are erased as before.
  select coalesce(array_agg(id),'{}'::uuid[]) into family_ids from public.families where created_by=u;
  -- Binary objects are removed through the authenticated Storage API before this RPC.
  delete from public.media_assets where family_id=any(family_ids);
  delete from public.vaccinations where family_id=any(family_ids);
  delete from public.medication_reminders where family_id=any(family_ids);
  delete from public.baby_care_states where family_id=any(family_ids);
  delete from public.body_measurements where family_id=any(family_ids);
  delete from public.care_activities where family_id=any(family_ids);
  delete from public.import_jobs where family_id=any(family_ids) or user_id=u;
  delete from public.mutation_receipts where family_id=any(family_ids) or user_id=u;
  delete from public.babies where family_id=any(family_ids);
  delete from public.family_members where family_id=any(family_ids) or user_id=u;
  delete from public.families where id=any(family_ids);
  delete from auth.users where id=u;
  perform set_config('babycare.maintenance','off',true);
  return true;
end $$;

revoke all on function babycare_private.invite_code(),babycare_private.invite_hash(text),
  public.babycare_create_invite(uuid,text),public.babycare_accept_invite(text),public.babycare_my_families(),
  public.babycare_family_sharing(uuid),public.babycare_revoke_invite(uuid),
  public.babycare_set_member_role(uuid,uuid,text),public.babycare_remove_member(uuid,uuid),
  public.babycare_leave_family(uuid),public.babycare_begin_baby_deletion(uuid,uuid),
  public.babycare_delete_account() from public,anon,authenticated;
grant execute on function public.babycare_create_invite(uuid,text),public.babycare_accept_invite(text),
  public.babycare_my_families(),public.babycare_family_sharing(uuid),public.babycare_revoke_invite(uuid),
  public.babycare_set_member_role(uuid,uuid,text),public.babycare_remove_member(uuid,uuid),
  public.babycare_leave_family(uuid),public.babycare_begin_baby_deletion(uuid,uuid),
  public.babycare_delete_account() to authenticated;
notify pgrst,'reload schema';
commit;
