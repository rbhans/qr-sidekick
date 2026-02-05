-- Allow station access for org members or personal orgs.

create policy "stations_select_org_or_self"
on qsk_stations
for select
to authenticated
using (
  organization_id = auth.uid()
  OR organization_id in (
    select organization_id
    from qsk_organization_members
    where user_id = auth.uid()
  )
);

create policy "stations_insert_org_or_self"
on qsk_stations
for insert
to authenticated
with check (
  created_by = auth.uid()
  AND (
    organization_id = auth.uid()
    OR organization_id in (
      select organization_id
      from qsk_organization_members
      where user_id = auth.uid()
    )
  )
);

create policy "stations_update_org_or_self"
on qsk_stations
for update
to authenticated
using (
  organization_id = auth.uid()
  OR organization_id in (
    select organization_id
    from qsk_organization_members
    where user_id = auth.uid()
  )
)
with check (
  organization_id = auth.uid()
  OR organization_id in (
    select organization_id
    from qsk_organization_members
    where user_id = auth.uid()
  )
);

create policy "stations_delete_org_or_self"
on qsk_stations
for delete
to authenticated
using (
  organization_id = auth.uid()
  OR organization_id in (
    select organization_id
    from qsk_organization_members
    where user_id = auth.uid()
  )
);
