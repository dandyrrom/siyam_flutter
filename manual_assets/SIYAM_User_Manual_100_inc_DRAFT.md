**SIYAM**

*A Cross-Platform Shelter Inventory and Audit Management System*

**User Manual**

Dumaguete Animal Sanctuary (DAS)

By Group 4

Version 2.0  ·  August 2026



# **Table of Contents**

**1. Introduction**

1.1 User Roles

**2. Account Management**

2.1 Logging In

2.2 Login Errors

2.3 Registering as a Donor

2.4 Logging Out

2.5 Viewing Your Profile

2.6 Updating Your Profile

2.7 Changing Your Password

**3. Notifications**

3.1 Viewing All Notifications

3.2 Using the Notification Bell

3.3 Viewing Notification Details

3.4 Viewing Inventory Item Details from a Notification (Staff)

**4. Manager**

4.1 Manager Dashboard

4.1.1 Viewing the Manager Dashboard

4.1.2 Viewing Inventory Overview (Read-Only)

4.1.3 Enabling or Disabling a Staff Account

4.2 Animal Records

4.2.1 Viewing Animal Records

4.2.2 Searching and Filtering Animal Records

4.2.3 Adding an Animal Record

4.2.4 Updating an Animal Status

4.2.5 Editing an Animal Record

4.3 Supplier Management

4.3.1 Viewing the Supplier List

4.3.2 Searching for a Supplier

4.3.3 Adding a New Supplier

4.3.4 Editing an Existing Supplier

4.4 Donation Submissions

4.4.1 Viewing Donation Submissions

4.4.2 Searching and Filtering Donation Submissions

4.4.3 Reviewing a Donation Submission

4.4.4 Approving a Donation Submission

4.4.5 Rejecting a Donation Submission

4.4.6 Confirming Items Received

4.4.7 Stocking In an Approved Donation (Goods Received)

4.4.8 Recording a Walk-in Donation as Manager

4.5 Reports

4.5.1 Viewing Monthly Usage

4.5.2 Viewing ROP Status

4.6 Audit Trail

4.6.1 Viewing the Audit Trail

4.6.2 Searching and Filtering Audit Entries

4.7 System Settings — Inventory Alerts

4.7.1 Viewing Inventory Alert Settings

4.7.2 Updating the Low Stock Threshold

4.7.3 Updating the Expiration Warning Window

4.8 System Settings — Reorder Point Defaults

4.8.1 Viewing Reorder Point Defaults

4.8.2 Updating Reorder Point Defaults

4.9 System Settings — Item ROP Overrides

4.9.1 Viewing Item ROP Overrides

4.9.2 Adding an Item ROP Override

4.9.3 Editing an Item ROP Override

4.9.4 Removing an Item ROP Override

4.10 System Settings — Category Management

4.10.1 Viewing the Category List

4.10.2 Expanding and Collapsing a Category

4.10.3 Adding a Category

4.10.4 Renaming a Category

4.10.5 Deleting a Category

4.10.6 Toggling the Expiry Date Requirement for a Category

4.10.7 Adding a Subcategory

4.10.8 Renaming a Subcategory

4.10.9 Deleting a Subcategory

4.10.10 Setting the Expiry Requirement for a Subcategory

4.11 System Settings — Unit Management

4.11.1 Viewing Units

4.11.2 Adding a Unit

4.11.3 Editing a Unit

4.11.4 Deleting a Unit

**5. Staff**

5.1 Staff Dashboard

5.1.1 Viewing the Staff Dashboard

5.1.2 Generating a Social Media Post

5.2 Inventory Management

5.2.1 Viewing the Inventory List

5.2.2 Filtering the Inventory List

5.2.3 Searching and Sorting

5.2.4 Pagination

5.2.5 Viewing Item Details

5.2.6 Editing an Inventory Item

5.2.7 Recording Goods Received via Purchase

5.2.8 Recording Goods Received via Donation (Walk-in)

5.2.9 Recording a Dispense

5.3 Medical Records

5.3.1 Viewing Medical Records

5.3.2 Searching Animals with Treatments

5.3.3 Adding a Treatment

5.3.4 Viewing Treatment Details

5.3.5 Adding an Item to an Existing Treatment

5.4 Ordering

5.4.1 Viewing the Replenishment Tab

5.4.2 Filtering and Searching Replenishment Needs

5.4.3 Viewing Purchase History

5.4.4 Viewing Purchase Details

5.4.5 Recording a Purchase from Ordering

5.5 Reports

5.5.1 Viewing the Staff Monthly Usage Report

5.6 My Activity

5.6.1 Viewing Your Activity

5.6.2 Searching and Filtering Your Activity

**6. Donor**

6.1 Donor Dashboard

6.1.1 Viewing the Donor Dashboard

6.2 Make a Donation

6.2.1 Submitting a Donation Request

6.3 My Donations

6.3.1 Viewing Donation History

6.3.2 Viewing Donation Details

6.4 Impacts

6.4.1 Viewing Your Impact

6.4.2 Searching Impact Messages

**7. Quick Reference**

7.1 Stock Level Statuses

7.2 Dispense Types

7.3 Donation Types

7.4 Donation Statuses (Manager)

7.5 Donation Statuses (Donor)

7.6 Replenishment Priorities

7.7 Animal Statuses



# **1. Introduction**

SIYAM (Shelter Inventory and Audit Management System) is a cross-platform system built for Dumaguete Animal Sanctuary. It digitizes and streamlines the sanctuary's manual processes by integrating inventory management, medical treatment recording, donation coordination, ordering, audit review, and reporting into a single system accessible through both web and mobile platforms.

This manual covers the complete (100%) system and the steps required to use SIYAM across three user roles: Manager, Staff, and Donor. Each section maps to the key modules of the system, guiding users through navigating screens, entering data, and understanding system feedback.



## **1.1 User Roles**

