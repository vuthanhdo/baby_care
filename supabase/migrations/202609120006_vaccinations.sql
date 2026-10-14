-- Versioned wire format. A batch is one transaction, including its retry receipt.
begin;

create table public.vaccinations (
  id uuid primary key, family_id uuid not null, baby_id uuid not null,
  vaccine_name text not null check (length(btrim(vaccine_name)) between 1 and 200),
  vaccinated_at timestamptz not null,
  dose_number integer not null check (dose_number between 1 and 1000),
  next_dose_date timestamptz, clinic text not null default '', notes text not null default '',
  reminder_enabled boolean not null default false, reminder_date timestamptz,
  version bigint not null default 1, revision bigint not null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz,
  foreign key (baby_id,family_id) references public.babies(id,family_id),
  check (isfinite(vaccinated_at)),
  check (next_dose_date is null or (isfinite(next_dose_date) and next_dose_date > vaccinated_at)),
  check (reminder_date is null or (isfinite(reminder_date) and next_dose_date is not null and reminder_date < next_dose_date)),
  check (not reminder_enabled or (next_dose_date is not null and reminder_date is not null))
);
create index vaccinations_baby_date on public.vaccinations(baby_id,vaccinated_at desc,id);
create index vaccinations_sync on public.vaccinations(family_id,revision,id);
alter table public.vaccinations enable row level security;
revoke all on public.vaccinations from anon, authenticated;
grant select on public.vaccinations to authenticated;
create policy family_read on public.vaccinations for select to authenticated using
  (babycare_private.has_role(family_id,array['owner','caregiver','viewer']));

