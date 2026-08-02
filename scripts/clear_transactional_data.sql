-- Clears all transactional/inventory data while preserving reference data.
-- Run manually in the Supabase SQL Editor -- not part of the migrations
-- sequence (0001_init_schema.sql etc.), since this is a data wipe, not a
-- schema change.
--
-- Kept as-is: users, pet, supplier, units, primary_category, subcategory.
-- Cleared:    item, purchase, purchase_item, treatment, treatment_item,
--             submission, donation, donation_item, stock_out.
--
-- WARNING: irreversible. Back up first if this data matters.

truncate table
  public.stock_out,
  public.purchase_item,
  public.treatment_item,
  public.donation_item,
  public.purchase,
  public.treatment,
  public.donation,
  public.submission,
  public.item
restart identity cascade;
