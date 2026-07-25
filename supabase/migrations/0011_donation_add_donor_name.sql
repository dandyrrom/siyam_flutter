-- SIYAM: add the donor_name column that 0005 should have added.
-- =============================================================================
-- Confirmed via information_schema against the live database that
-- 0005_donation_optional_donor.sql was never actually applied: donorid was
-- still not-null (fixed manually) and donor_name didn't exist at all. This
-- adds just the missing column. It deliberately does NOT recreate the
-- donation_donor_identified check constraint from 0005 -- see
-- 0010_donation_drop_donor_identified_check.sql, which already establishes
-- that a donation can have neither donorid nor donor_name set.
-- =============================================================================

alter table public.donation
  add column if not exists donor_name text;
