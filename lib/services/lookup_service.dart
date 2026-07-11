import 'package:supabase_flutter/supabase_flutter.dart';

/// Read access to the `category` and `uom` lookup tables -- the managed
/// lists that back the item Category/Unit fields' "Type, Search, Select"
/// inputs (see widgets/search_select_field.dart). These are select-only
/// lists: adding a new category/UOM is not exposed in the item form, so
/// values here must already exist for an item to use them.
class LookupService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<String>> fetchCategories() async {
    final rows = await _client
        .from('category')
        .select('categoryname')
        .order('categoryname', ascending: true);
    return (rows as List).map((r) => r['categoryname'] as String).toList();
  }

  Future<List<String>> fetchUoms() async {
    final rows =
        await _client.from('uom').select('uomname').order('uomname', ascending: true);
    return (rows as List).map((r) => r['uomname'] as String).toList();
  }
}
