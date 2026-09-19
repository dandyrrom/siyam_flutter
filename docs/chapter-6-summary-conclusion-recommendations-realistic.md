# CHAPTER 6

# SUMMARY, CONCLUSION, AND RECOMMENDATIONS

## 6.1 Summary

This capstone project produced SIYAM: A Cross-Platform Shelter Inventory and Audit Management System for Dumaguete Animal Sanctuary (DAS). The system was developed to replace the sanctuary's manual logbook-based stock recording with a role-based digital platform for Manager, Staff, and Donor users. In practice, it covers inventory and stock movement, ordering and replenishment support, animal records, treatment logging with linked supply use, donation submission and tracking, alerts and notifications, reports, an audit trail, and a donor portal for donation activity and impact information.

The application was developed using Flutter and Dart, with Supabase providing cloud authentication and database services. Consistent with the implemented system repository, SIYAM is delivered primarily as a Flutter Web application and also includes an Android build target. The web application is hosted on Vercel for production use.

## 6.2 Conclusion

The project has met its objectives. SIYAM automates stock tracking in place of manual logbooks, provides donation tracking and history, links treatment records to inventory updates and animal medical information, applies automated threshold-based inventory monitoring, offers reporting on inventory usage and resource consumption, and gives authorized users accessible, up-to-date information on stocks, animals, and treatments.

In conclusion, SIYAM provides Dumaguete Animal Sanctuary with a working inventory and audit management system suited to its documented operating needs. Within the project's stated scope and limitations--such as internet dependence and the absence of payment, procurement automation, and clinical charting features--the system offers a practical means of recording, monitoring, and reviewing sanctuary supply and care-related activity.

## 6.3 Recommendations

The application is ready for deployment. It is recommended that Dumaguete Animal Sanctuary adopt SIYAM for day-to-day inventory, treatment, donation, and reporting work so that managers, staff, and donors operate from one shared digital record instead of separate logbooks.

Beyond immediate adoption, the following recommendations are offered based on the implemented system and the project's documented scope and limitations:

1. Provide structured user training and a short operating guide for Manager, Staff, and Donor roles before full cutover. Clear role boundaries matter because the system is role-based, and incorrect use of stock-in, treatment logging, or donation approval can weaken inventory accuracy.

2. Keep a reliable internet connection as an operational requirement. SIYAM is online-dependent; transactions and record viewing are not supported offline. DAS should identify a fallback paper procedure only for unavoidable outages, then encode those transactions in SIYAM once connectivity returns.

3. Enforce physical FEFO handling at the storeroom. The system assumes First-Expired, First-Out when deducting stock, but it cannot verify that staff actually withdrew the nearest-expiry batch. Periodic physical checks should remain part of sanctuary practice.

4. Treat non-deductible medical supplies (for example, ointments, eardrops, and similar items whose dispense unit differs from the package unit) as manually reconciled inventory. Treatment rows for these items are still recorded, but stock quantities are not auto-deducted. Staff should use periodic physical counts and manual stock adjustments to keep those balances truthful, and future releases should add clear on-screen notices so users are not misled by unchanged stock figures.

5. Use the replenishment list as decision support, not as an automatic purchasing system. Purchase orders are not auto-generated; managers and staff should continue supplier coordination outside SIYAM while using the system's ordering cues and reports to prioritize restocks.

6. Continue product hardening after handover. Practical next steps supported by current system gaps include: clearer treatment and inventory notices for non-deductible items; optional per-item low-stock thresholds; a batch-level expiry or FEFO reporting view; safer concurrent stock updates under multi-user load; and completing Android release packaging (application identity and signing) if DAS intends regular field use of the mobile build. Any later addition of barcode scanning, offline mode, payments, or clinical charting should be treated as new scope, not as unfinished core delivery.

7. Align the project documentation with the deployed system after acceptance. Where earlier drafts and the repository differ (for example, platform coverage or public access without login), the final documentation should reflect what SIYAM actually provides so future maintainers and DAS staff are not guided by outdated claims.
