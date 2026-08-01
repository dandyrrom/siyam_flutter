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
`unused_stocks` here as evidence of the gap — those were removed entirely in
favor of the FEFO batch model (`total_package_stock_ins`/`stock_count_mode`,
now implemented on both mock and Supabase), so this note now just points at
the Stock Movement history: a non-deductible item's log will show treatment
rows that never correspond to a stock decrease.)

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

## Reorder Point with Safety Stock / batch-level expiry UI -- deferred by scope decision

Alerts & Notifications (increment 1) intentionally ships only: zero-stock
alerts, a single configurable low-stock threshold (`SYSTEM_SETTINGS.
low_stock_threshold`, global — not per-item), and expiry warnings driven by a
configurable window (`SYSTEM_SETTINGS.expiration_warning_days`) over the
existing batch-level `expiry_date`.

Not built, and not implied by the above:
- **Reorder Point with Safety Stock** — no lead-time or safety-stock formula,
  no per-item reorder-point column. `stockLevel`'s low-stock tier is a plain
  threshold comparison, not a computed reorder point.
- **Per-item low-stock threshold override** — confirmed out of scope for this
  increment (would need a nullable `item.low_stock_threshold` column falling
  back to the global setting); only the global setting exists today.
- **Batch-level expiry / FEFO reporting UI** — `expiry_date` is read for
  alerting (soonest date per item), but there is no per-batch expiry list/
  report page; that data model already exists for FEFO deduction ordering
  (see updated_db.md's PURCHASE_ITEM), just not surfaced as its own UI.

**Why:** Scope decision, confirmed with the requester before implementation —
not an oversight. Raise these explicitly if a future increment needs them.