SIYAM has three registered user roles, each with access to specific features:

**•** **Manager**

Has operational oversight including the Manager Dashboard, Animals, Suppliers, Donations, Reports, Audit, Settings, Profile, and Notifications. Managers review and progress donation submissions, configure inventory alerts and reorder settings, and can enable or disable Staff accounts from the dashboard. Managers do not use the Inventory module for day-to-day stock operations; Inventory Overview on the dashboard is read-only. Managers may still record Goods Received for donated items through the Donations workflow.

Manager sidebar navigation: Dashboard, Animals, Suppliers, Reports, Audit, Settings, Donations, Profile, Notifications.

**•** **Staff**

Manages day-to-day inventory and medical operations, including Inventory (Goods Received and Dispense), Medical, Ordering (Replenishment and Purchase History), Reports, My Activity, Profile, and Notifications.

Staff sidebar navigation: Dashboard, Inventory, Medical, Ordering, Reports, My Activity, Profile, Notifications.

**•** **Donor**

Uses public registration to create an account, then submits donation requests, tracks donation progress, and views impact updates.

Donor sidebar navigation: Dashboard, Donate, Impacts, Donations, Profile, Notifications.



# **2. Account Management**

## **2.1 Logging In**

All users log in through the same login page. Access the system through the SIYAM web or mobile application.

1.  Navigate to the login page.
2.  Enter your registered email address and password.
3.  Click the **Sign In** button.
4.  The system authenticates your credentials. If successful, the message **Account successfully Logged In!** is displayed and you are redirected to your role-specific dashboard.

[SCREENSHOT: login-page.png]

**Note:** *Managers and Staff are redirected to `/dashboard`. Donors are redirected to the Donor home area. Public registration is available for Donors only.*

**Note:** *If you click **Forgot password?**, the system displays: **Password reset isn't available yet.** There is no password-reset workflow in this version.*



## **2.2 Login Errors**

The system displays error messages for the following login failures:

  - **Invalid credentials (both fields wrong):** An error message is displayed. You are not logged in.
  - **Valid email but wrong password:** An error message is displayed. You remain on the login page.
  - **Wrong email but valid password:** An error message is displayed. You remain on the login page.
  - **Email field blank:** A validation error indicates the email field is required. You are not logged in.
  - **Password field blank:** A validation error indicates **Password is required**. You are not logged in.



## **2.3 Registering as a Donor**

Public registration is for Donors only. Staff accounts are managed internally by DAS.

1.  From the login page, click **Register your account**.
2.  The Create your account page is displayed.
3.  Enter **First name**, **Last name**, and **Email address**.
4.  Optionally enter a phone number using the format shown (for example, `09XXXXXXXXX`).
5.  Enter a password that meets all **Password requirements** (uppercase letter, lowercase letter, number, and symbol), then re-enter it in **Confirm password**.
6.  Click **Create Account**.
7.  If successful, a confirmation message is displayed (for example, that the account was created and email confirmation may be required before signing in).
8.  Return to login and sign in with your new credentials when ready.

[SCREENSHOT: register-donor.png]

**Note:** *If required fields are blank, passwords do not match, or password requirements are not met, the system displays a validation error and the account is not created.*



## **2.4 Logging Out**

1.  Locate **Logout** in the sidebar (or drawer on mobile).
2.  Click **Logout**.
3.  When prompted with **Log out?**, review the confirmation message.
4.  Click **Confirm Logout**.
5.  Your session is terminated and you are redirected to the login page.

[SCREENSHOT: logout-confirm.png]

**Note:** *Logout is started from the sidebar Logout control, not from Profile Settings.*



## **2.5 Viewing Your Profile**

1.  Navigate to **Profile** from the sidebar.
2.  The page title **Profile Settings** is displayed.
3.  Open the **Profile** tab.
4.  Review your personal information, including first name, last name, email address, phone number, and related account details for your role.

[SCREENSHOT: profile-settings-profile-tab.png]



## **2.6 Updating Your Profile**

1.  Navigate to **Profile** and open the **Profile** tab.
2.  Modify the editable fields (for example, **First Name**, **Last Name**, and **Phone Number**).
3.  Click **Save Changes**.
4.  Confirm when prompted (**Save changes?**).
5.  A confirmation message such as **Profile updated successfully.** is displayed.

**Note:** *If you enter invalid values, the system displays a validation error and the profile is not updated.*



## **2.7 Changing Your Password**

1.  Navigate to **Profile** and open the **Security** tab.
2.  Enter your **Current Password**.
3.  Enter your **New Password** and re-enter it in **Confirm New Password**.
4.  Click **Update Password**.
5.  Confirm when prompted (**Change password?**).
6.  A confirmation message such as **Password updated successfully.** is displayed. Use the new password the next time you sign in.

[SCREENSHOT: profile-settings-security-tab.png]

**Note:** *If your current password is incorrect, required fields are blank, or the new and confirmed passwords do not match, the system displays an appropriate validation error and the password is not changed.*



# **3. Notifications**

SIYAM generates alerts for inventory events such as low stock, out-of-stock items, and expired stock, and also surfaces role-appropriate donation updates for Donors. Notifications are accessible through the Notifications page and the notification bell.

[SCREENSHOT: notifications-page.png]



## **3.1 Viewing All Notifications**

1.  Click **Notifications** from the sidebar.
2.  The Notifications page lists available notifications for your role.
3.  Each notification shows the alert type and related summary information.
4.  Click any notification to view its full details.

**Note:** *Managers and Staff typically see inventory-related alerts. Donors see donation update notifications related to their submissions.*



## **3.2 Using the Notification Bell**

1.  Click the notification bell icon at the top of the screen.
2.  A notification panel appears showing recent notifications, or an empty state if none are available.
3.  Open a notification from the panel, or go to the full **Notifications** page from the sidebar.



## **3.3 Viewing Notification Details**

