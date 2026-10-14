-- Run after all migrations. Synthetic fixtures are rolled back, including version updates.
begin;
create temporary table consent_results(name text primary key);
grant all on consent_results to authenticated;
create function pg_temp.verify(ok boolean,label text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'FAILED: %',label; end if;
  insert into pg_temp.consent_results values(label);
end $$;
create function pg_temp.denied(statement text,expected_code text,expected_message text,label text)
returns void language plpgsql as $$
begin
  begin execute statement;
  exception when others then
    if sqlstate=expected_code and (expected_message is null or sqlerrm=expected_message) then
      insert into pg_temp.consent_results values(label); return;
    end if;
    raise;
  end;
  raise exception 'FAILED: unexpected success: %',label;
end $$;
insert into auth.users(id,email) values
 ('c0180000-0000-0000-0000-000000000001','consent-owner@example.invalid'),
 ('c0180000-0000-0000-0000-000000000002','consent-other@example.invalid');
insert into public.families(id,name,created_by) values
 ('c0180000-0000-0000-0000-000000000010','Existing family','c0180000-0000-0000-0000-000000000001');
insert into public.family_members(family_id,user_id,role) values
 ('c0180000-0000-0000-0000-000000000010','c0180000-0000-0000-0000-000000000001','owner');
insert into public.babies(id,family_id,name,birth_date,revision) values
 ('c0180000-0000-0000-0000-000000000100','c0180000-0000-0000-0000-000000000010','Existing baby','2025-01-01',0);
insert into public.media_assets(id,family_id,baby_id,purpose,object_path,mime_type,byte_count,revision)
values('c0180000-0000-0000-0000-000000000101','c0180000-0000-0000-0000-000000000010',
 'c0180000-0000-0000-0000-000000000100','avatar',
 'c0180000-0000-0000-0000-000000000010/c0180000-0000-0000-0000-000000000100/c0180000-0000-0000-0000-000000000101','image/jpeg',100,0);
set local role authenticated;
select set_config('request.jwt.claim.sub','c0180000-0000-0000-0000-000000000001',true);
select pg_temp.verify(not (public.babycare_consent_status()->>'valid')::boolean,'existing user requires consent');
select pg_temp.verify((select count(*)=1 from public.babies),'existing data remains readable');
select pg_temp.denied($q$insert into storage.objects(bucket_id,name) values('babycare-media',
 'c0180000-0000-0000-0000-000000000010/c0180000-0000-0000-0000-000000000100/c0180000-0000-0000-0000-000000000101')$q$,
 'P0001','CONSENT_REQUIRED','missing consent blocks reserved upload');
select pg_temp.denied($q$select public.babycare_apply(gen_random_uuid(),'c0180000-0000-0000-0000-000000000010','[]')$q$,
 'P0001','CONSENT_REQUIRED','missing consent blocks writes');
select pg_temp.denied($q$select public.babycare_accept_consent('1.0','1.0','1.0',true,false,true)$q$,
 '22023',null,'partial consent rejected');
select pg_temp.denied($q$select public.babycare_accept_consent('old','1.0','1.0',true,true,true)$q$,
 'P0001','CONSENT_REQUIRED','stale submission rejected');
select pg_temp.verify(public.babycare_consent_status()->'accepted'='null'::jsonb,'failed acceptance is atomic');
select public.babycare_accept_consent('1.0','1.0','1.0',true,true,true);
select pg_temp.verify((public.babycare_consent_status()->>'valid')::boolean,'current consent valid');
insert into storage.objects(bucket_id,name) values('babycare-media',
 'c0180000-0000-0000-0000-000000000010/c0180000-0000-0000-0000-000000000100/c0180000-0000-0000-0000-000000000101');
select pg_temp.verify((select count(*)=1 from storage.objects),'current consent allows reserved upload');
delete from storage.objects;
select public.babycare_accept_consent('1.0','1.0','1.0',true,true,true);
select pg_temp.denied($q$update public.user_consents set health_version='fake'$q$,'42501',null,'audit is immutable to client');
select pg_temp.denied($q$select babycare_private.babycare_apply(gen_random_uuid(),'c0180000-0000-0000-0000-000000000010','[]',1)$q$,
 '42501',null,'unguarded mutation implementation inaccessible');
select public.babycare_apply(gen_random_uuid(),'c0180000-0000-0000-0000-000000000010',
 '[{"entity":"babies","id":"c0180000-0000-0000-0000-000000000100","expected_version":1,"data":{"name":"Updated with consent"}}]');
select pg_temp.verify((select name='Updated with consent' from public.babies),'current consent allows protected write');
select set_config('request.jwt.claim.sub','c0180000-0000-0000-0000-000000000002',true);
select pg_temp.verify(not (public.babycare_consent_status()->>'valid')::boolean,'consent isolated by authenticated user');
select pg_temp.denied($q$select public.babycare_accept_consent('1.0','1.0','1.0',true,true,true,'c0180000-0000-0000-0000-000000000001'::uuid)$q$,
 '42883',null,'API does not accept arbitrary user ID');
reset role;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.verify((select count(*)=1 from public.user_consents where user_id='c0180000-0000-0000-0000-000000000001'),'retry keeps one audit entry');
select pg_temp.verify((select terms_accepted_at=privacy_accepted_at and terms_accepted_at=health_accepted_at
 and terms_accepted_at=representative_confirmed_at and terms_accepted_at=created_at
 and created_at>=transaction_timestamp() and created_at<=clock_timestamp()
 from public.user_consents where user_id='c0180000-0000-0000-0000-000000000001'),'atomic server timestamps');
update public.consent_requirements set health_version='2.0',updated_at=now();
set local role authenticated;
select set_config('request.jwt.claim.sub','c0180000-0000-0000-0000-000000000001',true);
select pg_temp.verify(not (public.babycare_consent_status()->>'valid')::boolean,'version update requires reconsent');
select pg_temp.denied($q$insert into storage.objects(bucket_id,name) values('babycare-media',
 'c0180000-0000-0000-0000-000000000010/c0180000-0000-0000-0000-000000000100/c0180000-0000-0000-0000-000000000101')$q$,
 'P0001','CONSENT_REQUIRED','outdated consent blocks reserved upload');
select pg_temp.denied($q$select public.babycare_apply(gen_random_uuid(),'c0180000-0000-0000-0000-000000000010','[]')$q$,
 'P0001','CONSENT_REQUIRED','outdated consent blocks writes');
select public.babycare_accept_consent('1.0','1.0','2.0',true,true,true);
select pg_temp.verify((public.babycare_consent_status()->>'valid')::boolean,'reconsent restores access');
reset role;
select pg_temp.verify((select count(*)=2 from public.user_consents where user_id='c0180000-0000-0000-0000-000000000001'),'old audit record retained');
-- Trigger enforcement for a future server function using the same user context.
update public.consent_requirements set health_version='3.0',updated_at=now();
select pg_temp.denied($q$update public.babies set name='Blocked' where id='c0180000-0000-0000-0000-000000000100'$q$,
 'P0001','CONSENT_REQUIRED','table guard protects future mutation paths');
select pg_temp.denied($q$insert into public.family_members(family_id,user_id,role) values
 ('c0180000-0000-0000-0000-000000000010','c0180000-0000-0000-0000-000000000002','viewer')$q$,
 'P0001','CONSENT_REQUIRED','caregiver invitation requires consent');
select pg_temp.verify((select count(*)=2 from pg_policies where schemaname='storage'
 and policyname in ('babycare_consent_upload','babycare_consent_overwrite') and permissive='RESTRICTIVE'),'storage policies cannot be bypassed by permissive family policy');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.denied($q$select public.babycare_accept_consent('1.0','1.0','3.0',true,true,true)$q$,
 '42501','Authentication required','unauthenticated acceptance rejected');
select count(*) as passed_checks from consent_results;
rollback;
