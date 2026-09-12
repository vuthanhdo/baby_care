begin;
-- Keep family IDs as internal storage namespaces, preserving existing records/outboxes.
create or replace function public.babycare_create_family(p_id uuid, p_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare u uuid := auth.uid(); existing_id uuid;
begin
  if u is null then raise exception 'Authentication required' using errcode='42501'; end if;
  perform pg_advisory_xact_lock(hashtextextended(u::text, 14));
  select id into existing_id from public.families where created_by=u order by created_at,id limit 1;
  if existing_id is not null then return existing_id; end if;
  if p_id is null then raise exception 'Family ID required' using errcode='22023'; end if;
  insert into public.families(id,name,created_by) values(p_id,'Hồ sơ của tôi',u);
  insert into public.family_members(family_id,user_id,role) values(p_id,u,'owner');
  return p_id;
end $$;

create function babycare_private.enforce_baby_limit()
returns trigger language plpgsql security definer set search_path = '' as $$
declare owner_id uuid;
begin
  if new.deleted_at is not null then return new; end if;
  if TG_OP='UPDATE' then
    if old.deleted_at is null and old.family_id=new.family_id then return new; end if;
  end if;
  select created_by into owner_id from public.families where id=new.family_id;
  perform pg_advisory_xact_lock(hashtextextended(owner_id::text, 14));
  if (select count(*) from public.babies b join public.families f on f.id=b.family_id
      where f.created_by=owner_id and b.deleted_at is null and b.id<>new.id) >= 4 then
    raise exception 'Baby limit reached' using errcode='P0001';
  end if;
  return new;
end $$;
revoke all on function babycare_private.enforce_baby_limit() from public,anon,authenticated;
create trigger babies_account_limit before insert or update of family_id,deleted_at on public.babies
for each row execute function babycare_private.enforce_baby_limit();
commit;
