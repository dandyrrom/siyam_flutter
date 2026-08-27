import '../mock/mock_database.dart';
import '../models/qty_unit.dart';
import '../models/supplier.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'inventory_service.dart';
import 'supabase/supabase_supplier_service.dart';

// ============================================================================
// SUPPLIER SERVICE
// ============================================================================
//
// Factory resolves to mock or Supabase based on [kUseMock].
// ============================================================================

abstract interface class SupplierService {
  factory SupplierService() =>
      kUseMock ? MockSupplierService() : SupabaseSupplierService();

  Future<List<Supplier>> fetchSuppliers();

  Future<Supplier> createSupplier({
    required String suppName,
    String? contactNum,
    String? contactTel,
    String? address,
  });

  Future<Supplier> updateSupplier({
    required String suppId,
    required String suppName,
    String? contactNum,
    String? contactTel,
    String? address,
  });

  Future<void> deleteSupplier(String suppId);

  Future<List<PurchaseOrder>> fetchAllPurchaseOrders();

  Future<List<PurchaseOrder>> fetchPurchaseOrdersForSupplier(
    String suppId,
  );

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

/// In-memory equivalent of public.supplier / purchase / purchase_item.
class MockSupplierService implements SupplierService {
  final MockDatabase _db = MockDatabase.instance;
  final InventoryService _inventoryService = MockInventoryService();

  String _cleanSupplierName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _supplierNameKey(String value) {
    return _cleanSupplierName(value).toLowerCase();
  }

  void _ensureUniqueSupplierName(
    String suppName, {
    String? excludeSuppId,
  }) {
    final targetKey = _supplierNameKey(suppName);

    for (final supplier in _db.suppliers) {
      if (supplier.suppId == excludeSuppId) continue;
      if (_supplierNameKey(supplier.suppName) == targetKey) {
        throw Exception('A supplier with this name already exists.');
      }
    }
  }

  String _userName(String userId) {
    final user = firstWhereOrNull(_db.users, (u) => u.userId == userId);
    return user?.fullName ?? 'Unknown user';
  }

  PurchaseOrder _toPurchaseOrder(PurchaseRow row) {
    final supplier =
        firstWhereOrNull(_db.suppliers, (s) => s.suppId == row.suppId);
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
    list.sort(
      (a, b) => a.suppName.toLowerCase().compareTo(b.suppName.toLowerCase()),
    );
    return list;
  }

  @override
  Future<Supplier> createSupplier({
    required String suppName,
    String? contactNum,
    String? contactTel,
    String? address,
  }) async {
    final cleanName = _cleanSupplierName(suppName);
    _ensureUniqueSupplierName(cleanName);

    final supplier = Supplier(
      suppId: newMockId('supplier'),
      suppName: cleanName,
      contactNum: contactNum,
      contactTel: contactTel,
      address: address,
    );
    _db.suppliers.add(supplier);
    DataChangeBus.instance.ping();
    return supplier;
  }

  @override
  Future<Supplier> updateSupplier({
    required String suppId,
    required String suppName,
    String? contactNum,
    String? contactTel,
    String? address,
  }) async {
    final index = _db.suppliers.indexWhere((s) => s.suppId == suppId);
    if (index == -1) throw Exception('Supplier not found');

    final cleanName = _cleanSupplierName(suppName);
    _ensureUniqueSupplierName(cleanName, excludeSuppId: suppId);

    final updated = Supplier(
      suppId: suppId,
      suppName: cleanName,
      contactNum: contactNum,
      contactTel: contactTel,
      address: address,
    );
    _db.suppliers[index] = updated;
    DataChangeBus.instance.ping();
    return updated;
  }

  @override
  Future<void> deleteSupplier(String suppId) async {
    _db.suppliers.removeWhere((s) => s.suppId == suppId);
    DataChangeBus.instance.ping();
  }

  @override
  Future<List<PurchaseOrder>> fetchAllPurchaseOrders() async {
    final list = _db.purchases.map(_toPurchaseOrder).toList();
    list.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    return list;
  }

  @override
  Future<List<PurchaseOrder>> fetchPurchaseOrdersForSupplier(
    String suppId,
  ) async {
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

  @override
  Future<List<OrderSpendEntry>> fetchOrderSpendEntries() async {
    final result = <OrderSpendEntry>[];
    for (final row in _db.purchaseItems) {
      final purchase =
          firstWhereOrNull(_db.purchases, (p) => p.id == row.purchaseId);
      if (purchase == null) continue;
      result.add(OrderSpendEntry(
        purDate: purchase.receivedDate,
        amount: row.qty * row.unitCost,
      ));
    }
    return result;
  }

  @override
  Future<PurchaseOrder> createPurchaseOrder({
    required String suppId,
    required String recordedByUserId,
    required String receivedBy,
    required List<OrderItemInput> items,
    DateTime? receivedDate,
  }) async {
    final actualReceivedDate = receivedDate ?? DateTime.now();
    final row = PurchaseRow(
      id: newMockId('purchase'),
      suppId: suppId,
      recordedByUserId: recordedByUserId,
      recordedDate: DateTime.now(),
      receivedBy: receivedBy,
      receivedDate: actualReceivedDate,
    );
    _db.purchases.add(row);

    for (final item in items) {
      if (item.qty <= 0) continue;

      final invItem = await _inventoryService.fetchItem(item.itemId);
      final packageQuantity = invItem?.packageQuantity;
      final qtyRemaining = packageQuantity == null
          ? item.qty
          : (item.qtyUnit == QtyUnit.packageUnit
              ? item.qty
              : item.qty * packageQuantity);

      _db.purchaseItems.add(PurchaseItemRow(
        purchaseId: row.id,
        itemId: item.itemId,
        qty: item.qty,
        qtyUnit: item.qtyUnit,
        unitCost: item.unitCost,
        expiryDate: item.expiryDate,
        qtyRemaining: qtyRemaining,
      ));

      await _inventoryService.stockIn(
        itemId: item.itemId,
        qty: item.qty,
        qtyUnit: item.qtyUnit,
      );
    }

    DataChangeBus.instance.ping();
    return _toPurchaseOrder(row);
  }
}
