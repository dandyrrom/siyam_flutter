-- SIYAM: record how a donation physically came in (walk-in vs drop-off).
-- =============================================================================
-- Staff previously distinguished these implicitly via subid (null = walk-in,
-- set = drop-off), with no explicit column. This adds a real type column so
-- it's captured directly, independent of whether donorid/subid/donor_name
-- are actually set -- all three stay optional regardless of type (see
-- 0005_donation_optional_donor.sql).
--
-- Existing rows are backfilled from the same subid signal that used to imply
-- this, since that's the best available signal for data written before this
-- column existed.
-- =============================================================================

create type donation_type as enum ('walk_in', 'drop_off');

alter table public.donation
  add column type donation_type;

update public.donation
  set type = case when subid is not null then 'drop_off' else 'walk_in' end::donation_type
  where type is null;

alter table public.donation
  alter column type set not null;
