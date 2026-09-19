# 6.3 Recommendations — five distinct two-paragraph versions

Use only one version in the final paper.

---

## Version 1 — Deployment and production readiness

### 6.3 Recommendations

Based on the results of system validation and testing, SIYAM is now ready for deployment. All requirements have been fulfilled according to the defined project scope, and the system performs effectively under its intended operating conditions. Before full sanctuary cutover, it is recommended to confirm the production Vercel host and Supabase configuration so Manager, Staff, and Donor accounts can access the live web application reliably.

This release includes low-stock and expiry alerts through system settings and an audit trail for operational monitoring. For the next iteration, a donor-facing share-to-socials option for donations is logged for the backlog. Continued feedback from DAS users will help keep the system relevant over time.

---

## Version 2 — Operating practice at the sanctuary

### 6.3 Recommendations

SIYAM is ready for deployment and is recommended for regular use by Dumaguete Animal Sanctuary. Because the application depends on internet access, DAS should treat connectivity as part of daily operations and encode any outage records once service returns. Staff should also keep physical First-Expired, First-Out practice in the storeroom, since the system assumes FEFO when deducting stock but cannot confirm which batch was withdrawn.

For supplies such as ointments and eardrops, where the dispense unit differs from the package unit, treatments should still be logged while stock is reconciled through physical counts and manual adjustments. These operating habits will help SIYAM’s digital records stay accurate alongside sanctuary workflow.

---

## Version 3 — Training and role discipline

### 6.3 Recommendations

The application is ready for deployment. It is recommended that Dumaguete Animal Sanctuary adopt SIYAM for inventory, treatment, donation, and reporting work so managers, staff, and donors share one digital record instead of separate logbooks. Before full use, DAS should train each role on its screens and responsibilities, since incorrect stock-in, treatment logging, or donation review can weaken inventory accuracy.

SIYAM already separates Manager, Staff, and Donor access according to the project design. Sustained correct use, not only installation, will determine whether the system replaces manual tracking as intended.

---

## Version 4 — Post-handover product backlog

### 6.3 Recommendations

SIYAM meets its defined scope and is ready for deployment at Dumaguete Animal Sanctuary. The current release already supports role-based inventory, medical treatment logging with inventory links, donation tracking, alerts, reports, and audit monitoring on the Flutter Web application hosted with Supabase and Vercel.

After handover, further work should be treated as backlog rather than missing core delivery. Practical next items include clearer notices for non-deductible medical supplies, optional per-item low-stock thresholds, a batch-level expiry view, and Android release packaging if DAS expands field use. Features outside scope—such as barcode scanning, offline mode, payments, or clinical charting—should remain future projects if needed.

---

## Version 5 — Tester insight and continuous improvement

### 6.3 Recommendations

Based on validation and testing, SIYAM is ready for deployment and should be used by Dumaguete Animal Sanctuary in regular operations. One tester also suggested a social space or share-to-socials button so donors can show their contributions; that enhancement is recorded for a later iteration, since the present release centers on inventory, audit, treatment, and donation management.

User needs may change after go-live. Keeping an open feedback channel with managers, staff, and donors will guide future updates and help SIYAM stay useful for sanctuary work and donor engagement.
