-- In-app feedback: bug reports with screenshots, suggestions and other messages, read by the developer in the
-- dashboard (Table Editor → babycare_private.feedback_inbox, Storage → babycare-feedback). Additive.
begin;

create table public.app_feedback (
  id uuid primary key,
  -- Deleting the account deletes its feedback; the app removes the screenshots first, like other photos.
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('bug','suggestion','other')),
  message text not null check (length(btrim(message)) between 1 and 4000),
  allow_contact boolean not null default false,
  -- App version, build, iOS version, device model, language and storage mode; nothing about the baby.
  context jsonb not null default '{}' check (jsonb_typeof(context)='object' and octet_length(context::text)<=2000),
  attachments text[] not null default '{}' check (cardinality(attachments)<=3),
  status text not null default 'new' check (status in ('new','seen','done')),
  created_at timestamptz not null default now()
);
create index app_feedback_user on public.app_feedback(user_id,created_at);
create index app_feedback_inbox on public.app_feedback(status,created_at desc);
alter table public.app_feedback enable row level security;
revoke all on public.app_feedback from anon,authenticated;
grant select on public.app_feedback to authenticated;
-- Members read only their own messages (account deletion lists their screenshots this way); writes go through the RPC.
create policy own_feedback on public.app_feedback for select to authenticated using (user_id=(select auth.uid()));

-- Screenshots live under <user id>/<feedback id>/; only the sender uploads or deletes them, nobody else reads them.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('babycare-feedback','babycare-feedback',false,5242880,array['image/jpeg','image/png','image/heic','image/webp']);
create policy babycare_feedback_upload on storage.objects for insert to authenticated
with check(bucket_id='babycare-feedback' and split_part(name,'/',1)=(select auth.uid())::text);
create policy babycare_feedback_own_read on storage.objects for select to authenticated
using(bucket_id='babycare-feedback' and split_part(name,'/',1)=(select auth.uid())::text);
create policy babycare_feedback_own_delete on storage.objects for delete to authenticated
using(bucket_id='babycare-feedback' and split_part(name,'/',1)=(select auth.uid())::text);

-- Retry-safe: the same id with the same content returns the stored row instead of a duplicate.
create function public.babycare_send_feedback(p_id uuid,p_kind text,p_message text,p_allow_contact boolean,
  p_context jsonb default '{}',p_attachments text[] default '{}')
returns jsonb language plpgsql security definer set search_path='' as $$
declare u uuid := auth.uid(); existing public.app_feedback; path text;
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  if p_id is null then raise exception 'Feedback ID required' using errcode='22023'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text,31));
  select * into existing from public.app_feedback where id=p_id;
  if found then
    if existing.user_id<>u then raise exception 'Feedback conflict' using errcode='40001'; end if;
    return jsonb_build_object('id',existing.id,'created_at',existing.created_at);
  end if;
  if (select count(*) from public.app_feedback where user_id=u and created_at>now()-interval '1 hour') >= 10 then
    raise exception 'Too much feedback' using errcode='P0001';
  end if;
  foreach path in array coalesce(p_attachments,'{}') loop
    if split_part(path,'/',1)<>u::text or split_part(path,'/',2)<>p_id::text
      or not exists(select 1 from storage.objects o where o.bucket_id='babycare-feedback' and o.name=path) then
      raise exception 'Unknown attachment' using errcode='22023';
    end if;
  end loop;
  insert into public.app_feedback(id,user_id,kind,message,allow_contact,context,attachments)
  values (p_id,u,p_kind,btrim(p_message),coalesce(p_allow_contact,false),coalesce(p_context,'{}'),coalesce(p_attachments,'{}'))
  returning * into existing;
  return jsonb_build_object('id',existing.id,'created_at',existing.created_at);
end $$;
revoke all on function public.babycare_send_feedback(uuid,text,text,boolean,jsonb,text[]) from public,anon,authenticated;
grant execute on function public.babycare_send_feedback(uuid,text,text,boolean,jsonb,text[]) to authenticated;

-- The developer's inbox: newest first, with the sender's email when they agreed to be contacted.
create view babycare_private.feedback_inbox with (security_invoker=true) as
  select f.created_at,f.status,f.kind,f.message,
    case when f.allow_contact then u.email end as contact_email,
    f.context->>'app_version' as app_version,f.context->>'os_version' as os_version,f.context->>'device' as device,
    f.attachments,f.id,f.user_id
  from public.app_feedback f left join auth.users u on u.id=f.user_id
  order by f.created_at desc;
revoke all on babycare_private.feedback_inbox from public,anon,authenticated;

notify pgrst,'reload schema';
commit;
