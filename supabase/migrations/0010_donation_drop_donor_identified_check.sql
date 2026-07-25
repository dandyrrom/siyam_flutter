-- SIYAM: allow a donation to have no donor info on file at all.
-- =============================================================================
-- 0005_donation_optional_donor.sql required donorid or donor_name to be set.
-- With 0009_donation_type.sql, staff can record either a walk-in or drop-off
-- donation without picking a submission or typing a donor name at all (both
-- fields stay independently optional regardless of type) -- so the
-- constraint no longer holds. Uses IF EXISTS since 0005 was never actually
-- applied against the live database (donorid/donor_name were fixed
-- separately -- see 0011_donation_add_donor_name.sql), so this constraint
-- may never have existed there in the first place.
-- =============================================================================

alter table public.donation
  drop constraint if exists donation_donor_identified;
