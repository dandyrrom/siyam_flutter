SIYAM User Manual — FINAL-100 Cross-Check
Against branch: realtime_and_updates (commit 07cb534)
Scope: Manager + Staff (+ shared Login / Profile / Notifications used by Manager/Staff)
Source tab: FINAL-100 only
Date: September 13, 2026

________________________________________________________________________________

HOW TO READ THIS REPORT

• COMPLETED AND INCLUDED — Feature exists on realtime_and_updates AND FINAL-100 already has a written procedure/guide for it.
• INCLUDED BUT NEEDS CORRECTION — FINAL-100 has a guide, but wording/steps partially mismatch the current UI.
• ON BRANCH BUT NOT IN MANUAL — Feature exists on realtime_and_updates; FINAL-100 has no guide (or only an incomplete mention).
• OBSOLETE MANUAL TEXT — FINAL-100 text that no longer matches this branch.

Companion Drive files:
1) Exact layout/format copy of the full Google Doc (all tabs, figures, styling preserved):
   SIYAM_UserManual: FINAL-100 Updated (realtime_and_updates)
2) FINAL-100 Updated Content Pack (Manager/Staff) — corrected + new procedures written in the same manual style for merge into the FINAL-100 tab.

________________________________________________________________________________

A. COMPLETED AND INCLUDED IN FINAL-100
(Guide present in FINAL-100 AND implemented on realtime_and_updates)

SHARED (Manager/Staff)
• 2.1 Logging In
• 2.2 Login Errors
• 2.3 Registering as a Donor (note: public register is donor-only; Staff are created by Manager)
• 2.5 Viewing Your Profile
• 2.6 Updating Your Profile
• 2.7 Changing Your Password
• 3.1 Viewing All Notifications
• 3.2 Using the Notification Bell
• 3.3 Viewing Notification Details (Manager/Staff)
• 3.4 Viewing Inventory Item Details from a Notification (Staff)

MANAGER
• 4.1.1 Viewing the Manager Dashboard
• 4.1.2 Viewing Inventory Overview (Read-Only)
• 4.1.3 Enabling or Disabling a Staff Account
• Adding a Staff Account (body procedure present; TOC numbering incomplete — see Corrections)
• 4.2.1 Viewing Animal Records
• 4.2.2 Searching and Filtering Animal Records
• 4.2.3 Adding an Animal Record
• 4.2.4 Updating an Animal Status
• 4.2.5 Editing an Animal Record
• 4.3.1 Viewing the Supplier List
• 4.3.2 Searching for a Supplier
• 4.3.3 Adding a New Supplier
• 4.3.4 Editing an Existing Supplier
• 4.4.1 Viewing Donation Submissions
• 4.4.2 Searching and Filtering Donation Submissions
• 4.4.3 Reviewing a Donation Submission
• 4.4.4 Approving a Donation Submission
• 4.4.5 Declining a Donation Submission (UI label uses Rejected — see Corrections)
• 4.4.6 Confirming Items Received
• 4.4.7 Stocking In an Approved Donation (Goods Received)
• 4.4.8 Recording a Walk-in Donation as Manager
• 4.5.1 Viewing Monthly Usage
• 4.5.2 Viewing ROP Status
• 4.6.1 Viewing the Audit Trail
• 4.6.2 Searching and Filtering Audit Entries
• 4.7.1–4.7.3 Inventory Alerts (view / low-stock threshold / expiration warning)
• 4.8.1–4.8.2 Reorder Point Defaults (view / update lead time & safety stock)
• 4.9.1–4.9.4 Item ROP Overrides (view / add / edit / remove)
• 4.10.1–4.10.10 Category Management (full set)
• 4.11.1–4.11.4 Unit Management (full set)

STAFF
• 5.1.1 Viewing the Staff Dashboard (Stock Attention model — matches branch)
• 5.1.2 Generating a Social Media Post
• 5.2.1 Viewing the Inventory List
• 5.2.2 Filtering the Inventory List (includes Needs Restock / ROP-related levels)
• 5.2.3 Searching and Sorting
• 5.2.4 Pagination
• 5.2.5 Viewing Item Details
• 5.2.6 Editing an Inventory Item
• 5.2.7 Recording Goods Received via Purchase
• 5.2.8 Recording Goods Received via Donation (Walk-in) — still available to Staff
• 5.2.9 Recording a Dispense (Waste / Expired / Adjustment / Treatment)
• 5.3.1 Viewing Medical Records
• 5.3.2 Searching Animals with Treatments
• 5.3.3 Adding a Treatment (core steps present; follow-up UI missing — see Not In Manual)
• 5.3.4 Viewing Treatment Details
• 5.3.5 Adding an Item to an Existing Treatment
• 5.4.1 Viewing the Replenishment Tab
• 5.4.2 Filtering and Searching Replenishment Needs
• 5.4.3 Viewing Purchase History
• 5.4.4 Viewing Purchase Details
• 5.4.5 Recording a Purchase from Ordering (routes to Inventory Goods Received / purchase stock-in)
• 5.5.1 Viewing the Staff Monthly Usage Report
• 5.6.1 Viewing Your Activity
• 5.6.2 Searching and Filtering Your Activity

