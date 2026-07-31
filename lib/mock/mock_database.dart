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

/// The single settings row -- see updated_db.md's SYSTEM_SETTINGS. There is
/// always exactly one of these; nothing ever adds a second row.
class SystemSettingsRow {
  double lowStockThreshold;
  int expirationWarningDays;

  SystemSettingsRow({
    this.lowStockThreshold = 10,
    this.expirationWarningDays = 30,
  });
}

/// In-memory data store standing in for the (currently absent) backend.
/// Shaped by updated_db.md. Resets every time the app restarts -- there is
/// no persistence beyond process memory.
class MockDatabase {
  MockDatabase._();
  static final MockDatabase instance = MockDatabase._();

  final SystemSettingsRow systemSettings = SystemSettingsRow();

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
      const Pet(
        petId: 'pet-max',
        petName: 'Max',
        species: PetSpecies.dog,
        breed: 'Aspin',
        gender: PetGender.male,
        spayedNeutered: true,
        status: PetStatus.available,
      ),
      const Pet(
        petId: 'pet-luna',
        petName: 'Luna',
        species: PetSpecies.cat,
        breed: 'Puspin',
        gender: PetGender.female,
        spayedNeutered: true,
        status: PetStatus.underTreatment,
      ),
      const Pet(
        petId: 'pet-rocky',
        petName: 'Rocky',
        species: PetSpecies.dog,
        breed: 'Aspin',
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
    final unitRoll = Unit(id: newMockId('unit'), name: 'Roll', abbrName: 'roll');
    final unitAmpoule = Unit(id: newMockId('unit'), name: 'Ampoule', abbrName: 'amp');
    units.addAll([
      unitBox,
      unitTablet,
      unitBottle,
      unitMl,
      unitBag,
      unitKg,
      unitDrop,
      unitPcs,
      unitRoll,
      unitAmpoule,
    ]);

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
    final subSupplements =
        Subcategory(id: newMockId('scat'), pCategoryId: catMedical.id, type: 'Supplements');
    final subNebules =
        Subcategory(id: newMockId('scat'), pCategoryId: catMedical.id, type: 'Nebules');
    subcategories.addAll([
      subTablets,
      subOralSuspension,
      subDrops,
      subSupplies,
      subDry,
      subBleach,
      subTools,
      subSupplements,
      subNebules,
    ]);

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

    // Chew + Heal Milk Thistle -- liver-support liquid supplement, 2oz (60ml)
    // dropper bottle, dosed in ml.
    final itemMilkThistle = ItemRow(
      id: newMockId('item'),
      name: 'Milk Thistle Liquid Supplement',
      pCategoryId: catMedical.id,
      sCategoryId: subSupplements.id,
      purchaseUnitId: unitBottle.id,
      packageUnitId: unitMl.id,
      packageQuantity: 60,
      dispenseUnitId: unitMl.id,
      purchaseStocks: 8,
      packageStocks: 480,
    );
    // Elanco Drontal -- flavored allwormer tablets, sold 2 tablets per box.
    final itemDrontal = ItemRow(
      id: newMockId('item'),
      name: 'Drontal Allwormer Tablet',
      pCategoryId: catMedical.id,
      sCategoryId: subTablets.id,
      purchaseUnitId: unitBox.id,
      packageUnitId: unitTablet.id,
      packageQuantity: 2,
      dispenseUnitId: unitTablet.id,
      purchaseStocks: 15,
      packageStocks: 30,
    );
    // Papi Livwell -- L-Carnitine/Silymarin/DHA liver-support syrup, 60ml
    // bottle, dosed in ml.
    final itemPapiLivwell = ItemRow(
      id: newMockId('item'),
      name: 'Papi Livwell Syrup 60ml',
      pCategoryId: catMedical.id,
      sCategoryId: subSupplements.id,
      purchaseUnitId: unitBottle.id,
      packageUnitId: unitMl.id,
      packageQuantity: 60,
      dispenseUnitId: unitMl.id,
      purchaseStocks: 6,
      packageStocks: 360,
    );
    // VetWrap -- self-adhesive bandage roll, used whole per treatment; no
    // sub-unit breakdown, same shape as Mop.
    final itemVetWrap = ItemRow(
      id: newMockId('item'),
      name: 'VetWrap Bandage',
      pCategoryId: catMedical.id,
      sCategoryId: subSupplies.id,
      purchaseUnitId: unitPcs.id,
      purchaseStocks: 20,
    );
    // Nacalvit-C -- ascorbic acid (vitamin C) syrup, 120ml bottle, dosed in ml.
    final itemNacalvitC = ItemRow(
      id: newMockId('item'),
      name: 'Nacalvit-C Syrup 120ml',
      pCategoryId: catMedical.id,
      sCategoryId: subSupplements.id,
      purchaseUnitId: unitBottle.id,
      packageUnitId: unitMl.id,
      packageQuantity: 120,
      dispenseUnitId: unitMl.id,
      purchaseStocks: 5,
      packageStocks: 600,
    );
    // 3M Micropore -- surgical tape, sold 6 rolls per box, used a roll at a
    // time.
    final itemMicropore = ItemRow(
      id: newMockId('item'),
      name: 'Micropore Surgical Tape',
      pCategoryId: catMedical.id,
      sCategoryId: subSupplies.id,
      purchaseUnitId: unitBox.id,
      packageUnitId: unitRoll.id,
      packageQuantity: 6,
      dispenseUnitId: unitRoll.id,
      purchaseStocks: 4,
      packageStocks: 24,
    );
    // Sentolin (salbutamol) nebules -- box of 20x5 = 100 ampoules, used one
    // ampoule per nebulization.
    final itemSalbutamol = ItemRow(
      id: newMockId('item'),
      name: 'Salbutamol Nebules 2.5mg/2.5ml',
      pCategoryId: catMedical.id,
      sCategoryId: subNebules.id,
      purchaseUnitId: unitBox.id,
      packageUnitId: unitAmpoule.id,
      packageQuantity: 100,
      dispenseUnitId: unitAmpoule.id,
      purchaseStocks: 3,
      packageStocks: 300,
    );

    items.addAll([
      itemUticare,
      itemRoyalCanin,
      itemEyeDrop,
      itemDryFood,
      itemBleach,
      itemMop,
      itemMilkThistle,
      itemDrontal,
      itemPapiLivwell,
      itemVetWrap,
      itemNacalvitC,
      itemMicropore,
      itemSalbutamol,
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

    // Uticare and the dry food are dated within the default 30-day
    // expiration_warning_days window (relative to seed time, not a fixed
    // calendar date) so Alerts & Notifications has something to show out of
    // the box -- see lib/services/expiry_alerts.dart.
    final soon = DateTime.now();
    addOpeningBatch(itemUticare, soon.add(const Duration(days: 12)));
    addOpeningBatch(itemRoyalCanin, DateTime(2027, 1, 1));
    addOpeningBatch(itemEyeDrop, DateTime(2027, 3, 15));
    addOpeningBatch(itemDryFood, soon.add(const Duration(days: 25)));
    addOpeningBatch(itemBleach, null);
    addOpeningBatch(itemMop, null);
    addOpeningBatch(itemMilkThistle, DateTime(2027, 6, 1));
    addOpeningBatch(itemDrontal, DateTime(2027, 9, 1));
    addOpeningBatch(itemPapiLivwell, DateTime(2027, 5, 1));
    addOpeningBatch(itemVetWrap, null);
    addOpeningBatch(itemNacalvitC, soon.add(const Duration(days: 20)));
    addOpeningBatch(itemMicropore, null);
    addOpeningBatch(itemSalbutamol, DateTime(2027, 4, 1));

    // Recent activity -- spread across "this week / last week / earlier this
    // month / last month" so the Staff Dashboard's Week/Month filter has
    // real week-over-week and month-over-month data to compare, instead of
    // everything landing on the single 2026-01-01 opening balance above.
    final now = DateTime.now();
    final manager = users[0];
    final staff = users[1];
    final donorAna = users[2];
    DateTime daysAgo(int n) => now.subtract(Duration(days: n));

    // Adds a restock purchase-item batch and grows the item's stock pools --
    // mirrors what PurchaseService.recordPurchase does for a whole-container
    // stock-in (see InventoryService/addOpeningBatch above for the same math).
    void restock(
      ItemRow item,
      PurchaseRow purchase,
      double qty, {
      DateTime? expiryDate,
      double unitCost = 0,
    }) {
      final canonicalQty =
          item.packageQuantity != null ? qty * item.packageQuantity! : qty;
      purchaseItems.add(PurchaseItemRow(
        purchaseId: purchase.id,
        itemId: item.id,
        qty: qty,
        unitCost: unitCost,
        expiryDate: expiryDate,
        qtyRemaining: canonicalQty,
      ));
      item.purchaseStocks += qty;
      if (item.packageQuantity != null) {
        item.packageStocks = (item.packageStocks ?? 0) + canonicalQty;
      }
    }

    // Logs a treatment's dispensed item and draws down stock FEFO-style.
    // Skips the pool draw-down when the dispense unit differs from the
    // package unit (e.g. Eye Vitamin Drop dispensed in drops but tracked in
    // ml) -- matches the app's documented non-deductible-dispense-unit
    // limitation, so seeded data doesn't fake tracking that doesn't exist.
    void dispense(
      ItemRow item,
      TreatmentRow treatment,
      double dispensedQty,
      String dispenseUnitId,
      DateTime date,
      String givenBy,
    ) {
      treatmentItems.add(TreatmentItemRow(
        id: newMockId('titem'),
        treatId: treatment.id,
        itemId: item.id,
        dispensedQty: dispensedQty,
        dispenseUnitId: dispenseUnitId,
        consumedDate: date,
        givenBy: givenBy,
        recordedDate: date,
        recordedByUserId: staff.userId,
      ));

      final isDeductible = item.packageQuantity == null
          ? dispenseUnitId == item.purchaseUnitId
          : dispenseUnitId == item.packageUnitId;
      if (!isDeductible) return;

      var remaining = dispensedQty;
      final batches = purchaseItems
          .where((p) => p.itemId == item.id && p.qtyRemaining > 0)
          .toList()
        ..sort((a, b) {
          if (a.expiryDate == null && b.expiryDate == null) return 0;
          if (a.expiryDate == null) return 1;
          if (b.expiryDate == null) return -1;
          return a.expiryDate!.compareTo(b.expiryDate!);
        });
      for (final batch in batches) {
        if (remaining <= 0) break;
        final take = remaining < batch.qtyRemaining ? remaining : batch.qtyRemaining;
        batch.qtyRemaining -= take;
        remaining -= take;
      }
      if (item.packageQuantity != null) {
        item.packageStocks =
            ((item.packageStocks ?? 0) - dispensedQty).clamp(0, double.infinity);
      } else {
        item.purchaseStocks = (item.purchaseStocks - dispensedQty).clamp(0, double.infinity);
      }
    }

    // Adds a donation-item batch and grows the item's stock pools --
    // mirrors [restock] above minus unit cost (donations have no cost).
    void donate(ItemRow item, DonationRow donation, double qty, {DateTime? expiryDate}) {
      final canonicalQty =
          item.packageQuantity != null ? qty * item.packageQuantity! : qty;
      donationItems.add(DonationItemRow(
        donId: donation.id,
        itemId: item.id,
        qty: qty,
        expiryDate: expiryDate,
        qtyRemaining: canonicalQty,
      ));
      item.purchaseStocks += qty;
      if (item.packageQuantity != null) {
        item.packageStocks = (item.packageStocks ?? 0) + canonicalQty;
      }
    }

    PurchaseRow addPurchase(int daysAgoN, double unitCostScale) {
      final date = daysAgo(daysAgoN);
      final purchase = PurchaseRow(
        id: newMockId('purchase'),
        suppId: 'supplier-petcare',
        recordedByUserId: staff.userId,
        recordedDate: date,
        receivedBy: staff.firstName,
        receivedDate: date,
      );
      purchases.add(purchase);
      return purchase;
    }

    // -- Purchases: 2 this week, 2 last week, 2 earlier this month, 3 last month.
    final p1 = addPurchase(1, 1);
    restock(itemUticare, p1, 3, expiryDate: daysAgo(-180), unitCost: 250);
    final p2 = addPurchase(5, 1);
    restock(itemEyeDrop, p2, 4, expiryDate: daysAgo(-300), unitCost: 180);
    final p3 = addPurchase(9, 1);
    restock(itemRoyalCanin, p3, 3, expiryDate: daysAgo(-300), unitCost: 320);
    final p4 = addPurchase(12, 1);
    restock(itemDryFood, p4, 2, expiryDate: daysAgo(-60), unitCost: 900);
    final p5 = addPurchase(16, 1);
    restock(itemBleach, p5, 3, unitCost: 85);
    final p6 = addPurchase(25, 1);
    restock(itemUticare, p6, 2, expiryDate: daysAgo(-150), unitCost: 250);
    final p7 = addPurchase(33, 1);
    restock(itemEyeDrop, p7, 3, expiryDate: daysAgo(-280), unitCost: 180);
    final p8 = addPurchase(45, 1);
    restock(itemRoyalCanin, p8, 2, expiryDate: daysAgo(-260), unitCost: 320);
    final p9 = addPurchase(52, 1);
    restock(itemDryFood, p9, 2, expiryDate: daysAgo(-30), unitCost: 900);
    final p10 = addPurchase(3, 1);
    restock(itemDrontal, p10, 5, expiryDate: daysAgo(-400), unitCost: 450);
    final p11 = addPurchase(14, 1);
    restock(itemMicropore, p11, 2, unitCost: 300);
    final p12 = addPurchase(29, 1);
    restock(itemSalbutamol, p12, 1, expiryDate: daysAgo(-500), unitCost: 1200);

    // -- Treatments: 4 this week, 3 last week, 2 earlier this month, 4 last month.
    TreatmentRow addTreatment(String name, String petId, int daysAgoN) {
      final date = daysAgo(daysAgoN);
      final treatment = TreatmentRow(
        id: newMockId('treatment'),
        name: name,
        petId: petId,
        recordedByUserId: staff.userId,
        recordedDate: date,
      );
      treatments.add(treatment);
      return treatment;
    }

    var t = addTreatment('Deworming', 'pet-whiskers', 1);
    dispense(itemUticare, t, 4, unitTablet.id, daysAgo(1), staff.firstName);
    t = addTreatment('Antibiotic Course', 'pet-luna', 2);
    dispense(itemRoyalCanin, t, 30, unitMl.id, daysAgo(2), staff.firstName);
    t = addTreatment('Wound Cleaning', 'pet-rocky', 4);
    dispense(itemEyeDrop, t, 10, unitDrop.id, daysAgo(4), staff.firstName);
    t = addTreatment('Follow-up Checkup', 'pet-whiskers', 6);
    dispense(itemDryFood, t, 0.5, unitKg.id, daysAgo(6), staff.firstName);

    t = addTreatment('Vitamin Supplement', 'pet-luna', 8);
    dispense(itemUticare, t, 2, unitTablet.id, daysAgo(8), staff.firstName);
    t = addTreatment('Antibiotic Course', 'pet-rocky', 10);
    dispense(itemRoyalCanin, t, 25, unitMl.id, daysAgo(10), staff.firstName);
    t = addTreatment('Deworming', 'pet-whiskers', 12);
    dispense(itemUticare, t, 3, unitTablet.id, daysAgo(12), staff.firstName);

    t = addTreatment('Wound Cleaning', 'pet-luna', 18);
    dispense(itemEyeDrop, t, 8, unitDrop.id, daysAgo(18), staff.firstName);
    t = addTreatment('Deworming', 'pet-rocky', 24);
    dispense(itemUticare, t, 4, unitTablet.id, daysAgo(24), staff.firstName);

    t = addTreatment('Antibiotic Course', 'pet-whiskers', 35);
    dispense(itemRoyalCanin, t, 20, unitMl.id, daysAgo(35), staff.firstName);
    t = addTreatment('Deworming', 'pet-luna', 42);
    dispense(itemUticare, t, 3, unitTablet.id, daysAgo(42), staff.firstName);
    t = addTreatment('Follow-up Checkup', 'pet-rocky', 48);
    dispense(itemDryFood, t, 0.5, unitKg.id, daysAgo(48), staff.firstName);
    t = addTreatment('Vitamin Supplement', 'pet-max', 55);
    dispense(itemUticare, t, 2, unitTablet.id, daysAgo(55), staff.firstName);

    t = addTreatment('Deworming', 'pet-max', 3);
    dispense(itemDrontal, t, 1, unitTablet.id, daysAgo(3), staff.firstName);
    t = addTreatment('Wound Dressing', 'pet-rocky', 5);
    dispense(itemVetWrap, t, 1, unitPcs.id, daysAgo(5), staff.firstName);
    t = addTreatment('Nebulization', 'pet-whiskers', 9);
    dispense(itemSalbutamol, t, 1, unitAmpoule.id, daysAgo(9), staff.firstName);
    t = addTreatment('Liver Support', 'pet-luna', 15);
    dispense(itemPapiLivwell, t, 5, unitMl.id, daysAgo(15), staff.firstName);
    t = addTreatment('Wound Dressing', 'pet-max', 30);
    dispense(itemMicropore, t, 1, unitRoll.id, daysAgo(30), staff.firstName);

    // -- Donations: 3 this week, 2 last week, 2 earlier this month, 2 last month.
    DonationRow addDonation(int daysAgoN, {String? donorId, String? donorName}) {
      final date = daysAgo(daysAgoN);
      final donation = DonationRow(
        id: newMockId('donation'),
        type: donorId != null ? 'drop_off' : 'walk_in',
        donorId: donorId,
        donorName: donorName,
        receivedBy: manager.firstName,
        receivedDate: date,
        recordedByUserId: staff.userId,
        recordedDate: date,
      );
      donations.add(donation);
      return donation;
    }

    var d = addDonation(0, donorId: donorAna.userId);
    donate(itemDryFood, d, 1, expiryDate: daysAgo(-60));
    d = addDonation(2, donorName: 'Grace Villanueva');
    donate(itemBleach, d, 2);
    d = addDonation(5, donorId: donorAna.userId);
    donate(itemUticare, d, 1, expiryDate: daysAgo(-180));

    d = addDonation(8, donorName: 'Roberto Cruz');
    donate(itemRoyalCanin, d, 2, expiryDate: daysAgo(-300));
    d = addDonation(11, donorId: donorAna.userId);
    donate(itemEyeDrop, d, 1, expiryDate: daysAgo(-300));

    d = addDonation(19, donorName: 'Grace Villanueva');
    donate(itemDryFood, d, 2, expiryDate: daysAgo(-45));
    d = addDonation(27, donorId: donorAna.userId);
    donate(itemUticare, d, 2, expiryDate: daysAgo(-160));

    d = addDonation(38, donorName: 'Roberto Cruz');
    donate(itemBleach, d, 1);
    d = addDonation(55, donorId: donorAna.userId);
    donate(itemRoyalCanin, d, 1, expiryDate: daysAgo(-250));

    d = addDonation(3, donorName: 'Liza Fernandez');
    donate(itemMilkThistle, d, 2, expiryDate: daysAgo(-500));
    d = addDonation(13, donorId: donorAna.userId);
    donate(itemNacalvitC, d, 1, expiryDate: daysAgo(-300));
    d = addDonation(22, donorName: 'Liza Fernandez');
    donate(itemVetWrap, d, 5);

    // -- Submissions: 4 pending (mixed scheduling), 2 completed for history.
    submissions.addAll([
      SubmissionRow(
        id: newMockId('sub'),
        donorId: donorAna.userId,
        status: 'pending',
        dateSub: daysAgo(2),
        schedDate: daysAgo(-3),
      ),
      SubmissionRow(
        id: newMockId('sub'),
        donorId: donorAna.userId,
        status: 'pending',
        dateSub: daysAgo(6),
        schedDate: daysAgo(1), // past its scheduled date -- overdue
      ),
      SubmissionRow(
        id: newMockId('sub'),
        donorId: donorAna.userId,
        status: 'pending',
        dateSub: daysAgo(1),
      ),
      SubmissionRow(
        id: newMockId('sub'),
        donorId: donorAna.userId,
        status: 'pending',
        dateSub: daysAgo(9),
        schedDate: daysAgo(-2),
      ),
      SubmissionRow(
        id: newMockId('sub'),
        donorId: donorAna.userId,
        updatedByUserId: staff.userId,
        status: 'completed',
        dateSub: daysAgo(20),
        schedDate: daysAgo(18),
        dateReceived: daysAgo(18),
      ),
      SubmissionRow(
        id: newMockId('sub'),
        donorId: donorAna.userId,
        updatedByUserId: staff.userId,
        status: 'completed',
        dateSub: daysAgo(40),
        schedDate: daysAgo(38),
        dateReceived: daysAgo(38),
      ),
    ]);
  }
}
