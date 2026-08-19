import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/qty_unit.dart';
import '../../models/supplier.dart';
import '../../state/data_bus.dart';
import '../inventory_service.dart';
import '../supplier_service.dart';

// ============================================================================
// SUPABASE SUPPLIER SERVICE
// ============================================================================
//
// REAL DATABASE FLOW:
//
// SUPPLIER
//
// PURCHASE
//   ↓
// PURCHASE_ITEM
//   ↓
// INVENTORY_BATCH
//   ↓
// BATCH_TRANSACTION_LOG (RECEIVE)
//
// The purchase/batch logic below preserves the working batch-based inventory
// implementation already added to SIYAM.
// ============================================================================

class SupabaseSupplierService implements SupplierService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  // ==========================================================================
  // SUPPLIER NAME NORMALIZATION
  // ==========================================================================
  //
  // These names are considered duplicates:
  //
  // Mercury Drug
  // mercury drug
  // MERCURY DRUG
  // Mercury     Drug
  //
  // Extra spaces are also removed before saving.
  // ==========================================================================

  String _cleanSupplierName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _supplierNameKey(String value) {
    return _cleanSupplierName(value).toLowerCase();
  }

  // ==========================================================================
  // DUPLICATE SUPPLIER CHECK
  // ==========================================================================
  //
  // Performed in the actual Supabase service, not only in the UI.
  //
  // [excludeSuppId] allows an existing supplier to retain its own name when
  // it is being edited.
  // ==========================================================================

  Future<void> _ensureUniqueSupplierName(
    String suppName, {
    String? excludeSuppId,
  }) async {
    final rows = await _client
        .from('supplier')
        .select('id, name');

    final targetKey = _supplierNameKey(suppName);

    for (final row in rows) {
      final supplierId = row['id'] as String;

      if (supplierId == excludeSuppId) {
        continue;
      }

      final existingName = (row['name'] as String?) ?? '';

      if (_supplierNameKey(existingName) == targetKey) {
        throw Exception(
          'A supplier with this name already exists.',
        );
      }
    }
  }

  // ==========================================================================
  // MAPPERS
  // ==========================================================================

  Supplier _mapSupplier(Map<String, dynamic> r) => Supplier(
        suppId: r['id'] as String,
        suppName: (r['name'] as String?) ?? '',
        contactNum: r['contactnum'] as String?,
        contactTel: r['contacttel'] as String?,
        address: r['address'] as String?,
      );

  Future<Map<String, String>> _userNameMap() async {
    final rows = await _client
        .from('users')
        .select('id, fname, lname');

    return {
      for (final r in rows)
        r['id'] as String:
            '${(r['fname'] as String?) ?? ''} ${(r['lname'] as String?) ?? ''}'
                .trim(),
    };
  }

  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client
        .from('units')
        .select('id, abbr_name');

    return {
      for (final r in rows)
        r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  PurchaseOrder _mapOrder(
    Map<String, dynamic> r,
    Map<String, String> users,
  ) {
    final supplier = r['supplier'] as Map<String, dynamic>?;
    final recordedBy = r['recordedby'] as String;

    return PurchaseOrder(
      purId: r['id'] as String,
      suppId: r['suppid'] as String,
      suppName: supplier?['name'] as String? ?? 'Unknown supplier',
      recordedByUserId: recordedBy,
      buyerName: users[recordedBy] ?? 'Unknown user',
      receivedBy: (r['receivedby'] as String?) ?? '',
      receivedDate: DateTime.parse(r['receiveddate'] as String),
    );
  }

  static const String _orderColumns =
      'id, suppid, recordedby, receivedby, receiveddate, supplier(name)';

  // ==========================================================================
  // FETCH SUPPLIERS
  // ==========================================================================

  @override
  Future<List<Supplier>> fetchSuppliers() async {
    final rows = await _client
        .from('supplier')
        .select('id, name, contactnum, contacttel, address')
        .order('name');

    return rows.map((r) => _mapSupplier(r)).toList();
  }

  // ==========================================================================
  // CREATE SUPPLIER
  // ==========================================================================

  @override
  Future<Supplier> createSupplier({
    required String suppName,
    String? contactNum,
    String? contactTel,
    String? address,
  }) async {
    final cleanName = _cleanSupplierName(suppName);

    await _ensureUniqueSupplierName(cleanName);

    final row = await _client
        .from('supplier')
        .insert({
          'name': cleanName,
          'contactnum': contactNum,
          'contacttel': contactTel,
          'address': address,
        })
        .select('id, name, contactnum, contacttel, address')
        .single();

    DataChangeBus.instance.ping();

    return _mapSupplier(row);
  }

  // ==========================================================================
  // UPDATE SUPPLIER
  // ==========================================================================

  @override
  Future<Supplier> updateSupplier({
    required String suppId,
    required String suppName,
    String? contactNum,
    String? contactTel,
    String? address,
  }) async {
    final cleanName = _cleanSupplierName(suppName);

    await _ensureUniqueSupplierName(
      cleanName,
      excludeSuppId: suppId,
    );

    final row = await _client
        .from('supplier')
        .update({
          'name': cleanName,
          'contactnum': contactNum,
          'contacttel': contactTel,
          'address': address,
        })
        .eq('id', suppId)
        .select('id, name, contactnum, contacttel, address')
        .single();

    DataChangeBus.instance.ping();

    return _mapSupplier(row);
  }

  // ==========================================================================
  // DELETE SUPPLIER
  // ==========================================================================

  @override
  Future<void> deleteSupplier(String suppId) async {
    await _client
        .from('supplier')
        .delete()
        .eq('id', suppId);

    DataChangeBus.instance.ping();
  }

  // ==========================================================================
  // FETCH ALL PURCHASE ORDERS
  // ==========================================================================

  @override
  Future<List<PurchaseOrder>> fetchAllPurchaseOrders() async {
    final users = await _userNameMap();

    final rows = await _client
        .from('purchase')
        .select(_orderColumns)
        .order('receiveddate', ascending: false);

    return rows.map((r) => _mapOrder(r, users)).toList();
  }

  // ==========================================================================
  // FETCH SUPPLIER PURCHASE ORDERS
  // ==========================================================================

  @override
  Future<List<PurchaseOrder>> fetchPurchaseOrdersForSupplier(
    String suppId,
  ) async {
    final users = await _userNameMap();

    final rows = await _client
        .from('purchase')
        .select(_orderColumns)
        .eq('suppid', suppId)
        .order('receiveddate', ascending: false);

    return rows.map((r) => _mapOrder(r, users)).toList();
  }

  // ==========================================================================
  // FETCH PURCHASE ORDER
  // ==========================================================================

  @override
  Future<PurchaseOrder?> fetchPurchaseOrder(String purId) async {
    final row = await _client
        .from('purchase')
        .select(_orderColumns)
        .eq('id', purId)
        .maybeSingle();

    if (row == null) return null;

    final users = await _userNameMap();

    return _mapOrder(row, users);
  }

  // ==========================================================================
  // FETCH PURCHASE ORDER ITEMS
  // ==========================================================================

  @override
  Future<List<OrderLineItem>> fetchOrderItems(String purId) async {
    final units = await _unitAbbrMap();

    final rows = await _client
        .from('purchase_item')
        .select(
          'itemid, qty, purchase_unit_cost, item(name, purchase_unit)',
        )
        .eq('purchaseid', purId);

    return rows.map((r) {
      final item = r['item'] as Map<String, dynamic>?;
      final purchaseUnit = item?['purchase_unit'] as String?;

      return OrderLineItem(
        itemId: r['itemid'] as String,
        itemName: item?['name'] as String? ?? 'Unknown item',
        itemUom: purchaseUnit == null ? '' : (units[purchaseUnit] ?? ''),
        qty: _d(r['qty']),
        unitCost: _d(r['purchase_unit_cost']),
      );
    }).toList();
  }

  // ==========================================================================
  // PURCHASE SPEND
  // ==========================================================================

  @override
  Future<List<OrderSpendEntry>> fetchOrderSpendEntries() async {
    final rows = await _client
        .from('purchase_item')
        .select(
          'qty, purchase_unit_cost, purchase(receiveddate)',
        );

    final result = <OrderSpendEntry>[];

    for (final r in rows) {
      final purchase = r['purchase'] as Map<String, dynamic>?;

      if (purchase == null) continue;

      result.add(
        OrderSpendEntry(
          purDate: DateTime.parse(
            purchase['receiveddate'] as String,
          ),
          amount: _d(r['qty']) * _d(r['purchase_unit_cost']),
        ),
      );
    }

    return result;
  }

  // ==========================================================================
  // CREATE PURCHASE ORDER
  // ==========================================================================
  //
  // IMPORTANT:
  //
  // This is the existing batch-based stock-in flow.
  //
  // PURCHASE
  //    ↓
  // PURCHASE_ITEM
  //    ↓
  // INVENTORY_BATCH
  //    ↓
  // BATCH_TRANSACTION_LOG / RECEIVE
  //
  // Do not move expiry or remaining stock back into purchase_item.
  // ==========================================================================

  @override
  Future<PurchaseOrder> createPurchaseOrder({
    required String suppId,
    required String recordedByUserId,
    required String receivedBy,
    required List<OrderItemInput> items,
    DateTime? receivedDate,
  }) async {
    final actualReceivedDate = receivedDate ?? DateTime.now();

    final insert = <String, dynamic>{
      'suppid': suppId,
      'recordedby': recordedByUserId,
      'receivedby': receivedBy,
      'receiveddate': actualReceivedDate.toUtc().toIso8601String(),
    };

    final purchase = await _client
        .from('purchase')
        .insert(insert)
        .select('id')
        .single();

    final purId = purchase['id'] as String;

    for (final item in items) {
      if (item.qty <= 0) continue;

      final invItem = await _inventoryService.fetchItem(item.itemId);

      final packageQuantity = invItem?.packageQuantity;

      // ======================================================================
      // CANONICAL BATCH QUANTITY
      // ======================================================================
      //
      // Items with package breakdowns are stored in package-unit terms.
      //
      // Example:
      // 2 bag × 10 kg = 20 kg in inventory_batch.
      // ======================================================================

      final batchQty = packageQuantity == null
          ? item.qty
          : item.qtyUnit == QtyUnit.packageUnit
              ? item.qty
              : item.qty * packageQuantity;

      // ======================================================================
      // PURCHASE ITEM
      // ======================================================================

      final purchaseItem = await _client
          .from('purchase_item')
          .insert({
            'purchaseid': purId,
            'itemid': item.itemId,
            'qty': item.qty,
            'purchase_unit_cost': item.unitCost,
            'qty_unit': qtyUnitToString(item.qtyUnit),
          })
          .select('purchaseitemid')
          .single();

      final purchaseItemId = purchaseItem['purchaseitemid'] as String;

      // ======================================================================
      // INVENTORY BATCH
      // ======================================================================

      final batch = await _client
          .from('inventory_batch')
          .insert({
            'itemid': item.itemId,
            'purchaseitemid': purchaseItemId,
            'donationitemid': null,
            'batchcode':
                'PUR-${purchaseItemId.substring(0, 8).toUpperCase()}',
            'receiveddate':
                actualReceivedDate.toUtc().toIso8601String(),
            'expirydate':
                item.expiryDate?.toIso8601String().split('T').first,
            'qtyreceived': batchQty,
            'qtyavailable': batchQty,
            'qtyunit': qtyUnitToString(
              packageQuantity == null
                  ? QtyUnit.purchaseUnit
                  : QtyUnit.packageUnit,
            ),
            'unitcost': item.unitCost,
            'status': 'ACTIVE',
            'createdby': recordedByUserId,
          })
          .select('inventorybatchid')
          .single();

      final inventoryBatchId = batch['inventorybatchid'] as String;

      // ======================================================================
      // RECEIVE TRANSACTION
      // ======================================================================

      await _client
          .from('batch_transaction_log')
          .insert({
        'inventorybatchid': inventoryBatchId,
        'treatmentitemid': null,
        'txntype': 'RECEIVE',
        'qtychange': batchQty,
        'qtyunit': qtyUnitToString(
          packageQuantity == null
              ? QtyUnit.purchaseUnit
              : QtyUnit.packageUnit,
        ),
        'txndate':
            actualReceivedDate.toUtc().toIso8601String(),
        'performedby': recordedByUserId,
        'notes': 'Stock received from purchase $purId',
      });

      // ======================================================================
      // TEMPORARY ITEM-LEVEL AGGREGATE SYNC
      // ======================================================================
      //
      // Keep existing aggregate values synchronized while the remaining pages
      // transition completely to batch-derived stock.
      // ======================================================================

      await _inventoryService.stockIn(
        itemId: item.itemId,
        qty: item.qty,
        qtyUnit: item.qtyUnit,
      );
    }

    final created = await fetchPurchaseOrder(purId);

    DataChangeBus.instance.ping();

    return created!;
  }
}