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

The Alerts & Notifications feature (`lib/services/expiry_alerts.dart`,
`lib/pages/notifications_page.dart`) now actually consumes `expiry_date` on
the mock backend to compute Expiry Warning alerts — `ManagerDashboardStats.
expiryTrackingAvailable` is `true` for `MockDashboardService`, `false` for
`SupabaseDashboardService`, so the Supabase-backed dashboard/notifications
pages still show an empty/"not available" state for that one alert type
until the migration below happens.

**Why:** The client-facing design was worked out and validated against the
mock layer first (see the FEFO/expiry/package-unit-restock design
conversation); writing Supabase migrations before the mock shape was final
would have meant migrating twice.

**Follow-up:** Write the `supabase/migrations/` files for these columns,
then update `SupabaseInventoryService`/`SupabaseSupplierService`/
`SupabaseDonationService` to match the mock's FEFO/batch logic exactly (see
the `// not yet migrated` / `// mock-only for now` comments in those files
for every spot that needs updating), and update
`SupabaseDashboardService.fetchManagerStats` to compute real expiry alerts
and set `expiryTrackingAvailable: true`.

## system_settings -- mock-only, session cache on Supabase

`SYSTEM_SETTINGS` (see updated_db.md) is a new single-row table backing the
Manager Settings page's low-stock threshold and expiration-warning-days.
`MockSettingsService` persists it on `MockDatabase.instance` like every other
mock table. `SupabaseSettingsService` (`lib/services/settings_service.dart`)
has no table to read/write yet, so it keeps edits in a static in-memory
cache for the current session only (seeded with the same defaults, 10 / 30)
rather than pretending to persist across reloads or devices.

**Follow-up:** Add a `supabase/migrations/` file for `system_settings` and
have `SupabaseSettingsService` read/write it instead of the local cache.

## Staff Dashboard week/month period stats -- mock-only for now

`StaffDashboardStats.week`/`.month` (purchases/treatments/donations counts,
with the prior-period figures the dashboard's ↑/↓ badges are computed from)
are only implemented against the mock data layer
(`MockDashboardService._periodStats` in `lib/services/dashboard_service.dart`).
`SupabaseDashboardService.fetchStaffStats` returns a zeroed
`DashboardPeriodStats` for both windows instead of querying `purchase`/
`treatment`/`donation` by date range, and its `fetchReplenishmentAlerts` only
covers the zero/low tiers (no `needsRestock` tier) since it just re-wraps the
existing `_fetchStockAlerts` zero/low split.

**Why:** Same "implement in mock first" rollout as the FEFO/expiry work
above -- the Week/Month toggle and the Replenishment/social-post generator
were designed and validated against the mock layer first.

**Follow-up:** Port `MockDashboardService._periodStats` to Supabase range
queries (`.gte`/`.lt` on `receiveddate`/`recordeddate`), and extend
`_fetchStockAlerts` (or a new query) to also select a `needsRestock` tier
(`total_purchase_stocks` between the low-stock threshold and 30) so
`fetchReplenishmentAlerts` matches the mock's three tiers.

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
