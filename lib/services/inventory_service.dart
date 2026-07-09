import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_item.dart';

/// Thin wrapper around the public.item table.
///
/// Table reference (from your schema):
///   item(itemid uuid PK, itemname, itemcategory, item_uom, stockqty int)
///
/// Note: reorder points, expiry dates, and a stock history log are NOT
/// part of the current schema, so this service only touches columns
/// that actually exist. Stock in/out here adjusts `stockqty` directly
/// -- it does not create donation/purchase/treatment records, since
/// those require a full parent transaction to attach to.
///
/// Supplier is intentionally NOT a column on `item` -- it's derived
/// from purchase history via the `item_last_supplier` view (see
/// supabase/item_last_supplier.sql), which picks each item's most
/// recent purchase_trans/order_item/supplier chain. That view has to
/// exist in your database for supplierName to ever be non-null.
class InventoryService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Best-effort supplier lookup. If `item_last_supplier` doesn't exist
  /// yet (e.g. the view hasn't been created in this Supabase project)
  /// or the query fails for any other reason, this returns an empty
  /// map instead of throwing -- a broken/missing "nice to have" enhancement
  /// should never take down the whole Inventory page with it.
  Future<Map<String, String>> _fetchLastSupplierByItemId([String? itemId]) async {
    try {
      var query = _client.from('item_last_supplier').select('itemid, suppname');
      final rows = itemId == null
          ? await query
          : await query.eq('itemid', itemId);
      return {
        for (final r in (rows as List))
          (r as Map<String, dynamic>)['itemid'] as String: r['suppname'] as String,
      };
    } catch (e) {
      // ignore: avoid_print
      print('item_last_supplier lookup failed (has the view been created?): $e');
      return {};
    }
  }

  Future<List<InventoryItem>> fetchItems() async {
    final rows =
        await _client.from('item').select().order('itemname', ascending: true);
    final supplierByItemId = await _fetchLastSupplierByItemId();

    return (rows as List).map((r) {
      final item = InventoryItem.fromMap(r as Map<String, dynamic>);
      final supplierName = supplierByItemId[item.itemId];
      return supplierName == null ? item : item.copyWith(supplierName: supplierName);
    }).toList();
  }

  Future<InventoryItem?> fetchItem(String itemId) async {
    final row = await _client
        .from('item')
        .select()
        .eq('itemid', itemId)
        .maybeSingle();
    if (row == null) return null;
    final item = InventoryItem.fromMap(row);
    final supplierByItemId = await _fetchLastSupplierByItemId(itemId);
    final supplierName = supplierByItemId[itemId];
    return supplierName == null ? item : item.copyWith(supplierName: supplierName);
  }

  Future<InventoryItem> createItem({
    required String itemName,
    required String itemCategory,
    required String itemUom,
    int initialQty = 0,
  }) async {
    final row = await _client
        .from('item')
        .insert({
          'itemname': itemName,
          'itemcategory': itemCategory,
          'item_uom': itemUom,
          'stockqty': initialQty,
        })
        .select()
        .single();
    return InventoryItem.fromMap(row);
  }

  Future<InventoryItem> updateDetails({
    required String itemId,
    String? itemName,
    String? itemCategory,
    String? itemUom,
  }) async {
    final updates = <String, dynamic>{};
    if (itemName != null) updates['itemname'] = itemName;
    if (itemCategory != null) updates['itemcategory'] = itemCategory;
    if (itemUom != null) updates['item_uom'] = itemUom;

    final row = await _client
        .from('item')
        .update(updates)
        .eq('itemid', itemId)
        .select()
        .single();
    return InventoryItem.fromMap(row);
  }

  /// Adjusts stockqty by [delta] (positive = stock in, negative = stock
  /// out). Reads the current value first so we don't need a Postgres
  /// function just for this -- fine for the current single-writer usage.
  Future<InventoryItem> adjustStock({
    required String itemId,
    required int delta,
  }) async {
    final current = await fetchItem(itemId);
    if (current == null) throw Exception('Item not found');

    final next = current.stockQty + delta;
    if (next < 0) {
      throw Exception(
          'Not enough stock: only ${current.stockQty} ${current.itemUom} left');
    }

    final row = await _client
        .from('item')
        .update({'stockqty': next})
        .eq('itemid', itemId)
        .select()
        .single();
    return InventoryItem.fromMap(row);
  }

  Future<void> deleteItem(String itemId) async {
    await _client.from('item').delete().eq('itemid', itemId);
  }
}