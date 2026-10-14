-- User-controlled erasure for child profiles and accounts.
-- These RPCs use hard deletion so removed health data is not returned by sync or retained in mutation receipts.
begin;

create or replace function babycare_private.can_delete_media(p_path text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.media_assets a
    where a.object_path=p_path
      and babycare_private.has_role(a.family_id,array['owner']));
$$;
revoke all on function babycare_private.can_delete_media(text) from public,anon;
grant execute on function babycare_private.can_delete_media(text) to authenticated;

drop policy if exists babycare_media_delete on storage.objects;
create policy babycare_media_delete on storage.objects for delete to authenticated
using(bucket_id='babycare-media' and babycare_private.can_delete_media(name));

create or replace function public.babycare_delete_baby(p_family_id uuid, p_baby_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not babycare_private.has_role(p_family_id,array['owner']) then
    raise exception 'Owner access required' using errcode='42501';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_family_id::text,0));
  if not exists(select 1 from public.babies where id=p_baby_id and family_id=p_family_id) then
    raise exception 'Baby not found' using errcode='40001';
  end if;

  -- Binary objects are removed through the authenticated Storage API before this RPC.
  -- Supabase deliberately rejects direct SQL deletion from storage.objects.
  delete from public.media_assets where family_id=p_family_id and baby_id=p_baby_id;
  delete from public.vaccinations where family_id=p_family_id and baby_id=p_baby_id;
  delete from public.medication_reminders where family_id=p_family_id and baby_id=p_baby_id;
  delete from public.baby_care_states where family_id=p_family_id and baby_id=p_baby_id;
  delete from public.body_measurements where family_id=p_family_id and baby_id=p_baby_id;
  delete from public.care_activities where family_id=p_family_id and baby_id=p_baby_id;
  delete from public.babies where family_id=p_family_id and id=p_baby_id;
  -- Receipts can contain a copy of earlier health payloads and are not needed after an explicit erasure.
  delete from public.mutation_receipts where family_id=p_family_id;
  update public.families set revision=revision+1 where id=p_family_id;
  return true;
end $$;
revoke all on function public.babycare_delete_baby(uuid,uuid) from public,anon;
grant execute on function public.babycare_delete_baby(uuid,uuid) to authenticated;

create or replace function public.babycare_delete_account()
returns boolean language plpgsql security definer set search_path = '' as $$
declare
  u uuid := auth.uid();
  family_ids uuid[];
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text,0));
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
  return true;
end $$;
revoke all on function public.babycare_delete_account() from public,anon;
grant execute on function public.babycare_delete_account() to authenticated;

commit;
