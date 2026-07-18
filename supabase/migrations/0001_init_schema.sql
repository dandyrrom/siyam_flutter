-- SIYAM initial schema (Supabase / GoTrue)
-- =============================================================================
-- WARNING: This script RESETS the entire `public` schema. Running it DROPS ALL
-- existing tables/data in `public`. Run it once in the Supabase SQL Editor to
-- (re)create the SIYAM schema from scratch.
--
-- Auth model: Supabase Auth (GoTrue) owns credentials in `auth.users`.
-- `public.users` is a profile table (1:1 with auth.users) created by a trigger
-- on signup. There is intentionally NO plaintext password column (updated_db.md
-- notes its `password` field was for the mock only).
--
-- Deviations from updated_db.md (schema doc), made so the schema matches the
-- app code that actually runs:
--   * users.contactnum is TEXT, not bigint -- PH numbers have leading zeros and
--     the app models contactNum as a String.
--   * pet_status enum = available/adopted/under_treatment (what the Flutter
--     PetStatus enum implements), NOT under_treatment/healthy/adopted/deceased.
--   * users.password column omitted (GoTrue owns credentials).
-- =============================================================================

-- ----------------------------------------------------------------------------
-- 0. Reset public schema
-- ----------------------------------------------------------------------------
drop schema if exists public cascade;
create schema public;

grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on all tables in schema public to postgres, anon, authenticated, service_role;
grant all on all routines in schema public to postgres, anon, authenticated, service_role;
grant all on all sequences in schema public to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant all on tables to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant all on routines to postgres, anon, authenticated, service_role;
alter default privileges for role postgres in schema public grant all on sequences to postgres, anon, authenticated, service_role;

-- ----------------------------------------------------------------------------
-- 1. Enums
-- ----------------------------------------------------------------------------
create type user_role as enum ('manager', 'staff', 'donor');
create type pet_species as enum ('dog', 'cat');
create type pet_gender as enum ('male', 'female');
create type pet_status as enum ('available', 'adopted', 'under_treatment');
create type submission_status as enum ('pending', 'approved', 'rejected');
create type stock_out_reason as enum ('waste', 'expired', 'adjustment');

-- ----------------------------------------------------------------------------
-- 2. Tables
-- ----------------------------------------------------------------------------
create table public.users (
  id         uuid primary key references auth.users (id) on delete cascade,
  fname      text not null default '',
  lname      text not null default '',
  role       user_role not null default 'donor',
  email      text not null unique,
  contactnum text
);

create table public.primary_category (
  id   uuid primary key default gen_random_uuid(),
  type text not null
);

create table public.subcategory (
  id         uuid primary key default gen_random_uuid(),
  p_category uuid not null references public.primary_category (id) on delete cascade,
  type       text not null
);

create table public.units (
  id        uuid primary key default gen_random_uuid(),
  abbr_name text not null
);

create table public.item (
  id               uuid primary key default gen_random_uuid(),
  name             text not null,
  p_category       uuid not null references public.primary_category (id),
  s_category       uuid references public.subcategory (id),
  purchase_unit    uuid not null references public.units (id),
  package_unit     uuid references public.units (id),
  package_quantity double precision,
  dispense_unit    uuid references public.units (id),
  purchase_stocks  double precision not null default 0
);

create table public.pet (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  species         pet_species not null,
  breed           text,
  gender          pet_gender not null,
  spayed_neutered boolean not null default false,
  status          pet_status not null default 'available'
);

create table public.supplier (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  contactnum text,
  contacttel text,
  address    text
);

create table public.purchase (
  id           uuid primary key default gen_random_uuid(),
  suppid       uuid not null references public.supplier (id),
  recordedby   uuid not null references public.users (id),
  recordeddate timestamptz not null default now(),
  receivedby   text,
  receiveddate timestamptz not null default now()
);

create table public.purchase_item (
  purchaseid         uuid not null references public.purchase (id) on delete cascade,
  itemid             uuid not null references public.item (id),
  qty                double precision not null,
  purchase_unit_cost numeric not null default 0,
  primary key (purchaseid, itemid)
);

