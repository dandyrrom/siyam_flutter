import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/qty_unit.dart';
import '../../models/supplier.dart';
import '../../state/data_bus.dart';
import '../inventory_service.dart';
import '../supplier_service.dart';

/// Supabase-backed access for public.supplier / purchase / purchase_item.
///
/// Creating a purchase order also increments stock for each item received,
/// via [InventoryService] -- the same pattern the mock uses.
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
            '${(r['fname'] as String?) ?? ''} ${(r['lname'] as String?) ?? ''}'
                .trim(),
    };
  }

  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select('id, abbr_name');
    return {
      for (final r in rows) r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  PurchaseOrder _mapOrder(Map<String, dynamic> r, Map<String, String> users) {
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
        .select('itemid, qty, purchase_unit_cost, item(name, purchase_unit)')
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
      result.add(OrderSpendEntry(
        purDate: DateTime.parse(purchase['receiveddate'] as String),
        amount: _d(r['qty']) * _d(r['purchase_unit_cost']),
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
    final insert = <String, dynamic>{
      'suppid': suppId,
      'recordedby': recordedByUserId,
      'receivedby': receivedBy,
    };
    if (receivedDate != null) {
      insert['receiveddate'] = receivedDate.toUtc().toIso8601String();
    }
    final purchase =
        await _client.from('purchase').insert(insert).select('id').single();
    final purId = purchase['id'] as String;

    for (final item in items) {
      if (item.qty <= 0) continue;
      final invItem = await _inventoryService.fetchItem(item.itemId);
      // Canonical remaining qty for FEFO: package_unit terms when the item
      // has a breakdown (converting from purchase_unit if that's how this
      // line was entered), else purchase_unit terms directly. Mirrors
      // lib/services/supplier_service.dart's mock createPurchaseOrder.
      final packageQuantity = invItem?.packageQuantity;
      final qtyRemaining = packageQuantity == null
          ? item.qty
          : (item.qtyUnit == QtyUnit.packageUnit
              ? item.qty
              : item.qty * packageQuantity);
      await _client.from('purchase_item').insert({
        'purchaseid': purId,
        'itemid': item.itemId,
        'qty': item.qty,
        'purchase_unit_cost': item.unitCost,
        'qty_unit': qtyUnitToString(item.qtyUnit),
        'expiry_date': item.expiryDate?.toIso8601String(),
        'qty_remaining': qtyRemaining,
      });
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