1.  Click a notification from the Notifications page or the notification bell panel.
2.  The Notification Details page displays the alert type (for example, **Low Stock**, **Out of Stock**, or **Expired Stock**) and related inventory information.
3.  Use the back control to return to the Notifications page.

[SCREENSHOT: notification-detail.png]



## **3.4 Viewing Inventory Item Details from a Notification (Staff)**

From Notification Details, Staff can open the related inventory item when the action is available:

1.  Click **View Item & Remove Expired Stock** (or the equivalent item action shown for that alert).
2.  The Inventory Item Details page is displayed for the selected item.
3.  Continue with Goods Received or Dispense as needed from Inventory.



# **4. Manager**

## **4.1 Manager Dashboard**

The Manager Dashboard provides a high-level overview of sanctuary operations across animals, suppliers, inventory alerts, staff accounts, and pending donation submissions.



### **4.1.1 Viewing the Manager Dashboard**

1.  Log in with a valid Manager account.
2.  Navigate to **Dashboard** from the sidebar.
3.  Review the welcome message and Management Overview summary cards, which may include **Total Animals**, **Suppliers**, **Pending Submissions**, **Staff Accounts**, **Total Inventory Items**, **Zero Stock**, **Low Stock**, and expiry-related alerts.
4.  Review the **Replenishment List** / items requiring stock attention section for items at or below reorder point.

[SCREENSHOT: manager-dashboard.png]



### **4.1.2 Viewing Inventory Overview (Read-Only)**

1.  From the Manager Dashboard, open **Inventory Overview** (for example, via **View inventory overview**).
2.  Review the read-only inventory status information, including items requiring stock attention.
3.  Close the overview when finished.

**Note:** *Inventory Overview is read-only for Managers. Day-to-day Inventory operations (Goods Received and Dispense) are handled by Staff in the Inventory module. Managers stock donated goods through the Donations workflow.*



### **4.1.3 Enabling or Disabling a Staff Account**

Staff accounts are managed internally by DAS. From the Manager Dashboard, you can enable or disable existing Staff accounts. There is no create-staff workflow in this version.

1.  From the Manager Dashboard, open **Staff Accounts** (for example, via **View Staff accounts**).
2.  Locate the Staff account to update.
3.  Click **Enable** or **Disable** as appropriate.
4.  Confirm when prompted (**Enable Staff account?** or **Disable Staff account?**).
5.  The account status updates to **Active** or **Disabled**.

[SCREENSHOT: manager-staff-accounts-modal.png]

**Note:** *Disabling a Staff account restricts login without removing existing operational records.*



## **4.2 Animal Records**

The Animals screen allows the Manager to maintain the sanctuary's animal population data.



### **4.2.1 Viewing Animal Records**

1.  Navigate to **Animals** from the sidebar.
2.  The system displays animal records, showing each animal's name, species, breed, gender, and status.

[SCREENSHOT: animals-list.png]



### **4.2.2 Searching and Filtering Animal Records**

1.  Navigate to **Animals**.
2.  Type a name, breed, or owner in the search field (**Search name, breed, or owner**).
3.  Use the **Species** filter to select **Dog** or **Cat**, or clear the filter to show all species.
4.  Use the **Status** filter to select **Healthy**, **Under Treatment**, **Adopted**, or **Deceased**.
5.  Clear search text and reset filters to display all animal records.



### **4.2.3 Adding an Animal Record**

1.  Navigate to **Animals** and click **Add Animal**.
2.  Fill in the required fields: **Name**, **Species** (**Dog** or **Cat**), **Breed**, **Gender**, and **Spayed / Neutered**.
3.  Set an initial **Status** if applicable (for example, **Healthy**).
4.  Click **Add Animal** / **Save Changes** to submit.
5.  The system creates the record and displays a confirmation message.

[SCREENSHOT: add-animal.png]

**Note:** *If a required field is left blank, the system displays a validation error and the record is not created.*



### **4.2.4 Updating an Animal Status**

1.  Open an existing animal record.
2.  Click **Update Status**.
3.  Select a new status: **Healthy**, **Under Treatment**, **Adopted**, or **Deceased**.
4.  Confirm the update.
5.  The new status is applied and reflected in the animal list and details.



### **4.2.5 Editing an Animal Record**

1.  Select an animal from the list and open **Edit Animal**.
2.  The edit form opens with current details pre-filled.
3.  Update the desired fields with valid values, including status if needed.
4.  Click **Save Changes**.
5.  The system updates the record and displays a confirmation message.



## **4.3 Supplier Management**

The Suppliers screen allows the Manager to maintain the list of suppliers used for inventory purchases.



### **4.3.1 Viewing the Supplier List**

1.  Navigate to **Suppliers** from the sidebar.
2.  The system displays registered suppliers, including name, contact number, and address.

[SCREENSHOT: suppliers-list.png]



### **4.3.2 Searching for a Supplier**

1.  Navigate to **Suppliers**.
2.  Type a supplier name or partial name in the search bar.
3.  Only matching suppliers are displayed.
4.  Clear the search bar to restore the full supplier list.



### **4.3.3 Adding a New Supplier**

1.  Navigate to **Suppliers** and click **Add Supplier**.
2.  Fill in the required fields: supplier name, contact number, and address.
3.  Save the new supplier.
4.  The system creates the supplier record and displays a confirmation message. The new supplier appears in the list.

**Note:** *If any required field is left blank or contains an invalid value, the system displays a validation error and the supplier is not created.*



### **4.3.4 Editing an Existing Supplier**

1.  Select a supplier from the list and click **Edit**.
2.  The Edit Supplier form opens with current details pre-filled.
3.  Update the desired fields with valid values.
4.  Click **Save**.
5.  The system updates the supplier record and displays a confirmation message.



## **4.4 Donation Submissions**

Managers review donor submission requests, approve or reject them, confirm physical receipt, and stock donated items into inventory through Goods Received.



