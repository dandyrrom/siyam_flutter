import '../mock/mock_database.dart';
import '../models/inventory_item.dart';
import '../models/stock_movement.dart';
import '../models/stock_out.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'supabase/supabase_inventory_service.dart';

/// Data-access interface for inventory items and stock movements. The factory
/// resolves to the mock or Supabase implementation based on [kUseMock], chosen
/// at build time.
abstract interface class InventoryService {
  factory InventoryService() =>
      kUseMock ? MockInventoryService() : SupabaseInventoryService();

  Future<List<InventoryItem>> fetchItems();
  Future<InventoryItem?> fetchItem(String itemId);
  Future<InventoryItem> createItem({
    required String itemName,
    required String pCategoryId,
    required String purchaseUnitId,
    String? sCategoryId,
    String? packageUnitId,
    double? packageQuantity,
    String? dispenseUnitId,
    double initialQty,
  });
  Future<InventoryItem> updateDetails({
    required String itemId,
    String? itemName,
    String? pCategoryId,
    String? sCategoryId,
    String? purchaseUnitId,
  });
  Future<InventoryItem> adjustStock({
    required String itemId,
    required double delta,
  });
  Future<InventoryItem> deductPackageStock({
    required String itemId,
    required double delta,
  });
  Future<InventoryItem> stockOut({
    required String itemId,
    required double qty,
    required StockOutReason reason,
    required String recordedByUserId,
  });
  Future<void> deleteItem(String itemId);
  Future<List<StockMovement>> fetchStockHistory(String itemId);
}

/// In-memory equivalent of the old public.item access layer. Every fetch
/// resolves the item's category/unit FKs into display names via
/// MockDatabase's lookup lists, denormalized onto InventoryItem.
class MockInventoryService implements InventoryService {
  final MockDatabase _db = MockDatabase.instance;

  InventoryItem _toInventoryItem(ItemRow row) {
    final hasPurchaseHistory = _db.purchaseItems.any((p) => p.itemId == row.id);
    final hasDonationHistory = _db.donationItems.any((d) => d.itemId == row.id);
    final lifetimeStockOutQty = _db.stockOuts
        .where((s) => s.itemId == row.id)
        .fold(0.0, (sum, s) => sum + s.qty);
    final lifetimeTreatmentQty = _db.treatmentItems
        .where((t) => t.itemId == row.id)
        .fold(0.0, (sum, t) => sum + t.dispensedQty);
    final pCategory =
        firstWhereOrNull(_db.primaryCategories, (c) => c.id == row.pCategoryId);
    final sCategory = row.sCategoryId == null
        ? null
        : firstWhereOrNull(_db.subcategories, (c) => c.id == row.sCategoryId);
    final purchaseUnit =
        firstWhereOrNull(_db.units, (u) => u.id == row.purchaseUnitId);
    final packageUnit = row.packageUnitId == null
        ? null
        : firstWhereOrNull(_db.units, (u) => u.id == row.packageUnitId);
    final dispenseUnit = row.dispenseUnitId == null
        ? null
        : firstWhereOrNull(_db.units, (u) => u.id == row.dispenseUnitId);

    return InventoryItem(
      itemId: row.id,
      itemName: row.name,
      pCategoryId: row.pCategoryId,
      pCategoryName: pCategory?.type ?? 'Unknown category',
      sCategoryId: row.sCategoryId,
      sCategoryName: sCategory?.type,
      purchaseUnitId: row.purchaseUnitId,
      purchaseUnitAbbr: purchaseUnit?.abbrName ?? '',
      packageUnitId: row.packageUnitId,
      packageUnitAbbr: packageUnit?.abbrName,
      packageQuantity: row.packageQuantity,
      dispenseUnitId: row.dispenseUnitId,
      dispenseUnitAbbr: dispenseUnit?.abbrName,
      stockQty: row.purchaseStocks,
      packageStockQty: row.packageStocks,
      hasPurchaseHistory: hasPurchaseHistory,
      hasDonationHistory: hasDonationHistory,
      lifetimeStockOutQty: lifetimeStockOutQty,
      lifetimeTreatmentQty: lifetimeTreatmentQty,
    );
  }

