-- SIYAM: stock-in (purchase) batch, one purchase transaction per item.
-- =============================================================================
-- Adds new catalog items and records each as its own purchase +
-- purchase_item pair (not bundled into one purchase), so the Reports page
-- has spendable, dated purchase history to chart. Run against the schema
-- produced by 0001_init_schema.sql + 0002_recategorize_and_units.sql +
-- 0003_seed_suppliers_and_pets.sql (each transaction below is placed with a
-- different one of the suppliers seeded there, instead of all going through
-- the original single supplier).
--
-- receivedby / receiveddate / recordeddate are intentionally varied and
-- backdated (Feb-Jul 2026) instead of all defaulting to now(), per request.
-- recordedby is the staff account (public.purchase-orders is staff-only per
-- lib/routing/nav_config.dart), same as every purchase entered through the
-- app today.
--
-- Excluded from the source list, per explicit instruction not to guess past
-- inconsistencies:
--   - Uticare (30 tab per box) x26 bottle -- the existing seeded Uticare
--     item's purchase_unit is already "box"; this line said "bottle".
--   - Tobramycin/Tobrason 5ml x12 "pcs bot" -- ambiguous unit phrasing.
--   - Paw Balm 30g x3 "pcs bot" -- ambiguous unit phrasing.
--   - Shampoo - Mixidine 250ml -- source category was the combined label
--     "Ointment/Anti-Inflam/Spray/Shampoo/Drops/Powder/Vetwrap".
--   - Gauze -- source category was "Vetwrap" alone, same ambiguity as above.
--
-- Assumption flagged for review: "Thermometer" was listed under an
-- "Equipment" category that no longer exists post-0002 (primary_category is
-- now Medical/Food/General only) -- mapped to Medical > "Medical Equipment"
-- as the closest existing subcategory. purchase_unit_cost values below are
-- placeholder estimates (no cost was given in the source list) -- adjust to
-- real supplier pricing before relying on spend reports.
-- =============================================================================

-- 1. Ascorbic Acid (100 tab per box) -- 55 boxes
with new_item as (
  insert into public.item
    (name, p_category, s_category, purchase_unit, package_unit, package_quantity, dispense_unit, total_purchase_stocks, total_package_stocks)
  values (
    'Ascorbic Acid',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'Tablets'),
    (select id from public.units where abbr_name = 'box'),
    (select id from public.units where abbr_name = 'tab'), 100,
    (select id from public.units where abbr_name = 'tab'),
    55, 5500
  )
  returning id
),
new_purchase as (
  insert into public.purchase (suppid, recordedby, recordeddate, receivedby, receiveddate)
  values (
    (select id from public.supplier where name = 'Bantay Gamot Veterinary Supplies'),
    (select id from public.users where email = 'staff@siyam.test'),
    timestamptz '2026-02-11 10:15:00+08',
    'Jomar Cruz',
    timestamptz '2026-02-10 14:30:00+08'
  )
  returning id
)
insert into public.purchase_item (purchaseid, itemid, qty, purchase_unit_cost)
select new_purchase.id, new_item.id, 55, 250.00
from new_purchase, new_item;

-- 2. K9 Doxy 60ml -- 6 bottles
with new_item as (
  insert into public.item
    (name, p_category, s_category, purchase_unit, package_unit, package_quantity, dispense_unit, total_purchase_stocks, total_package_stocks)
  values (
    'K9 Doxy 60ml',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'Syrup'),
    (select id from public.units where abbr_name = 'bot'),
    (select id from public.units where abbr_name = 'ml'), 60,
    (select id from public.units where abbr_name = 'ml'),
    6, 360
  )
  returning id
),
new_purchase as (
  insert into public.purchase (suppid, recordedby, recordeddate, receivedby, receiveddate)
  values (
    (select id from public.supplier where name = 'Ligtas Alaga Pet Pharma Trading'),
    (select id from public.users where email = 'staff@siyam.test'),
    timestamptz '2026-02-26 09:05:00+08',
    'Ana Villanueva',
    timestamptz '2026-02-25 16:00:00+08'
  )
  returning id
)
insert into public.purchase_item (purchaseid, itemid, qty, purchase_unit_cost)
select new_purchase.id, new_item.id, 6, 220.00
from new_purchase, new_item;

-- 3. Thermometer -- 20 pcs
with new_item as (
  insert into public.item
    (name, p_category, s_category, purchase_unit, package_unit, package_quantity, dispense_unit, total_purchase_stocks, total_package_stocks)
  values (
    'Thermometer',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'Medical Equipment'),
    (select id from public.units where abbr_name = 'pc'),
    null, null, null,
    20, null
  )
  returning id
),
new_purchase as (
  insert into public.purchase (suppid, recordedby, recordeddate, receivedby, receiveddate)
  values (
    (select id from public.supplier where name = 'Malayang Hayop Distributors Inc.'),
    (select id from public.users where email = 'staff@siyam.test'),
    timestamptz '2026-03-15 11:40:00+08',
    'Mark Dizon',
    timestamptz '2026-03-14 13:20:00+08'
  )
  returning id
)
insert into public.purchase_item (purchaseid, itemid, qty, purchase_unit_cost)
select new_purchase.id, new_item.id, 20, 150.00
from new_purchase, new_item;

