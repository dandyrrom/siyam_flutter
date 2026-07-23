import '../mock/mock_database.dart';
import '../models/supplier.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'inventory_service.dart';
import 'supabase/supabase_supplier_service.dart';

/// Data-access interface for suppliers and purchase orders. The factory
/// resolves to the mock or Supabase implementation based on [kUseMock], chosen
/// at build time.
abstract interface class SupplierService {
  factory SupplierService() =>
      kUseMock ? MockSupplierService() : SupabaseSupplierService();

  Future<List<Supplier>> fetchSuppliers();
  Future<Supplier> createSupplier({
    required String suppName,
    String? contactNum,
    String? address,
  });
  Future<List<PurchaseOrder>> fetchAllPurchaseOrders();
  Future<List<PurchaseOrder>> fetchPurchaseOrdersForSupplier(String suppId);
  Future<PurchaseOrder?> fetchPurchaseOrder(String purId);
  Future<List<OrderLineItem>> fetchOrderItems(String purId);
  Future<List<OrderSpendEntry>> fetchOrderSpendEntries();
  Future<PurchaseOrder> createPurchaseOrder({
    required String suppId,
    required String recordedByUserId,
    required String receivedBy,
    required List<OrderItemInput> items,
    DateTime? receivedDate,
  });
}

/// In-memory equivalent of the old public.supplier / purchase / purchase_item
/// access layer.
///
/// Creating a purchase order also increments stock for each item ordered,
/// via [InventoryService] -- the same "receiving increases stock" pattern
/// used when a donation is approved.
class MockSupplierService implements SupplierService {
  final MockDatabase _db = MockDatabase.instance;
  final InventoryService _inventoryService = MockInventoryService();

  String _userName(String userId) {
    final user = firstWhereOrNull(_db.users, (u) => u.userId == userId);
    return user?.fullName ?? 'Unknown user';
  }

  PurchaseOrder _toPurchaseOrder(PurchaseRow row) {
    final supplier = firstWhereOrNull(_db.suppliers, (s) => s.suppId == row.suppId);
    return PurchaseOrder(
      purId: row.id,
      suppId: row.suppId,
      suppName: supplier?.suppName ?? 'Unknown supplier',
      recordedByUserId: row.recordedByUserId,
      buyerName: _userName(row.recordedByUserId),
      receivedBy: row.receivedBy,
      receivedDate: row.receivedDate,
    );
  }

  @override
  Future<List<Supplier>> fetchSuppliers() async {
    final list = List<Supplier>.from(_db.suppliers);
    list.sort((a, b) => a.suppName.compareTo(b.suppName));
    return list;
  }

  @override
  Future<Supplier> createSupplier({
    required String suppName,
    String? contactNum,
    String? address,
  }) async {
    final supplier = Supplier(
      suppId: newMockId('supplier'),
      suppName: suppName,
      contactNum: contactNum,
      address: address,
    );
    _db.suppliers.add(supplier);
    DataChangeBus.instance.ping();
    return supplier;
  }

  /// All purchase orders across every supplier, most recent first.
  @override
  Future<List<PurchaseOrder>> fetchAllPurchaseOrders() async {
    final list = _db.purchases.map(_toPurchaseOrder).toList();
    list.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    return list;
  }

  @override
  Future<List<PurchaseOrder>> fetchPurchaseOrdersForSupplier(String suppId) async {
    final list = _db.purchases
        .where((p) => p.suppId == suppId)
        .map(_toPurchaseOrder)
        .toList();
    list.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    return list;
  }

  @override
  Future<PurchaseOrder?> fetchPurchaseOrder(String purId) async {
    final row = firstWhereOrNull(_db.purchases, (p) => p.id == purId);
    return row == null ? null : _toPurchaseOrder(row);
  }

  @override
  Future<List<OrderLineItem>> fetchOrderItems(String purId) async {
    final rows = _db.purchaseItems.where((oi) => oi.purchaseId == purId);
    final result = <OrderLineItem>[];
    for (final row in rows) {
      final item = await _inventoryService.fetchItem(row.itemId);
      result.add(OrderLineItem(
        itemId: row.itemId,
        itemName: item?.itemName ?? 'Unknown item',
        itemUom: item?.itemUom ?? '',
        qty: row.qty,
        unitCost: row.unitCost,
      ));
    }
    return result;
  }

  /// Spend per purchase_item row, with its parent purchase's date -- used
  /// to bucket total purchase spend by month on the Reports page.
  @override
  Future<List<OrderSpendEntry>> fetchOrderSpendEntries() async {
    final result = <OrderSpendEntry>[];
    for (final row in _db.purchaseItems) {
      final purchase = firstWhereOrNull(_db.purchases, (p) => p.id == row.purchaseId);
      if (purchase == null) continue;
      result.add(OrderSpendEntry(
        purDate: purchase.receivedDate,
        amount: row.qty * row.unitCost,
      ));
    }
    return result;
  }

  /// Creates the purchase, logs each item into purchase_item, and increments
  /// stock for each item received. [recordedByUserId] is the signed-in user
  /// entering the transaction; [receivedBy] is free text for who physically
  /// received the goods. [receivedDate] defaults to now() if omitted.
  @override
  Future<PurchaseOrder> createPurchaseOrder({
    required String suppId,
    required String recordedByUserId,
    required String receivedBy,
    required List<OrderItemInput> items,
    DateTime? receivedDate,
  }) async {
    final row = PurchaseRow(
      id: newMockId('purchase'),
      suppId: suppId,
      recordedByUserId: recordedByUserId,
      recordedDate: DateTime.now(),
      receivedBy: receivedBy,
      receivedDate: receivedDate ?? DateTime.now(),
    );
    _db.purchases.add(row);

    for (final item in items) {
      if (item.qty <= 0) continue;
      _db.purchaseItems.add(PurchaseItemRow(
        purchaseId: row.id,
        itemId: item.itemId,
        qty: item.qty,
        unitCost: item.unitCost,
      ));
      await _inventoryService.adjustStock(itemId: item.itemId, delta: item.qty);
    }

    DataChangeBus.instance.ping();
    return _toPurchaseOrder(row);
  }
}
