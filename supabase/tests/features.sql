-- Feature board: suggestions wait for review, votes count once per person, reports, limits, account deletion.
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
create function pg_temp.board_item(id text) returns jsonb language sql as $$
  select e from jsonb_array_elements(public.babycare_feature_board()) e where e->>'id'='00000000-0000-0000-0000-0000000000'||id;
$$;
insert into auth.users(id,email) values
 ('00000000-0000-0000-0000-0000000000c1','idea-author@example.invalid'),
 ('00000000-0000-0000-0000-0000000000c2','idea-voter@example.invalid'),
 ('00000000-0000-0000-0000-0000000000c3','idea-other@example.invalid');
set local role authenticated;
select pg_temp.as_user('c1');
do $$ declare first jsonb; begin
  first := public.babycare_submit_feature('00000000-0000-0000-0000-0000000000d1','  Water reminders  ','Remind every 2 hours');
  perform pg_temp.check_true(first->>'status'='pending','a new suggestion waits for review');
  perform pg_temp.check_true(public.babycare_submit_feature('00000000-0000-0000-0000-0000000000d1','Water reminders','')=first,'retrying returns the stored suggestion');
  perform pg_temp.check_true((pg_temp.board_item('d1')->>'mine')::boolean and (pg_temp.board_item('d1')->>'votes')::int=1
    and pg_temp.board_item('d1')->>'title'='Water reminders','the author sees it, with their own vote');
  perform pg_temp.rejects($q$select public.babycare_submit_feature(gen_random_uuid(),'Hi')$q$,'23514','a title needs at least 3 characters');
  perform pg_temp.rejects($q$select public.babycare_toggle_feature_vote('00000000-0000-0000-0000-0000000000d1')$q$,'P0001','no votes before it is published');
  perform pg_temp.rejects('insert into public.feature_votes(request_id,user_id) values(''00000000-0000-0000-0000-0000000000d1'',''00000000-0000-0000-0000-0000000000c1'')','42501','no direct writes');
  perform pg_temp.rejects('select * from public.feature_requests','42501','no direct reads');
end $$;
select pg_temp.as_user('c2');
select pg_temp.check_true(pg_temp.board_item('d1') is null,'others do not see a suggestion under review');
select pg_temp.rejects($q$select public.babycare_report_feature('00000000-0000-0000-0000-0000000000d1')$q$,'P0001','nothing to report before publishing');
-- The developer publishes it in the dashboard.
reset role;
update public.feature_requests set status='open' where id='00000000-0000-0000-0000-0000000000d1';
set local role authenticated;
select pg_temp.as_user('c2');
do $$ declare r jsonb; begin
  perform pg_temp.check_true(not (pg_temp.board_item('d1')->>'mine')::boolean and not (pg_temp.board_item('d1')->>'voted')::boolean
    and not (pg_temp.board_item('d1') ? 'author'),'published: visible to others, anonymous, not yet voted');
  r := public.babycare_toggle_feature_vote('00000000-0000-0000-0000-0000000000d1');
  perform pg_temp.check_true((r->>'voted')::boolean and (r->>'votes')::int=2,'a vote counts once');
  r := public.babycare_toggle_feature_vote('00000000-0000-0000-0000-0000000000d1');
  perform pg_temp.check_true(not (r->>'voted')::boolean and (r->>'votes')::int=1,'voting again takes the vote back');
  perform public.babycare_toggle_feature_vote('00000000-0000-0000-0000-0000000000d1');
  perform public.babycare_report_feature('00000000-0000-0000-0000-0000000000d1','Spam');
  perform public.babycare_report_feature('00000000-0000-0000-0000-0000000000d1','Spam again');
end $$;
select pg_temp.as_user('c3');
select public.babycare_submit_feature('00000000-0000-0000-0000-0000000000d2','Night mode for feeds','');
reset role;
update public.feature_requests set status='open' where id='00000000-0000-0000-0000-0000000000d2';
update public.feature_requests set status='done' where id='00000000-0000-0000-0000-0000000000d1';
set local role authenticated;
select pg_temp.as_user('c3');
do $$ declare board jsonb := public.babycare_feature_board(); begin
  perform pg_temp.check_true(board->0->>'id'='00000000-0000-0000-0000-0000000000d1' and (board->0->>'votes')::int=2
    and board->1->>'id'='00000000-0000-0000-0000-0000000000d2','most votes first');
  perform pg_temp.rejects($q$select public.babycare_toggle_feature_vote('00000000-0000-0000-0000-0000000000d1')$q$,'P0001','a shipped feature takes no more votes');
  for i in 1..4 loop perform public.babycare_submit_feature(gen_random_uuid(),'Idea number '||i,''); end loop;
  perform pg_temp.rejects($q$select public.babycare_submit_feature(gen_random_uuid(),'One too many','')$q$,'P0001','five suggestions a day at most');
end $$;
reset role;
select pg_temp.check_true((select reports=1 and votes=2 and author_email='idea-author@example.invalid'
  from babycare_private.feature_inbox where id='00000000-0000-0000-0000-0000000000d1')
  and (select status from babycare_private.feature_inbox limit 1)='pending','inbox: pending first, with reports, votes and author');
set local role anon;
select set_config('request.jwt.claim.sub','',true);
select pg_temp.rejects('select public.babycare_feature_board()','42501','anonymous board refused');
reset role;
set local role authenticated;
select pg_temp.as_user('c1');
select public.babycare_delete_account();
reset role;
select pg_temp.check_true(not exists(select 1 from public.feature_requests where user_id='00000000-0000-0000-0000-0000000000c1')
  and not exists(select 1 from public.feature_votes where request_id='00000000-0000-0000-0000-0000000000d1'),
  'deleting the account deletes its suggestions and their votes');
select count(*) as passed_checks, bool_and(passed) as all_passed from test_results;
rollback;
