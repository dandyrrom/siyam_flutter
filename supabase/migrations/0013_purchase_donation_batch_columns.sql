-- Adds PURCHASE_ITEM/DONATION_ITEM.qty_unit, expiry_date, qty_remaining for
-- FEFO batch tracking (see updated_db.md). Additive only. qty_remaining is
-- backfilled to the canonical (package_unit, if the item has a breakdown;
-- purchase_unit otherwise) equivalent of each existing row's qty, matching
-- the conversion the app already applies on write (see
-- lib/services/supplier_service.dart / lib/services/donation_service.dart).
-- Existing rows have no qty_unit on record, so the backfill assumes
-- purchase_unit, matching the new column's default.

create type qty_unit as enum ('purchase_unit', 'package_unit');

alter table public.purchase_item
  add column qty_unit qty_unit not null default 'purchase_unit',
  add column expiry_date date,
  add column qty_remaining double precision not null default 0;

update public.purchase_item pi
set qty_remaining = case
  when i.package_quantity is not null then pi.qty * i.package_quantity
  else pi.qty
end
from public.item i
where i.id = pi.itemid;

alter table public.donation_item
  add column qty_unit qty_unit not null default 'purchase_unit',
  add column expiry_date date,
  add column qty_remaining double precision not null default 0;

update public.donation_item di
set qty_remaining = case
  when i.package_quantity is not null then di.qty * i.package_quantity
  else di.qty
end
from public.item i
where i.id = di.itemid;
