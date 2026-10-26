-- Shared care: invites, roles, leaving, photo deletion and account deletion in a shared family.
-- Run as postgres in SQL Editor or with run-pglite.mjs. Every fixture is rolled back.
begin;
create temporary table test_results(name text, passed boolean);
grant all on test_results to authenticated, anon;
create function pg_temp.check_true(ok boolean, label text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'FAILED: %',label; end if;
  insert into pg_temp.test_results values(label,true);
end $$;
create function pg_temp.rejects(statement text, expected text, label text) returns void language plpgsql as $$
begin
  begin
    execute statement;
  exception when others then
    if sqlstate=expected then insert into pg_temp.test_results values(label,true); return; end if;
    raise;
  end;
  raise exception 'FAILED (unexpected success): %',label;
end $$;
create function pg_temp.as_user(id text) returns void language sql as $$
  select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000'||id,true);
$$;
create function pg_temp.change(entity text,id text,baby text,version integer,data jsonb)
returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('entity',entity,'id',('00000000-0000-0000-0000-00000000'||id)::uuid,
    'baby_id',case when baby is null then null else ('00000000-0000-0000-0000-00000000'||baby)::uuid end,
    'expected_version',version)) || jsonb_build_object('data',data);
$$;
-- a1 owner, a2 caregiver, a3 viewer, a4 stranger, a5 has not accepted the policy.
insert into auth.users(id,email) values
 ('00000000-0000-0000-0000-0000000000a1','share-owner@example.invalid'),
 ('00000000-0000-0000-0000-0000000000a2','share-caregiver@example.invalid'),
 ('00000000-0000-0000-0000-0000000000a3','share-viewer@example.invalid'),
 ('00000000-0000-0000-0000-0000000000a4','share-stranger@example.invalid'),
 ('00000000-0000-0000-0000-0000000000a5','share-no-consent@example.invalid');
create temporary table codes(name text primary key, code text);
grant all on codes to authenticated;
set local role authenticated;
do $$ declare u text; begin
  foreach u in array array['a1','a2','a3','a4'] loop
    perform pg_temp.as_user(u);
    perform public.babycare_accept_consent('1.0','1.0','1.0',true,true,true);
  end loop;
end $$;
select pg_temp.as_user('a1');
select public.babycare_create_family('00000000-0000-0000-0000-00000000aa10','Shared');
select public.babycare_apply(gen_random_uuid(),'00000000-0000-0000-0000-00000000aa10',jsonb_build_array(
  pg_temp.change('babies','aa11',null,0,'{"name":"Shared Baby","birth_date":"2025-01-01T00:00:00Z"}'),
  pg_temp.change('care_activities','aa12','aa11',0,'{"kind":"medicine","occurred_at":"2026-01-01T08:00:00Z","value":"5","unit":"ml","detail":"Synthetic"}'),
  pg_temp.change('media_assets','aa13','aa11',0,'{"purpose":"activity","activity_id":"00000000-0000-0000-0000-00000000aa12","mime_type":"image/jpeg","byte_count":100}')));
select pg_temp.as_user('a2');
select public.babycare_create_family('00000000-0000-0000-0000-00000000aa20','Own');

-- Invites
select pg_temp.as_user('a1');
insert into codes select 'caregiver',public.babycare_create_invite('00000000-0000-0000-0000-00000000aa10','caregiver')->>'code';
do $$ declare code text := (select code from codes where name='caregiver'); begin
  perform pg_temp.check_true(code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ2-9]{8}$','invite code: 8 unambiguous characters');
  perform pg_temp.check_true(jsonb_array_length(public.babycare_family_sharing('00000000-0000-0000-0000-00000000aa10')->'invites')=1,'owner sees the open invite');
  perform pg_temp.rejects($q$select public.babycare_create_invite('00000000-0000-0000-0000-00000000aa10','owner')$q$,'22023','invite cannot grant owner');
end $$;
reset role;
select pg_temp.check_true((select count(*)=1 from babycare_private.family_invites where code_hash=babycare_private.invite_hash((select code from codes where name='caregiver')))
  and not exists(select 1 from babycare_private.family_invites i where encode(i.code_hash,'escape')=(select code from codes where name='caregiver')),
  'only the hash of the code is stored');
