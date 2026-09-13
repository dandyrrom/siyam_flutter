-- Publish every table SIYAM reads so another user's insert/update/delete
-- reaches signed-in clients. Tables that do not exist yet are skipped.

do $$
declare
  table_name text;
  published text[] := array[
    'users',
    'primary_category',
    'subcategory',
    'units',
    'item',
    'system_settings',
    'item_rop_settings',
    'pet',
    'supplier',
    'purchase',
    'purchase_item',
    'treatment',
    'treatment_item',
    'treatment_occurrence',
    'submission',
    'donation',
    'donation_item',
    'stock_out',
    'inventory_batch',
    'batch_transaction_log',
    'audit_log'
  ];
begin
  foreach table_name in array published
  loop
    if to_regclass('public.' || table_name) is null then
      continue;
    end if;

    execute format(
      'alter table public.%I replica identity full',
      table_name
    );

    begin
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    exception
      when duplicate_object then
        null;
    end;
  end loop;
end $$;
