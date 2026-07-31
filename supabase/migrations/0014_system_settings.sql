-- Adds SYSTEM_SETTINGS, a single-row app-wide settings table (see
-- updated_db.md). The boolean primary key defaulted to true, combined with
-- the check constraint, forces exactly one row to ever exist.

create table public.system_settings (
  id                       boolean primary key default true,
  low_stock_threshold      double precision not null default 10,
  expiration_warning_days  int not null default 30,
  constraint system_settings_singleton check (id)
);

insert into public.system_settings (id) values (true);

alter table public.system_settings enable row level security;

create policy "authenticated read" on public.system_settings
  for select to authenticated using (true);
create policy "authenticated insert" on public.system_settings
  for insert to authenticated with check (true);
create policy "authenticated update" on public.system_settings
  for update to authenticated using (true) with check (true);
create policy "authenticated delete" on public.system_settings
  for delete to authenticated using (true);