set local role authenticated;
select pg_temp.as_user('a2');
do $$ declare code text := (select code from codes where name='caregiver'); r jsonb; begin
  perform pg_temp.rejects($q$select public.babycare_create_invite('00000000-0000-0000-0000-00000000aa10','caregiver')$q$,'42501','non-member cannot invite');
  perform pg_temp.check_true(not exists(select 1 from public.babies where family_id='00000000-0000-0000-0000-00000000aa10'),'before joining nothing is visible');
  -- Typed by hand: lower case with a dash still matches.
  r := public.babycare_accept_invite(lower(substr(code,1,4))||'-'||substr(code,5));
  perform pg_temp.check_true(r->>'status'='joined' and r->>'role'='caregiver' and r->>'owner_email'='share-owner@example.invalid','caregiver joins with the code');
  perform pg_temp.check_true((select count(*)=1 from public.babies where family_id='00000000-0000-0000-0000-00000000aa10'),'caregiver reads the family');
  perform public.babycare_apply(gen_random_uuid(),'00000000-0000-0000-0000-00000000aa10',jsonb_build_array(
    pg_temp.change('care_activities','aa14','aa11',0,'{"kind":"diaper","occurred_at":"2026-01-01T09:00:00Z","value":"Thay tã"}')));
  perform pg_temp.check_true((select count(*)=2 from public.care_activities where family_id='00000000-0000-0000-0000-00000000aa10'),'caregiver writes for the family');
  perform pg_temp.check_true(public.babycare_accept_invite(code)->>'status'='already_member','accepting again is harmless');
  r := public.babycare_my_families();
  perform pg_temp.check_true(jsonb_array_length(r)=2 and r->0->>'id'='00000000-0000-0000-0000-00000000aa20'
    and r->1->>'owner_email'='share-owner@example.invalid' and r->1->>'role'='caregiver' and (r->1->>'member_count')::int=2,
    'my families: own first, then the shared one');
  perform pg_temp.check_true(jsonb_array_length(public.babycare_family_sharing('00000000-0000-0000-0000-00000000aa10')->'invites')=0
    and jsonb_array_length(public.babycare_family_sharing('00000000-0000-0000-0000-00000000aa10')->'members')=2,'members listed; invites only for owners');
  perform pg_temp.rejects($q$select public.babycare_set_member_role('00000000-0000-0000-0000-00000000aa10','00000000-0000-0000-0000-0000000000a1','viewer')$q$,'42501','caregiver cannot change roles');
end $$;
select pg_temp.as_user('a4');
do $$ declare code text := (select code from codes where name='caregiver'); begin
  perform pg_temp.check_true(public.babycare_accept_invite(code)->>'status'='used','a used code does not let anyone else in');
  perform pg_temp.check_true(public.babycare_accept_invite('ZZZZ2222')->>'status'='invalid','wrong code');
  perform pg_temp.rejects($q$select public.babycare_family_sharing('00000000-0000-0000-0000-00000000aa10')$q$,'42501','stranger cannot list members');
end $$;
select pg_temp.as_user('a5');
select pg_temp.rejects($q$select public.babycare_accept_invite('ZZZZ2222')$q$,'P0001','joining requires the current policy');

