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
  from the shelf. A package-unit stock-in (see PURCHASE_ITEM/DONATION_ITEM `qty_unit`
  below) also adds here directly, with no corresponding whole container to count in
  `total_purchase_stocks` — see `total_package_stock_ins`. Null for items with no
  package breakdown (`package_quantity` unset).
- total_package_stock_ins — float, not null, default 0 — cumulative loose `package_unit`
  qty ever stocked in directly (not via a whole container). Only ever increases. Exists
  because a package-unit stock-in breaks the old invariant that `total_package_stocks`
  only ever moves in exact multiples of `package_quantity` alongside
  `total_purchase_stocks` — without this column there would be no way to tell "loose
  stock someone added" apart from "stock drawn down by treatment" when reading
  `total_package_stocks` alone. (This replaces the Unused/In-Use/Used Stocks derived
  formulas that used to live here — see below.)
- stock_count_mode — enum, nullable: `package` / `purchase` — which pool staff have
  chosen to see as this item's headline stock figure (see `InventoryItem.
  effectiveCountMode`, `.displayStockQty`, `.displayStockUnit` in
  `lib/models/inventory_item.dart`). A per-item setting, not a per-visit view toggle —
  two different physical readings of the same item ("3 boxes" vs. "160 tablets")
  shouldn't render differently depending on who's looking. Null means "not set
  explicitly," in which case the default is `package` for deductible items with a
  package breakdown (that's the unit doses are actually tracked in) and `purchase`
  otherwise.

  **Unused/In-Use/Used Stocks were removed** (previously derived from `total_consumed =
  total_purchase_stocks * package_quantity - total_package_stocks`). A package-unit
  stock-in breaks that formula outright — it adds to `total_package_stocks` with no
  corresponding change to `total_purchase_stocks * package_quantity`, so `total_consumed`
  would swing negative and "unused"/"used" would misreport. Rather than patch the
  formula for the new case, the breakdown was dropped entirely in favor of: (1) the
  single current-stock figure from `stock_count_mode` above, and (2) the Stock Movement
  history (`InventoryService.fetchStockHistory`) as the one place staff check "how much
  of this was used" — a chronological log of every purchase/donation/treatment/stock-out
  event, not a rolled-up number that has to reconcile two pools that can now diverge for
  more than one reason.

  Donor-facing impact reporting (`lib/services/impact_fifo.dart`) is unaffected by this
  removal — it was always a separate, independently-computed FIFO replay over
  purchase_item/donation_item/treatment_item/stock_out for donor-facing "your donation's
  impact" messaging, not a read of these derived item-level stats.

  **Out of stock**: an item is out of stock only when NEITHER pool has anything left —
  `total_purchase_stocks <= 0` AND (`total_package_stocks` is null or `<= 0`). A bottle
  that's been fully drained (used=2, unused=0, in_use=0, `total_package_stocks`=0) but
  not yet discarded via stock-out still shows as "In Stock" as long as
  `total_purchase_stocks` is still > 0 — the empty container is still physically on the
  shelf. See `InventoryItem.isOutOfStock`.

## SYSTEM_SETTINGS (new — not in the original draft)

A single-row config table for app-wide alert thresholds. There was no settings
table at all in the original draft; the app previously used a hardcoded
placeholder constant (`kLowStockPurchaseUnitThreshold`) for low-stock alerts and
had no configurable expiry warning window. Deliberately typed columns rather than
a generic key-value settings table — only two values exist today, and a
key-value/EAV design would be premature for that.

- id — uuid, PK (exactly one row ever exists)
- low_stock_threshold — float, not null, default 10 — an item is "Low Stock" when
  `total_purchase_stocks` is at or below this many whole `purchase_unit`
  containers (and not already zero). See `InventoryItem.stockLevel`.
- expiration_warning_days — int, not null, default 30 — an item is flagged with
  an expiry warning when any of its `PURCHASE_ITEM`/`DONATION_ITEM` batches (with
  `qty_remaining > 0`) has an `expiry_date` within this many days of today
  (including already-past dates). No new column was needed on `ITEM` or the
  batch tables for this — `expiry_date` already existed for FEFO deduction
  ordering (see PURCHASE_ITEM below); this setting just defines the alert
  window over that existing data.

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

Also the FEFO batch a treatment/stock-out deduction draws from (see the TREATMENT_ITEM
stock deduction rule below) — there is no separate `stock_batches` table; each
purchase_item/donation_item row already is one stock-in event for one item, which is
exactly batch identity. `qty_remaining` is a separate, mutable running balance,
independent of `qty` (which stays fixed as the original stock-in record).

- purchaseid — PK, fk PURCHASE.id
- itemid — PK, fk ITEM.id
- qty — float (in `qty_unit` terms — added; the original draft omitted this column,
  which would have made stock-in math impossible)
- qty_unit — enum: `purchase_unit` / `package_unit`, default `purchase_unit` — which unit
  `qty`/`purchase_unit_cost` are denominated in for this stock-in event. `package_unit`
  is only valid when the item has a package breakdown (`item.package_unit` set) — a
  restock entered by prescribed/needed amount (e.g. "40 tablets") rather than whole
  containers (e.g. "2 boxes"). See ITEM.total_package_stock_ins for the aggregate-side
  effect of a package_unit stock-in.
- purchase_unit_cost — numeric — cost per `qty_unit` (so this is a cost-per-tablet
  figure on a package_unit row, not a cost-per-box figure divided down — a loose
  partial-box purchase can genuinely have a different per-unit price than the box rate).
- expiry_date — timestamptz, nullable — required (enforced in the Stock In UI) when the
  item's primary category is Medical or Food; optional/hidden otherwise (e.g. a mop).
  Batches with no expiry_date are drawn last in FEFO order, after every batch that has
  one.
- qty_remaining — float, not null — running balance in *canonical* terms: package_unit
  if the item has a package breakdown, else purchase_unit terms (matching whichever unit
  treatment deduction actually draws down — see TREATMENT_ITEM below). Initialized to the
  canonical equivalent of `qty` at stock-in time, then decremented by FEFO deduction as
  batches are drawn from oldest-expiry-first. Not clamped to zero from below by anything
  but the deduction logic itself — the aggregate pools on ITEM remain the source of truth
  for whether stock actually exists; batch qty_remaining is bookkeeping for ordering and
  future per-batch reporting, not a second source of truth to reconcile against.

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

Stock deduction rule (see `applyTreatmentDeduction` in `lib/services/unit_conversion.dart`,
which calls `InventoryService.deductFefo`):
- `item.dispense_unit == item.package_unit` (package breakdown, deductible, e.g. syrup
  dosed in ml): `dispensed_qty` is already in `package_unit` terms. Drawn from this
  item's PURCHASE_ITEM/DONATION_ITEM batches oldest-expiry-first (FEFO, batches with no
  expiry_date drawn last), decrementing each batch's `qty_remaining` in turn, then
  deducted from `item.total_package_stocks`. `item.total_purchase_stocks` (whole
  containers) is NOT touched.
- `item.dispense_unit` is null (no breakdown at all, e.g. a mop counted per-piece):
  `dispensed_qty` is in `purchase_unit` terms — drawn from batches the same FEFO way,
  then deducted 1:1 from `item.total_purchase_stocks`.
- `item.dispense_unit` is set and differs from `item.package_unit` (e.g. package_unit=ml,
  dispense_unit=drop): no known conversion between them — the row is still written (full
  audit trail on the item and the treatment), but neither stock pool nor any batch is
  touched.

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

A FEFO batch, mirroring PURCHASE_ITEM minus cost (donations have no purchase cost) — see
PURCHASE_ITEM above for the batch-model rationale and the shared `qty_unit`/
`qty_remaining`/`expiry_date` fields.

- dntid — PK, fk DONATION.id
- itemid — PK, fk ITEM.id
- qty — float (in `qty_unit` terms — added; the original draft omitted this column)
- qty_unit — enum: `purchase_unit` / `package_unit`, default `purchase_unit` — see
  PURCHASE_ITEM.qty_unit.
- expiry_date — timestamptz, nullable — see PURCHASE_ITEM.expiry_date.
- qty_remaining — float, not null — see PURCHASE_ITEM.qty_remaining.

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

Also drains the equivalent canonical qty (`qty * package_quantity` for items with a
breakdown, else `qty` directly) from this item's batches in FEFO order, same as
TREATMENT_ITEM above — keeps per-batch `qty_remaining` consistent even though STOCK_OUT
itself still only ever moves the aggregate pools at whole-`purchase_unit` granularity.
