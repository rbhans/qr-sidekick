-- Create station via RPC so the app doesn't need org logic.

create or replace function public.qsk_create_station(
  p_name text,
  p_host text,
  p_port integer default 443,
  p_protocol text default 'https',
  p_fingerprint text default null
)
returns public.qsk_stations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid;
  v_org uuid;
  v_station public.qsk_stations;
begin
  v_user := auth.uid();
  if v_user is null then
    raise exception 'User not authenticated';
  end if;

  select organization_id
    into v_org
    from public.qsk_organization_members
   where user_id = v_user
   limit 1;

  if v_org is null then
    insert into public.qsk_organizations (name)
    values ('Personal')
    returning id into v_org;

    insert into public.qsk_organization_members (organization_id, user_id, role)
    values (v_org, v_user, 'admin');
  end if;

  insert into public.qsk_stations (
    organization_id,
    name,
    host,
    port,
    protocol,
    fingerprint,
    created_by
  )
  values (
    v_org,
    p_name,
    p_host,
    p_port,
    p_protocol,
    p_fingerprint,
    v_user
  )
  returning * into v_station;

  return v_station;
end;
$$;

grant execute on function public.qsk_create_station(
  text,
  text,
  integer,
  text,
  text
) to authenticated;

-- Replace station policies to rely on org membership only.

drop policy if exists "stations_select_org_or_self" on public.qsk_stations;
drop policy if exists "stations_insert_org_or_self" on public.qsk_stations;
drop policy if exists "stations_update_org_or_self" on public.qsk_stations;
drop policy if exists "stations_delete_org_or_self" on public.qsk_stations;

create policy "stations_select_org_member"
on public.qsk_stations
for select
to authenticated
using (
  organization_id in (
    select organization_id
    from public.qsk_organization_members
    where user_id = auth.uid()
  )
);

create policy "stations_insert_org_member"
on public.qsk_stations
for insert
to authenticated
with check (
  created_by = auth.uid()
  and organization_id in (
    select organization_id
    from public.qsk_organization_members
    where user_id = auth.uid()
  )
);

create policy "stations_update_org_member"
on public.qsk_stations
for update
to authenticated
using (
  organization_id in (
    select organization_id
    from public.qsk_organization_members
    where user_id = auth.uid()
  )
)
with check (
  organization_id in (
    select organization_id
    from public.qsk_organization_members
    where user_id = auth.uid()
  )
);

create policy "stations_delete_org_member"
on public.qsk_stations
for delete
to authenticated
using (
  organization_id in (
    select organization_id
    from public.qsk_organization_members
    where user_id = auth.uid()
  )
);
