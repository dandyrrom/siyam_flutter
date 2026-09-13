SIYAM
A Cross-Platform Shelter Inventory and Audit Management System
User Manual
Dumaguete Animal Sanctuary (DAS)
Version 2.1  ·  September 2026

FINAL-100 Updated Content Pack (Manager / Staff)
Branch baseline: realtime_and_updates

Purpose of this file
This content pack is written in the same procedure style as the FINAL-100 tab of SIYAM_UserManual: 100% inc. Use it together with the exact Google Docs copy that preserves the original layout, figures, tabs, and formatting:

Companion exact copy (figures + full layout preserved):
SIYAM_UserManual: FINAL-100 Updated (realtime_and_updates)

How to apply
1. Open the exact-copy Google Doc.
2. Work only in the FINAL-100 tab.
3. Replace / insert the sections below so FINAL-100 matches realtime_and_updates.
4. Keep existing Figure captions and screenshots unless a screenshot no longer matches the UI.

________________________________________________________________________________

TABLE OF CONTENTS UPDATES (Manager / Staff)

Insert under 4.1 Manager Dashboard:
4.1.4 Adding a Staff Account

Insert under 5.1 Staff Dashboard:
5.1.3 Viewing Medical Follow-up Reminders

Insert under 5.3 Medical Records:
5.3.6 Scheduling a Follow-up Reminder (during Add Treatment)
5.3.7 Recording a Follow-up Treatment
5.3.8 Rescheduling a Follow-up
5.3.9 Stopping a Follow-up Schedule

Insert under Shared / Introduction or Account notes as applicable:
Realtime Data Refresh (Manager and Staff)

________________________________________________________________________________

CORRECTIONS TO EXISTING FINAL-100 TEXT

4.1.3 Enabling or Disabling a Staff Account
DELETE this sentence from the intro:
“There is no create-staff workflow in this version.”

REPLACE the Adding a Staff Account body (currently unnumbered under 4.1.3) with the numbered 4.1.4 procedure below.
Also change the submit step from “+ Create Account” to “Create Account”.

4.2.2 Searching and Filtering Animal Records
After the Status filter step, ADD:
Use the Breed filter to narrow by breed when needed. Mixed-breed animals can also be found through search terms recognized by the Animals screen.

4.3.3 Adding a New Supplier
REPLACE the required-fields wording so that only Supplier Name is required. Contact Number, Telephone, and Address are optional.

4.4.1 Viewing Donation Submissions
ADD Approved to the summary cards reviewed with Pending Review, Ready to Stock In, and Stocked In.

4.4.5 Declining a Donation Submission
NOTE the current UI labels: the Donations list may show Declined, while the submission detail screen may show Rejected. Document both labels consistently with the screens being described.

4.6.2 Searching and Filtering Audit Entries
INCLUDE Configuration among Manager audit module filters.

5.1.1 Viewing the Staff Dashboard
ALIGN Stock Attention wording with current UI:
Review the Stock Attention card.
Review Stock Priority helpers where shown:
* Critical: No usable stock
* High: Well below ROP
* Medium: At or below ROP

5.1.2 Generating a Social Media Post
REPLACE the copy step with:
Click Copy caption to copy the caption text.
Review Supply Needs and Thank-You options in the dialog when both are available.

5.3.3 Adding a Treatment
KEEP the existing treatment logging steps.
ADD a cross-reference:
To schedule follow-up care while adding a treatment, see 5.3.6 Scheduling a Follow-up Reminder.

5.4.1 Viewing the Replenishment Tab
ADD to the review list:
Usage and Average Daily Use. Average Daily Use may display with decimals (for example, two decimal places).

5.2.7 / 5.2.8 Goods Received
ADD:
Use Clear All when you need to remove all lines and reset the Goods Received form fields before saving.

4.9.2 / 4.9.3 Item ROP Overrides
ADD:
When recent usage is available, the system may show a suggested safety stock based on Average Daily Use. You may apply the suggestion or enter a safety stock value manually.

________________________________________________________________________________

NEW AND REPLACEMENT PROCEDURES
(Same writing style as FINAL-100)

4.1.4 Adding a Staff Account
1. From the Manager Dashboard, open Staff Accounts.
2. Click the Add Staff Account button.
3. The Add Staff Account form is displayed with the following fields:
* First Name * (required)
* Last Name * (required)
* Email Address * (required)
* Contact Number (optional)
* Role (fixed to "Staff")
* Temporary Password * (required)
* Confirm Password * (required)
4. Fill in all required fields with valid information.
5. Click the Create Account button.
6. The system creates the account immediately and displays a success confirmation.
7. The new Staff account appears in the Staff Accounts list with Active status.
Note: The account becomes active immediately upon creation.
Staff accounts are not created through the public Register page. Public registration is for Donors only.
	  Figure 4.1.4.1. Staff Account Form

________________

