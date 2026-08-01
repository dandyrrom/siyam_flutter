import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/primary_category.dart';
import '../../models/subcategory.dart';
import '../../models/unit.dart';
import '../../state/data_bus.dart';
import '../catalog_service.dart';

/// Supabase-backed catalog lookups: public.primary_category / subcategory /
/// units.
class SupabaseCatalogService implements CatalogService {
  final SupabaseClient _client = Supabase.instance.client;

  PrimaryCategory _mapPrimary(Map<String, dynamic> r) => PrimaryCategory(
        id: r['id'] as String,
        type: (r['type'] as String?) ?? '',
        requiresExpiry: r['requires_expiry'] as bool? ?? false,
      );

  Subcategory _mapSub(Map<String, dynamic> r) => Subcategory(
        id: r['id'] as String,
        pCategoryId: r['p_category'] as String,
        type: (r['type'] as String?) ?? '',
        requiresExpiry: r['requires_expiry'] as bool?,
      );

  Unit _mapUnit(Map<String, dynamic> r) => Unit(
        id: r['id'] as String,
        name: (r['name'] as String?) ?? '',
        abbrName: (r['abbr_name'] as String?) ?? '',
      );

  @override
  Future<List<PrimaryCategory>> fetchPrimaryCategories() async {
    final rows = await _client
        .from('primary_category')
        .select('id, type, requires_expiry')
        .order('type');
    return rows.map((r) => _mapPrimary(r)).toList();
  }

  @override
  Future<List<Subcategory>> fetchSubcategories([String? pCategoryId]) async {
    var query =
        _client.from('subcategory').select('id, p_category, type, requires_expiry');
    if (pCategoryId != null) {
      query = query.eq('p_category', pCategoryId);
    }
    final rows = await query.order('type');
    return rows.map((r) => _mapSub(r)).toList();
  }

  @override
  Future<List<Unit>> fetchUnits() async {
    final rows =
        await _client.from('units').select('id, name, abbr_name').order('name');
    return rows.map((r) => _mapUnit(r)).toList();
  }

  @override
  Future<PrimaryCategory> createPrimaryCategory(String type) async {
    final row = await _client
        .from('primary_category')
        .insert({'type': type})
        .select('id, type, requires_expiry')
        .single();
    DataChangeBus.instance.ping();
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
        .select('id, p_category, type, requires_expiry')
        .single();
    DataChangeBus.instance.ping();
    return _mapSub(row);
  }

  @override
  Future<Unit> createUnit({required String name, required String abbrName}) async {
    final row = await _client
        .from('units')
        .insert({'name': name, 'abbr_name': abbrName})
        .select('id, name, abbr_name')
        .single();
    DataChangeBus.instance.ping();
    return _mapUnit(row);
  }

  @override
  Future<Unit> renameUnit({
    required String id,
    required String name,
    required String abbrName,
  }) async {
    final row = await _client
        .from('units')
        .update({'name': name, 'abbr_name': abbrName})
        .eq('id', id)
        .select('id, name, abbr_name')
        .single();
    DataChangeBus.instance.ping();
    return _mapUnit(row);
  }

  // Relies on the database's own foreign-key constraints (ITEM.purchase_unit
  // / package_unit / dispense_unit -- see updated_db.md) to reject the
  // delete with a PostgrestException when rows still reference it, same as
  // deletePrimaryCategory/deleteSubcategory below.
  @override
  Future<void> deleteUnit(String id) async {
    await _client.from('units').delete().eq('id', id);
    DataChangeBus.instance.ping();
  }

  @override
  Future<PrimaryCategory> setPrimaryCategoryRequiresExpiry({
    required String id,
    required bool requiresExpiry,
  }) async {
    final row = await _client
        .from('primary_category')
        .update({'requires_expiry': requiresExpiry})
        .eq('id', id)
        .select('id, type, requires_expiry')
        .single();
    DataChangeBus.instance.ping();
    return _mapPrimary(row);
  }

  @override
  Future<Subcategory> setSubcategoryRequiresExpiry({
    required String id,
    required bool? requiresExpiry,
  }) async {
    final row = await _client
        .from('subcategory')
        .update({'requires_expiry': requiresExpiry})
        .eq('id', id)
        .select('id, p_category, type, requires_expiry')
        .single();
    DataChangeBus.instance.ping();
    return _mapSub(row);
  }

  @override
  Future<PrimaryCategory> renamePrimaryCategory({
    required String id,
    required String type,
  }) async {
    final row = await _client
        .from('primary_category')
        .update({'type': type})
        .eq('id', id)
        .select('id, type, requires_expiry')
        .single();
    DataChangeBus.instance.ping();
    return _mapPrimary(row);
  }

  @override
  Future<Subcategory> renameSubcategory({required String id, required String type}) async {
    final row = await _client
        .from('subcategory')
        .update({'type': type})
        .eq('id', id)
        .select('id, p_category, type, requires_expiry')
        .single();
    DataChangeBus.instance.ping();
    return _mapSub(row);
  }

  // Relies on the database's own foreign-key constraints (ITEM.p_category /
  // ITEM.s_category / SUBCATEGORY.p_category -- see updated_db.md) to
  // reject the delete with a PostgrestException when rows still reference
  // it, same as SupabaseSupplierService.deleteSupplier. updated_db.md
  // doesn't document each FK's ON DELETE behavior, so this assumes the
  // migrations don't set CASCADE; verify against the actual migration SQL
  // before relying on this in production.
  @override
  Future<void> deletePrimaryCategory(String id) async {
    await _client.from('primary_category').delete().eq('id', id);
    DataChangeBus.instance.ping();
  }

  @override
  Future<void> deleteSubcategory(String id) async {
    await _client.from('subcategory').delete().eq('id', id);
    DataChangeBus.instance.ping();
  }
}
