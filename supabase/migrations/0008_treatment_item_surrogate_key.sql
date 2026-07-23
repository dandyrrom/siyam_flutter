-- SIYAM: allow multiple separate dosing events of the same item on one treatment.
-- =============================================================================
-- treatment_item's primary key was (treatid, itemid), which allowed only one
-- row per item per treatment -- a second dose of the same item logged on a
-- later day had nowhere to go except overwriting the first row's qty/date.
-- Ongoing treatments need each dose recorded as its own distinct row, so this
-- replaces the composite PK with a surrogate id; treatid/itemid remain plain
-- (now non-unique together) foreign keys.
-- =============================================================================

alter table public.treatment_item drop constraint treatment_item_pkey;
alter table public.treatment_item add column id uuid primary key default gen_random_uuid();
