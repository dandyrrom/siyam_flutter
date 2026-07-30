import '../models/app_user.dart';
import '../models/pet.dart';
import '../models/primary_category.dart';
import '../models/qty_unit.dart';
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

  /// Cumulative loose package-unit qty ever stocked in directly (not via a
  /// whole container) -- see updated_db.md's total_package_stock_ins. Only
  /// ever increases; needed because a package-unit stock-in adds to
  /// [packageStocks] without a corresponding whole container to count in
  /// [purchaseStocks], which would otherwise make the two pools impossible
  /// to reconcile.
  double totalPackageStockIns;

  /// Staff-chosen display mode for this item's stock figure (package_unit
  /// vs purchase_unit) -- null means "not set yet," in which case
  /// [InventoryItem.effectiveCountMode] derives a default from whether the
  /// item is deductible with a package breakdown.
  String? stockCountMode;

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
    this.totalPackageStockIns = 0,
    this.stockCountMode,
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

/// One purchase_item row -- also the batch used for FEFO deduction (see
/// updated_db.md). [qty]/[unitCost] are in [qtyUnit] terms, as entered by
/// staff. [qtyRemaining] is a separate, mutable running balance in
/// *canonical* terms (package_unit if the item has a package breakdown,
/// else purchase_unit terms) -- drawn down by treatment usage / stock-out,
/// independent of [qty] which stays fixed as the original stock-in record.
class PurchaseItemRow {
  final String purchaseId;
  final String itemId;
  final double qty;
  final QtyUnit qtyUnit;
  final double unitCost;
  final DateTime? expiryDate;
  double qtyRemaining;

  PurchaseItemRow({
    required this.purchaseId,
    required this.itemId,
    required this.qty,
    this.qtyUnit = QtyUnit.purchaseUnit,
    required this.unitCost,
    this.expiryDate,
    required this.qtyRemaining,
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
  final String id;
  final String treatId;
  final String itemId;
  final double dispensedQty;
  final String dispenseUnitId;
  final DateTime consumedDate;
  final String givenBy;
  final DateTime recordedDate;
  final String recordedByUserId;

  TreatmentItemRow({
    required this.id,
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
  /// 'walk_in' or 'drop_off' -- see [DonationType]. Descriptive only; does
  /// not constrain whether [donorId] or [subId] are set.
  final String type;
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
    required this.type,
    this.donorId,
    this.donorName,
    this.subId,
    required this.receivedBy,
    required this.receivedDate,
    required this.recordedByUserId,
    required this.recordedDate,
  });
}

/// One donation_item row -- also a FEFO batch, mirroring [PurchaseItemRow]
/// minus cost (donations have no purchase cost).
class DonationItemRow {
  final String donId;
  final String itemId;
  final double qty;
  final QtyUnit qtyUnit;
  final DateTime? expiryDate;
  double qtyRemaining;

  DonationItemRow({
    required this.donId,
    required this.itemId,
    required this.qty,
    this.qtyUnit = QtyUnit.purchaseUnit,
    this.expiryDate,
    required this.qtyRemaining,
  });
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

    final itemUticare = ItemRow(
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
    );
    final itemRoyalCanin = ItemRow(
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
    );
    final itemEyeDrop = ItemRow(
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
    );
    final itemDryFood = ItemRow(
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
    );
    final itemBleach = ItemRow(
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
    );
    final itemMop = ItemRow(
      id: newMockId('item'),
      name: 'Mop',
      pCategoryId: catEquipment.id,
      sCategoryId: subTools.id,
      purchaseUnitId: unitPcs.id,
      purchaseStocks: 5,
    );

    items.addAll([
      itemUticare,
      itemRoyalCanin,
      itemEyeDrop,
      itemDryFood,
      itemBleach,
      itemMop,
    ]);

    // Opening-balance batches -- every unit of stock above needs a
    // purchase_item/donation_item row backing it, or FEFO deduction has
    // nothing to draw from (see updated_db.md). Modeled as one "opening
    // balance" purchase per item, dated in the past, with staggered expiry
    // dates on the medical/food items so a later real stock-in demonstrates
    // FEFO ordering against these.
    final openingPurchase = PurchaseRow(
      id: newMockId('purchase'),
      suppId: 'supplier-petcare',
      recordedByUserId: users[0].userId,
      recordedDate: DateTime(2026, 1, 1),
      receivedBy: 'Opening balance',
      receivedDate: DateTime(2026, 1, 1),
    );
    purchases.add(openingPurchase);

    void addOpeningBatch(ItemRow item, DateTime? expiryDate) {
      final qtyRemaining = item.packageQuantity != null
          ? (item.packageStocks ?? item.purchaseStocks * item.packageQuantity!)
          : item.purchaseStocks;
      purchaseItems.add(PurchaseItemRow(
        purchaseId: openingPurchase.id,
        itemId: item.id,
        qty: item.purchaseStocks,
        qtyUnit: QtyUnit.purchaseUnit,
        unitCost: 0,
        expiryDate: expiryDate,
        qtyRemaining: qtyRemaining,
      ));
    }

    addOpeningBatch(itemUticare, DateTime(2026, 12, 31));
    addOpeningBatch(itemRoyalCanin, DateTime(2027, 1, 1));
    addOpeningBatch(itemEyeDrop, DateTime(2027, 3, 15));
    addOpeningBatch(itemDryFood, DateTime(2026, 10, 1));
    addOpeningBatch(itemBleach, null);
    addOpeningBatch(itemMop, null);
  }
}
