-- SIYAM: track when a submission's items were physically confirmed received.
-- =============================================================================
-- Staff previously confirmed "Items Received" client-side only (not
-- persisted), before stocking a donation's items into inventory. This adds a
-- real column so that timestamp survives reloads and can be shown alongside
-- a submission when staff pick one to link during Stock In.
-- =============================================================================

alter table public.submission
  add column date_received timestamptz;
