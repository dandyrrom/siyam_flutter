-- SIYAM data reset: clear transactional/catalog data, rebuild units and
-- categories to match how DAS actually tracks stock.
-- =============================================================================
-- WARNING: This script is DESTRUCTIVE. It truncates every table except
-- users, pet, supplier, and units (those four are left untouched), then
-- replaces the contents of units, primary_category, and subcategory. Run it
-- once in the Supabase SQL Editor after reviewing it -- there is no undo.
--
-- After this runs, `item` is empty, so every inventory item will need to be
-- re-created (via the app's Add Item flow) with the new primary/sub category
-- and unit picks below.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 1. Truncate everything except users, pet, supplier, units.
--    Listed together so Postgres handles the FK dependencies between them
--    in one atomic statement (no CASCADE needed onto tables outside this
--    list, since supplier/pet/units are only ever referenced by, never
--    reference, the tables below).
-- ----------------------------------------------------------------------------
truncate table
  public.stock_out,
  public.treatment_item,
  public.treatment,
  public.donation_item,
  public.donation,
  public.submission,
  public.purchase_item,
  public.purchase,
  public.item,
  public.subcategory,
  public.primary_category;

-- ----------------------------------------------------------------------------
-- 2. Units: add a full name alongside the existing abbreviation, and
--    replace the seed rows with the units DAS actually logs stock in (per
--    the March/April 2026 Stock In/Out CSVs). Safe to fully replace now --
--    `item` was just truncated above, so nothing still references the old
--    unit rows.
-- ----------------------------------------------------------------------------
alter table public.units add column if not exists name text;

delete from public.units;

insert into public.units (name, abbr_name) values
  ('Bottle',   'bot'),
  ('Tablet',   'tab'),
  ('Piece',    'pc'),
  ('Box',      'box'),
  ('Bag',      'bag'),
  ('Kilogram', 'kg'),
  ('Milliliter', 'ml'),
  ('Drop',     'drop'),
  ('Vial',     'vial'),
  ('Ampoule',  'amp'),
  ('Capsule',  'cap'),
  ('Strip',    'strip'),
  ('Pouch',    'pouch'),
  ('Test Kit', 'test');

alter table public.units alter column name set not null;

-- ----------------------------------------------------------------------------
-- 3. Primary categories: Medical, Food, General only.
-- ----------------------------------------------------------------------------
insert into public.primary_category (type) values
  ('Medical'), ('Food'), ('General');

-- ----------------------------------------------------------------------------
-- 4. Subcategories: Food and General as specified; Medical mirrors the DAS
--    CSV groupings, with each slash-separated group split into its own row
--    (e.g. "Capsule/Tablets" -> Capsule, Tablets).
-- ----------------------------------------------------------------------------
insert into public.subcategory (p_category, type) values
  -- Medical (from "Capsule/Tablets")
  ((select id from public.primary_category where type = 'Medical'), 'Capsule'),
  ((select id from public.primary_category where type = 'Medical'), 'Tablets'),
  -- Medical (from "Oral Suspension/Syrup")
  ((select id from public.primary_category where type = 'Medical'), 'Oral Suspension'),
  ((select id from public.primary_category where type = 'Medical'), 'Syrup'),
  -- Medical (from "Ointment/Anti-Inflam/Spray/Shampoo/Drops/Powder/Vetwrap")
  ((select id from public.primary_category where type = 'Medical'), 'Ointment'),
  ((select id from public.primary_category where type = 'Medical'), 'Anti-Inflammatory'),
  ((select id from public.primary_category where type = 'Medical'), 'Spray'),
  ((select id from public.primary_category where type = 'Medical'), 'Shampoo'),
  ((select id from public.primary_category where type = 'Medical'), 'Drops'),
  ((select id from public.primary_category where type = 'Medical'), 'Powder'),
  ((select id from public.primary_category where type = 'Medical'), 'Vetwrap'),
  -- Medical (from "Test Kit/Vaccine")
  ((select id from public.primary_category where type = 'Medical'), 'Test Kit'),
  ((select id from public.primary_category where type = 'Medical'), 'Vaccine'),
  -- Medical (from "Oxygen/Medical")
  ((select id from public.primary_category where type = 'Medical'), 'Oxygen'),
  ((select id from public.primary_category where type = 'Medical'), 'Medical Equipment'),
  -- Medical (from "Injectables (IV/Nebul)")
  ((select id from public.primary_category where type = 'Medical'), 'IV Injectables'),
  ((select id from public.primary_category where type = 'Medical'), 'Nebulizer'),

  -- Food
  ((select id from public.primary_category where type = 'Food'), 'Dry'),
  ((select id from public.primary_category where type = 'Food'), 'Wet'),
  ((select id from public.primary_category where type = 'Food'), 'Treats'),

  -- General
  ((select id from public.primary_category where type = 'General'), 'Cleaning'),
  ((select id from public.primary_category where type = 'General'), 'Supplies');