create table public.treatment (
  id           uuid primary key default gen_random_uuid(),
  name         text not null,
  petid        uuid not null references public.pet (id),
  recordedby   uuid not null references public.users (id),
  recordeddate timestamptz not null default now(),
  notes        text
);

create table public.treatment_item (
  treatid       uuid not null references public.treatment (id) on delete cascade,
  itemid        uuid not null references public.item (id),
  dispensed_qty double precision not null,
  dispense_unit uuid not null references public.units (id),
  consumeddate  timestamptz not null default now(),
  givenby       text,
  recordeddate  timestamptz not null default now(),
  recordedby    uuid not null references public.users (id),
  primary key (treatid, itemid)
);

create table public.submission (
  id             uuid primary key default gen_random_uuid(),
  donorid        uuid not null references public.users (id),
  updatedby      uuid references public.users (id),
  status         submission_status not null default 'pending',
  drop_off_sched timestamptz,
  datesubmitted  timestamptz not null default now(),
  proof_img      text,
  notes          text
);

create table public.donation (
  id           uuid primary key default gen_random_uuid(),
  donorid      uuid not null references public.users (id),
  subid        uuid references public.submission (id),
  receivedby   text,
  receiveddate timestamptz not null default now(),
  recordedby   uuid not null references public.users (id),
  recordeddate timestamptz not null default now()
);

create table public.donation_item (
  dntid  uuid not null references public.donation (id) on delete cascade,
  itemid uuid not null references public.item (id),
  qty    double precision not null,
  primary key (dntid, itemid)
);

create table public.stock_out (
  id           uuid primary key default gen_random_uuid(),
  itemid       uuid not null references public.item (id),
  qty          double precision not null,
  reason       stock_out_reason not null,
  recordeddate timestamptz not null default now(),
  recordedby   uuid not null references public.users (id)
);

-- ----------------------------------------------------------------------------
-- 3. Profile trigger: create a public.users row when an auth user signs up.
--    Donor self-signup passes first_name/last_name/contact_num in metadata.
--    Role defaults to 'donor'; staff/manager are promoted manually (below).
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, fname, lname, role, email, contactnum)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'first_name', ''),
    coalesce(new.raw_user_meta_data ->> 'last_name', ''),
    coalesce((new.raw_user_meta_data ->> 'role')::user_role, 'donor'),
    new.email,
    nullif(new.raw_user_meta_data ->> 'contact_num', '')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- 4. Row Level Security