-- Viewer, roles and removal
select pg_temp.as_user('a1');
insert into codes select 'viewer',public.babycare_create_invite('00000000-0000-0000-0000-00000000aa10','viewer')->>'code';
select pg_temp.as_user('a3');
select pg_temp.check_true(public.babycare_accept_invite((select code from codes where name='viewer'))->>'role'='viewer','viewer joins');
select pg_temp.rejects($q$select public.babycare_apply(gen_random_uuid(),'00000000-0000-0000-0000-00000000aa10',jsonb_build_array(pg_temp.change('care_activities','aa15','aa11',0,'{"kind":"diaper","occurred_at":"2026-01-01T10:00:00Z","value":"x"}')))$q$,'42501','viewer cannot write');
select pg_temp.as_user('a1');
select public.babycare_set_member_role('00000000-0000-0000-0000-00000000aa10','00000000-0000-0000-0000-0000000000a3','caregiver');
select pg_temp.rejects($q$select public.babycare_set_member_role('00000000-0000-0000-0000-00000000aa10','00000000-0000-0000-0000-0000000000a1','viewer')$q$,'P0001','owner cannot demote themselves');
select pg_temp.as_user('a3');
select public.babycare_apply(gen_random_uuid(),'00000000-0000-0000-0000-00000000aa10',jsonb_build_array(pg_temp.change('care_activities','aa15','aa11',0,'{"kind":"diaper","occurred_at":"2026-01-01T10:00:00Z","value":"Promoted"}')));
select pg_temp.check_true(true,'promoted viewer can write');
select pg_temp.as_user('a2');
select pg_temp.rejects($q$select public.babycare_remove_member('00000000-0000-0000-0000-00000000aa10','00000000-0000-0000-0000-0000000000a3')$q$,'42501','caregiver cannot remove members');
select pg_temp.as_user('a1');
select public.babycare_remove_member('00000000-0000-0000-0000-00000000aa10','00000000-0000-0000-0000-0000000000a3');
select pg_temp.rejects($q$select public.babycare_remove_member('00000000-0000-0000-0000-00000000aa10','00000000-0000-0000-0000-0000000000a1')$q$,'P0001','owner cannot remove themselves');
select pg_temp.as_user('a3');
select pg_temp.check_true(not exists(select 1 from public.babies where family_id='00000000-0000-0000-0000-00000000aa10'),'removed member loses access');
select pg_temp.rejects($q$select public.babycare_family_sharing('00000000-0000-0000-0000-00000000aa10')$q$,'42501','removed member cannot list members');

-- Revoked, expired, limits and guessing
select pg_temp.as_user('a1');
insert into codes select 'revoked',public.babycare_create_invite('00000000-0000-0000-0000-00000000aa10','viewer')->>'code';
select public.babycare_revoke_invite((public.babycare_family_sharing('00000000-0000-0000-0000-00000000aa10')->'invites'->0->>'id')::uuid);
select pg_temp.check_true(jsonb_array_length(public.babycare_family_sharing('00000000-0000-0000-0000-00000000aa10')->'invites')=0,'revoked invite no longer open');
insert into codes select 'expired',public.babycare_create_invite('00000000-0000-0000-0000-00000000aa10','viewer')->>'code';
reset role;
update babycare_private.family_invites set expires_at=now()-interval '1 minute'
  where code_hash=babycare_private.invite_hash((select code from codes where name='expired'));
set local role authenticated;
select pg_temp.as_user('a4');
select pg_temp.check_true(public.babycare_accept_invite((select code from codes where name='revoked'))->>'status'='revoked','revoked code refused');
select pg_temp.check_true(public.babycare_accept_invite((select code from codes where name='expired'))->>'status'='expired','expired code refused');
select pg_temp.as_user('a1');
do $$ begin
  for i in 1..5 loop perform public.babycare_create_invite('00000000-0000-0000-0000-00000000aa10','viewer'); end loop;
  perform pg_temp.rejects($q$select public.babycare_create_invite('00000000-0000-0000-0000-00000000aa10','viewer')$q$,'P0001','at most five open invites');
end $$;
reset role;
-- Give one of the five open invites a code the test knows.
update babycare_private.family_invites set code_hash=babycare_private.invite_hash('KNOWN234')
  where id=(select id from babycare_private.family_invites where family_id='00000000-0000-0000-0000-00000000aa10'
    and accepted_at is null and revoked_at is null and expires_at>now() order by created_at,id limit 1);
set local role authenticated;
select pg_temp.as_user('a4');
do $$ begin
  for i in 1..9 loop perform public.babycare_accept_invite('WRONG'||i); end loop; -- plus one wrong code above
  perform pg_temp.check_true(public.babycare_accept_invite('KNOWN234')->>'status'='rate_limited','ten wrong codes in an hour stop further tries');
