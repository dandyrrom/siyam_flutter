# SIYAM database schema (current source of truth)

Replaces `siyam_db_wo_rls.md` as the schema reference — that file described the
Supabase project that was deleted. `schema.md` is also stale (described the same
deleted project). This app currently runs on an in-memory mock data layer
(`lib/mock/mock_database.dart`) shaped exactly like the tables below; when a real
backend is stood up again, it should be created to match this document.

Notes on fields not explicitly typed in the original draft, resolved by inference from
existing patterns in this same schema (not invented from nothing):
- `donorid` (on SUBMISSION, DONATION) is a FK to `USER.id` where `role = 'donor'` —
  there's no separate donor table.
- `PURCHASE.receivedby` / `DONATION.receivedby` are free text (no FK), matching the
  free-text `givenby` pattern already on `TREATMENT_ITEM`.

## USER
- id — uuid, PK
- fname — text
- lname — text
- role — enum: manager / staff / donor
- email — text, unique, not null
- password — text (plaintext for the current mock auth only — never do this against a
  real backend; a real implementation must hash it / use proper auth)
- contactnum — bigint

## PRIMARY_CATEGORY
- id — uuid, PK
- type — text

## SUBCATEGORY
- id — uuid, PK
- p_category — fk PRIMARY_CATEGORY.id
- type — text

## UNITS
- id — uuid, PK
- abbr_name — text (e.g. "ml", "tablet", "drop", "bottle", "box", "bag", "kg", "pcs")

## ITEM
- id — uuid, PK
- name — text
- p_category — fk PRIMARY_CATEGORY.id
- s_category — fk SUBCATEGORY.id, nullable
- purchase_unit — fk UNITS.id — the container/unit actually bought (box, bottle, bag).
  `purchase_stocks` is counted in this unit.
- package_unit — fk UNITS.id, nullable — the unit the package's contents are measured
  in (tablet, ml, kg). Null for items with no breakdown (mop, food bowl).
- package_quantity — float, nullable — how many `package_unit`s are in one
  `purchase_unit` (e.g. 1 box = 30 tablet, 1 bottle = 200 ml). Only meaningful when
  `package_unit` is set.
- dispense_unit — fk UNITS.id, nullable — the unit doses/usage are actually recorded in.
  Independent of `package_unit`: usually the same, but can differ (e.g. package_unit=ml,
  dispense_unit=drop) with no stored conversion between them. When it differs from
  `package_unit`, stock cannot be automatically deducted for that item (see
  TREATMENT_ITEM below) — usage is still logged, just not converted.
- purchase_stocks — float — running stock, denominated in `purchase_unit`.

## PET
- id — uuid, PK
- name — text
- species — enum: dog / cat
- breed — text, nullable
- gender — enum: female / male
- spayed_neutered — bool
- status — enum: under_treatment / healthy / adopted / deceased

## SUPPLIER
- id — uuid, PK
- name — text
- contactnum — text
- contacttel — text
- address — text

## PURCHASE
- id — uuid, PK
- suppid — fk SUPPLIER.id
- recordedby — fk USER.id
- recordeddate — timestamptz
- receivedby — text (free text, see notes above)
- receiveddate — timestamptz

## PURCHASE_ITEM
- purchaseid — PK, fk PURCHASE.id
- itemid — PK, fk ITEM.id
- qty — float (purchase_unit terms — added; the original draft omitted this column,
  which would have made stock-in math impossible)
- purchase_unit_cost — numeric

## TREATMENT
- id — uuid, PK
- name — text
- petid — fk PET.id
- recordedby — fk USER.id
- recordeddate — timestamptz
- notes — text, nullable

## TREATMENT_ITEM
- treatid — PK, fk TREATMENT.id
- itemid — PK, fk ITEM.id
- dispensed_qty — float
- dispense_unit — fk UNITS.id (copied from `item.dispense_unit` at time of logging)
- consumeddate — timestamptz
- givenby — text (free text — who physically administered it, may not be a system user)
- recordeddate — timestamptz
- recordedby — fk USER.id

Stock deduction rule: `dispensed_qty` converts to `purchase_unit` via
`dispensed_qty / item.package_quantity` only when `item.dispense_unit ==
item.package_unit`. When they differ, the row is still written (full audit trail on the
item and the treatment), but `item.purchase_stocks` is left untouched — there is no
conversion factor between `package_unit` and `dispense_unit` in this schema.

## SUBMISSION
- id — uuid, PK
- donorid — fk USER.id (role=donor)
- updatedby — fk USER.id, nullable
- status — enum: pending / approved / rejected
- drop_off_sched — timestamptz, nullable
- datesubmitted — timestamptz
- proof_img — text, nullable
- notes — text, nullable

## DONATION
- id — uuid, PK
- donorid — fk USER.id (role=donor)
- subid — fk SUBMISSION.id, nullable (null for a direct/walk-in donation)
- receivedby — text (free text, see notes above)
- receiveddate — timestamptz
- recordedby — fk USER.id
- recordeddate — timestamptz

## DONATION_ITEM
- dntid — PK, fk DONATION.id
- itemid — PK, fk ITEM.id
- qty — float (purchase_unit terms — added; the original draft omitted this column)

## STOCK_OUT (new — not in the original draft)

Covers stock-outs with no medical/treatment reason: waste, expired stock, manual
adjustment. There was no table for this at all in the original draft, so items like
waste/expired batches or worn-out consumables (mops, cleaning supplies) had no way to
be recorded. Stays at `purchase_unit` granularity (whole boxes/bottles/bags) since these
are typically whole-package events, not partial-dose losses.

- id — uuid, PK
- itemid — fk ITEM.id
- qty — float (purchase_unit terms)
- reason — enum: waste / expired / adjustment
- recordeddate — timestamptz
- recordedby — fk USER.id
