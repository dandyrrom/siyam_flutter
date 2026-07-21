-- SIYAM: additional suppliers and pets (Filipino-flavored sample data).
-- =============================================================================
-- Adds new supplier and pet rows on top of whatever 0001/0002/0003 already
-- seeded -- doesn't touch or replace existing rows in either table.
-- =============================================================================

-- ----------------------------------------------------------------------------
-- Suppliers
-- ----------------------------------------------------------------------------
insert into public.supplier (name, contactnum, contacttel, address) values
  ('Bantay Gamot Veterinary Supplies',   '09173456789', '(02) 8734-1122', 'Barangay Commonwealth, Quezon City, Metro Manila'),
  ('Ligtas Alaga Pet Pharma Trading',    '09189876543', '(032) 255-6789', 'Barangay Lahug, Cebu City, Cebu'),
  ('Malayang Hayop Distributors Inc.',   '09201122334', '(082) 224-5566', 'Barangay Matina, Davao City, Davao del Sur'),
  ('Kalinga Vet Supply Co.',             '09225566778', '(033) 337-8899', 'Barangay Mandurriao, Iloilo City, Iloilo'),
  ('Alagang Maka-Hayop Trading',         '09339988771', '(02) 8991-2233', 'Barangay San Antonio, Makati City, Metro Manila'),
  ('Bukid at Bahay Pet Essentials',      '09451234098', null,             'Barangay San Isidro, Angeles City, Pampanga');

-- ----------------------------------------------------------------------------
-- Pets
-- ----------------------------------------------------------------------------
insert into public.pet (name, species, breed, gender, spayed_neutered, status) values
  ('Bantay',   'dog', 'Aspin',              'male',   true,  'available'),
  ('Kikay',    'cat', 'Puspin',             'female', true,  'available'),
  ('Brownie',  'dog', 'Shih Tzu mix',       'male',   false, 'under_treatment'),
  ('Chichay',  'cat', 'Puspin',             'female', false, 'available'),
  ('Bogart',   'dog', 'Aspin',              'male',   true,  'adopted'),
  ('Mochi',    'cat', 'Puspin',             'male',   true,  'available'),
  ('Duchess',  'dog', 'Siberian Husky mix', 'female', true,  'available'),
  ('Buboy',    'dog', 'Aspin',              'male',   false, 'under_treatment'),
  ('Yuki',     'cat', 'Persian mix',        'female', true,  'adopted'),
  ('Pilay',    'dog', 'Aspin',              'male',   false, 'under_treatment');
