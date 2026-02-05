-- Align equipment config access with station ownership/org membership.

do $$
declare
  pol record;
begin
  for pol in
    select policyname
    from pg_policies
    where schemaname = 'public'
      and tablename = 'qsk_equipment_configs'
  loop
    execute format('drop policy if exists %I on public.qsk_equipment_configs', pol.policyname);
  end loop;
end
$$;

alter table public.qsk_equipment_configs enable row level security;

create policy "equipment_configs_select_owner_or_org"
on public.qsk_equipment_configs
for select
to authenticated
using (
  exists (
    select 1
    from public.qsk_stations s
    where s.id = qsk_equipment_configs.station_id
      and (
        (s.organization_id is null and s.created_by = auth.uid())
        or (
          s.organization_id is not null
          and s.organization_id in (
            select organization_id
            from public.qsk_organization_members
            where user_id = auth.uid()
          )
        )
      )
  )
);

create policy "equipment_configs_insert_owner_or_org"
on public.qsk_equipment_configs
for insert
to authenticated
with check (
  created_by = auth.uid()
  and exists (
    select 1
    from public.qsk_stations s
    where s.id = qsk_equipment_configs.station_id
      and (
        (s.organization_id is null and s.created_by = auth.uid())
        or (
          s.organization_id is not null
          and s.organization_id in (
            select organization_id
            from public.qsk_organization_members
            where user_id = auth.uid()
          )
        )
      )
  )
);

create policy "equipment_configs_update_owner_or_org"
on public.qsk_equipment_configs
for update
to authenticated
using (
  exists (
    select 1
    from public.qsk_stations s
    where s.id = qsk_equipment_configs.station_id
      and (
        (s.organization_id is null and s.created_by = auth.uid())
        or (
          s.organization_id is not null
          and s.organization_id in (
            select organization_id
            from public.qsk_organization_members
            where user_id = auth.uid()
          )
        )
      )
  )
)
with check (
  exists (
    select 1
    from public.qsk_stations s
    where s.id = qsk_equipment_configs.station_id
      and (
        (s.organization_id is null and s.created_by = auth.uid())
        or (
          s.organization_id is not null
          and s.organization_id in (
            select organization_id
            from public.qsk_organization_members
            where user_id = auth.uid()
          )
        )
      )
  )
);

create policy "equipment_configs_delete_owner_or_org"
on public.qsk_equipment_configs
for delete
to authenticated
using (
  exists (
    select 1
    from public.qsk_stations s
    where s.id = qsk_equipment_configs.station_id
      and (
        (s.organization_id is null and s.created_by = auth.uid())
        or (
          s.organization_id is not null
          and s.organization_id in (
            select organization_id
            from public.qsk_organization_members
            where user_id = auth.uid()
          )
        )
      )
  )
);
