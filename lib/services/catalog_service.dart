import '../mock/mock_database.dart';
import '../models/primary_category.dart';
import '../models/subcategory.dart';
import '../models/unit.dart';

/// Lookup-table access for public.primary_category / subcategory / units --
/// the catalog data used by the Stock In form's category/unit pickers.
class CatalogService {
  final MockDatabase _db = MockDatabase.instance;

  Future<List<PrimaryCategory>> fetchPrimaryCategories() async {
    final list = List<PrimaryCategory>.from(_db.primaryCategories);
    list.sort((a, b) => a.type.compareTo(b.type));
    return list;
  }

  /// All subcategories, or only those under [pCategoryId] if given.
  Future<List<Subcategory>> fetchSubcategories([String? pCategoryId]) async {
    final list = (pCategoryId == null
            ? _db.subcategories
            : _db.subcategories.where((s) => s.pCategoryId == pCategoryId))
        .toList();
    list.sort((a, b) => a.type.compareTo(b.type));
    return list;
  }

  Future<List<Unit>> fetchUnits() async {
    final list = List<Unit>.from(_db.units);
    list.sort((a, b) => a.abbrName.compareTo(b.abbrName));
    return list;
  }

  Future<PrimaryCategory> createPrimaryCategory(String type) async {
    final category = PrimaryCategory(id: newMockId('pcat'), type: type);
    _db.primaryCategories.add(category);
    return category;
  }

  Future<Subcategory> createSubcategory({
    required String pCategoryId,
    required String type,
  }) async {
    final subcategory =
        Subcategory(id: newMockId('scat'), pCategoryId: pCategoryId, type: type);
    _db.subcategories.add(subcategory);
    return subcategory;
  }

  Future<Unit> createUnit(String abbrName) async {
    final unit = Unit(id: newMockId('unit'), abbrName: abbrName);
    _db.units.add(unit);
    return unit;
  }
}
