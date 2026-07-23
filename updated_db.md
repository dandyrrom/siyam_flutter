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
- type — text (Medical / Food / General, as of `0002_recategorize_and_units.sql`)

## SUBCATEGORY
- id — uuid, PK
- p_category — fk PRIMARY_CATEGORY.id
- type — text (per `0002_recategorize_and_units.sql`: Medical has Capsule, Tablets,
  Oral Suspension, Syrup, Ointment, Anti-Inflammatory, Spray, Shampoo, Drops, Powder,
  Vetwrap, Test Kit, Vaccine, Oxygen, Medical Equipment, IV Injectables, Nebulizer —
  mirroring how the DAS Stock In/Out CSVs group items, split on "/". Food has Dry, Wet,
  Treats. General has Cleaning, Supplies.)

## UNITS
- id — uuid, PK
- name — text, not null — full unit name (e.g. "Bottle", "Tablet"). Added in
  `0002_recategorize_and_units.sql`; **not yet read by the app** — `lib/models/unit.dart`
  only has `abbrName`. Wire this up if/when the UI needs to show full names.
- abbr_name — text, not null — short form used in the app today (e.g. "bot", "tab",
  "pc", "box", "bag", "kg", "ml", "drop", "vial", "amp", "cap", "strip", "pouch",
  "test"). As of `0002_recategorize_and_units.sql`, these are genuine abbreviations
  (previously this column held full words like "tablet"/"bottle").

## ITEM
- id — uuid, PK
- name — text
- p_category — fk PRIMARY_CATEGORY.id
- s_category — fk SUBCATEGORY.id, nullable
- purchase_unit — fk UNITS.id — the container/unit actually bought (box, bottle, bag).
  `total_purchase_stocks` is counted in this unit.
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
- total_purchase_stocks — float, not null, default 0 — count of whole containers
  physically present, denominated in `purchase_unit`. (Renamed from `purchase_stocks`.)
  Changed only by whole-container events: purchase/donation stock-in, and
  waste/expired/adjustment stock-out. Treatment usage does NOT change this — see
  `total_package_stocks` below and the TREATMENT_ITEM stock deduction rule.
- total_package_stocks — float, nullable — running remainder in `package_unit` terms
  (e.g. ml left across all bottles, opened or not). Starts in sync with
  `total_purchase_stocks * package_quantity` at stock-in, and every whole-container
  stock-in/out event moves both by the same proportion to keep them in sync. Treatment
  usage (for deductible items with a package breakdown) deducts from this pool only,
  leaving `total_purchase_stocks` untouched — using part of a bottle doesn't remove it
  from the shelf. Null for items with no package breakdown (`package_quantity` unset).

  **Unused Stocks / Used Stocks** (derived, not stored columns): once the two pools can
  diverge, "how many bottles are still sealed" is no longer just
  `total_purchase_stocks`. `unused_stocks = floor(total_package_stocks /
  package_quantity)` (whole containers with nothing touched yet); `used_stocks =
  total_purchase_stocks - unused_stocks` (containers that have been opened, whether
  partially or fully consumed, but not yet discarded via stock-out). Example: 2 bottles
  at 100ml each (`total_package_stocks` = 200), 1.5ml used in a treatment →
  `total_package_stocks` = 198.5 → unused = 1, used = 1. See
  `InventoryItem.unusedStockQty` / `.usedStockQty` in `lib/models/inventory_item.dart`.
  Both equal `total_purchase_stocks` / 0 for items with no package breakdown.

  **Out of stock**: an item is out of stock only when NEITHER pool has anything left —
  `total_purchase_stocks <= 0` AND (`total_package_stocks` is null or `<= 0`). A bottle
  that's been fully drained (used=2, unused=0, `total_package_stocks`=0) but not yet
  discarded via stock-out still shows as "In Stock" as long as `total_purchase_stocks`
  is still > 0 — the empty container is still physically on the shelf. See
  `InventoryItem.isOutOfStock`.

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

Stock deduction rule (see `applyTreatmentDeduction` in `lib/services/unit_conversion.dart`):
- `item.dispense_unit == item.package_unit` (package breakdown, deductible, e.g. syrup
  dosed in ml): `dispensed_qty` is already in `package_unit` terms — deducted straight
  from `item.total_package_stocks`. `item.total_purchase_stocks` (whole containers) is
  NOT touched.
- `item.dispense_unit` is null (no breakdown at all, e.g. a mop counted per-piece):
  `dispensed_qty` is in `purchase_unit` terms — deducted 1:1 from
  `item.total_purchase_stocks`.
- `item.dispense_unit` is set and differs from `item.package_unit` (e.g. package_unit=ml,
  dispense_unit=drop): no known conversion between them — the row is still written (full
  audit trail on the item and the treatment), but neither stock pool is touched.

## SUBMISSION
- id — uuid, PK
- donorid — fk USER.id (role=donor)
- updatedby — fk USER.id, nullable
- status — enum: pending / approved / rejected / received / stocked -- flow:
  pending -> approved (staff review) -> received (staff confirms items
  physically arrived, sets date_received) -> stocked (Stock In creates the
  linked DONATION/DONATION_ITEM rows); rejected is terminal, reachable only
  from pending
- drop_off_sched — timestamptz, nullable
- datesubmitted — timestamptz
- date_received — timestamptz, nullable — set when staff confirms the items physically arrived (the "Items Received" step, before Stock In)
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