### **4.4.1 Viewing Donation Submissions**

1.  Navigate to **Donations** from the sidebar.
2.  The Donations page lists submissions with donor, status, drop-off information, and related summary details.
3.  Summary groups may include **Pending Review**, **Ready to Stock In**, and **Stocked In**.

[SCREENSHOT: manager-donations-list.png]



### **4.4.2 Searching and Filtering Donation Submissions**

1.  Navigate to **Donations**.
2.  Use **Search by donor** to find a specific submission.
3.  Use the **Status** filter to show **Pending**, **Approved**, **Rejected**, **Received**, **Stocked In**, or **All statuses**.
4.  Clear filters to restore the full list.



### **4.4.3 Reviewing a Donation Submission**

1.  Open a submission from the Donations list.
2.  Review donor details, preferred drop-off date (if provided), donation photo, notes, and current status.
3.  Use the status timeline to understand progress (**Pending** → **Approved** → **Received** → **Stocked In**, or **Rejected**).

[SCREENSHOT: donation-submission-detail.png]



### **4.4.4 Approving a Donation Submission**

1.  Open a submission with status **Pending**.
2.  Click **Approve**.
3.  Confirm when prompted (for example, **Approve donation from [donor]?**).
4.  The status changes to **Approved**. The donor sees this as **Accepted**.



### **4.4.5 Rejecting a Donation Submission**

1.  Open a submission with status **Pending**.
2.  Click **Reject**.
3.  Confirm when prompted (for example, **Reject donation from [donor]?**).
4.  The status changes to **Rejected**. The donor sees this as **Not Accepted**.

**Note:** *After rejection, the donor can no longer have that submission stocked in.*



### **4.4.6 Confirming Items Received**

1.  Open an **Approved** submission after the donation has physically arrived.
2.  Click **Confirm Items Received**.
3.  Confirm the action when prompted.
4.  The status changes to **Received**. The donor sees this as **Received by Shelter**.
5.  The submission becomes ready for stock-in.



### **4.4.7 Stocking In an Approved Donation (Goods Received)**

1.  Open a submission in **Received** status.
2.  Click **Stock In Items**.
3.  The Goods Received form opens for donated stock (`/inventory/add?type=donated` with the submission linked).
4.  Complete item details, quantities, and required fields (including expiry date when the category requires it).
5.  Click **Save**.
6.  On success, stock increases and the submission status becomes **Stocked In**. The donor sees this as **Completed**.

[SCREENSHOT: manager-goods-received-donated.png]

**Note:** *Managers stock donated goods through this Donations workflow. The Inventory module itself remains Staff-only for general inventory operations.*



### **4.4.8 Recording a Walk-in Donation as Manager**

Use this when donated goods arrive without a prior donor submission and should be entered through the Manager Donations path.

1.  Navigate to **Donations**.
2.  Click **Add Donation**.
3.  The Goods Received form opens with Type set for donated stock (`/inventory/add?type=donated`).
4.  Set **Donation Type** to **Walk-in** (or the appropriate donated type).
5.  Optionally fill **Donated by**.
6.  Set **Received By** and **Date received**.
7.  Add one or more items with valid quantities.
8.  Click **Save**.
9.  The walk-in donation is recorded and stock increases.

**Note:** *Required fields typically include Received By, at least one item, and Quantity greater than 0. Expiry date is required when the category enforces it.*



## **4.5 Reports**

Manager Reports provide monthly usage visibility and reorder-point status across inventory.



### **4.5.1 Viewing Monthly Usage**

1.  Navigate to **Reports** from the sidebar.
2.  Open the **Monthly Usage** tab.
3.  Review items used, items with losses, usage records, and loss records for the selected month.
4.  Use search and category filters as needed.
5.  Open an item row for additional recorded-activity detail when available.

[SCREENSHOT: manager-reports-monthly-usage.png]



### **4.5.2 Viewing ROP Status**

1.  Navigate to **Reports**.
2.  Open the **ROP Status** tab.
3.  Review replenishment needs and priority groupings such as **Critical**, **High**, and **Medium**.
4.  Use filters such as **Needs Replenishment** and category filters to narrow results.
5.  Open an item for current stock, reorder point, suggested quantity, and recommended action details.

[SCREENSHOT: manager-reports-rop-status.png]



## **4.6 Audit Trail**

The Audit Trail provides Managers with a full permitted history of operational actions across modules such as Donations, Inventory, and Medical.



### **4.6.1 Viewing the Audit Trail**

1.  Navigate to **Audit** from the sidebar.
2.  The page title **Audit Trail** is displayed.
3.  Review summary cards and the activity list, including user, action, module, and related entity context.

[SCREENSHOT: audit-trail.png]



### **4.6.2 Searching and Filtering Audit Entries**

1.  Navigate to **Audit**.
2.  Use the search field (**Search user, action, item, animal, supplier**) to find matching entries.
3.  Filter by module (for example, **Donations**, **Inventory**, **Medical**) and by period (Today, 7 days, 30 days, or All).
4.  Click **Clear Filters** to restore the full list.
5.  Use **Previous** and **Next** to page through results.



## **4.7 System Settings — Inventory Alerts**

The Settings screen allows the Manager to configure system-wide alert thresholds that control when inventory notifications are triggered.



### **4.7.1 Viewing Inventory Alert Settings**

1.  Navigate to **Settings** from the sidebar.
2.  Locate the **Inventory Alerts** section.
3.  Review **Low stock threshold** and **Expiration warning window (days)**.

[SCREENSHOT: settings-inventory-alerts.png]



### **4.7.2 Updating the Low Stock Threshold**

1.  Locate the **Low stock threshold** field under **Inventory Alerts**.
2.  Clear the field and enter a new valid whole number.
3.  Click **Save Settings**.
4.  A confirmation message is displayed.
5.  Reload Settings if needed to verify the updated value.