  ItemRow _requireRow(String itemId) {
    final row = firstWhereOrNull(_db.items, (i) => i.id == itemId);
    if (row == null) throw Exception('Item not found');
    return row;
  }

  String _userName(String userId) {
    final user = firstWhereOrNull(_db.users, (u) => u.userId == userId);
    return user?.fullName ?? 'Unknown user';
  }

  String _stockOutReasonLabel(StockOutReason reason) {
    switch (reason) {
      case StockOutReason.waste:
        return 'Waste';
      case StockOutReason.expired:
        return 'Expired';
      case StockOutReason.adjustment:
        return 'Adjustment';
    }
  }

  @override
  Future<List<InventoryItem>> fetchItems() async {
    final list = _db.items.map(_toInventoryItem).toList();
    list.sort((a, b) => a.itemName.compareTo(b.itemName));
    return list;
  }

  @override
  Future<InventoryItem?> fetchItem(String itemId) async {
    final row = firstWhereOrNull(_db.items, (i) => i.id == itemId);
    return row == null ? null : _toInventoryItem(row);
  }

  @override
  Future<InventoryItem> createItem({
    required String itemName,
    required String pCategoryId,
    required String purchaseUnitId,
    String? sCategoryId,
    String? packageUnitId,
    double? packageQuantity,
    String? dispenseUnitId,
    double initialQty = 0,
  }) async {
    final row = ItemRow(
      id: newMockId('item'),
      name: itemName,
      pCategoryId: pCategoryId,
      sCategoryId: sCategoryId,
      purchaseUnitId: purchaseUnitId,
      packageUnitId: packageUnitId,
      packageQuantity: packageQuantity,
      dispenseUnitId: dispenseUnitId,
      purchaseStocks: initialQty,
      packageStocks: packageQuantity == null ? null : initialQty * packageQuantity,
    );
    _db.items.add(row);
    DataChangeBus.instance.ping();
    return _toInventoryItem(row);
  }

  @override
  Future<InventoryItem> updateDetails({
    required String itemId,
    String? itemName,
    String? pCategoryId,
    String? sCategoryId,
    String? purchaseUnitId,
  }) async {
    final row = _requireRow(itemId);
    if (itemName != null) row.name = itemName;
    if (pCategoryId != null && pCategoryId != row.pCategoryId) {
      row.pCategoryId = pCategoryId;
      // The old subcategory belongs to the previous primary category and
      // may no longer apply -- clear it rather than leave a stale FK.
      row.sCategoryId = null;
    }
    if (sCategoryId != null) row.sCategoryId = sCategoryId;
    if (purchaseUnitId != null) row.purchaseUnitId = purchaseUnitId;
    DataChangeBus.instance.ping();
    return _toInventoryItem(row);
  }

  /// Adjusts purchase_stocks by [delta] (positive = stock in, negative =
  /// stock out) -- whole-container events (purchase, donation, waste,
  /// expired, adjustment). Keeps package_stocks in sync by the same
  /// proportion (delta * package_quantity) so the two pools don't drift.
  @override
  Future<InventoryItem> adjustStock({
    required String itemId,
    required double delta,
  }) async {
    final row = _requireRow(itemId);
    final next = row.purchaseStocks + delta;
    if (next < 0) {
      throw Exception(
          'Not enough stock: only ${formatQty(row.purchaseStocks)} left');
    }
    row.purchaseStocks = next;
    if (row.packageQuantity != null) {
      final currentPackage = row.packageStocks ?? (row.purchaseStocks - delta) * row.packageQuantity!;
      row.packageStocks = currentPackage + delta * row.packageQuantity!;
    }
    DataChangeBus.instance.ping();
    return _toInventoryItem(row);
  }

