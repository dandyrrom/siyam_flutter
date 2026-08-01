-- Adds the manager-configurable expiry-date requirement to categories (see
-- updated_db.md's PRIMARY_CATEGORY/SUBCATEGORY `requires_expiry`), matching
-- what the mock catalog already implements.
--
-- primary_category.requires_expiry: not null, defaults false. Medical/Food
-- are backfilled to true below since Stock In already enforces expiry for
-- those two (previously hardcoded by name in add_item_page.dart).
--
-- subcategory.requires_expiry: nullable. Null means "inherit the parent
-- primary category's setting" -- left null for every existing row so
-- nothing changes behavior until a manager explicitly sets an override.

alter table public.primary_category
  add column requires_expiry boolean not null default false;

update public.primary_category
  set requires_expiry = true
  where type in ('Medical', 'Food');

alter table public.subcategory
  add column requires_expiry boolean;