--    Baseline: any authenticated user may read; writes require authentication.
--    NOTE: This is a permissive first pass. Tightening to per-role rules
--    (e.g. donors can't write inventory) is a documented follow-up.
-- ----------------------------------------------------------------------------
do $$
declare t text;
begin
  foreach t in array array[
    'users','primary_category','subcategory','units','item','pet','supplier',
    'purchase','purchase_item','treatment','treatment_item','submission',
    'donation','donation_item','stock_out'
  ]
  loop
    execute format('alter table public.%I enable row level security;', t);
    execute format(
      'create policy "authenticated read" on public.%I for select to authenticated using (true);', t);
    execute format(
      'create policy "authenticated insert" on public.%I for insert to authenticated with check (true);', t);
    execute format(
      'create policy "authenticated update" on public.%I for update to authenticated using (true) with check (true);', t);
    execute format(
      'create policy "authenticated delete" on public.%I for delete to authenticated using (true);', t);
  end loop;
end $$;

-- ----------------------------------------------------------------------------
-- 5. Seed: catalog, units, suppliers, pets, items (mirrors the mock seed).
--    No transactional rows (purchase/treatment/donation) -- those need real
--    user ids and can be created through the app.
-- ----------------------------------------------------------------------------
insert into public.units (abbr_name) values
  ('box'), ('tablet'), ('bottle'), ('ml'), ('bag'), ('kg'), ('drop'), ('pcs');

insert into public.primary_category (type) values
  ('Medical'), ('Food'), ('Cleaning Supplies'), ('Equipment');

insert into public.subcategory (p_category, type) values
  ((select id from public.primary_category where type = 'Medical'),           'Tablets'),
  ((select id from public.primary_category where type = 'Medical'),           'Oral Suspension'),
  ((select id from public.primary_category where type = 'Medical'),           'Drops'),
  ((select id from public.primary_category where type = 'Medical'),           'Supplies'),
  ((select id from public.primary_category where type = 'Food'),              'Dry'),
  ((select id from public.primary_category where type = 'Cleaning Supplies'), 'Bleach'),
  ((select id from public.primary_category where type = 'Equipment'),         'Tools');

insert into public.supplier (name, contactnum, address) values
  ('PetCare Distributors Inc.', '09201234567', 'Quezon City, Metro Manila');

insert into public.pet (name, species, breed, gender, spayed_neutered, status) values
  ('Bella',    'dog', 'Aspin',  'female', true,  'available'),
  ('Whiskers', 'cat', 'Puspin', 'male',   false, 'under_treatment');

-- Items (mirrors mock; category/unit resolved by lookup).
insert into public.item
  (name, p_category, s_category, purchase_unit, package_unit, package_quantity, dispense_unit, purchase_stocks)
values
  ('Uticare',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'Tablets'),
    (select id from public.units where abbr_name = 'box'),
    (select id from public.units where abbr_name = 'tablet'), 30,
    (select id from public.units where abbr_name = 'tablet'), 2),
  ('Royal Canin Adult Dry Food',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'Oral Suspension'),
    (select id from public.units where abbr_name = 'bottle'),
    (select id from public.units where abbr_name = 'ml'), 100,
    (select id from public.units where abbr_name = 'ml'), 10),
  ('Eye Vitamin Drop',
    (select id from public.primary_category where type = 'Medical'),
    (select id from public.subcategory where type = 'Drops'),
    (select id from public.units where abbr_name = 'bottle'),
    (select id from public.units where abbr_name = 'ml'), 200,
    (select id from public.units where abbr_name = 'drop'), 26),
  ('Adult Dog Dry Food',
    (select id from public.primary_category where type = 'Food'),
    (select id from public.subcategory where type = 'Dry'),
    (select id from public.units where abbr_name = 'bag'),
    (select id from public.units where abbr_name = 'kg'), 9,
    (select id from public.units where abbr_name = 'kg'), 4),
  ('Zonrox Bleach',
    (select id from public.primary_category where type = 'Cleaning Supplies'),
    (select id from public.subcategory where type = 'Bleach'),
    (select id from public.units where abbr_name = 'bottle'),
    (select id from public.units where abbr_name = 'ml'), 450,
    (select id from public.units where abbr_name = 'ml'), 2),
  ('Mop',
    (select id from public.primary_category where type = 'Equipment'),
    (select id from public.subcategory where type = 'Tools'),
    (select id from public.units where abbr_name = 'pcs'),
    null, null, null, 5);

-- ----------------------------------------------------------------------------
-- 6. Seed users (RUN AFTER creating the auth users).
--    Create these three accounts first (Supabase Dashboard > Authentication >
--    Users > Add user, "Auto Confirm"), all with password: password123
--      manager@siyam.test / staff@siyam.test / donor@siyam.test
--    The trigger inserts their profile rows (role defaults to 'donor'); then
--    run the UPDATEs below to set names/roles to match the mock accounts.
-- ----------------------------------------------------------------------------
-- update public.users set role = 'manager', fname = 'Maria', lname = 'Santos', contactnum = '09171234567' where email = 'manager@siyam.test';
-- update public.users set role = 'staff',   fname = 'Jomar', lname = 'Cruz',   contactnum = '09181234567' where email = 'staff@siyam.test';
-- update public.users set role = 'donor',   fname = 'Ana',   lname = 'Reyes',  contactnum = '09191234567' where email = 'donor@siyam.test';
