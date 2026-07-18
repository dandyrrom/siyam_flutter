import '../mock/mock_database.dart';
import '../models/primary_category.dart';
import '../models/subcategory.dart';
import '../models/unit.dart';
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
  Future<Unit> createUnit(String abbrName);
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
    list.sort((a, b) => a.abbrName.compareTo(b.abbrName));
    return list;
  }

  @override
  Future<PrimaryCategory> createPrimaryCategory(String type) async {
    final category = PrimaryCategory(id: newMockId('pcat'), type: type);
    _db.primaryCategories.add(category);
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
    return subcategory;
  }

  @override
  Future<Unit> createUnit(String abbrName) async {
    final unit = Unit(id: newMockId('unit'), abbrName: abbrName);
    _db.units.add(unit);
    return unit;
  }
}
