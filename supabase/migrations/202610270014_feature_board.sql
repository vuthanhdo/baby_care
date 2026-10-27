-- Feature board: parents suggest features and vote for the ones they want. A suggestion is shown to everyone only
-- after the developer publishes it (status 'open' in the dashboard), and its author is never shown. Additive.
begin;

create table public.feature_requests (
  id uuid primary key,
  -- Deleting the account deletes what it wrote, with the votes it collected.
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(btrim(title)) between 3 and 120),
  details text not null default '' check (length(details) <= 1000),
  -- pending: waiting for review, seen only by its author. open: published, votable. planned: votable, being built.
  -- done: shipped, no more votes. declined: hidden from everyone but its author.
  status text not null default 'pending' check (status in ('pending','open','planned','done','declined')),
  created_at timestamptz not null default now()
);
create index feature_requests_status on public.feature_requests(status,created_at);
create index feature_requests_user on public.feature_requests(user_id,created_at);
create table public.feature_votes (
  request_id uuid not null references public.feature_requests(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (request_id,user_id)
);
create index feature_votes_user on public.feature_votes(user_id);
-- Reports of offensive content (App Store Review Guideline 1.2); the developer reads them in the inbox view.
create table public.feature_reports (
  request_id uuid not null references public.feature_requests(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  reason text not null default '' check (length(reason) <= 500),
  created_at timestamptz not null default now(),
  primary key (request_id,user_id)
);
create index feature_reports_user on public.feature_reports(user_id);
alter table public.feature_requests enable row level security;
alter table public.feature_votes enable row level security;
alter table public.feature_reports enable row level security;
-- No policies: the app reads the board and writes only through the functions below.
revoke all on public.feature_requests,public.feature_votes,public.feature_reports from anon,authenticated;

create function public.babycare_feature_board()
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id',r.id,'title',r.title,'details',r.details,'status',r.status,
      'votes',(select count(*) from public.feature_votes v where v.request_id=r.id),
      'voted',exists(select 1 from public.feature_votes v where v.request_id=r.id and v.user_id=u),
      'mine',r.user_id=u,'created_at',r.created_at)
    order by (r.status in ('pending','declined')) desc,(select count(*) from public.feature_votes v where v.request_id=r.id) desc,r.created_at)
    from public.feature_requests r
    where r.status in ('open','planned','done') or r.user_id=u),'[]'::jsonb);
end $$;

-- Retry-safe by id. The author's own vote comes with the suggestion.
create function public.babycare_submit_feature(p_id uuid,p_title text,p_details text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid := auth.uid(); existing public.feature_requests;
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_id is null then raise exception 'Suggestion ID required' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text,41));
  select * into existing from public.feature_requests where id=p_id;
  if found then
    if existing.user_id<>u then raise exception 'Suggestion conflict' using errcode='40001'; end if;
    return jsonb_build_object('id',existing.id,'status',existing.status);
  end if;
  if (select count(*) from public.feature_requests where user_id=u and created_at>now()-interval '1 day') >= 5 then
    raise exception 'Too many suggestions' using errcode='P0001';
  end if;
  insert into public.feature_requests(id,user_id,title,details) values (p_id,u,btrim(p_title),btrim(coalesce(p_details,'')))
  returning * into existing;
  insert into public.feature_votes(request_id,user_id) values (p_id,u);
  return jsonb_build_object('id',existing.id,'status',existing.status);
end $$;

-- Votes go on published suggestions still open for them (open, planned). Returns the new state and count.
create function public.babycare_toggle_feature_vote(p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid := auth.uid(); now_voted boolean;
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform 1 from public.feature_requests where id=p_request_id and status in ('open','planned') for update;
  if not found then raise exception 'Not open for votes' using errcode='P0001'; end if;
  delete from public.feature_votes where request_id=p_request_id and user_id=u;
  now_voted := not found;
  if now_voted then insert into public.feature_votes(request_id,user_id) values (p_request_id,u); end if;
  return jsonb_build_object('voted',now_voted,'votes',(select count(*) from public.feature_votes where request_id=p_request_id));
end $$;

create function public.babycare_report_feature(p_request_id uuid,p_reason text default '')
returns boolean language plpgsql security definer set search_path='' as $$
declare u uuid := auth.uid();
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if not exists(select 1 from public.feature_requests where id=p_request_id and status in ('open','planned','done')) then
    raise exception 'Not found' using errcode='P0001';
  end if;
  insert into public.feature_reports(request_id,user_id,reason) values (p_request_id,u,left(btrim(coalesce(p_reason,'')),500))
  on conflict (request_id,user_id) do nothing;
  return true;
end $$;

revoke all on function public.babycare_feature_board(),public.babycare_submit_feature(uuid,text,text),
  public.babycare_toggle_feature_vote(uuid),public.babycare_report_feature(uuid,text) from public,anon,authenticated;
grant execute on function public.babycare_feature_board(),public.babycare_submit_feature(uuid,text,text),
  public.babycare_toggle_feature_vote(uuid),public.babycare_report_feature(uuid,text) to authenticated;

-- The developer's queue: suggestions waiting for review first, then by votes, with reports and the author's email.
create view babycare_private.feature_inbox with (security_invoker=true) as
  select r.status,r.title,r.details,
    (select count(*) from public.feature_votes v where v.request_id=r.id) as votes,
    (select count(*) from public.feature_reports p where p.request_id=r.id) as reports,
    u.email as author_email,r.created_at,r.id
  from public.feature_requests r left join auth.users u on u.id=r.user_id
  order by (r.status='pending') desc,(select count(*) from public.feature_reports p where p.request_id=r.id) desc,
    (select count(*) from public.feature_votes v where v.request_id=r.id) desc,r.created_at;
revoke all on babycare_private.feature_inbox from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
