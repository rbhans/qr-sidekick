-- Allow stations to be user-owned without organizations, while keeping orgs for the website.

alter table public.qsk_stations
  alter column organization_id drop not null;

-- Remove RPC that created orgs on behalf of the app.
drop function if exists public.qsk_create_station(text, text, integer, text, text);

-- Replace station policies to allow either user-owned or org-owned rows.
drop policy if exists "stations_select_org_member" on public.qsk_stations;
drop policy if exists "stations_insert_org_member" on public.qsk_stations;
drop policy if exists "stations_update_org_member" on public.qsk_stations;
drop policy if exists "stations_delete_org_member" on public.qsk_stations;

drop policy if exists "stations_select_org_or_self" on public.qsk_stations;
drop policy if exists "stations_insert_org_or_self" on public.qsk_stations;
drop policy if exists "stations_update_org_or_self" on public.qsk_stations;
drop policy if exists "stations_delete_org_or_self" on public.qsk_stations;

create policy "stations_select_owner_or_org"
on public.qsk_stations
for select
to authenticated
using (
  (organization_id is null and created_by = auth.uid())
  or (
    organization_id is not null
    and organization_id in (
      select organization_id
      from public.qsk_organization_members
      where user_id = auth.uid()
    )
  )
);

create policy "stations_insert_owner_or_org"
on public.qsk_stations
for insert
to authenticated
with check (
  created_by = auth.uid()
  and (
    organization_id is null
    or organization_id in (
      select organization_id
      from public.qsk_organization_members
      where user_id = auth.uid()
    )
  )
);

create policy "stations_update_owner_or_org"
on public.qsk_stations
for update
to authenticated
using (
  (organization_id is null and created_by = auth.uid())
  or (
    organization_id is not null
    and organization_id in (
      select organization_id
      from public.qsk_organization_members
      where user_id = auth.uid()
    )
  )
)
with check (
  (organization_id is null and created_by = auth.uid())
  or (
    organization_id is not null
    and organization_id in (
      select organization_id
      from public.qsk_organization_members
      where user_id = auth.uid()
    )
  )
);

create policy "stations_delete_owner_or_org"
on public.qsk_stations
for delete
to authenticated
using (
  (organization_id is null and created_by = auth.uid())
  or (
    organization_id is not null
    and organization_id in (
      select organization_id
      from public.qsk_organization_members
      where user_id = auth.uid()
    )
  )
);