  /// Deducts treatment usage (already in package_unit terms) from
  /// package_stocks only -- purchase_stocks (whole containers) is untouched,
  /// since using part of a bottle doesn't remove the bottle from inventory.
  @override
  Future<InventoryItem> deductPackageStock({
    required String itemId,
    required double delta,
  }) async {
    final row = _requireRow(itemId);
    final current = row.packageStocks ??
        (row.packageQuantity == null ? 0 : row.purchaseStocks * row.packageQuantity!);
    final next = current + delta;
    if (next < 0) {
      throw Exception('Not enough stock: only ${formatQty(current)} left');
    }
    row.packageStocks = next;
    DataChangeBus.instance.ping();
    return _toInventoryItem(row);
  }

  /// Records a non-treatment stock-out (waste/expired/adjustment) and
  /// decrements purchase_stocks (and package_stocks in lockstep via
  /// [adjustStock]). Purchase-unit granularity -- these are whole-package
  /// events.
  @override
  Future<InventoryItem> stockOut({
    required String itemId,
    required double qty,
    required StockOutReason reason,
    required String recordedByUserId,
  }) async {
    _db.stockOuts.add(StockOut(
      id: newMockId('stockout'),
      itemId: itemId,
      qty: qty,
      reason: reason,
      recordedDate: DateTime.now(),
      recordedByUserId: recordedByUserId,
    ));
    return adjustStock(itemId: itemId, delta: -qty);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    _db.items.removeWhere((i) => i.id == itemId);
    DataChangeBus.instance.ping();
  }

  /// Unified stock movement history for one item -- merges every table that
  /// ever changes purchase_stocks (purchase_item, donation_item,
  /// treatment_item, stock_out), most recent first.
  @override
  Future<List<StockMovement>> fetchStockHistory(String itemId) async {
    final item = await fetchItem(itemId);
    final purchaseUnitAbbr = item?.purchaseUnitAbbr ?? '';
    final movements = <StockMovement>[];

    for (final row in _db.purchaseItems.where((p) => p.itemId == itemId)) {
      final purchase =
          firstWhereOrNull(_db.purchases, (p) => p.id == row.purchaseId);
      if (purchase == null) continue;
      movements.add(StockMovement(
        id: '${purchase.id}-${row.itemId}',
        date: purchase.receivedDate,
        direction: StockDirection.stockIn,
        qty: row.qty,
        unitAbbr: purchaseUnitAbbr,
        typeLabel: 'Purchased',
        recordedByName: _userName(purchase.recordedByUserId),
      ));
    }

    for (final row in _db.donationItems.where((d) => d.itemId == itemId)) {
      final donation = firstWhereOrNull(_db.donations, (d) => d.id == row.donId);
      if (donation == null) continue;
      movements.add(StockMovement(
        id: '${donation.id}-${row.itemId}',
        date: donation.receivedDate,
        direction: StockDirection.stockIn,
        qty: row.qty,
        unitAbbr: purchaseUnitAbbr,
        typeLabel: 'Donated',
        recordedByName: _userName(donation.recordedByUserId),
      ));
    }

    for (final row in _db.treatmentItems.where((t) => t.itemId == itemId)) {
      final treatment =
          firstWhereOrNull(_db.treatments, (t) => t.id == row.treatId);
      final unit =
          firstWhereOrNull(_db.units, (u) => u.id == row.dispenseUnitId);
      movements.add(StockMovement(
        id: '${row.treatId}-${row.itemId}',
        date: row.consumedDate,
        direction: StockDirection.stockOut,
        qty: row.dispensedQty,
        unitAbbr: unit?.abbrName ?? purchaseUnitAbbr,
        typeLabel: 'Treatment',
        treatmentId: row.treatId,
        treatmentName: treatment?.name ?? 'Unknown treatment',
        recordedByName: _userName(row.recordedByUserId),
      ));
    }

    for (final row in _db.stockOuts.where((s) => s.itemId == itemId)) {
      movements.add(StockMovement(
        id: row.id,
        date: row.recordedDate,
        direction: StockDirection.stockOut,
        qty: row.qty,
        unitAbbr: purchaseUnitAbbr,
        typeLabel: _stockOutReasonLabel(row.reason),
        recordedByName: _userName(row.recordedByUserId),
      ));
    }

    movements.sort((a, b) => b.date.compareTo(a.date));
    return movements;
  }
}
