-- =====================================================================
-- SIYAM fresh database setup
-- Run this once, top to bottom, in a brand-new Supabase project's
-- SQL Editor. It recreates your full schema WITHOUT re-arming the
-- RLS auto-enable trigger, so login/register/CRUD all work
-- immediately while you build out the frontend.
--
-- When you're ready to lock things down for real, see the
-- "RE-ENABLE LATER" block at the bottom.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Enum types
-- ---------------------------------------------------------------------
CREATE TYPE user_role AS ENUM ('staff', 'manager', 'donor');
CREATE TYPE pet_species AS ENUM ('dog', 'cat');
CREATE TYPE pet_gender AS ENUM ('male', 'female');
CREATE TYPE sub_status AS ENUM ('pending', 'approved', 'rejected');
CREATE TYPE pet_status AS ENUM ('available', 'adopted', 'under_treatment');

-- ---------------------------------------------------------------------
-- 2. Tables (identical to your original schema, constraints untouched)
-- ---------------------------------------------------------------------
CREATE TABLE "users" (
    "userid" UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    "userfname" TEXT NOT NULL,
    "userlname" TEXT NOT NULL,
    "role" user_role NOT NULL,
    "email" TEXT UNIQUE NOT NULL,
    "contactnum" TEXT
);

CREATE TABLE "supplier" (
    "suppid" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "suppname" TEXT NOT NULL,
    "contactnum" TEXT,
    "address" TEXT
);

CREATE TABLE "category" (
    "categoryid" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "categoryname" TEXT UNIQUE NOT NULL
);

CREATE TABLE "uom" (
    "uomid" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "uomname" TEXT UNIQUE NOT NULL -- Unit of Measure, singular form (e.g. 'kg', 'pc', 'bag')
);

CREATE TABLE "item" (
    "itemid" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "itemname" TEXT NOT NULL,
    "itemcategory" TEXT NOT NULL, -- free text; values are expected to match "category"."categoryname"
    "item_uom" TEXT NOT NULL, -- free text; values are expected to match "uom"."uomname"
    "stockqty" INTEGER DEFAULT 0 NOT NULL
);

CREATE TABLE "pet" (
    "petid" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "petname" TEXT NOT NULL,
    "species" pet_species NOT NULL,
    "breed" TEXT,
    "gender" pet_gender NOT NULL,
    "spayed_neutered" BOOLEAN DEFAULT FALSE,
    "status" pet_status DEFAULT 'available'
);

CREATE TABLE "submission" (
    "subid" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "donorid" UUID NOT NULL REFERENCES "users"("userid"),
    "revby" UUID REFERENCES "users"("userid"), -- Staff who reviewed
    "status" sub_status DEFAULT 'pending',
    "scheddate" TIMESTAMPTZ,
    "datesub" TIMESTAMPTZ DEFAULT now(),
    "proofimg" TEXT -- Stores the Supabase Storage URL
);

CREATE TABLE "donation" (
    "donid" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "subid" UUID REFERENCES "submission"("subid"),
    "donorid" UUID NOT NULL REFERENCES "users"("userid"),
    "transdate" TIMESTAMPTZ DEFAULT now(),
    "rcvdby" UUID REFERENCES "users"("userid") -- Staff who received
);

CREATE TABLE "purchase_trans" (
    "purid" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "suppid" UUID NOT NULL REFERENCES "supplier"("suppid"),
    "userid" UUID NOT NULL REFERENCES "users"("userid"), -- Manager/Staff who purchased
    "purdate" TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE "treatment" (
    "treatid" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "petid" UUID NOT NULL REFERENCES "pet"("petid") ON DELETE CASCADE,
    "userid" UUID NOT NULL REFERENCES "users"("userid"), -- Staff who performed it
    "treatname" TEXT NOT NULL,
    "notes" TEXT,
    "recdate" TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE "donation_item" (
    "donid" UUID NOT NULL REFERENCES "donation"("donid") ON DELETE CASCADE,
    "itemid" UUID NOT NULL REFERENCES "item"("itemid"),
    "qty" INTEGER NOT NULL CHECK (qty > 0),
    PRIMARY KEY ("donid", "itemid")
);

CREATE TABLE "order_item" (
    "orderid" UUID NOT NULL REFERENCES "purchase_trans"("purid") ON DELETE CASCADE,
    "itemid" UUID NOT NULL REFERENCES "item"("itemid"),
    "qty" INTEGER NOT NULL CHECK (qty > 0),
    "unitcost" NUMERIC(10, 2) NOT NULL,
    PRIMARY KEY ("orderid", "itemid")
);

CREATE TABLE "treatment_item" (
    "treatid" UUID NOT NULL REFERENCES "treatment"("treatid") ON DELETE CASCADE,
    "itemid" UUID NOT NULL REFERENCES "item"("itemid"),
    "qtyused" INTEGER NOT NULL CHECK ("qtyused" > 0),
    "consumeddate" TIMESTAMPTZ DEFAULT now(),
    "givenby" UUID REFERENCES "users"("userid"),
    PRIMARY KEY ("treatid", "itemid")
);

-- ---------------------------------------------------------------------
-- 3. IMPORTANT: no "ensure_rls" event trigger is created here.
--
-- Your old project had an event trigger that auto-enabled RLS on every
-- table the instant it was created, which is what locked you out of
-- sign-in earlier. This script deliberately skips creating that
-- trigger, so all 11 tables above are left with RLS OFF (Postgres's
-- default state for a freshly created table) -- exactly what you want
-- while you're designing pages and wiring up the frontend.
-- ---------------------------------------------------------------------

-- Safety net: explicitly confirm RLS is off on everything (harmless if
-- already off, useful if you ever paste in a table definition from
-- elsewhere that had RLS baked in).
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN SELECT tablename FROM pg_tables WHERE schemaname = 'public' LOOP
    EXECUTE format('ALTER TABLE public.%I DISABLE ROW LEVEL SECURITY;', r.tablename);
  END LOOP;
END $$;

-- =====================================================================
-- RE-ENABLE LATER (do NOT run this now -- reference only for when
-- you're ready to add real security before this goes anywhere near
-- real users):
--
--   1. Write CREATE POLICY statements for each table.
--   2. Then run, per table:
--        ALTER TABLE public.<table> ENABLE ROW LEVEL SECURITY;
--   3. Optionally recreate an event trigger like your old "ensure_rls"
--      so any *future* table you add gets RLS auto-armed on creation:
--
--        CREATE OR REPLACE FUNCTION ensure_rls_fn()
--        RETURNS event_trigger AS $$
--        DECLARE
--          cmd record;
--        BEGIN
--          FOR cmd IN
--            SELECT * FROM pg_event_trigger_ddl_commands()
--            WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
--              AND object_type IN ('table', 'partitioned table')
--          LOOP
--            IF cmd.schema_name = 'public' THEN
--              EXECUTE format('ALTER TABLE IF EXISTS %s ENABLE ROW LEVEL SECURITY', cmd.object_identity);
--            END IF;
--          END LOOP;
--        END;
--        $$ LANGUAGE plpgsql;
--
--        CREATE EVENT TRIGGER ensure_rls ON ddl_command_end
--        EXECUTE FUNCTION ensure_rls_fn();
-- =====================================================================