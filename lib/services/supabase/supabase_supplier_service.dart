import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/qty_unit.dart';
import '../../models/supplier.dart';
import '../../state/data_bus.dart';
import '../inventory_service.dart';
import '../supplier_service.dart';

/// Supabase-backed access for public.supplier / purchase / purchase_item.
///
/// Creating a purchase order now also creates an inventory_batch for each
/// received purchase_item and records the initial RECEIVE movement in
/// batch_transaction_log.
class SupabaseSupplierService implements SupplierService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  Supplier _mapSupplier(Map<String, dynamic> r) => Supplier(
        suppId: r['id'] as String,
        suppName: (r['name'] as String?) ?? '',
        contactNum: r['contactnum'] as String?,
        contactTel: r['contacttel'] as String?,
        address: r['address'] as String?,
      );

  Future<Map<String, String>> _userNameMap() async {
    final rows = await _client.from('users').select('id, fname, lname');
    return {
      for (final r in rows)
        r['id'] as String:
            '${(r['fname'] as String?) ?? ''} ${(r['lname'] as String?) ?? ''}'.trim(),
    };
  }

  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select('id, abbr_name');
    return {
      for (final r in rows)
        r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  PurchaseOrder _mapOrder(
      Map<String, dynamic> r, Map<String, String> users) {
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

  @override
  Future<List<Supplier>> fetchSuppliers() async {
    final rows = await _client
        .from('supplier')
        .select('id, name, contactnum, contacttel, address')
        .order('name');

    return rows.map((r) => _mapSupplier(r)).toList();
  }

  @override
  Future<Supplier> createSupplier({
    required String suppName,
    String? contactNum,
    String? contactTel,
    String? address,
  }) async {
    final row = await _client
        .from('supplier')
        .insert({
          'name': suppName,
          'contactnum': contactNum,
          'contacttel': contactTel,
          'address': address,
        })
        .select('id, name, contactnum, contacttel, address')
        .single();

    DataChangeBus.instance.ping();
    return _mapSupplier(row);
  }

  @override
  Future<Supplier> updateSupplier({
    required String suppId,
    required String suppName,
    String? contactNum,
    String? contactTel,
    String? address,
  }) async {
    final row = await _client
        .from('supplier')
        .update({
          'name': suppName,
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

  @override
  Future<void> deleteSupplier(String suppId) async {
    await _client.from('supplier').delete().eq('id', suppId);
    DataChangeBus.instance.ping();
  }

  @override
  Future<List<PurchaseOrder>> fetchAllPurchaseOrders() async {
    final users = await _userNameMap();

    final rows = await _client
        .from('purchase')
        .select(_orderColumns)
        .order('receiveddate', ascending: false);

    return rows.map((r) => _mapOrder(r, users)).toList();
  }

  @override
  Future<List<PurchaseOrder>> fetchPurchaseOrdersForSupplier(
      String suppId) async {
    final users = await _userNameMap();

    final rows = await _client
        .from('purchase')
        .select(_orderColumns)
        .eq('suppid', suppId)
        .order('receiveddate', ascending: false);

    return rows.map((r) => _mapOrder(r, users)).toList();
  }

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

  @override
  Future<List<OrderLineItem>> fetchOrderItems(String purId) async {
    final units = await _unitAbbrMap();

    final rows = await _client
        .from('purchase_item')
        .select(
            'itemid, qty, purchase_unit_cost, item(name, purchase_unit)')
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

  @override
  Future<List<OrderSpendEntry>> fetchOrderSpendEntries() async {
    final rows = await _client
        .from('purchase_item')
        .select('qty, purchase_unit_cost, purchase(receiveddate)');

    final result = <OrderSpendEntry>[];

    for (final r in rows) {
      final purchase = r['purchase'] as Map<String, dynamic>?;
      if (purchase == null) continue;

      result.add(
        OrderSpendEntry(
          purDate: DateTime.parse(purchase['receiveddate'] as String),
          amount: _d(r['qty']) * _d(r['purchase_unit_cost']),
        ),
      );
    }

    return result;
  }

  /// Creates the purchase, logs each item into purchase_item, creates the
  /// corresponding physical inventory_batch, and records a RECEIVE movement
  /// for that batch in batch_transaction_log.
  ///
  /// Expiry and remaining stock are no longer stored in purchase_item.
  /// They now belong to inventory_batch.
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

    final purchase =
        await _client.from('purchase').insert(insert).select('id').single();

    final purId = purchase['id'] as String;

    for (final item in items) {
      if (item.qty <= 0) continue;

      final invItem = await _inventoryService.fetchItem(item.itemId);

      // Canonical batch qty for FEFO: package_unit terms when the item
      // has a breakdown (converting from purchase_unit if that's how this
      // line was entered), else purchase_unit terms directly.
      final packageQuantity = invItem?.packageQuantity;

      final batchQty = packageQuantity == null
          ? item.qty
          : (item.qtyUnit == QtyUnit.packageUnit
              ? item.qty
              : item.qty * packageQuantity);

      // purchase_item now records only the procurement line. Expiry and
      // remaining stock are stored in inventory_batch instead.
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

      // Every purchase_item received creates its own physical batch.
      //
      // qtyreceived and qtyavailable use the canonical stock quantity:
      // package units when the item has a package breakdown, otherwise
      // purchase units.
      final batch = await _client
          .from('inventory_batch')
          .insert({
            'itemid': item.itemId,
            'purchaseitemid': purchaseItemId,
            'donationitemid': null,
            'batchcode': 'PUR-${purchaseItemId.substring(0, 8).toUpperCase()}',
            'receiveddate': actualReceivedDate.toUtc().toIso8601String(),
            'expirydate': item.expiryDate?.toIso8601String().split('T').first,
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

      // RECEIVE is the first transaction for a newly created batch and
      // records the exact quantity that entered inventory.
      await _client.from('batch_transaction_log').insert({
        'inventorybatchid': inventoryBatchId,
        'treatmentitemid': null,
        'txntype': 'RECEIVE',
        'qtychange': batchQty,
        'qtyunit': qtyUnitToString(
          packageQuantity == null
              ? QtyUnit.purchaseUnit
              : QtyUnit.packageUnit,
        ),
        'txndate': actualReceivedDate.toUtc().toIso8601String(),
        'performedby': recordedByUserId,
        'notes': 'Stock received from purchase $purId',
      });

      // TEMPORARY:
      // The existing inventory pages may still read the old item-level stock
      // value. Keep that value synchronized while the UI is being migrated to
      // SUM(inventory_batch.qtyavailable). Remove this call once batch stock
      // becomes the only source used throughout the application.
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