**Note:** *Negative numbers, non-numeric values, and blank entries are rejected with a validation error.*



### **4.7.3 Updating the Expiration Warning Window**

1.  Locate the **Expiration warning window (days)** field under **Inventory Alerts**.
2.  Clear the field and enter a valid number of days.
3.  Click **Save Settings**.
4.  A confirmation message is displayed.

**Note:** *Negative numbers, non-numeric values, and blank entries are rejected with a validation error.*



## **4.8 System Settings — Reorder Point Defaults**

Reorder Point Defaults define the system-wide lead time and safety stock used for items that do not have custom overrides.



### **4.8.1 Viewing Reorder Point Defaults**

1.  Navigate to **Settings**.
2.  Locate the **Reorder Point Defaults** section.
3.  Review **Default lead time** and **Default safety stock**.



### **4.8.2 Updating Reorder Point Defaults**

1.  Update **Default lead time** and/or **Default safety stock** with valid values.
2.  Click **Save Settings**.
3.  Confirm any related prompts if shown.
4.  A confirmation message is displayed.

**Note:** *Invalid or blank numeric values are rejected. These defaults apply to items that do not use custom Item ROP Overrides.*



## **4.9 System Settings — Item ROP Overrides**

Item ROP Overrides let the Manager assign custom lead time and safety stock values to specific inventory items.



### **4.9.1 Viewing Item ROP Overrides**

1.  Navigate to **Settings**.
2.  Scroll to **Item ROP Overrides**.
3.  Review items using **Custom** settings versus system **Default** settings.
4.  Use search or filters if available to locate a specific item.



### **4.9.2 Adding an Item ROP Override**

1.  In **Item ROP Overrides**, click **Add Override** / **Add ROP Override**.
2.  Select the inventory item.
3.  Enter custom lead time and safety stock values.
4.  Save the override.
5.  The item now uses its custom ROP settings.

**Note:** *Invalid numeric values are rejected. Custom overrides take precedence over Reorder Point Defaults.*



### **4.9.3 Editing an Item ROP Override**

1.  Locate an existing custom override.
2.  Click **Edit** / **Edit ROP Override**.
3.  Update lead time and/or safety stock.
4.  Save the changes.



### **4.9.4 Removing an Item ROP Override**

1.  Locate the custom override to remove.
2.  Reset or remove the override so the item returns to system defaults when prompted.
3.  Confirm the reset.
4.  The item resumes using Reorder Point Defaults.



## **4.10 System Settings — Category Management**

Category Management allows the Manager to define the classification structure used for inventory items. Each primary category can have subcategories, and each level can independently require an expiry date at goods received.



### **4.10.1 Viewing the Category List**

1.  Scroll to the **Category Management** section on the Settings screen.
2.  Existing primary categories are listed, each showing its name and subcategory count.

[SCREENSHOT: settings-category-management.png]



### **4.10.2 Expanding and Collapsing a Category**

1.  Click the chevron beside a category name to expand it.
2.  Subcategories are displayed along with expiry-requirement controls and **Add Subcategory**.
3.  Click the chevron again to collapse the category.



### **4.10.3 Adding a Category**

1.  Click **Add Category**.
2.  Enter a valid, unique **Category name**.
3.  Confirm with **Create**.
4.  The new category appears in the list.

**Note:** *Blank names and duplicate category names are rejected.*



### **4.10.4 Renaming a Category**

1.  Click the edit (pencil) control beside the category name.
2.  Enter a new valid name.
3.  Confirm the change.
4.  The updated name is reflected in the category list.



### **4.10.5 Deleting a Category**

1.  Click the delete control beside the target category.
2.  Confirm when prompted (**Delete category?**).
3.  The category and its subcategories are removed if deletion is allowed.

**Note:** *If items are still assigned to the category, the system may block deletion and list the assigned items.*



### **4.10.6 Toggling the Expiry Date Requirement for a Category**

1.  Expand the target category.
2.  Switch the requires-expiry control on or off.
3.  Confirm expiry-requirement changes when prompted (**Confirm expiry-requirement changes**).
4.  The change applies to future Goods Received recordings for that category.



### **4.10.7 Adding a Subcategory**

1.  Expand the parent category.
2.  Click **Add Subcategory**.
3.  Enter a valid, unique subcategory name.
4.  Confirm the addition.
5.  The new subcategory appears under the category.

**Note:** *Blank names and duplicate subcategory names within the same category are rejected.*



### **4.10.8 Renaming a Subcategory**

1.  Click the edit control beside the subcategory name.
2.  Enter a new valid name.
3.  Confirm the change.



### **4.10.9 Deleting a Subcategory**

1.  Click the delete control beside the target subcategory.
2.  Confirm when prompted (**Delete subcategory?**).
3.  The subcategory is removed if deletion is allowed.



### **4.10.10 Setting the Expiry Requirement for a Subcategory**

1.  Expand the parent category.
2.  Locate the subcategory expiry requirement control.
3.  Set the subcategory to require or not require an expiry date.
4.  Confirm changes when prompted.
5.  The setting is saved for future Goods Received recordings.



## **4.11 System Settings — Unit Management**

Unit Management lets the Manager maintain purchase, package, and dispense units used across inventory.



### **4.11.1 Viewing Units**

1.  Navigate to **Settings**.
2.  Scroll to **Unit Management**.
3.  Review the list of units and abbreviations.
4.  Use the unit filter/search field if needed.



### **4.11.2 Adding a Unit**

1.  Click **Add Unit**.
2.  Enter the unit name and **Abbreviation**.
3.  Click **Create**.
4.  The new unit appears in the list.

**Note:** *Blank or duplicate values are rejected.*



### **4.11.3 Editing a Unit**

1.  Click **Edit** on an existing unit.
2.  Update the name and/or abbreviation.
3.  Save the changes.



### **4.11.4 Deleting a Unit**