Realtime Data Refresh (Manager and Staff)
SIYAM keeps open Manager and Staff screens in sync when other users change shared operational data.
1. Keep the relevant screen open while other users create or update records (for example inventory, treatments, donations, settings, or animal records).
2. When a subscribed change occurs, the screen refreshes silently without requiring a manual reload.
3. Continue working with the updated list, cards, or details shown on screen.
Note: Realtime refresh updates the data already opened in the app. It does not replace role permissions. Managers and Staff still only see and perform actions allowed for their role.

________________

5.1.3 Viewing Medical Follow-up Reminders
The Staff Dashboard shows Medical Follow-up Reminders that need attention within the next 7 days.
1. Log in with a valid Staff account and navigate to Dashboard.
2. Locate the Medical Follow-up Reminders card.
3. Review the preview of the most urgent follow-ups, including animal name, treatment, due date, and status (for example Overdue, Due Today, or Due Soon).
4. Click a reminder row to open the animal’s medical history for that follow-up.
5. Click View All to open the full Medical Follow-up Reminders list.
6. In View All, use search and filters (All, Overdue, Due Soon) as needed.
7. Open a reminder from the list to continue from the animal medical history screen.
Figure 5.1.3.1. Medical Follow-up Reminders (Web and Mobile)

Note: If no follow-ups need attention, the card indicates that no follow-ups need attention.

________________

5.3.6 Scheduling a Follow-up Reminder (during Add Treatment)
1. Start Adding a Treatment using the steps in 5.3.3.
2. Before saving, turn on Follow-up Reminder.
3. Choose Follow-up type:
* One-time
* Repeating
4. Set First follow-up to the date of the next real administration.
5. If Repeating is selected, set the interval and choose whether the schedule has an end date.
6. Optionally enter a Follow-up note.
7. Click Save Treatment / Record Treatment.
8. The treatment is saved and the follow-up schedule becomes active for Staff Dashboard reminders and the animal medical history screen.
Figure 5.3.6.1. Follow-up Reminder on Add Treatment (Web and Mobile)

Note: The first follow-up date must be after the administered date. For repeating schedules, the end date cannot be before the first follow-up.

________________

5.3.7 Recording a Follow-up Treatment
1. Open the animal medical history from Medical Records, from a dashboard reminder, or from the related treatment path.
2. Locate the active follow-up schedule.
3. Click Record Follow-up Treatment.
4. Confirm the scheduled follow-up context shown on the treatment entry screen.
5. Add or confirm inventory items and quantities actually used for this follow-up administration.
6. Click Record Follow-up.
7. The follow-up administration is recorded, inventory is updated for items used, and the schedule advances or completes according to the follow-up type.
Figure 5.3.7.1. Record Follow-up Treatment (Web and Mobile)

Note: Recording a follow-up logs a real treatment administration. It is not only a reminder acknowledgment.

________________

5.3.8 Rescheduling a Follow-up
1. Open the animal medical history for the animal with an active follow-up.
2. Locate the active follow-up schedule.
3. Click Reschedule.
4. Choose the new follow-up date.
5. Confirm the change.
6. The next follow-up date updates and Staff Dashboard reminders use the new date.
Figure 5.3.8.1. Reschedule Follow-up (Web and Mobile)

________________

5.3.9 Stopping a Follow-up Schedule
1. Open the animal medical history for the animal with an active follow-up.
2. Locate the active follow-up schedule.
3. Click Stop Schedule.
4. Confirm when prompted (Stop follow-up schedule?).
5. The follow-up schedule is stopped and no longer appears as an actionable dashboard reminder.
Figure 5.3.9.1. Stop Follow-up Schedule (Web and Mobile)

Note: Stopping a schedule does not delete past treatment records.

________________

5.2.7 / 5.2.8 Additional step — Clear All (Goods Received)
While recording Goods Received via Purchase or Donation (Walk-in):
1. If the form contains lines or procurement details you want to discard, click Clear All.
2. Confirm when prompted (Clear all?).
3. All item lines and resettable procurement fields are cleared.
4. Continue entering the correct Goods Received details, then save.
Figure 5.2.x. Clear All on Goods Received (Web and Mobile)

________________

5.4.1 Viewing the Replenishment Tab (updated review list)
1. Navigate to Ordering from the sidebar.
2. Open the Replenishment tab.
3. Review items that need replenishment, including priority (Critical, High, Medium), current stock, Usage, Average Daily Use, ROP, and suggested quantities.
4. Use the ROP formula guidance shown on screen when needed:
ROP = (Average Daily Usage × Lead Time) + Safety Stock.
    Figure 5.4.1.1. Ordering Page - Replenishment (Web and Mobile)

Note: Average Daily Use may display with decimal precision. Replenishment identifies needs; receiving stock is completed through Goods Received / Record Purchase.

________________

4.9.2 Adding an Item ROP Override (suggestion note)
After entering custom lead time and safety stock values:
When recent usage exists, review the suggested safety stock based on Average Daily Use. Click the suggestion action if available, or keep a manually entered safety stock value.
Then save the override as documented in FINAL-100.

________________

End of FINAL-100 Updated Content Pack (Manager / Staff)
