import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supplier.dart';
import 'inventory_service.dart';

/// Thin wrapper around public.supplier / public.purchase_trans / public.order_item.
///
/// Table reference (from your schema):
///   supplier(suppid PK, suppname, contactnum, address)
///   purchase_trans(purid PK, suppid FK->supplier, userid FK->users, purdate)
///   order_item(orderid FK->purchase_trans, itemid FK->item, qty int, unitcost numeric)
///
/// Creating a purchase order also increments stock for each item
/// ordered, via InventoryService -- the same "receiving increases
/// stock" pattern used when a donation is approved.
class SupplierService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  Future<List<Supplier>> fetchSuppliers() async {
    final rows =
        await _client.from('supplier').select().order('suppname', ascending: true);
    return (rows as List)
        .map((r) => Supplier.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<Supplier> createSupplier({
    required String suppName,
    String? contactNum,
    String? address,
  }) async {
    final row = await _client
        .from('supplier')
        .insert({
          'suppname': suppName,
          'contactnum': contactNum,
          'address': address,
        })
        .select()
        .single();
    return Supplier.fromMap(row);
  }

  /// All purchase orders across every supplier, most recent first --
  /// used to derive each supplier's order count / last-order date
  /// client-side without a separate aggregate query per supplier.
  Future<List<PurchaseOrder>> fetchAllPurchaseOrders() async {
    final rows = await _client
        .from('purchase_trans')
        .select('*, users(userfname, userlname)')
        .order('purdate', ascending: false);
    return (rows as List)
        .map((r) => PurchaseOrder.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<PurchaseOrder>> fetchPurchaseOrdersForSupplier(String suppId) async {
    final rows = await _client
        .from('purchase_trans')
        .select('*, users(userfname, userlname)')
        .eq('suppid', suppId)
        .order('purdate', ascending: false);
    return (rows as List)
        .map((r) => PurchaseOrder.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<OrderLineItem>> fetchOrderItems(String purId) async {
    final rows = await _client
        .from('order_item')
        .select('qty, unitcost, item(itemid, itemname, item_uom)')
        .eq('orderid', purId);
    return (rows as List)
        .map((r) => OrderLineItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Spend per order_item row, with its parent order's date -- used to
  /// bucket total purchase spend by month on the Reports page.
  Future<List<OrderSpendEntry>> fetchOrderSpendEntries() async {
    final rows =
        await _client.from('order_item').select('qty, unitcost, purchase_trans(purdate)');
    return (rows as List)
        .map((r) => OrderSpendEntry.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Creates the purchase order, logs each item into order_item, and
  /// increments stock for each item received.
  Future<PurchaseOrder> createPurchaseOrder({
    required String suppId,
    required String userId,
    required List<OrderItemInput> items,
  }) async {
    final row = await _client
        .from('purchase_trans')
        .insert({'suppid': suppId, 'userid': userId})
        .select('*, users(userfname, userlname)')
        .single();
    final purId = row['purid'] as String;

    for (final item in items) {
      if (item.qty <= 0) continue;
      await _client.from('order_item').insert({
        'orderid': purId,
        'itemid': item.itemId,
        'qty': item.qty,
        'unitcost': item.unitCost,
      });
      await _inventoryService.adjustStock(itemId: item.itemId, delta: item.qty);
    }

    return PurchaseOrder.fromMap(row);
  }
}
