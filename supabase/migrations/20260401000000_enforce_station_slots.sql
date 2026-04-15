-- Enforce station slot limits at the database level.
-- Prevents bypassing the paywall via direct API inserts.

create or replace function public.check_station_slot_limit()
returns trigger
language plpgsql
security definer
as $$
declare
  v_slots integer;
  v_count integer;
begin
  -- Get purchased slots for the user
  select coalesce(purchased_station_slots, 0)
    into v_slots
    from public.profiles
   where id = new.created_by;

  -- Count existing stations owned by this user
  select count(*)
    into v_count
    from public.qsk_stations
   where created_by = new.created_by;

  if v_count >= v_slots then
    raise exception 'Station limit reached. You have % slot(s) and % station(s).', v_slots, v_count;
  end if;

  return new;
end;
$$;

-- Fire before insert so the row is rejected before it hits the table
create trigger enforce_station_slot_limit
  before insert on public.qsk_stations
  for each row
  execute function public.check_station_slot_limit();