create or replace function public.babycare_apply(
  p_operation_id uuid, p_family_id uuid, p_changes jsonb, p_api_version integer default 1
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  u uuid := auth.uid(); c jsonb; d jsonb; old_row jsonb; row_data jsonb;
  t text; allowed text[]; defaults jsonb; cols text; vals text; updates text;
  item_id uuid; baby uuid; expected bigint; rev bigint; result jsonb;
  request_data jsonb; receipt public.mutation_receipts; items jsonb := '[]';
  removing boolean; seen text[] := '{}'; key text;
begin
  if u is null or not babycare_private.has_role(p_family_id,array['owner','caregiver']) then
    raise exception 'Write access denied' using errcode='42501';
  end if;
  if p_api_version is distinct from 1 or p_operation_id is null or p_changes is null
    or jsonb_typeof(p_changes)<>'array' then
    raise exception 'Invalid v1 envelope' using errcode='22023';
  end if;
  if jsonb_array_length(p_changes) not between 1 and 100 or octet_length(p_changes::text)>1048576 then
    raise exception 'Batch must contain 1..100 changes and at most 1 MiB' using errcode='22023';
  end if;
  -- Serialize retries globally by operation ID, then all changes within a family.
  perform pg_advisory_xact_lock(hashtextextended(p_operation_id::text,1));
  select revision into rev from public.families where id=p_family_id for update;
  request_data := jsonb_build_object('api_version',p_api_version,'changes',p_changes);
  select * into receipt from public.mutation_receipts where operation_id=p_operation_id;
  if found then
    if receipt.user_id<>u or receipt.family_id<>p_family_id or receipt.request<>request_data then
      raise exception 'Operation ID already used with another request' using errcode='40001';
    end if;
    return receipt.result;
  end if;
  rev := rev+1;
  for c in select value from jsonb_array_elements(p_changes) loop
    if jsonb_typeof(c)<>'object' or exists(select 1 from jsonb_object_keys(c) k
      where k not in ('entity','id','baby_id','expected_version','data','deleted')) then
      raise exception 'Invalid change keys' using errcode='22023';
    end if;
    t := c->>'entity'; item_id := (c->>'id')::uuid;
    expected := (c->>'expected_version')::bigint;
    removing := coalesce((c->>'deleted')::boolean,false);
    d := coalesce(c->'data','{}');
    if item_id is null or expected is null or expected<0 or jsonb_typeof(d)<>'object' then
      raise exception 'ID, expected_version and object data required' using errcode='22023';
    end if;
    case t
      when 'babies' then
        allowed := array['name','birth_date','gender','blood_type','allergies','health_notes'];
        defaults := '{"gender":"unspecified","blood_type":"Chưa rõ","allergies":"","health_notes":""}';
      when 'care_activities' then
        allowed := array['kind','occurred_at','value','unit','note','detail'];
        defaults := '{"unit":"","note":"","detail":""}';
      when 'vaccinations' then
        allowed := array['vaccine_name','vaccinated_at','dose_number','next_dose_date','clinic','notes','reminder_enabled','reminder_date'];
        defaults := '{"clinic":"","notes":"","reminder_enabled":false}';
      when 'body_measurements' then
        allowed := array['measured_at','weight','height','head_circumference','method','notes'];
        defaults := '{"method":"","notes":""}';
      when 'baby_care_states' then
        allowed := array['is_tracking_illness','illness_title','illness_start_date','sleep_start_date'];
        defaults := '{"is_tracking_illness":false,"illness_title":""}';
      when 'medication_reminders' then
        allowed := array['name','amount','unit','next_date','note','enabled','episode_only'];
        defaults := '{"note":"","enabled":true,"episode_only":false}';
      when 'media_assets' then
        allowed := array['activity_id','purpose','mime_type','byte_count','status'];
        defaults := '{"status":"pending"}';
      when 'import_jobs' then
        allowed := array['source_id','status','checkpoint'];
        defaults := '{"status":"pending","checkpoint":{}}';
      else raise exception 'Unknown entity' using errcode='22023';
    end case;
    key := t||':'||item_id::text;
    if key=any(seen) then raise exception 'Duplicate entity in batch' using errcode='22023'; end if;
    seen := array_append(seen,key);
    if exists(select 1 from jsonb_object_keys(d) k where not k=any(allowed)) then
      raise exception 'Unknown or protected field' using errcode='22023';
    end if;
    execute format('select to_jsonb(r) from public.%I r where id=$1',t) into old_row using item_id;
    if old_row is null then
      if expected<>0 or removing then raise exception 'Record does not exist' using errcode='40001'; end if;
      row_data := defaults || jsonb_build_object('id',item_id,'family_id',p_family_id,'created_at',now());
    else
      if (old_row->>'family_id')::uuid<>p_family_id then raise exception 'Family mismatch' using errcode='42501'; end if;
      if (old_row->>'version')::bigint<>expected or old_row->>'deleted_at' is not null then
        raise exception 'Version conflict or deleted record' using errcode='40001';
      end if;
      row_data := old_row;
    end if;
    if t not in ('babies','import_jobs') then
      baby := (c->>'baby_id')::uuid;
      if baby is null or (old_row is not null and (old_row->>'baby_id')::uuid<>baby)
        or not exists(select 1 from public.babies where id=baby and family_id=p_family_id and deleted_at is null) then
        raise exception 'Live baby in this family required' using errcode='42501';
      end if;
      row_data := row_data || jsonb_build_object('baby_id',baby);
    elsif c ? 'baby_id' then
      raise exception 'Unexpected baby_id' using errcode='22023';
    end if;
    if t='import_jobs' then
      if old_row is not null and ((old_row->>'user_id')::uuid<>u
        or (d ? 'source_id' and d->'source_id' is distinct from old_row->'source_id')) then
        raise exception 'Import ownership/source mismatch' using errcode='42501';
      end if;
      row_data := row_data || jsonb_build_object('user_id',u);
    end if;
    if removing and (d<>'{}' or t in ('babies','baby_care_states','import_jobs')) then
      raise exception 'Unsupported deletion or nonempty delete data' using errcode='22023';
    end if;
    row_data := row_data || d || jsonb_build_object('version',expected+1,'revision',rev,'updated_at',now(),
      'deleted_at',case when removing then now() else null end);
    if t='babies' and (row_data->>'birth_date')::timestamptz>now()+interval '1 day' then
      raise exception 'Birth date is in the future' using errcode='22023';
    end if;
    if t='vaccinations' and not removing then
      if (row_data->>'vaccinated_at')::timestamptz > now()
        or (row_data->>'vaccinated_at')::timestamptz < (select birth_date from public.babies where id=baby) then
        raise exception 'Invalid vaccination date' using errcode='22023';
      end if;
    end if;
    if t='babies' and exists(select 1 from public.vaccinations where baby_id=item_id and deleted_at is null
      and vaccinated_at < (row_data->>'birth_date')::timestamptz) then
      raise exception 'Birth date is after vaccination history' using errcode='22023';
    end if;
    if t='media_assets' then
      if old_row is not null and exists(select 1 from jsonb_object_keys(d) k where k<>'status') then
        raise exception 'Media identity is immutable' using errcode='22023';
      end if;
      if old_row->>'status'='ready' and row_data->>'status'<>'ready' then
        raise exception 'Cannot reopen completed upload' using errcode='22023';
      end if;
      row_data := row_data || jsonb_build_object('object_path',p_family_id::text||'/'||baby::text||'/'||item_id::text);
      if row_data->>'purpose'='activity' and not exists(select 1 from public.care_activities
        where id=(row_data->>'activity_id')::uuid and baby_id=baby and family_id=p_family_id and deleted_at is null) then
        raise exception 'Live activity required' using errcode='22023';
      end if;
      if row_data->>'status'='ready' and not removing and not exists(select 1 from storage.objects
        where bucket_id='babycare-media' and name=row_data->>'object_path'
        and (metadata->>'size')::bigint=(row_data->>'byte_count')::bigint
        and metadata->>'mimetype'=row_data->>'mime_type') then
        raise exception 'Uploaded object missing or metadata mismatch' using errcode='22023';
      end if;
    end if;
    -- Identifiers come only from the case allowlist and PostgreSQL's catalog.
    select string_agg(format('%I',a.attname),',' order by a.attnum),
      string_agg(format('r.%I',a.attname),',' order by a.attnum),
      string_agg(format('%I=excluded.%I',a.attname,a.attname),',' order by a.attnum)
      into cols,vals,updates from pg_catalog.pg_attribute a
      where a.attrelid=format('public.%I',t)::regclass and a.attnum>0 and not a.attisdropped;
    if old_row is null then
      -- Never upsert: simultaneous UUID collisions across families must fail.
      execute format('insert into public.%I (%s) select %s from jsonb_populate_record(null::public.%I,$1) r',
        t,cols,vals,t) using row_data;
    else
      execute format('update public.%I target set (%s)=(%s)
        from jsonb_populate_record(null::public.%I,$1) r where target.id=r.id and target.family_id=r.family_id',
        t,cols,vals,t) using row_data;
    end if;
    items := items || jsonb_build_array(jsonb_build_object('entity',t,'id',item_id,'version',expected+1));
  end loop;
  update public.families set revision=rev where id=p_family_id;
  result := jsonb_build_object('api_version',1,'operation_id',p_operation_id,'revision',rev,'records',items);
  insert into public.mutation_receipts(operation_id,family_id,user_id,request,result)
    values(p_operation_id,p_family_id,u,request_data,result);
  return result;
end $$;
revoke all on function public.babycare_apply(uuid,uuid,jsonb,integer) from public,anon;
grant execute on function public.babycare_apply(uuid,uuid,jsonb,integer) to authenticated;

-- Consistent bounded reads: pin p_at_revision to the current family revision.
-- If it changes between pages, discard the partial read and restart (40001).
-- This is safe for MVP; retained change history/offline sync is a later phase.
create or replace function public.babycare_read_page(
  p_family_id uuid, p_entity text, p_at_revision bigint,
  p_since_revision bigint default 0, p_after_id uuid default null, p_limit integer default 200
) returns jsonb language plpgsql security invoker set search_path = '' as $$
declare current_revision bigint; rows jsonb;
begin
  if not babycare_private.has_role(p_family_id,array['owner','caregiver','viewer']) then
    raise exception 'Read access denied' using errcode='42501';
  end if;
  if p_entity is null or p_entity not in ('babies','care_activities','body_measurements','baby_care_states',
    'medication_reminders','media_assets','import_jobs','vaccinations') or p_limit is null or p_limit not between 1 and 500
    or p_since_revision is null or p_since_revision<0 or p_at_revision is null or p_since_revision>p_at_revision then
    raise exception 'Invalid read cursor' using errcode='22023';
  end if;
  select revision into current_revision from public.families where id=p_family_id;
  if current_revision is distinct from p_at_revision then
    raise exception 'Family changed; restart pagination' using errcode='40001';
  end if;
  execute format('select coalesce(jsonb_agg(to_jsonb(r) order by r.id),''[]''::jsonb) from
    (select * from public.%I where family_id=$1 and revision>$2 and revision<=$3
      and ($4 is null or id>$4) order by id limit $5) r',p_entity)
    into rows using p_family_id,p_since_revision,p_at_revision,p_after_id,p_limit;
  -- A separate statement may see a concurrent commit under READ COMMITTED.
  select revision into current_revision from public.families where id=p_family_id;
  if current_revision is distinct from p_at_revision then
    raise exception 'Family changed; restart pagination' using errcode='40001';
  end if;
  return jsonb_build_object('revision',p_at_revision,'rows',rows,'next_after_id',
    case when jsonb_array_length(rows)=p_limit then rows->-1->>'id' else null end);
end $$;
revoke all on function public.babycare_read_page(uuid,text,bigint,bigint,uuid,integer) from public,anon;
grant execute on function public.babycare_read_page(uuid,text,bigint,bigint,uuid,integer) to authenticated;

commit;