-- 4. Co-trimoxazole 60ml (Papi Scour) -- 19 bottles
with new_item as (
  insert into public.item
    (name, p_category, s_category, purchase_unit, package_unit, package_quantity, dispense_unit, total_purchase_stocks, total_package_stocks)
  values (
    'Co-trimoxazole 60ml (Papi Scour)',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'Syrup'),
    (select id from public.units where abbr_name = 'bot'),
    (select id from public.units where abbr_name = 'ml'), 60,
    (select id from public.units where abbr_name = 'ml'),
    19, 1140
  )
  returning id
),
new_purchase as (
  insert into public.purchase (suppid, recordedby, recordeddate, receivedby, receiveddate)
  values (
    (select id from public.supplier where name = 'Kalinga Vet Supply Co.'),
    (select id from public.users where email = 'staff@siyam.test'),
    timestamptz '2026-03-29 08:50:00+08',
    'Jomar Cruz',
    timestamptz '2026-03-28 15:10:00+08'
  )
  returning id
)
insert into public.purchase_item (purchaseid, itemid, qty, purchase_unit_cost)
select new_purchase.id, new_item.id, 19, 180.00
from new_purchase, new_item;

-- 5. CPV Test Kit -- 3 boxes (10 test kits per box = 30)
with new_item as (
  insert into public.item
    (name, p_category, s_category, purchase_unit, package_unit, package_quantity, dispense_unit, total_purchase_stocks, total_package_stocks)
  values (
    'CPV',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'Test Kit'),
    (select id from public.units where abbr_name = 'box'),
    (select id from public.units where abbr_name = 'test'), 10,
    (select id from public.units where abbr_name = 'test'),
    3, 30
  )
  returning id
),
new_purchase as (
  insert into public.purchase (suppid, recordedby, recordeddate, receivedby, receiveddate)
  values (
    (select id from public.supplier where name = 'Alagang Maka-Hayop Trading'),
    (select id from public.users where email = 'staff@siyam.test'),
    timestamptz '2026-04-19 10:00:00+08',
    'Ana Villanueva',
    timestamptz '2026-04-18 09:45:00+08'
  )
  returning id
)
insert into public.purchase_item (purchaseid, itemid, qty, purchase_unit_cost)
select new_purchase.id, new_item.id, 3, 1500.00
from new_purchase, new_item;

-- 6. Feline Test Kit -- 4 boxes (10 test kits per box = 40)
with new_item as (
  insert into public.item
    (name, p_category, s_category, purchase_unit, package_unit, package_quantity, dispense_unit, total_purchase_stocks, total_package_stocks)
  values (
    'Feline Test Kit',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'Test Kit'),
    (select id from public.units where abbr_name = 'box'),
    (select id from public.units where abbr_name = 'test'), 10,
    (select id from public.units where abbr_name = 'test'),
    4, 40
  )
  returning id
),
new_purchase as (
  insert into public.purchase (suppid, recordedby, recordeddate, receivedby, receiveddate)
  values (
    (select id from public.supplier where name = 'Bukid at Bahay Pet Essentials'),
    (select id from public.users where email = 'staff@siyam.test'),
    timestamptz '2026-05-06 14:25:00+08',
    'Mark Dizon',
    timestamptz '2026-05-05 11:00:00+08'
  )
  returning id
)
insert into public.purchase_item (purchaseid, itemid, qty, purchase_unit_cost)
select new_purchase.id, new_item.id, 4, 1600.00
from new_purchase, new_item;

-- 7. Pomisol Ear Drop (15ml) -- 5 bottles
with new_item as (
  insert into public.item
    (name, p_category, s_category, purchase_unit, package_unit, package_quantity, dispense_unit, total_purchase_stocks, total_package_stocks)
  values (
    'Pomisol Ear Drop (15ml)',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'Drops'),
    (select id from public.units where abbr_name = 'bot'),
    (select id from public.units where abbr_name = 'ml'), 15,
    (select id from public.units where abbr_name = 'drop'),
    5, 75
  )
  returning id
),
new_purchase as (
  insert into public.purchase (suppid, recordedby, recordeddate, receivedby, receiveddate)
  values (
    (select id from public.supplier where name = 'Bantay Gamot Veterinary Supplies'),
    (select id from public.users where email = 'staff@siyam.test'),
    timestamptz '2026-06-13 16:30:00+08',
    'Jomar Cruz',
    timestamptz '2026-06-12 10:20:00+08'
  )
  returning id
)
insert into public.purchase_item (purchaseid, itemid, qty, purchase_unit_cost)
select new_purchase.id, new_item.id, 5, 195.00
from new_purchase, new_item;

-- 8. Epinephrine -- 2 boxes (10 ampoules per box = 20)
with new_item as (
  insert into public.item
    (name, p_category, s_category, purchase_unit, package_unit, package_quantity, dispense_unit, total_purchase_stocks, total_package_stocks)
  values (
    'Epinephrine',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'IV Injectables'),
    (select id from public.units where abbr_name = 'box'),
    (select id from public.units where abbr_name = 'amp'), 10,
    (select id from public.units where abbr_name = 'amp'),
    2, 20
  )
  returning id
),
new_purchase as (
  insert into public.purchase (suppid, recordedby, recordeddate, receivedby, receiveddate)
  values (
    (select id from public.supplier where name = 'Ligtas Alaga Pet Pharma Trading'),
    (select id from public.users where email = 'staff@siyam.test'),
    timestamptz '2026-07-03 09:15:00+08',
    'Ana Villanueva',
    timestamptz '2026-07-02 13:50:00+08'
  )
  returning id
)
insert into public.purchase_item (purchaseid, itemid, qty, purchase_unit_cost)
select new_purchase.id, new_item.id, 2, 450.00
from new_purchase, new_item;
