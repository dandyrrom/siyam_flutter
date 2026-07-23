import '../models/app_user.dart';
import '../models/pet.dart';
import '../models/primary_category.dart';
import '../models/stock_out.dart';
import '../models/subcategory.dart';
import '../models/supplier.dart';
import '../models/unit.dart';

int _idCounter = 0;

/// Generates a unique mock id. Not a real UUID -- there's no backend to
/// enforce uniqueness against, so a counter is enough for an in-memory store.
String newMockId([String prefix = 'id']) {
  _idCounter += 1;
  return '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
}

/// Null-safe "find first match" -- avoids pulling in package:collection just
/// for firstOrNull.
T? firstWhereOrNull<T>(Iterable<T> items, bool Function(T) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

/// Raw storage row for public.item -- FK ids only. Services resolve these
/// into the denormalized InventoryItem model (with category/unit names) on
/// fetch; this row is what actually gets mutated (createItem/adjustStock).
class ItemRow {
  final String id;
  String name;
  String pCategoryId;
  String? sCategoryId;
  String purchaseUnitId;
  String? packageUnitId;
  double? packageQuantity;
  String? dispenseUnitId;
  double purchaseStocks;
  double? packageStocks;

  ItemRow({
    required this.id,
    required this.name,
    required this.pCategoryId,
    this.sCategoryId,
    required this.purchaseUnitId,
    this.packageUnitId,
    this.packageQuantity,
    this.dispenseUnitId,
    required this.purchaseStocks,
    this.packageStocks,
  });
}

class PurchaseRow {
  final String id;
  final String suppId;
  final String recordedByUserId;
  final DateTime recordedDate;
  final String receivedBy;
  final DateTime receivedDate;

  PurchaseRow({
    required this.id,
    required this.suppId,
    required this.recordedByUserId,
    required this.recordedDate,
    required this.receivedBy,
    required this.receivedDate,
  });
}

class PurchaseItemRow {
  final String purchaseId;
  final String itemId;
  final double qty;
  final double unitCost;

  PurchaseItemRow({
    required this.purchaseId,
    required this.itemId,
    required this.qty,
    required this.unitCost,
  });
}

class TreatmentRow {
  final String id;
  final String name;
  final String petId;
  final String recordedByUserId;
  final DateTime recordedDate;
  final String? notes;

  TreatmentRow({
    required this.id,
    required this.name,
    required this.petId,
    required this.recordedByUserId,
    required this.recordedDate,
    this.notes,
  });
}

class TreatmentItemRow {
  final String treatId;
  final String itemId;
  final double dispensedQty;
  final String dispenseUnitId;
  final DateTime consumedDate;
  final String givenBy;
  final DateTime recordedDate;
  final String recordedByUserId;

  TreatmentItemRow({
    required this.treatId,
    required this.itemId,
    required this.dispensedQty,
    required this.dispenseUnitId,
    required this.consumedDate,
    required this.givenBy,
    required this.recordedDate,
    required this.recordedByUserId,
  });
}

class SubmissionRow {
  final String id;
  final String donorId;
  String? updatedByUserId;
  String status;
  final DateTime? schedDate;
  final DateTime dateSub;
  DateTime? dateReceived;
  final String? proofImg;
  final String? notes;

  SubmissionRow({
    required this.id,
    required this.donorId,
    this.updatedByUserId,
    required this.status,
    this.schedDate,
    required this.dateSub,
    this.dateReceived,
    this.proofImg,
    this.notes,
  });
}

class DonationRow {
  final String id;
  /// Null when the donor has no SIYAM account -- see [donorName].
  final String? donorId;
  /// Free-text donor name, for documentation only, when [donorId] is null
  /// (an unregistered/walk-in donor). Not a real donor reference.
  final String? donorName;
  final String? subId;
  final String receivedBy;
  final DateTime receivedDate;
  final String recordedByUserId;
  final DateTime recordedDate;

  DonationRow({
    required this.id,
    this.donorId,
    this.donorName,
    this.subId,
    required this.receivedBy,
    required this.receivedDate,
    required this.recordedByUserId,
    required this.recordedDate,
  });
}

class DonationItemRow {
  final String donId;
  final String itemId;
  final double qty;

  DonationItemRow({required this.donId, required this.itemId, required this.qty});
}

/// In-memory data store standing in for the (currently absent) backend.
/// Shaped by updated_db.md. Resets every time the app restarts -- there is
/// no persistence beyond process memory.
class MockDatabase {
  MockDatabase._();
  static final MockDatabase instance = MockDatabase._();

  final List<AppUser> users = [];
  final List<Pet> pets = [];
  final List<Supplier> suppliers = [];
  final List<PrimaryCategory> primaryCategories = [];
  final List<Subcategory> subcategories = [];
  final List<Unit> units = [];
  final List<ItemRow> items = [];
  final List<PurchaseRow> purchases = [];
  final List<PurchaseItemRow> purchaseItems = [];
  final List<TreatmentRow> treatments = [];
  final List<TreatmentItemRow> treatmentItems = [];
  final List<SubmissionRow> submissions = [];
  final List<DonationRow> donations = [];
  final List<DonationItemRow> donationItems = [];
  final List<StockOut> stockOuts = [];

  bool _seeded = false;

  /// Populates sample data. Safe to call more than once -- only seeds once.
  void seed() {
    if (_seeded) return;
    _seeded = true;

    // Login credentials for the seeded accounts (plaintext, mock auth only):
    //   manager@siyam.test / password123
    //   staff@siyam.test   / password123
    //   donor@siyam.test   / password123
    users.addAll([
      AppUser(
        userId: newMockId('user'),
        firstName: 'Maria',
        lastName: 'Santos',
        role: AppRole.manager,
        email: 'manager@siyam.test',
        password: 'password123',
        contactNum: '09171234567',
      ),
      AppUser(
        userId: newMockId('user'),
        firstName: 'Jomar',
        lastName: 'Cruz',
        role: AppRole.staff,
        email: 'staff@siyam.test',
        password: 'password123',
        contactNum: '09181234567',
      ),
      AppUser(
        userId: newMockId('user'),
        firstName: 'Ana',
        lastName: 'Reyes',
        role: AppRole.donor,
        email: 'donor@siyam.test',
        password: 'password123',
        contactNum: '09191234567',
      ),
    ]);

    pets.addAll([
      const Pet(
        petId: 'pet-bella',
        petName: 'Bella',
        species: PetSpecies.dog,
        breed: 'Aspin',
        gender: PetGender.female,
        spayedNeutered: true,
        status: PetStatus.available,
      ),
      const Pet(
        petId: 'pet-whiskers',
        petName: 'Whiskers',
        species: PetSpecies.cat,
        breed: 'Puspin',
        gender: PetGender.male,
        spayedNeutered: false,
        status: PetStatus.underTreatment,
      ),
    ]);

    suppliers.add(const Supplier(
      suppId: 'supplier-petcare',
      suppName: 'PetCare Distributors Inc.',
      contactNum: '09201234567',
      address: 'Quezon City, Metro Manila',
    ));

    final unitBox = Unit(id: newMockId('unit'), name: 'Box', abbrName: 'box');
    final unitTablet = Unit(id: newMockId('unit'), name: 'Tablet', abbrName: 'tablet');
    final unitBottle = Unit(id: newMockId('unit'), name: 'Bottle', abbrName: 'bottle');
    final unitMl = Unit(id: newMockId('unit'), name: 'Milliliter', abbrName: 'ml');
    final unitBag = Unit(id: newMockId('unit'), name: 'Bag', abbrName: 'bag');
    final unitKg = Unit(id: newMockId('unit'), name: 'Kilogram', abbrName: 'kg');
    final unitDrop = Unit(id: newMockId('unit'), name: 'Drop', abbrName: 'drop');
    final unitPcs = Unit(id: newMockId('unit'), name: 'Piece', abbrName: 'pcs');
    units.addAll(
        [unitBox, unitTablet, unitBottle, unitMl, unitBag, unitKg, unitDrop, unitPcs]);

    final catMedical = PrimaryCategory(id: newMockId('pcat'), type: 'Medical');
    final catFood = PrimaryCategory(id: newMockId('pcat'), type: 'Food');
    final catCleaning = PrimaryCategory(id: newMockId('pcat'), type: 'Cleaning Supplies');
    final catEquipment = PrimaryCategory(id: newMockId('pcat'), type: 'Equipment');
    primaryCategories.addAll([catMedical, catFood, catCleaning, catEquipment]);

    final subTablets =
        Subcategory(id: newMockId('scat'), pCategoryId: catMedical.id, type: 'Tablets');
    final subOralSuspension = Subcategory(
        id: newMockId('scat'), pCategoryId: catMedical.id, type: 'Oral Suspension');
    final subDrops =
        Subcategory(id: newMockId('scat'), pCategoryId: catMedical.id, type: 'Drops');
    final subSupplies =
        Subcategory(id: newMockId('scat'), pCategoryId: catMedical.id, type: 'Supplies');
    final subDry = Subcategory(id: newMockId('scat'), pCategoryId: catFood.id, type: 'Dry');
    final subBleach =
        Subcategory(id: newMockId('scat'), pCategoryId: catCleaning.id, type: 'Bleach');
    final subTools =
        Subcategory(id: newMockId('scat'), pCategoryId: catEquipment.id, type: 'Tools');
    subcategories.addAll(
        [subTablets, subOralSuspension, subDrops, subSupplies, subDry, subBleach, subTools]);

    items.addAll([
      ItemRow(
        id: newMockId('item'),
        name: 'Uticare',
        pCategoryId: catMedical.id,
        sCategoryId: subTablets.id,
        purchaseUnitId: unitBox.id,
        packageUnitId: unitTablet.id,
        packageQuantity: 30,
        dispenseUnitId: unitTablet.id,
        purchaseStocks: 2,
        packageStocks: 60,
      ),
      ItemRow(
        id: newMockId('item'),
        name: 'Royal Canin Adult Dry Food',
        pCategoryId: catMedical.id,
        sCategoryId: subOralSuspension.id,
        purchaseUnitId: unitBottle.id,
        packageUnitId: unitMl.id,
        packageQuantity: 100,
        dispenseUnitId: unitMl.id,
        purchaseStocks: 10,
        packageStocks: 1000,
      ),
      ItemRow(
        id: newMockId('item'),
        name: 'Eye Vitamin Drop',
        pCategoryId: catMedical.id,
        sCategoryId: subDrops.id,
        purchaseUnitId: unitBottle.id,
        packageUnitId: unitMl.id,
        packageQuantity: 200,
        dispenseUnitId: unitDrop.id, // differs from package_unit (ml) on purpose
        purchaseStocks: 26,
        packageStocks: 5200,
      ),
      ItemRow(
        id: newMockId('item'),
        name: 'Adult Dog Dry Food',
        pCategoryId: catFood.id,
        sCategoryId: subDry.id,
        purchaseUnitId: unitBag.id,
        packageUnitId: unitKg.id,
        packageQuantity: 9,
        dispenseUnitId: unitKg.id,
        purchaseStocks: 4,
        packageStocks: 36,
      ),
      ItemRow(
        id: newMockId('item'),
        name: 'Zonrox Bleach',
        pCategoryId: catCleaning.id,
        sCategoryId: subBleach.id,
        purchaseUnitId: unitBottle.id,
        packageUnitId: unitMl.id,
        packageQuantity: 450,
        dispenseUnitId: unitMl.id,
        purchaseStocks: 2,
        packageStocks: 900,
      ),
      ItemRow(
        id: newMockId('item'),
        name: 'Mop',
        pCategoryId: catEquipment.id,
        sCategoryId: subTools.id,
        purchaseUnitId: unitPcs.id,
        purchaseStocks: 5,
      ),
    ]);
  }
}
