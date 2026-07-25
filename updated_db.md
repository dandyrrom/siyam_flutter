# SIYAM database schema (current source of truth)

Replaces `siyam_db_wo_rls.md` as the schema reference — that file described the
Supabase project that was deleted. `schema.md` is also stale (described the same
deleted project). This app currently runs on an in-memory mock data layer
(`lib/mock/mock_database.dart`) shaped exactly like the tables below; when a real
backend is stood up again, it should be created to match this document.

Notes on fields not explicitly typed in the original draft, resolved by inference from
existing patterns in this same schema (not invented from nothing):
- `donorid` (on SUBMISSION, DONATION) is a FK to `USER.id` where `role = 'donor'` —
  there's no separate donor table. Required on SUBMISSION (a submission can only be
  created by a logged-in donor account); nullable on DONATION (a walk-in/drop-off
  donation may have no linked donor account) — see DONATION.donorid below.
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

  **Unused Stocks / In Use** (derived from the item row alone, not stored columns): once
  the two pools can diverge, "how many bottles are still sealed" is no longer just
  `total_purchase_stocks`. Let `total_consumed = total_purchase_stocks * package_quantity
  - total_package_stocks` (cumulative package-unit qty drawn down by treatment against
  the containers currently on hand — stock-in/out events always move both pools by an
  exact multiple of `package_quantity`, so this value is unaffected by them; only
  treatment usage changes it). Then: `unused_stocks = floor(total_package_stocks /
  package_quantity)` (whole containers with nothing touched yet); `in_use =
  total_consumed % package_quantity` (the partial qty consumed from the one container
  that's currently open but not yet depleted — 0 if nothing's currently open).

  **Used Stocks** (derived from full history, not just the item row): unlike Unused/In
  Use, a container that's been stocked out (waste/expired/adjustment) is gone from
  `total_purchase_stocks` entirely, with nothing left on the item row to show it ever
  existed — so Used Stocks is a lifetime tally across STOCK_OUT and TREATMENT_ITEM,
  not derived from current pool state. `used_stocks = (sum of STOCK_OUT.qty for this
  item, always whole purchase_unit events) + floor(total_consumed / package_quantity)`
  (the whole-container equivalent of fully-depleted treatment usage). Using an item in a
  treatment and stocking it out for any other reason are both just "this container is no
  longer available," so both count. For items with no package breakdown, every dose is
  itself a direct whole-purchase-unit deduction (see the TREATMENT_ITEM stock deduction
  rule), so `used_stocks` there is simply `sum(STOCK_OUT.qty) + sum(TREATMENT_ITEM.
  dispensed_qty)`. Non-deductible treatment usage (dispense unit differs from package
  unit, no stored conversion) never draws from any pool and isn't counted anywhere.

  Example: 2 bottles at 100ml each (`total_package_stocks` = 200), 6ml used in a
  treatment → `total_package_stocks` = 194 → unused = 1, in_use = 6ml (one bottle
  opened, not yet fully consumed), used = 0 (nothing fully depleted or stocked out yet).
  If a whole bottle is then thrown out via a waste stock-out (qty=1): `total_purchase_
  stocks` drops to 1, `total_package_stocks` drops to 94 (both pools move by the same
  exact multiple of `package_quantity`). Recomputed against the new, smaller container
  count: unused drops to 0 (94/100 floors to 0), in_use is still 6ml (total_consumed is
  unchanged by whole-container events — see above), and used becomes 1 (the STOCK_OUT
  sum) — the wasted bottle is accounted for even though it no longer appears in
  `total_purchase_stocks` at all, and the model doesn't track *which* physical bottle
  was discarded, only the aggregate pools. See `InventoryItem.unusedStockQty` /
  `.usedStockQty` / `.inUseQty` in `lib/models/inventory_item.dart`. `unused_stocks`
  equals `total_purchase_stocks`, and `in_use` is 0, for items with no package
  breakdown.

  Donor-facing impact reporting (`lib/services/impact_fifo.dart`) intentionally uses a
  *different*, simpler convention — any container touched at all (even partially) counts
  as one whole "used" container — so a donor is told "1 bottle used" rather than a
  fraction. It does not share `usedStockQty`'s "fully depleted only" definition.

  **Out of stock**: an item is out of stock only when NEITHER pool has anything left —
  `total_purchase_stocks <= 0` AND (`total_package_stocks` is null or `<= 0`). A bottle
  that's been fully drained (used=2, unused=0, in_use=0, `total_package_stocks`=0) but
  not yet discarded via stock-out still shows as "In Stock" as long as
  `total_purchase_stocks` is still > 0 — the empty container is still physically on the
  shelf. See `InventoryItem.isOutOfStock`.

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
- id — uuid, PK (`0008_treatment_item_surrogate_key.sql` -- was originally `primary key
  (treatid, itemid)`, which only allowed one row per item per treatment. An ongoing
  treatment can come back for a second, separately-timed dose of the same item, and
  that has to be its own row, not merged into/overwriting the first -- so treatid/itemid
  are now plain FKs, not unique together)
- treatid — fk TREATMENT.id
- itemid — fk ITEM.id
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
- type — enum: walk_in / drop_off. Added in `0009_donation_type.sql`. Purely
  descriptive (how the donation physically came in) — does not constrain
  donorid/subid/donor_name, all of which stay independently optional
  regardless of type. Backfilled on existing rows from subid (set -> 'drop_off',
  null -> 'walk_in'), since that was the only signal for this before the
  column existed.
- donorid — fk USER.id (role=donor), **nullable** as of
  `0005_donation_optional_donor.sql` (the original draft had this required).
  A walk-in donor may have no SIYAM account at all; a drop-off donation's
  donorid is populated from the linked SUBMISSION.donorid when a submission
  is picked, but no submission link is required either.
- donor_name — text, nullable. `0005_donation_optional_donor.sql` was meant
  to add this (plus the donorid nullability above and a check constraint
  requiring donorid or donor_name to be set) but was never actually applied
  to the live database -- confirmed via `information_schema.columns`, the
  column didn't exist and donorid was still not-null. donorid nullability
  was fixed manually; `0011_donation_add_donor_name.sql` adds this column on
  its own, deliberately without recreating 0005's check constraint,
  since a donation can now be recorded with neither donorid nor donor_name
  set (no submission linked, no name typed) -- both fields are independently
  optional regardless of type. `0010_donation_drop_donor_identified_check.sql`
  drops that constraint too, using `IF EXISTS` since it may never have
  existed on this database. Free-text, matching the `receivedby`/`givenby`
  pattern used elsewhere. For a drop-off linked to a submission, this is
  populated from the submission's donor (via donorid), not typed by staff.
- subid — fk SUBMISSION.id, nullable (null for a direct/walk-in donation, or
  any donation not linked to a prior submission)
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