QUICK REFERENCE (Manager/Staff-relevant tables present)
• 7.1 Stock Level Statuses
• 7.2 Dispense Types
• 7.3 Donation Types
• 7.4 Donation Statuses (Manager)
• 7.6 Replenishment Priorities
• 7.7 Animal Statuses

________________________________________________________________________________

B. INCLUDED IN FINAL-100 BUT NEEDS CORRECTION
(Guide exists; steps/labels partially wrong vs realtime_and_updates)

1) 4.1.3 intro sentence
   Manual: “There is no create-staff workflow in this version.”
   Branch: Create-staff EXISTS (Add Staff Account).
   Fix: Remove obsolete sentence; promote Adding a Staff Account to 4.1.4 in TOC.

2) Adding a Staff Account — submit button label
   Manual: “+ Create Account”
   Branch UI: “Create Account”

3) 4.2.2 Animal search/filters
   Manual documents Species + Status.
   Branch also has Breed filter and mixed-breed search handling.

4) 4.3.3 Adding a Supplier — required fields
   Manual treats name, contact, and address as required.
   Branch: only Supplier Name is required; contact numbers and address are optional.

5) 4.4.1 Donation summary cards
   Manual lists Pending Review, Ready to Stock In, Stocked In.
   Branch also shows an Approved summary card.

6) 4.4.5 Decline / Reject wording
   Manual: status becomes Declined.
   Branch: Donations list label uses Declined; submission detail status label uses Rejected (inconsistent UI labels on the branch).

7) 4.6.2 Audit module filters
   Manual examples omit Configuration.
   Branch Manager audit includes Configuration.

8) 5.1.1 Stock Attention detail wording
   Manual describes counts such as “no usable stock, low stock, and needs restock soon.”
   Branch: one Stock Attention KPI; priority helpers are Critical = No usable stock, High = Well below ROP, Medium = At or below ROP.

9) 5.1.2 Social Media copy action
   Manual: “Copy the caption if a copy action is provided.”
   Branch: explicit “Copy caption” control (and Supply Needs / Thank-You style tabs in the dialog).

10) 5.3.3 Adding a Treatment
    Core logging steps match, but FINAL-100 omits the Follow-up Reminder controls that exist on Add Treatment.

11) 5.4.1 Replenishment columns
    Manual: priority, stock, ROP, suggested.
    Branch also shows Usage and Average Daily Use (ADU), including decimal display (e.g. 2 d.p.).

12) Goods Received (5.2.7 / 5.2.8 / Manager donated stock-in)
    Branch has Clear All on the Goods Received form; FINAL-100 does not document it.

13) 4.9 Item ROP Overrides
    Branch can show ADU-based suggested safety stock when adding/editing overrides; FINAL-100 does not document the suggestion.

________________________________________________________________________________

C. ON BRANCH (realtime_and_updates) BUT NOT IN FINAL-100 GUIDE
(Manager/Staff features missing from the manual)

1) Medical Follow-up workflow (Staff) — HIGH PRIORITY GAP
   • Schedule Follow-up Reminder while Adding a Treatment (One-time or Repeating; first follow-up date; interval; optional end date; optional note)
   • Staff Dashboard card: Medical Follow-up Reminders (overdue / due today / due soon within ~7 days; View All)
   • From animal medical history: Record Follow-up Treatment, Reschedule, Stop Schedule

2) Realtime multi-user silent refresh (Manager + Staff) — SYSTEM CAPABILITY GAP
   • Postgres realtime → silent screen refresh when other users change subscribed data
   • Not documented as a user-facing capability (FINAL-100 only uses “real-time” loosely for dashboard/search wording)

3) Staff account creation as a numbered TOC section (4.1.4)
   • Procedure exists in body but is not listed in the FINAL-100 Table of Contents

4) Clear All on Goods Received / Stock In form (Staff; Manager donated path)

5) Average Daily Use (ADU) + decimal display on Ordering → Replenishment (Staff)

6) Suggested safety stock when adding/editing Item ROP Overrides (Manager)

7) Animal Breed filter (+ mixed-breed search behavior) (Manager)

8) Donations “Approved” summary card (Manager)

9) Audit Trail Configuration module filter (Manager)

10) Social Media dialog tabs (Supply Needs / Thank-You) detail beyond a single caption modal (Staff)

________________________________________________________________________________

D. OBSOLETE / DO NOT TREAT AS CURRENT FOR THIS BRANCH

• “There is no create-staff workflow in this version.” (under 4.1.3)
• Manager donation status label inconsistency: list shows Declined, detail shows Rejected
• Supplier contact + address as required fields
• Older non-FINAL-100 Staff dashboard copy elsewhere in the multi-tab document that still describes Inventory Health / Pending Submissions as Staff KPIs (ignored for this cross-check; FINAL-100 Staff body correctly uses Stock Attention)

________________________________________________________________________________

E. SUMMARY COUNTS (Manager/Staff FINAL-100 procedures)

• Completed and included: all core TOC procedures in §2 (shared), §3 (Manager/Staff), §4 Manager, §5 Staff, and relevant §7 tables — feature coverage is present on the branch.
• Included but needs correction: 13 items (above).
• On branch but not in manual: 10 items (above), led by Medical Follow-up + Realtime refresh + TOC gap for Add Staff Account.
• Fully removed Manager/Staff TOC procedures: none found.

________________________________________________________________________________

End of cross-check report.
