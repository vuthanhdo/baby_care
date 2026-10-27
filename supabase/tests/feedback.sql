-- In-app feedback: sending, screenshots, privacy between users, limits and account deletion. Rolled back.
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
insert into auth.users(id,email) values
 ('00000000-0000-0000-0000-0000000000f1','feedback-sender@example.invalid'),
 ('00000000-0000-0000-0000-0000000000f2','feedback-other@example.invalid');
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000f1',true);
-- The screenshot is uploaded first, under the sender's folder and the feedback id.
insert into storage.objects(bucket_id,name) values
 ('babycare-feedback','00000000-0000-0000-0000-0000000000f1/00000000-0000-0000-0000-00000000fb01/0.jpg');
select pg_temp.rejects($q$insert into storage.objects(bucket_id,name) values('babycare-feedback','00000000-0000-0000-0000-0000000000f2/x/0.jpg')$q$,'42501','cannot upload into another user''s folder');
do $$
declare first jsonb; again jsonb;
begin
  first := public.babycare_send_feedback('00000000-0000-0000-0000-00000000fb01','bug','  The chart is blank  ',true,
    '{"app_version":"1.2","os_version":"27.0","device":"iPhone18,3"}'::jsonb,
    array['00000000-0000-0000-0000-0000000000f1/00000000-0000-0000-0000-00000000fb01/0.jpg']);
  again := public.babycare_send_feedback('00000000-0000-0000-0000-00000000fb01','bug','  The chart is blank  ',true,'{}'::jsonb,'{}');
  perform pg_temp.check_true(first=again,'retrying the same feedback returns the stored row');
  perform pg_temp.check_true((select count(*)=1 and bool_and(message='The chart is blank' and status='new' and cardinality(attachments)=1)
    from public.app_feedback),'feedback stored trimmed, with its screenshot, as new');
  perform pg_temp.rejects($q$select public.babycare_send_feedback('00000000-0000-0000-0000-00000000fb02','bug','x',false,'{}'::jsonb,array['00000000-0000-0000-0000-0000000000f1/00000000-0000-0000-0000-00000000fb02/9.jpg'])$q$,'22023','attachment must have been uploaded');
  perform pg_temp.rejects($q$select public.babycare_send_feedback('00000000-0000-0000-0000-00000000fb02','bug','x',false,'{}'::jsonb,array['00000000-0000-0000-0000-0000000000f1/00000000-0000-0000-0000-00000000fb01/0.jpg'])$q$,'22023','attachment must belong to this feedback');
  perform pg_temp.rejects($q$select public.babycare_send_feedback('00000000-0000-0000-0000-00000000fb02','praise','x',false)$q$,'23514','unknown kind refused');
  perform pg_temp.rejects($q$select public.babycare_send_feedback('00000000-0000-0000-0000-00000000fb02','other','   ',false)$q$,'23514','empty message refused');
  perform pg_temp.rejects('insert into public.app_feedback(id,user_id,kind,message) values(gen_random_uuid(),''00000000-0000-0000-0000-0000000000f1'',''bug'',''x'')','42501','no direct writes');
  for i in 2..10 loop perform public.babycare_send_feedback(gen_random_uuid(),'suggestion','Idea '||i,false); end loop;
  perform pg_temp.rejects($q$select public.babycare_send_feedback(gen_random_uuid(),'other','One too many',false)$q$,'P0001','ten messages an hour at most');
end $$;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000f2',true);
select pg_temp.check_true((select count(*)=0 from public.app_feedback),'others cannot read someone''s feedback');
select pg_temp.check_true((select count(*)=0 from storage.objects where bucket_id='babycare-feedback'),'others cannot see someone''s screenshots');
select pg_temp.rejects($q$select public.babycare_send_feedback('00000000-0000-0000-0000-00000000fb01','bug','Hijack',false)$q$,'40001','an id taken by another user is refused');
reset role;
select pg_temp.check_true((select contact_email='feedback-sender@example.invalid' and app_version='1.2' and device='iPhone18,3'
  from babycare_private.feedback_inbox where message='The chart is blank')
  and (select bool_and(contact_email is null) from babycare_private.feedback_inbox where message like 'Idea %'),
  'inbox shows the email only when the sender allowed contact');
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.rejects($q$select public.babycare_send_feedback(gen_random_uuid(),'bug','Anonymous',false)$q$,'42501','anonymous feedback refused');
reset role;
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-0000-0000-0000000000f1',true);
select pg_temp.check_true((select count(*)=10 from public.app_feedback),'the sender reads their own messages');
select public.babycare_delete_account();
reset role;
select pg_temp.check_true(not exists(select 1 from public.app_feedback where user_id='00000000-0000-0000-0000-0000000000f1'),'deleting the account deletes its feedback');
select count(*) as passed_checks, bool_and(passed) as all_passed from test_results;
rollback;
