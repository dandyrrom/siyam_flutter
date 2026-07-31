-- Adds ITEM.total_package_stock_ins / stock_count_mode (see updated_db.md).
-- Additive only -- both columns are nullable/defaulted so existing rows and
-- queries are unaffected.

alter table public.item
  add column total_package_stock_ins double precision not null default 0;

alter table public.item
  add column stock_count_mode text
    check (stock_count_mode in ('package', 'purchase'));
