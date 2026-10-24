-- 1.1 health details: breathing-rate entries, a baby's medical history and a doctor visit's follow-up date.
-- Apply before releasing 1.1; versions 1.0/1.0.1 keep working:
-- * They treat an unknown activity kind as corrupt data and would stop loading the whole family, so
--   babycare_read_page only returns kinds they know unless the caller asks for p_api_version >= 2.
-- * New columns have defaults, and babycare_apply merges sent fields into the stored row, so their writes
--   never clear medical_history or follow_up_at.
begin;

alter table public.babies add column medical_history text not null default ''
  check (length(medical_history) <= 4000);
alter table public.care_activities add column follow_up_at timestamptz
  check (follow_up_at is null or (kind = 'doctor' and follow_up_at > occurred_at));

alter table public.care_activities drop constraint care_activities_kind_check;
alter table public.care_activities add constraint care_activities_kind_check check (kind in
  ('temperature','breathing','medicine','symptom','doctor','allergy','milk','meal','water','sleep','bath','diaper','other'));

-- Adding a parameter creates a new overload; drop the old one so PostgREST resolves old and new calls to one function.
drop function public.babycare_read_page(uuid,text,bigint,bigint,uuid,integer);
create function public.babycare_read_page(
  p_family_id uuid, p_entity text, p_at_revision bigint,
  p_since_revision bigint default 0, p_after_id uuid default null, p_limit integer default 200,
  p_api_version integer default 1
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare current_revision bigint; rows jsonb; legacy_filter text := '';
begin
  if not babycare_private.has_role(p_family_id,array['owner','caregiver','viewer']) then
    raise exception 'Read access denied' using errcode='42501';
  end if;
  if p_entity is null or p_entity not in ('babies','care_activities','body_measurements','baby_care_states',
    'medication_reminders','media_assets','import_jobs','vaccinations') or p_limit is null or p_limit not between 1 and 500
    or p_since_revision is null or p_since_revision<0 or p_at_revision is null or p_since_revision>p_at_revision
    or p_api_version is null or p_api_version<1 then
    raise exception 'Invalid read cursor' using errcode='22023';
  end if;
  if p_api_version<2 then
    if p_entity='care_activities' then
      legacy_filter:=' and kind in (''temperature'',''medicine'',''symptom'',''doctor'',''allergy'',''milk'',''meal'',''water'',''sleep'',''bath'',''diaper'',''other'')';
    elsif p_entity='media_assets' then
      legacy_filter:=' and not exists (select 1 from public.care_activities a where a.id=media_assets.activity_id and a.kind=''breathing'')';
    end if;
  end if;
  select revision into current_revision from public.families where id=p_family_id;
  if current_revision is distinct from p_at_revision then
    raise exception 'Family changed; restart pagination' using errcode='40001';
  end if;
  execute format('select coalesce(jsonb_agg(to_jsonb(r) order by r.id),''[]''::jsonb) from
    (select * from public.%I where family_id=$1 and revision>$2 and revision<=$3
      and ($4 is null or id>$4)%s order by id limit $5) r',p_entity,legacy_filter)
    into rows using p_family_id,p_since_revision,p_at_revision,p_after_id,p_limit;
  -- A separate statement may see a concurrent commit under READ COMMITTED.
  select revision into current_revision from public.families where id=p_family_id;
  if current_revision is distinct from p_at_revision then
    raise exception 'Family changed; restart pagination' using errcode='40001';
  end if;
  return jsonb_build_object('revision',p_at_revision,'rows',rows,'next_after_id',
    case when jsonb_array_length(rows)=p_limit then rows->-1->>'id' else null end);
end $$;
revoke all on function public.babycare_read_page(uuid,text,bigint,bigint,uuid,integer,integer) from public,anon;
grant execute on function public.babycare_read_page(uuid,text,bigint,bigint,uuid,integer,integer) to authenticated;

-- Allow the two new fields in babycare_apply. The function is patched in place from its deployed definition
-- (the live copy is a reformatted 202609120006 body, moved to babycare_private by 202609180008), so nothing
-- else in it changes. medical_history needs a default: inserts populate every column from the JSON row.
do $patch$
declare
  def text := pg_get_functiondef('babycare_private.babycare_apply(uuid,uuid,jsonb,integer)'::regprocedure);
  edits text[] := array[
    $a$array['name','birth_date','gender','blood_type','allergies','health_notes']$a$,
    $b$array['name','birth_date','gender','blood_type','allergies','health_notes','medical_history']$b$,
    $a$"health_notes":""}$a$,
    $b$"health_notes":"","medical_history":""}$b$,
    $a$array['kind','occurred_at','value','unit','note','detail']$a$,
    $b$array['kind','occurred_at','value','unit','note','detail','follow_up_at']$b$];
  i int;
begin
  for i in 1..array_length(edits,1) by 2 loop
    if (length(def) - length(replace(def, edits[i], ''))) / length(edits[i]) <> 1 then
      raise exception 'babycare_apply must contain exactly one %', edits[i];
    end if;
    def := replace(def, edits[i], edits[i+1]);
  end loop;
  execute def;
end $patch$;
revoke all on function babycare_private.babycare_apply(uuid,uuid,jsonb,integer) from public,anon,authenticated;

commit;