1.  Click the delete control for the target unit.
2.  Confirm when prompted (**Delete unit?**).
3.  The unit is removed if it is not required by existing inventory records.



# **5. Staff**

## **5.1 Staff Dashboard**

The Staff Dashboard provides a real-time summary of inventory attention needs, treatments, purchases, and replenishment priorities.



### **5.1.1 Viewing the Staff Dashboard**

1.  Log in with a valid Staff account and navigate to **Dashboard**.
2.  Review the Operational Overview cards, including inventory attention, **Animals Under Treatment**, and related operational summaries.
3.  Review **Stock Attention** counts such as no usable stock, low stock, and needs restock soon.
4.  Review **Purchases** and **Treatments** summaries for the selected period.
5.  Use the **Week** and **Month** controls to toggle the comparison period.
6.  Review **Stock Priority** / replenishment preview items (**Critical**, **High**, **Medium**).

[SCREENSHOT: staff-dashboard.png]



### **5.1.2 Generating a Social Media Post**

When inventory items need replenishment, Staff can generate a social media caption from current stock needs.

1.  From the Dashboard, click **Generate Social Media Post**.
2.  A modal appears with an auto-generated caption based on current stock needs.
3.  Review or edit the caption text.
4.  Copy the caption if a copy action is provided.
5.  Close the modal. No inventory data is modified.

[SCREENSHOT: staff-social-media-post.png]

**Note:** *If there are no current stock needs, the system indicates that there is nothing to include in a social-media post.*



## **5.2 Inventory Management**

The Inventory screen is the Staff-only hub for managing stock items, recording Goods Received and Dispense transactions, and monitoring stock levels. Inventory items are not deleted in this version.



### **5.2.1 Viewing the Inventory List**

1.  Navigate to **Inventory** from the sidebar.
2.  The page displays the item count, filters, sort controls, and a table with columns such as Item name, Category, Stock, Stock Level, and Action.
3.  Each row shows the item name with packaging detail, category, current stock with unit, and a stock level badge (**In Stock**, **Low Stock**, **Needs Restock**, or **Out of Stock**).

[SCREENSHOT: inventory-list.png]



### **5.2.2 Filtering the Inventory List**

Three independent filters are available at the top of the Inventory screen.

**Filter by Category**

1.  Click the **Category** dropdown.
2.  Select a primary category. The list updates immediately.
3.  Select a subcategory when available to narrow further.
4.  Select **All Categories** to clear the filter.

**Filter by Stock Level**

1.  Click the **Stock Level** dropdown.
2.  Select **In Stock**, **Low Stock**, **Needs Restock**, or **Out of Stock**.
3.  Select **All levels** to clear the filter.

**Filter by Source**

1.  Click the **Source** dropdown.
2.  Select **Purchased**, **Donated**, **Both**, or **None**.
3.  Select **All sources** to clear the filter.

Use **Reset Filters** to clear all filters at once.



### **5.2.3 Searching and Sorting**

**Search:**

1.  Type an item name in **Search items**. The list filters in real time.
2.  Clear the field to restore the full list.
3.  If no items match, an empty state message is displayed.

**Sort:**

1.  Click the Sort dropdown (default: **Name (A–Z)**).
2.  Select **Name (Z–A)**, **Stock (Low–High)**, or **Stock (High–Low)** to reorder the list.



### **5.2.4 Pagination**

1.  Use the **Show** / **Per Page** control to choose how many items appear per page.
2.  Use **Next** and **Previous** to navigate between pages.
3.  The page indicator (for example, `1 / 2`) shows the current and total page count.



### **5.2.5 Viewing Item Details**

1.  Click **View Details** on an inventory row.
2.  The Item Details page shows item identity, category, units, and current stock.
3.  Review **Stock History** for past Goods Received and Dispense movements.
4.  Use **Goods Received** or **Dispense** at the top of the page to record new transactions for this item.

[SCREENSHOT: inventory-item-details.png]

**Note:** *There is no inventory delete action in this version.*



### **5.2.6 Editing an Inventory Item**

1.  From Item Details, open the edit action for the item.
2.  The edit form opens with current values pre-filled.
3.  Update allowed fields (for example, name, category-related fields, or unit fields as permitted).
4.  Click **Save**.
5.  The item record is updated and Item Details reflects the new values.

**Note:** *If required fields are blank or invalid, the system displays a validation error and the item is not updated.*



### **5.2.7 Recording Goods Received via Purchase**

Use this when inventory is received from a supplier purchase.

1.  From Inventory, click **Goods Received**, or open an item and click **Goods Received**. You can also start from Ordering with **Record Purchase**.
2.  The Goods Received form opens. Set **Type** to **Purchased** (Purchase details).
3.  Select a **Supplier**.
4.  Set **Received By** (select a staff member, or click **I received this**). Set **Date received** if needed.
5.  In **Item details**, select an existing item or enter a new item **Name**, then set category and units as required.
6.  Choose **Stock in by** (purchase unit or package unit) and enter a quantity greater than 0.
7.  If the category requires an expiry date, select **Expiry date**.
8.  Optionally click **Add Item** to include additional lines in the same transaction.
9.  Click **Save**.
10. On success, the message **Stock in recorded successfully.** (or equivalent confirmation) is displayed and stock increases.

[SCREENSHOT: goods-received-purchase.png]

**Note:** *Required fields typically include Supplier, Received By, at least one item, and Quantity greater than 0. Expiry date is required when the category enforces it.*



### **5.2.8 Recording Goods Received via Donation (Walk-in)**

Use this when a donor physically walks into the sanctuary and drops off items without a prior submission.

1.  From Inventory, click **Goods Received**.
2.  Set **Type** to **Donated**.
3.  Set **Donation Type** to **Walk-in**.
4.  Optionally fill **Donated by**.
5.  Set **Received By** and **Date received**.
6.  Add one or more items with valid quantities and required category/unit fields.
7.  Select an expiry date when required.
8.  Click **Save**.
9.  The walk-in donation is recorded and stock increases.