end $$;
reset role;
delete from babycare_private.invite_attempts where user_id='00000000-0000-0000-0000-0000000000a4';
set local role authenticated;
select pg_temp.check_true(public.babycare_accept_invite('KNOWN234')->>'status'='joined','after the hour the code works');

-- Photos: an owner may delete them only for a baby being deleted, or when nobody else uses the family.
select pg_temp.as_user('a1');
do $$ declare path text := '00000000-0000-0000-0000-00000000aa10/00000000-0000-0000-0000-00000000aa11/00000000-0000-0000-0000-00000000aa13'; begin
  perform pg_temp.check_true(not babycare_private.can_delete_media(path),'shared family photos protected');
  perform public.babycare_begin_baby_deletion('00000000-0000-0000-0000-00000000aa10','00000000-0000-0000-0000-00000000aa11');
  perform pg_temp.check_true(babycare_private.can_delete_media(path),'deleting that baby allows its photos to go');
end $$;
select pg_temp.as_user('a2');
select pg_temp.rejects($q$select public.babycare_begin_baby_deletion('00000000-0000-0000-0000-00000000aa10','00000000-0000-0000-0000-00000000aa11')$q$,'42501','caregiver cannot start a baby deletion');
select pg_temp.check_true(not babycare_private.can_delete_media('00000000-0000-0000-0000-00000000aa10/00000000-0000-0000-0000-00000000aa11/00000000-0000-0000-0000-00000000aa13'),'caregiver cannot delete photos');

-- Leaving
select pg_temp.as_user('a1');
select pg_temp.rejects($q$select public.babycare_leave_family('00000000-0000-0000-0000-00000000aa10')$q$,'P0001','nobody leaves the family of their own account');
select pg_temp.as_user('a4');
select public.babycare_leave_family('00000000-0000-0000-0000-00000000aa10');
select pg_temp.check_true(not exists(select 1 from public.babies where family_id='00000000-0000-0000-0000-00000000aa10'),'member who left loses access');

-- Account deletion: a1 (creator) leaves a2 (caregiver) and a3 (viewer) behind.
select pg_temp.as_user('a1');
insert into codes select 'again',public.babycare_create_invite('00000000-0000-0000-0000-00000000aa10','viewer')->>'code';
select pg_temp.as_user('a3');
select public.babycare_accept_invite((select code from codes where name='again'));
select pg_temp.as_user('a1');
select public.babycare_delete_account();
select pg_temp.check_true(coalesce(current_setting('babycare.maintenance',true),'off')='off','maintenance flag does not outlive the deletion');
reset role;
select pg_temp.check_true(not exists(select 1 from auth.users where id='00000000-0000-0000-0000-0000000000a1')
  and (select created_by='00000000-0000-0000-0000-0000000000a2' from public.families where id='00000000-0000-0000-0000-00000000aa10')
  and (select role='owner' from public.family_members where family_id='00000000-0000-0000-0000-00000000aa10' and user_id='00000000-0000-0000-0000-0000000000a2')
  and (select role='viewer' from public.family_members where family_id='00000000-0000-0000-0000-00000000aa10' and user_id='00000000-0000-0000-0000-0000000000a3')
  and exists(select 1 from public.babies where id='00000000-0000-0000-0000-00000000aa11')
  and (select count(*)=3 from public.care_activities where family_id='00000000-0000-0000-0000-00000000aa10'),
  'deleting the creator hands the shared family to the caregiver with its data');
set local role authenticated;
select pg_temp.as_user('a2');
select pg_temp.check_true((select count(*)=2 from public.families),'new owner keeps their own family too');
select public.babycare_delete_account();
reset role;
select pg_temp.check_true((select created_by='00000000-0000-0000-0000-0000000000a3' from public.families where id='00000000-0000-0000-0000-00000000aa10')
  and (select role='owner' from public.family_members where family_id='00000000-0000-0000-0000-00000000aa10' and user_id='00000000-0000-0000-0000-0000000000a3')
  and not exists(select 1 from public.families where id='00000000-0000-0000-0000-00000000aa20'),
  'a viewer left alone takes over; the unshared family is erased');
select count(*) as passed_checks, bool_and(passed) as all_passed from test_results;
rollback;
