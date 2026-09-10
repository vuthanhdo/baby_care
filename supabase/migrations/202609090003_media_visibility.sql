begin;
-- A tombstoned activity must also hide its stored images immediately.
create or replace function babycare_private.can_access_media(p_path text, p_write boolean)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.media_assets a
    join public.babies b on b.id=a.baby_id and b.family_id=a.family_id
    where a.object_path=p_path and a.deleted_at is null and b.deleted_at is null
      and (a.activity_id is null or exists(select 1 from public.care_activities c
        where c.id=a.activity_id and c.baby_id=a.baby_id and c.family_id=a.family_id and c.deleted_at is null))
      and (not p_write or a.status='pending')
      and babycare_private.has_role(a.family_id,
        case when p_write then array['owner','caregiver'] else array['owner','caregiver','viewer'] end));
$$;
revoke all on function babycare_private.can_access_media(text,boolean) from public,anon;
grant execute on function babycare_private.can_access_media(text,boolean) to authenticated;
commit;
