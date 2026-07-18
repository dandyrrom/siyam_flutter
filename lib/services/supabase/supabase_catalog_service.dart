import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/primary_category.dart';
import '../../models/subcategory.dart';
import '../../models/unit.dart';
import '../catalog_service.dart';

/// Supabase-backed catalog lookups: public.primary_category / subcategory /
/// units.
class SupabaseCatalogService implements CatalogService {
  final SupabaseClient _client = Supabase.instance.client;

  PrimaryCategory _mapPrimary(Map<String, dynamic> r) =>
      PrimaryCategory(id: r['id'] as String, type: (r['type'] as String?) ?? '');

  Subcategory _mapSub(Map<String, dynamic> r) => Subcategory(
        id: r['id'] as String,
        pCategoryId: r['p_category'] as String,
        type: (r['type'] as String?) ?? '',
      );

  Unit _mapUnit(Map<String, dynamic> r) =>
      Unit(id: r['id'] as String, abbrName: (r['abbr_name'] as String?) ?? '');

  @override
  Future<List<PrimaryCategory>> fetchPrimaryCategories() async {
    final rows =
        await _client.from('primary_category').select('id, type').order('type');
    return rows.map((r) => _mapPrimary(r)).toList();
  }

  @override
  Future<List<Subcategory>> fetchSubcategories([String? pCategoryId]) async {
    var query = _client.from('subcategory').select('id, p_category, type');
    if (pCategoryId != null) {
      query = query.eq('p_category', pCategoryId);
    }
    final rows = await query.order('type');
    return rows.map((r) => _mapSub(r)).toList();
  }

  @override
  Future<List<Unit>> fetchUnits() async {
    final rows =
        await _client.from('units').select('id, abbr_name').order('abbr_name');
    return rows.map((r) => _mapUnit(r)).toList();
  }

  @override
  Future<PrimaryCategory> createPrimaryCategory(String type) async {
    final row = await _client
        .from('primary_category')
        .insert({'type': type})
        .select('id, type')
        .single();
    return _mapPrimary(row);
  }

  @override
  Future<Subcategory> createSubcategory({
    required String pCategoryId,
    required String type,
  }) async {
    final row = await _client
        .from('subcategory')
        .insert({'p_category': pCategoryId, 'type': type})
        .select('id, p_category, type')
        .single();
    return _mapSub(row);
  }

  @override
  Future<Unit> createUnit(String abbrName) async {
    final row = await _client
        .from('units')
        .insert({'abbr_name': abbrName})
        .select('id, abbr_name')
        .single();
    return _mapUnit(row);
  }
}
