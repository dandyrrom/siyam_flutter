# Known Limitations

## Non-deductible dispense units (ointments, eardrops, vetwrap, etc.)

When `ITEM.dispense_unit` is set but differs from `ITEM.package_unit` (e.g.
package_unit=ml, dispense_unit=drop for eardrops; ointments/vetwrap with no
fixed measurable amount), there is no conversion between the two units.
`applyTreatmentDeduction` in `lib/services/unit_conversion.dart` deliberately
skips stock deduction for these — the `TREATMENT_ITEM` row is still written as
an audit trail, but neither `total_package_stocks` nor `total_purchase_stocks`
moves. This is documented in `updated_db.md` under the TREATMENT_ITEM stock
deduction rule.

**Why:** Estimating a conversion (e.g. "1 tube ≈ 30 applications") would be a
fabricated field per the Data Scope Rule in `CLAUDE.md` — the schema has no
such column today. Adding one would be a deliberate schema decision, not a UI
backfill.

**Current gap:** As of 2026-07-21, no page tells the user this is happening.
`add_treatment_page.dart` logs the dispensed qty with no notice that stock
won't move. (The inventory item page used to show `used_stocks`/
`unused_stocks` here as evidence of the gap — those were removed entirely,
see below, so this note now just points at the Stock Movement history: a
non-deductible item's log will show treatment rows that never correspond to
a stock decrease.)

**Suggested follow-up (not yet implemented):**
1. Inline notice on the add-treatment form when the picked item's
   `dispense_unit != package_unit` ("stock won't be auto-deducted").
2. A "not deducted" badge on that `TREATMENT_ITEM` line in treatment/
   medical-record detail views.
3. A "manually tracked" badge on the item's inventory card so the current
   stock figure (`InventoryItem.displayStockQty`) isn't misread as
   reflecting real-time usage for these items.
4. Point staff toward periodic physical counts + manual adjustment
   stock-outs as the actual truth-up mechanism for these items — don't
   invent an auto-deduction estimate.

## FEFO batches / stock_count_mode / expiry_date -- mock-only for now

`PURCHASE_ITEM`/`DONATION_ITEM`'s `qty_unit`, `expiry_date`, `qty_remaining`
columns, and `ITEM`'s `total_package_stock_ins`/`stock_count_mode` columns
(added for expiry tracking + FEFO deduction + package-unit restocking) exist
in the mock data layer (`lib/mock/mock_database.dart`,
`lib/models/inventory_item.dart`) and are read/written by
`MockInventoryService`/`MockSupplierService`/`MockDonationService`. The
Supabase implementations (`lib/services/supabase/*.dart`) do not have these
columns migrated onto the real schema yet, per the "implement in mock first"
rollout — they fall back to the pre-redesign aggregate-only behavior
(`stockIn`/`deductFefo` deduct from `total_purchase_stocks`/
`total_package_stocks` directly, with no per-batch FEFO ordering, no
`total_package_stock_ins` tracking, and `stock_count_mode` silently ignored
on write, always null on read).

**Why:** The client-facing design was worked out and validated against the
mock layer first (see the FEFO/expiry/package-unit-restock design
conversation); writing Supabase migrations before the mock shape was final
would have meant migrating twice.

**Follow-up:** Write the `supabase/migrations/` files for these columns,
then update `SupabaseInventoryService`/`SupabaseSupplierService`/
`SupabaseDonationService` to match the mock's FEFO/batch logic exactly (see
the `// not yet migrated` / `// mock-only for now` comments in those files
for every spot that needs updating).
