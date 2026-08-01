import '../mock/mock_database.dart';
import '../models/primary_category.dart';
import '../models/subcategory.dart';
import '../models/unit.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'supabase/supabase_catalog_service.dart';

/// Data-access interface for catalog lookup tables. The factory resolves to
/// the mock or Supabase implementation based on [kUseMock], chosen at build
/// time.
abstract interface class CatalogService {
  factory CatalogService() =>
      kUseMock ? MockCatalogService() : SupabaseCatalogService();

  Future<List<PrimaryCategory>> fetchPrimaryCategories();
  Future<List<Subcategory>> fetchSubcategories([String? pCategoryId]);
  Future<List<Unit>> fetchUnits();
  Future<PrimaryCategory> createPrimaryCategory(String type);
  Future<Subcategory> createSubcategory({
    required String pCategoryId,
    required String type,
  });
  Future<Unit> createUnit({required String name, required String abbrName});
  Future<Unit> renameUnit({required String id, required String name, required String abbrName});

  /// Throws if any item still references this unit as its purchase, package,
  /// or dispense unit -- reassign/remove those first.
  Future<void> deleteUnit(String id);

  /// Sets whether items directly under this primary category require an
  /// expiry date at Stock In.
  Future<PrimaryCategory> setPrimaryCategoryRequiresExpiry({
    required String id,
    required bool requiresExpiry,
  });

  /// Sets this subcategory's expiry-date requirement override. Pass `null`
  /// to clear the override and inherit the parent primary category's
  /// setting instead.
  Future<Subcategory> setSubcategoryRequiresExpiry({
    required String id,
    required bool? requiresExpiry,
  });

  Future<PrimaryCategory> renamePrimaryCategory({required String id, required String type});
  Future<Subcategory> renameSubcategory({required String id, required String type});

  /// Throws if any subcategory still exists under this primary category, or
  /// any item still references it directly -- reassign/remove those first.
  Future<void> deletePrimaryCategory(String id);

  /// Throws if any item still references this subcategory -- reassign/
  /// remove those first.
  Future<void> deleteSubcategory(String id);
}

/// Thrown by [CatalogService.deletePrimaryCategory]/[deleteSubcategory] when
/// rows still reference the category being deleted. Carries the actual
/// blocking item/subcategory names so the UI can list them, not just a
/// count.
class CategoryInUseException implements Exception {
  final String message;
  final List<String> blockingSubcategoryNames;
  final List<String> blockingItemNames;

  const CategoryInUseException(
    this.message, {
    this.blockingSubcategoryNames = const [],
    this.blockingItemNames = const [],
  });

  @override
  String toString() => message;
}

/// Lookup-table access for public.primary_category / subcategory / units --
/// the catalog data used by the Stock In form's category/unit pickers.
class MockCatalogService implements CatalogService {
  final MockDatabase _db = MockDatabase.instance;

  @override
  Future<List<PrimaryCategory>> fetchPrimaryCategories() async {
    final list = List<PrimaryCategory>.from(_db.primaryCategories);
    list.sort((a, b) => a.type.compareTo(b.type));
    return list;
  }

  /// All subcategories, or only those under [pCategoryId] if given.
  @override
  Future<List<Subcategory>> fetchSubcategories([String? pCategoryId]) async {
    final list = (pCategoryId == null
            ? _db.subcategories
            : _db.subcategories.where((s) => s.pCategoryId == pCategoryId))
        .toList();
    list.sort((a, b) => a.type.compareTo(b.type));
    return list;
  }