**Note:** *Required fields: Received By, at least one item, Quantity. Donated by is optional. Expiry date is required only if the category enforces it.*



### **5.2.9 Recording a Dispense**

Use Dispense to record waste, expiry removal, adjustment, or to start a treatment-related stock reduction path.

1.  From the Inventory list or Item Details, click **Dispense**.
2.  Confirm the selected item.
3.  Enter a valid **Quantity** greater than 0 that does not exceed available stock.
4.  Set **Dispense Type** to one of: **Waste** (default), **Expired**, **Adjustment**, or **Treatment**.
5.  For **Expired**, quantity is limited to expired stock available. Use **Remove Expired Stock** when shown.
6.  For **Waste** or **Adjustment**, complete the dispense and click **Record Dispense**.
7.  For **Treatment**, continue through the Medical treatment workflow rather than a simple stock reduction only.
8.  On success, stock decreases and a confirmation is displayed.

[SCREENSHOT: dispense-dialog.png]

**Note:** *The system prevents stock from going below zero. Entering a quantity greater than available stock is rejected.*



## **5.3 Medical Records**

The Medical module lets Staff view animals with treatment history and log treatments that consume inventory.



### **5.3.1 Viewing Medical Records**

1.  Navigate to **Medical** from the sidebar.
2.  The Medical Records page lists animals with treatment-related information.
3.  Open an animal to view treatment history and related details.

[SCREENSHOT: medical-records.png]



### **5.3.2 Searching Animals with Treatments**

1.  Navigate to **Medical**.
2.  Type in **Search animals** to filter the list.
3.  Clear the search field to restore the full list.



### **5.3.3 Adding a Treatment**

1.  From Medical Records, start **Add Treatment** for the selected animal (or from the treatment entry path available on the page).
2.  Confirm the pet selection using **Search pet** if prompted.
3.  Click **Add item** and search inventory for items used during treatment.
4.  Enter dose / quantity details for each item used.
5.  Click **Save Treatment**.
6.  The treatment is recorded and related inventory is updated according to items used.

[SCREENSHOT: add-treatment.png]

**Note:** *Add at least one item used in the treatment. If no animals exist, the system may prompt you to add an animal before logging a treatment.*



### **5.3.4 Viewing Treatment Details**

1.  Open a treatment from Medical Records.
2.  Review **Treatment Details**, including administered-by information and **Items Used**.
3.  Use **Back to Medical Records** to return.



### **5.3.5 Adding an Item to an Existing Treatment**

1.  Open **Treatment Details**.
2.  Click **Add Item** / **Add Item to Treatment**.
3.  Select an inventory item and enter the dose/quantity.
4.  Set **Date administered** and related fields as required.
5.  Save the added item.
6.  The Items Used list updates and stock is adjusted accordingly.

**Note:** *If no item is selected or quantity is invalid, the system displays a validation error and the item is not added.*



## **5.4 Ordering**

Ordering combines replenishment needs and purchase history in one Staff module with two tabs: **Replenishment** and **Purchase History**.



### **5.4.1 Viewing the Replenishment Tab**

1.  Navigate to **Ordering** from the sidebar.
2.  Open the **Replenishment** tab.
3.  Review items that need replenishment, including priority (**Critical**, **High**, **Medium**), current stock, ROP, and suggested quantities.

[SCREENSHOT: ordering-replenishment.png]



### **5.4.2 Filtering and Searching Replenishment Needs**

1.  On the **Replenishment** tab, use search (**Search item, category, or unit**) to find specific items.
2.  Use priority and related filters as available.
3.  Click **Reset** / **Reset Filters** to clear filters.



### **5.4.3 Viewing Purchase History**

1.  Navigate to **Ordering**.
2.  Open the **Purchase History** tab.
3.  Review recorded purchases, including date received, supplier/staff context, and totals.
4.  Use **Search supplier or staff** to filter the list.

[SCREENSHOT: ordering-purchase-history.png]



### **5.4.4 Viewing Purchase Details**

1.  From **Purchase History**, open a purchase row.
2.  Review **Purchase Details**, including items received, quantities, unit costs, and received-by information.
3.  Close the details view when finished.



### **5.4.5 Recording a Purchase from Ordering**

1.  From Ordering, click **Record Purchase**.
2.  The Goods Received purchase form opens (`/inventory/add?type=purchased`).
3.  Complete the purchase Goods Received steps described in section 5.2.7.
4.  After saving, the purchase appears in Purchase History and inventory stock increases.



## **5.5 Reports**

Staff Reports focus on monthly inventory usage and losses recorded by the shelter.



### **5.5.1 Viewing the Staff Monthly Usage Report**

1.  Navigate to **Reports** from the sidebar.
2.  Review summary cards such as **Items Used** and **Items With Losses**.
3.  Select the target **Month**.
4.  Search by item or category and clear filters as needed.
5.  Open a row to review usage records and loss records for that item.

[SCREENSHOT: staff-reports.png]

**Note:** *Used means stock consumed through treatments or normal dispensing. Lost means stock removed because it expired or was wasted. Inventory adjustments are not counted as usage or losses in the same way.*



## **5.6 My Activity**

My Activity gives Staff a limited, personal view of their own Inventory and Medical audit actions.



### **5.6.1 Viewing Your Activity**

1.  Navigate to **My Activity** from the sidebar.
2.  The page title **My Activity** is displayed.
3.  Review only the Inventory and Medical actions recorded under your own Staff account.

[SCREENSHOT: my-activity.png]

**Note:** *Unlike Manager Audit Trail, My Activity does not show other users' actions or the full cross-module audit set.*



### **5.6.2 Searching and Filtering Your Activity**

