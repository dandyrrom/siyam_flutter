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
won't move; the item's inventory page shows `used_stocks`/`unused_stocks`,
which are meaningless for these items since they only change via manual
`STOCK_OUT` (reason=adjustment), never via treatment usage.

**Suggested follow-up (not yet implemented):**
1. Inline notice on the add-treatment form when the picked item's
   `dispense_unit != package_unit` ("stock won't be auto-deducted").
2. A "not deducted" badge on that `TREATMENT_ITEM` line in treatment/
   medical-record detail views.
3. A "manually tracked" badge on the item's inventory card so stale-looking
   used/unused counts aren't misread as "nothing used yet".
4. Point staff toward periodic physical counts + manual adjustment
   stock-outs as the actual truth-up mechanism for these items — don't
   invent an auto-deduction estimate.