  @override
  Future<List<Unit>> fetchUnits() async {
    final list = List<Unit>.from(_db.units);
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Future<PrimaryCategory> createPrimaryCategory(String type) async {
    final category =
        PrimaryCategory(id: newMockId('pcat'), type: type, requiresExpiry: false);
    _db.primaryCategories.add(category);
    DataChangeBus.instance.ping();
    return category;
  }

  @override
  Future<Subcategory> createSubcategory({
    required String pCategoryId,
    required String type,
  }) async {
    final subcategory =
        Subcategory(id: newMockId('scat'), pCategoryId: pCategoryId, type: type);
    _db.subcategories.add(subcategory);
    DataChangeBus.instance.ping();
    return subcategory;
  }

  @override
  Future<PrimaryCategory> setPrimaryCategoryRequiresExpiry({
    required String id,
    required bool requiresExpiry,
  }) async {
    final index = _db.primaryCategories.indexWhere((c) => c.id == id);
    if (index == -1) throw Exception('Primary category not found');
    final current = _db.primaryCategories[index];
    final updated = PrimaryCategory(
      id: current.id,
      type: current.type,
      requiresExpiry: requiresExpiry,
    );
    _db.primaryCategories[index] = updated;
    DataChangeBus.instance.ping();
    return updated;
  }

  @override
  Future<Subcategory> setSubcategoryRequiresExpiry({
    required String id,
    required bool? requiresExpiry,
  }) async {
    final index = _db.subcategories.indexWhere((s) => s.id == id);
    if (index == -1) throw Exception('Subcategory not found');
    final current = _db.subcategories[index];
    final updated = Subcategory(
      id: current.id,
      pCategoryId: current.pCategoryId,
      type: current.type,
      requiresExpiry: requiresExpiry,
    );
    _db.subcategories[index] = updated;
    DataChangeBus.instance.ping();
    return updated;
  }

  @override
  Future<Unit> createUnit({required String name, required String abbrName}) async {
    final unit = Unit(id: newMockId('unit'), name: name, abbrName: abbrName);
    _db.units.add(unit);
    DataChangeBus.instance.ping();
    return unit;
  }

  @override
  Future<Unit> renameUnit({
    required String id,
    required String name,
    required String abbrName,
  }) async {
    final index = _db.units.indexWhere((u) => u.id == id);
    if (index == -1) throw Exception('Unit not found');
    final updated = Unit(id: id, name: name, abbrName: abbrName);
    _db.units[index] = updated;
    DataChangeBus.instance.ping();
    return updated;
  }

  @override
  Future<void> deleteUnit(String id) async {
    final index = _db.units.indexWhere((u) => u.id == id);
    if (index == -1) throw Exception('Unit not found');
    final blockingItems = _db.items
        .where((i) =>
            i.purchaseUnitId == id || i.packageUnitId == id || i.dispenseUnitId == id)
        .map((i) => i.name)
        .toList();
    if (blockingItems.isNotEmpty) {
      throw CategoryInUseException(
        'This unit is still in use and cannot be deleted.',
        blockingItemNames: blockingItems,
      );
    }
    _db.units.removeAt(index);
    DataChangeBus.instance.ping();
  }

  @override
  Future<PrimaryCategory> renamePrimaryCategory({
    required String id,
    required String type,
  }) async {
    final index = _db.primaryCategories.indexWhere((c) => c.id == id);
    if (index == -1) throw Exception('Primary category not found');
    final current = _db.primaryCategories[index];
    final updated =
        PrimaryCategory(id: current.id, type: type, requiresExpiry: current.requiresExpiry);
    _db.primaryCategories[index] = updated;
    DataChangeBus.instance.ping();
    return updated;
  }

  @override
  Future<Subcategory> renameSubcategory({required String id, required String type}) async {
    final index = _db.subcategories.indexWhere((s) => s.id == id);
    if (index == -1) throw Exception('Subcategory not found');
    final current = _db.subcategories[index];
    final updated = Subcategory(
      id: current.id,
      pCategoryId: current.pCategoryId,
      type: type,
      requiresExpiry: current.requiresExpiry,
    );
    _db.subcategories[index] = updated;
    DataChangeBus.instance.ping();
    return updated;
  }

  @override
  Future<void> deletePrimaryCategory(String id) async {
    final index = _db.primaryCategories.indexWhere((c) => c.id == id);
    if (index == -1) throw Exception('Primary category not found');
    final blockingSubs =
        _db.subcategories.where((s) => s.pCategoryId == id).map((s) => s.type).toList();
    final blockingItems =
        _db.items.where((i) => i.pCategoryId == id).map((i) => i.name).toList();
    if (blockingSubs.isNotEmpty || blockingItems.isNotEmpty) {
      throw CategoryInUseException(
        'This category is still in use and cannot be deleted.',
        blockingSubcategoryNames: blockingSubs,
        blockingItemNames: blockingItems,
      );
    }
    _db.primaryCategories.removeAt(index);
    DataChangeBus.instance.ping();
  }

  @override
  Future<void> deleteSubcategory(String id) async {
    final index = _db.subcategories.indexWhere((s) => s.id == id);
    if (index == -1) throw Exception('Subcategory not found');
    final blockingItems =
        _db.items.where((i) => i.sCategoryId == id).map((i) => i.name).toList();
    if (blockingItems.isNotEmpty) {
      throw CategoryInUseException(
        'This subcategory is still in use and cannot be deleted.',
        blockingItemNames: blockingItems,
      );
    }
    _db.subcategories.removeAt(index);
    DataChangeBus.instance.ping();
  }
}