1.  Navigate to **My Activity**.
2.  Use **Search your activity, item, or treatment** to find matching entries.
3.  Filter by **Inventory** or **Medical** and by period as available.
4.  Click **Clear Filters** to restore your full personal activity list.



# **6. Donor**

## **6.1 Donor Dashboard**

The Donor Dashboard provides a snapshot of your support activity, recent donation updates, and impact highlights.



### **6.1.1 Viewing the Donor Dashboard**

1.  Log in with a valid Donor account.
2.  Navigate to **Dashboard**.
3.  Review **Your Support** summary information such as donations count, items donated, and last donation.
4.  Review **Recent Donation Activity** and status labels such as **Under Review**, **Accepted**, **Received by Shelter**, **Completed**, or **Not Accepted**.
5.  Review **Recent Impact** highlights when available.

[SCREENSHOT: donor-dashboard.png]

**Note:** *Any unfinished placeholder content on the dashboard is not a working feature in this version. Use Donate, Donations, and Impacts for the supported Donor workflows.*



## **6.2 Make a Donation**

Donors submit donation requests for Manager review. The form does not include an inventory item picker.



### **6.2.1 Submitting a Donation Request**

1.  Navigate to **Donate** from the sidebar.
2.  Review the **Make a Donation** / **Donation Details** form.
3.  Optionally set **Preferred Drop-off** date using **Choose Date** / **Select a date**.
4.  Under **Donation Photo**, click **Add Photo** and upload a clear photo of the items. This field is required.
5.  Optionally enter **Notes** for the shelter Manager.
6.  Click **Submit** / **Submit Donation Request**.
7.  On success, a confirmation such as **Donation request submitted. Thank you!** is displayed.
8.  Track progress anytime under **Donations** (My Donations).

[SCREENSHOT: donate-form.png]

**Note:** *Donation Photo is required. If no photo is attached, the system displays a validation error (for example, **Donation photo is required.**) and the request is not submitted.*



## **6.3 My Donations**

The Donations page for Donors shows your complete donation request history and progress.



### **6.3.1 Viewing Donation History**

1.  Navigate to **Donations** from the sidebar.
2.  The page title area reflects **My Donations** / **Donation History**.
3.  Review submissions grouped or filtered by stage (for example, **Under Review**, **In Progress**, **Completed**, **Not Accepted**).
4.  Use stage filters or **Show all** / **View all donations** as needed.

[SCREENSHOT: donor-donation-history.png]



### **6.3.2 Viewing Donation Details**

1.  Open a donation from your history list.
2.  Review status, preferred drop-off date, your note, donation timeline, and any items later recorded by the shelter.
3.  Close the details view when finished.

**Note:** *Donor-facing statuses are: **Under Review**, **Accepted**, **Received by Shelter**, **Completed**, and **Not Accepted**. These correspond to Manager statuses Pending, Approved, Received, Stocked In, and Rejected.*



## **6.4 Impacts**

Impacts shows how your received donations are helping animals in shelter care.



### **6.4.1 Viewing Your Impact**

1.  Navigate to **Impacts** from the sidebar.
2.  Review summary information such as items donated, donations used, and treatments helped when available.
3.  Browse impact messages for donated items that were put to use.

[SCREENSHOT: donor-impacts.png]



### **6.4.2 Searching Impact Messages**

1.  Navigate to **Impacts**.
2.  Use **Search your impact messages** to find specific items or messages.
3.  Clear search or choose **Show all donations** / **View all donations** to restore the full list.
4.  If no matches are found, try another search term.



# **7. Quick Reference**

## **7.1 Stock Level Statuses**

  - **In Stock:** Stock is above the low-stock and reorder attention ranges.
  - **Low Stock:** Stock is at or below the Low stock threshold set in Settings.
  - **Needs Restock:** Stock has reached the reorder point (ROP) and replenishment should be initiated.
  - **Out of Stock:** No usable stock remains.



## **7.2 Dispense Types**

  - **Waste:** Item was discarded or lost (default selection).
  - **Expired:** Item reached its expiry date; removal is limited to expired stock available.
  - **Adjustment:** Manual stock correction (for example, after a physical count discrepancy).
  - **Treatment:** Item was used during an animal medical treatment (continues through the Medical workflow).



## **7.3 Donation Types**

  - **Walk-in:** Donor arrives at the sanctuary without a prior submission. No Submission ID is required.
  - **Dropped-off:** Donor delivers items against an approved donation form submission. Submission ID is required for the linked Goods Received path.



## **7.4 Donation Statuses (Manager)**

  - **Pending:** Awaiting Manager review.
  - **Approved:** Manager accepted the donation request.
  - **Rejected:** Manager did not accept the donation request.
  - **Received:** Shelter confirmed physical receipt of items; ready to stock in.
  - **Stocked In:** Donated items have been recorded into inventory.



## **7.5 Donation Statuses (Donor)**

  - **Under Review:** Your request was submitted and is waiting for review (Manager: Pending).
  - **Accepted:** Your request was approved (Manager: Approved).
  - **Received by Shelter:** The shelter confirmed receiving your donation (Manager: Received).
  - **Completed:** Your donated items were stocked into inventory (Manager: Stocked In).
  - **Not Accepted:** The shelter did not accept the request (Manager: Rejected).



## **7.6 Replenishment Priorities**

  - **Critical:** Highest-priority replenishment need (for example, no usable stock remaining or urgently below ROP).
  - **High:** Requires closer attention; stock is at or below ROP with elevated urgency.
  - **Medium:** Needs replenishment soon based on ROP calculation.

ROP formula reference: **ROP = (Average Daily Usage × Lead Time) + Safety Stock**.



## **7.7 Animal Statuses**

  - **Healthy:** Animal is not under active treatment and is available in care.
  - **Under Treatment:** Animal has an active medical treatment status.
  - **Adopted:** Animal has been adopted.
  - **Deceased:** Animal is marked deceased.

Species values used in Animal Records: **Dog**, **Cat**.
