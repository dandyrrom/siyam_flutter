import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_item.dart';

/// Thin wrapper around the public.item table.
///
/// Table reference (from your schema):
///   item(itemid uuid PK, name, category, uom, currentstock float4)
///
/// Note: reorder points, expiry dates, and a stock history log are NOT
/// part of the current schema, so this service only touches columns
/// that actually exist. Stock in/out here adjusts `currentstock` directly
/// -- it does not create donation/purchase/treatment records, since
/// those require a full parent transaction to attach to.
///
/// There is intentionally no supplier lookup here: `item` has no
/// supplier column, and supplier/procurement type are per-transaction
/// (purchase_trans/donation), not a stable per-item attribute -- an
/// item's stock can be a mix of donated and purchased batches with no
/// way to attribute a single "the" supplier to it.
class InventoryService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<InventoryItem>> fetchItems() async {
    final rows =
        await _client.from('item').select().order('name', ascending: true);
    return (rows as List)
        .map((r) => InventoryItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<InventoryItem?> fetchItem(String itemId) async {
    final row = await _client
        .from('item')
        .select()
        .eq('itemid', itemId)
        .maybeSingle();
    if (row == null) return null;
    return InventoryItem.fromMap(row);
  }

  Future<InventoryItem> createItem({
    required String itemName,
    required String itemCategory,
    required String itemUom,
    double initialQty = 0,
  }) async {
    final row = await _client
        .from('item')
        .insert({
          'name': itemName,
          'category': itemCategory,
          'uom': itemUom,
          'currentstock': initialQty,
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
    if (itemName != null) updates['name'] = itemName;
    if (itemCategory != null) updates['category'] = itemCategory;
    if (itemUom != null) updates['uom'] = itemUom;

    final row = await _client
        .from('item')
        .update(updates)
        .eq('itemid', itemId)
        .select()
        .single();
    return InventoryItem.fromMap(row);
  }

  /// Adjusts currentstock by [delta] (positive = stock in, negative = stock
  /// out). Reads the current value first so we don't need a Postgres
  /// function just for this -- fine for the current single-writer usage.
  Future<InventoryItem> adjustStock({
    required String itemId,
    required double delta,
  }) async {
    final current = await fetchItem(itemId);
    if (current == null) throw Exception('Item not found');

    final next = current.stockQty + delta;
    if (next < 0) {
      throw Exception(
          'Not enough stock: only ${formatQty(current.stockQty)} ${current.itemUom} left');
    }

    final row = await _client
        .from('item')
        .update({'currentstock': next})
        .eq('itemid', itemId)
        .select()
        .single();
    return InventoryItem.fromMap(row);
  }

  Future<void> deleteItem(String itemId) async {
    await _client.from('item').delete().eq('itemid', itemId);
  }
}