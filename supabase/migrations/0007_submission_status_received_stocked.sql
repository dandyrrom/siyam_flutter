-- SIYAM: split the submission status flow into two more granular states.
-- =============================================================================
-- 'approved' used to stay set through both the "Items Received" confirmation
-- and the eventual Stock In. Staff couldn't tell those apart from status
-- alone. This adds 'received' (set alongside date_received) and 'stocked'
-- (set when Stock In links a donation row), so submission.status now
-- reflects the full flow: pending -> approved -> received -> stocked
-- (rejected remains terminal, reachable only from pending).
-- =============================================================================

alter type submission_status add value 'received';
alter type submission_status add value 'stocked';
