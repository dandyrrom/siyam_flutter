# SIYAM Conceptual Framework (Input–Process–Output)

Analysis of the project-documentation Conceptual Framework against the
**current** SIYAM Flutter Web system (`main`, schema in `updated_db.md`,
routes in `lib/routing/nav_config.dart`, services under `lib/services/`).

---

## Verdict

**The attached documentation Conceptual Framework does not fully match the
current system.** It still describes the right product (sanctuary inventory,
medical care, donations, reporting), but several items are inaccurate,
incomplete, or overstated relative to what the app actually does.

---

## Gap analysis (attached CF vs current system)

### Still accurate

| Area | Evidence |
| --- | --- |
| Auth / role access | `AuthService`, role-gated `app_router.dart` / `nav_config.dart` |
| Stock-in / stock-out | Purchases, donations, waste/expired/adjustment |
| Item + animal + medical records | Inventory, Pets, Treatments |
| Donation form workflow | Submission `pending → approved → received → stocked` / `rejected` |
| Monthly usage reports | Staff + Manager Reports |
| ROP + safety stock | `ReplenishmentService`, Ordering, Manager ROP Status report |
| Social media templates | Staff dashboard replenishment caption |
| Donor impact tracking | `impact_fifo.dart` / Impacts page |
| Audit trail | Manager Audit + Staff My Activity |
| System settings + profiles | Settings, Profile pages |

### Incorrect or overstated in the attached CF

| Attached claim | Actual system |
| --- | --- |
| Replenishment List **with estimated costs** | Replenishment suggests shortfall qty from ROP only. `ReplenishmentItem` has no cost field; Ordering does not estimate purchase cost. |
| “Shelter statistics” as a distinct Impact output | No separate shelter-statistics report. Role dashboards show operational counts; donor Impact is per-donation FIFO (used / discarded / remaining). |
| Process implies auto-ordering from ROP | SIYAM **recommends** replenishment only; it does **not** create purchases/POs from ROP. |

### Missing from the attached CF (present in the system)

| Missing item | Where it lives |
| --- | --- |
| Supplier records | Manager Suppliers |
| Purchase history / Ordering module | Staff Ordering (Replenishment + Purchase History) |
| Dual-pool stock + FEFO batch tracking | `ITEM` pools + `PURCHASE_ITEM` / `DONATION_ITEM` |
| Category / unit catalog management | Manager Settings |
| Alert thresholds + ROP defaults / overrides | `SYSTEM_SETTINGS`, `item_rop_settings`, Settings UI |
| Stock / expiry / donor notifications | Notifications pages (derived alerts; no notification table) |
| Treatment follow-up schedules | Medical / Staff dashboard follow-ups |
| Role-specific dashboards | Manager / Staff / Donor homes |
| Stock movement history | Inventory item history |
| Donor self-registration | Register + login confirmation flows |

### Documentation note

`KNOWN_LIMITATIONS.md` still says Reorder Point with Safety Stock is deferred.
That section is **stale**: ROP is implemented in code (`replenishment_service.dart`,
Settings ROP defaults, Ordering Replenishment tab, Manager ROP Status report).
ROP entities are used by services but are not fully listed in `updated_db.md`.

---

## Updated Conceptual Framework (3×1)

| INPUT | PROCESS | OUTPUT |
| --- | --- | --- |
| • User credentials and profile updates (Manager, Staff, Donor)<br>• Animal identity and status<br>• Item catalog, categories, and units<br>• Stock-in data (purchased and donated batches, optional expiry/cost)<br>• Stock-out data (waste / expired / adjustment)<br>• Medical treatment entries and follow-up schedules<br>• Donation submissions (notes, drop-off schedule, proof)<br>• Walk-in / drop-off donation records<br>• Supplier and purchase records<br>• System configuration (alert thresholds, ROP defaults, per-item ROP overrides) | • Authenticate users and manage access by role<br>• Maintain animal records and medical treatment history<br>• Record stock-in / stock-out; track dual-pool inventory and FEFO batches<br>• Deduct deductible treatment doses from inventory<br>• Monitor stock and expiry; generate role alerts<br>• Compute Average Daily Usage and Reorder Point with Safety Stock; recommend replenishment (does not auto-create purchases)<br>• Review donation submissions (approve / reject / receive / stock-in)<br>• Attribute donation usage via FIFO impact tracking<br>• Generate monthly usage reports and Manager ROP Status analysis<br>• Build social media replenishment captions<br>• Configure settings and catalog; enable/disable staff accounts<br>• Record and display audit trail / Staff My Activity | • Login / registration confirmation and role-gated navigation<br>• Role dashboards (Manager, Staff, Donor)<br>• Inventory status, stock movement history, and alerts<br>• Medical records and treatment follow-up reminders<br>• Replenishment shortfall suggestions (qty only; no estimated costs)<br>• ROP with Safety Stock restocking analysis (Manager)<br>• Monthly usage reports<br>• Donation form status, donation records, and donor donation history<br>• Donor impact statements (used / discarded / remaining)<br>• Social media templates (copyable captions)<br>• Supplier list and purchase history<br>• Notifications for the signed-in role<br>• Audit Trail / My Activity records<br>• Updated profile and system settings |

---

## Sources used for this update

- Runtime modules: `lib/routing/nav_config.dart`, role dashboards, Inventory, Medical, Ordering, Donations, Reports, Audit, Settings, donor portal
- Stock / ROP logic: `lib/services/inventory_service.dart`, `replenishment_service.dart`, `unit_conversion.dart`, `impact_fifo.dart`
- Schema: `updated_db.md` (+ service usage of ROP/audit beyond that doc)
- Product overview: `README.md`
