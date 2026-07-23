-- SIYAM: allow a donation to record an unregistered/walk-in donor.
-- =============================================================================
-- Stock In (Donation) no longer requires linking a real SIYAM donor account.
-- Staff can still optionally link a donor's submission (which always has a
-- real donorid, since a submission can only be created by a logged-in
-- donor), but when there's no submission to link, the donor may not have an
-- account at all -- so donorid must become nullable, and a plain-text
-- fallback column is added for documentation purposes only (no FK, not
-- queryable as a real donor).
--
-- A donation should still always identify a donor one way or another, so a
-- check constraint requires at least one of donorid/donor_name to be set.
-- =============================================================================

alter table public.donation
  alter column donorid drop not null;

alter table public.donation
  add column donor_name text;

alter table public.donation
  add constraint donation_donor_identified
  check (donorid is not null or donor_name is not null);
