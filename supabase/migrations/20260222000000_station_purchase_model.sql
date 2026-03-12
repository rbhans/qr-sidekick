-- Switch from subscription tiers to per-station purchase model.
-- Each station slot is a one-time consumable IAP purchase.

-- 1. CASCADE DELETE: when a station is deleted, all its equipment configs are removed.
--    This prevents gaming (set up building, delete station, reuse slot).
alter table public.qsk_equipment_configs
  drop constraint if exists qsk_equipment_configs_station_id_fkey;

alter table public.qsk_equipment_configs
  add constraint qsk_equipment_configs_station_id_fkey
  foreign key (station_id)
  references public.qsk_stations(id)
  on delete cascade;

-- 2. Track purchased station slots on user profiles.
--    Total allowed stations = purchased_station_slots.
--    No free stations; every station requires a purchase.
alter table public.profiles
  add column if not exists purchased_station_slots integer not null default 0;

-- 3. Drop the now-unused subscription columns.
alter table public.profiles
  drop column if exists subscription_tier,
  drop column if exists entitlements;
