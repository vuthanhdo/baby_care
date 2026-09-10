-- Run as postgres in SQL Editor. Every fixture and helper is rolled back.
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
create function pg_temp.change(entity text,id integer,baby integer,version integer,data jsonb)
returns jsonb language sql as $$
  select jsonb_strip_nulls(jsonb_build_object('entity',entity,'id',lpad(id::text,32,'0')::uuid,
    'baby_id',case when baby is null then null else lpad(baby::text,32,'0')::uuid end,
    'expected_version',version)) || jsonb_build_object('data',data);
$$;
insert into auth.users(id,email) values
 ('00000000-0000-0000-0000-000000000001','babycare-test-owner@example.invalid'),
 ('00000000-0000-0000-0000-000000000002','babycare-test-other@example.invalid'),
 ('00000000-0000-0000-0000-000000000003','babycare-test-viewer@example.invalid'),
 ('00000000-0000-0000-0000-000000000004','babycare-test-caregiver@example.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
select public.babycare_create_family('00000000-0000-0000-0000-000000000010','Test A');
select public.babycare_create_family('00000000-0000-0000-0000-000000000010','Test A');
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
select public.babycare_create_family('00000000-0000-0000-0000-000000000020','Test B');
reset role;
insert into public.family_members(family_id,user_id,role) values
 ('00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000003','viewer'),
 ('00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000004','caregiver');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',true);
do $$
declare f uuid:='00000000-0000-0000-0000-000000000010'; op uuid:=gen_random_uuid(); batch jsonb; r jsonb; rev bigint;
begin
  batch:=jsonb_build_array(
    pg_temp.change('babies',100,null,0,'{"name":"Synthetic Baby","birth_date":"2025-01-01T00:00:00Z"}'),
    pg_temp.change('baby_care_states',100,100,0,'{"sleep_start_date":"2026-01-01T10:00:00Z"}'),
    pg_temp.change('medication_reminders',101,100,0,'{"name":"Synthetic reminder","amount":1,"unit":"ml","next_date":"2026-01-01T12:00:00Z"}'),
    pg_temp.change('body_measurements',102,100,0,'{"measured_at":"2026-01-01T00:00:00Z","weight":8}'),
    pg_temp.change('import_jobs',103,null,0,'{"source_id":"00000000-0000-0000-0000-000000000099"}'));
  r:=public.babycare_apply(op,f,batch);
  perform pg_temp.check_true((r->>'revision')::int=1 and jsonb_array_length(r->'records')=5,'create batch / defaults / five entities');
  perform pg_temp.check_true(public.babycare_apply(op,f,batch)=r,'idempotent replay returns same receipt');
  perform pg_temp.check_true((select count(*)=1 from public.families),'owner sees only own family');
  perform pg_temp.rejects(format('select public.babycare_apply(%L,%L,%L::jsonb)',op,f,jsonb_build_array(pg_temp.change('babies',100,null,1,'{"name":"Changed"}'))),'40001','same operation different payload denied');
  perform pg_temp.rejects(format('select public.babycare_apply(%L,%L,%L::jsonb)',gen_random_uuid(),f,jsonb_build_array(pg_temp.change('babies',100,null,0,'{"name":"Stale"}'))),'40001','stale version denied');
  perform pg_temp.rejects('update public.babies set name=''Bypass''','42501','direct table write denied');
  perform pg_temp.rejects('update public.family_members set role=''owner''','42501','self promotion denied');
  perform pg_temp.rejects(format('select public.babycare_apply(%L,%L,%L::jsonb)',gen_random_uuid(),f,jsonb_build_array(pg_temp.change('babies',100,null,1,'{"family_id":"00000000-0000-0000-0000-000000000020"}'))),'22023','protected field injection denied');
  batch:=jsonb_build_array(pg_temp.change('babies',100,null,1,'{"name":"Must rollback"}'),pg_temp.change('body_measurements',104,100,0,'{"measured_at":"2026-01-01","weight":-1}'));
  perform pg_temp.rejects(format('select public.babycare_apply(%L,%L,%L::jsonb)',gen_random_uuid(),f,batch),'23514','invalid second change rejects batch');
  perform pg_temp.check_true((select name='Synthetic Baby' and version=1 from public.babies where id='00000000-0000-0000-0000-000000000100') and (select revision=1 from public.families where id=f),'failed batch rolled back rows and revision');
  batch:=jsonb_build_array(
    pg_temp.change('care_activities',105,100,0,'{"kind":"sleep","occurred_at":"2026-01-01T11:00:00Z","value":"60","unit":"phút"}'),
    pg_temp.change('baby_care_states',100,100,1,'{"sleep_start_date":null}'),
    pg_temp.change('care_activities',106,100,0,'{"kind":"medicine","occurred_at":"2026-01-01T12:00:00Z","value":"1","unit":"ml","detail":"Synthetic"}'),
    pg_temp.change('medication_reminders',101,100,1,'{"enabled":false}'),
    pg_temp.change('media_assets',107,100,0,'{"purpose":"activity","activity_id":"00000000-0000-0000-0000-000000000106","mime_type":"image/jpeg","byte_count":100}'));
  r:=public.babycare_apply(gen_random_uuid(),f,batch);
  perform pg_temp.check_true((select sleep_start_date is null and revision=2 from public.baby_care_states) and (select not enabled and revision=2 from public.medication_reminders),'sleep finish and reminder completion atomic');
  perform pg_temp.check_true(babycare_private.can_access_media('00000000-0000-0000-0000-000000000010/00000000-0000-0000-0000-000000000100/00000000-0000-0000-0000-000000000107',true),'owner can upload reserved media');
  perform pg_temp.check_true(not babycare_private.can_access_media('arbitrary/path',true),'unreserved storage path denied');
  perform pg_temp.rejects(format('select public.babycare_apply(%L,%L,%L::jsonb)',gen_random_uuid(),f,jsonb_build_array(pg_temp.change('media_assets',107,100,1,'{"status":"ready"}'))),'22023','missing uploaded object cannot become ready');
  perform pg_temp.check_true(jsonb_array_length(public.babycare_read_page(f,'care_activities',2,0,null,1)->'rows')=1,'bounded first page');
  perform pg_temp.check_true(jsonb_array_length(public.babycare_read_page(f,'care_activities',2,0,'00000000-0000-0000-0000-000000000105',1)->'rows')=1,'bounded second page');
  perform pg_temp.rejects(format('select public.babycare_read_page(%L,''babies'',1)',f),'40001','stale pagination snapshot rejected');
  batch:=jsonb_build_array(pg_temp.change('care_activities',105,100,1,'{}')||'{"deleted":true}'::jsonb);
  perform public.babycare_apply(gen_random_uuid(),f,batch);
  perform pg_temp.check_true((select deleted_at is not null and version=2 and revision=3 from public.care_activities where id='00000000-0000-0000-0000-000000000105'),'delete produces versioned tombstone');
  perform pg_temp.check_true(jsonb_array_length(public.babycare_read_page(f,'care_activities',3,2)->'rows')=1,'delta includes tombstone');
  perform pg_temp.rejects(format('select public.babycare_apply(%L,%L,%L::jsonb)',gen_random_uuid(),f,jsonb_build_array(pg_temp.change('care_activities',105,100,2,'{"note":"Resurrect"}'))),'40001','tombstone cannot be resurrected');
  perform public.babycare_apply(gen_random_uuid(),f,jsonb_build_array(pg_temp.change('care_activities',106,100,1,'{}')||'{"deleted":true}'::jsonb));
  perform pg_temp.check_true(not babycare_private.can_access_media('00000000-0000-0000-0000-000000000010/00000000-0000-0000-0000-000000000100/00000000-0000-0000-0000-000000000107',false),'deleted activity hides its media');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',true);
do $$ begin
  perform pg_temp.check_true((select count(*)=0 from public.babies),'other family cannot read babies');
  perform pg_temp.rejects($q$select public.babycare_apply(gen_random_uuid(),'00000000-0000-0000-0000-000000000010',jsonb_build_array(pg_temp.change('babies',100,null,1,'{"name":"Attack"}')))$q$,'42501','other family cannot write');
  perform pg_temp.rejects($q$select public.babycare_apply(gen_random_uuid(),'00000000-0000-0000-0000-000000000020',jsonb_build_array(pg_temp.change('babies',100,null,0,'{"name":"Attack","birth_date":"2025-01-01"}')))$q$,'42501','UUID collision cannot steal another family record');
  perform pg_temp.check_true(not babycare_private.can_access_media('00000000-0000-0000-0000-000000000010/00000000-0000-0000-0000-000000000100/00000000-0000-0000-0000-000000000107',false),'other family media denied');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',true);
do $$ begin
  perform pg_temp.check_true((select count(*)=1 from public.babies),'viewer can read family baby');
  perform pg_temp.check_true((select count(*)=0 from public.import_jobs) and (select count(*)=0 from public.mutation_receipts),'private import and receipts hidden from other members');
  perform pg_temp.rejects($q$select public.babycare_apply(gen_random_uuid(),'00000000-0000-0000-0000-000000000010',jsonb_build_array(pg_temp.change('babies',100,null,1,'{"name":"Viewer"}')))$q$,'42501','viewer cannot write');
  perform pg_temp.check_true(not babycare_private.can_access_media('00000000-0000-0000-0000-000000000010/00000000-0000-0000-0000-000000000100/00000000-0000-0000-0000-000000000107',true),'viewer cannot upload');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',true);
select public.babycare_apply(gen_random_uuid(),'00000000-0000-0000-0000-000000000010',jsonb_build_array(pg_temp.change('babies',100,null,1,'{"name":"Caregiver update"}')));
select pg_temp.check_true((select name='Caregiver update' and version=2 from public.babies),'caregiver can update');
reset role;
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.rejects('select * from public.babies','42501','anonymous read denied');
select pg_temp.rejects('select public.babycare_create_family(gen_random_uuid(),''Anon'')','42501','anonymous RPC denied');
reset role;
select pg_temp.check_true((select not public and file_size_limit=5242880 from storage.buckets where id='babycare-media'),'private bucket and 5 MiB limit');
select pg_temp.check_true((select count(*)=10 and bool_and(relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind='r'),'all ten app tables have RLS');
select count(*) as passed_checks, bool_and(passed) as all_passed from test_results;
rollback;
