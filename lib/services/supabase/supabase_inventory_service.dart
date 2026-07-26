import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/inventory_item.dart';
import '../../models/stock_movement.dart';
import '../../models/stock_out.dart';
import '../../state/data_bus.dart';
import '../inventory_service.dart';

/// Supabase-backed inventory access for public.item, with category/unit FKs
/// resolved into display names via lookup maps (mirrors the mock's
/// denormalization onto [InventoryItem]).
class SupabaseInventoryService implements InventoryService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _itemColumns =
      'id, name, p_category, s_category, purchase_unit, package_unit, '
      'package_quantity, dispense_unit, total_purchase_stocks, '
      'total_package_stocks';

  Future<Map<String, String>> _map(String table, String labelCol) async {
    final rows = await _client.from(table).select('id, $labelCol');
    return {
      for (final r in rows) r['id'] as String: (r[labelCol] as String?) ?? '',
    };
  }

  Future<Map<String, String>> _userNameMap() async {
    final rows = await _client.from('users').select('id, fname, lname');
    return {
      for (final r in rows)
        r['id'] as String:
            '${(r['fname'] as String?) ?? ''} ${(r['lname'] as String?) ?? ''}'
                .trim(),
    };
  }

  double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

  Future<Set<String>> _itemIdsIn(String table) async {
    final rows = await _client.from(table).select('itemid');
    return rows.map((r) => r['itemid'] as String).toSet();
  }

  /// Sums [qtyCol] per itemid across every row of [table] -- used for the
  /// lifetime stock-out / treatment totals behind `InventoryItem.
  /// usedPurchaseUnitQty`, which (unlike current stock levels) can't be
  /// recovered from the item row alone once a container's left inventory
  /// entirely.
  Future<Map<String, double>> _qtySumByItem(String table, String qtyCol) async {
    final rows = await _client.from(table).select('itemid, $qtyCol');
    final totals = <String, double>{};
    for (final r in rows) {
      final itemId = r['itemid'] as String;
      totals[itemId] = (totals[itemId] ?? 0) + (_toDouble(r[qtyCol]) ?? 0);
    }
    return totals;
  }

  InventoryItem _mapItem(
    Map<String, dynamic> r, {
    required Map<String, String> pcats,
    required Map<String, String> scats,
    required Map<String, String> units,
    required Set<String> purchasedItemIds,
    required Set<String> donatedItemIds,
    required Map<String, double> lifetimeStockOutTotals,
    required Map<String, double> lifetimeTreatmentTotals,
  }) {
    final sCategoryId = r['s_category'] as String?;
    final packageUnitId = r['package_unit'] as String?;
    final dispenseUnitId = r['dispense_unit'] as String?;
    return InventoryItem(
      itemId: r['id'] as String,
      itemName: (r['name'] as String?) ?? '',
      pCategoryId: r['p_category'] as String,
      pCategoryName: pcats[r['p_category']] ?? 'Unknown category',
      sCategoryId: sCategoryId,
      sCategoryName: sCategoryId == null ? null : scats[sCategoryId],
      purchaseUnitId: r['purchase_unit'] as String,
      purchaseUnitAbbr: units[r['purchase_unit']] ?? '',
      packageUnitId: packageUnitId,
      packageUnitAbbr: packageUnitId == null ? null : units[packageUnitId],
      packageQuantity: _toDouble(r['package_quantity']),
      dispenseUnitId: dispenseUnitId,
      dispenseUnitAbbr: dispenseUnitId == null ? null : units[dispenseUnitId],
      stockQty: _toDouble(r['total_purchase_stocks']) ?? 0,
      packageStockQty: _toDouble(r['total_package_stocks']),
      hasPurchaseHistory: purchasedItemIds.contains(r['id']),
      hasDonationHistory: donatedItemIds.contains(r['id']),
      lifetimeStockOutQty: lifetimeStockOutTotals[r['id']] ?? 0,
      lifetimeTreatmentQty: lifetimeTreatmentTotals[r['id']] ?? 0,
    );
  }

  @override
  Future<List<InventoryItem>> fetchItems() async {
    final pcats = await _map('primary_category', 'type');
    final scats = await _map('subcategory', 'type');
    final units = await _map('units', 'abbr_name');
    final purchasedItemIds = await _itemIdsIn('purchase_item');
    final donatedItemIds = await _itemIdsIn('donation_item');
    final lifetimeStockOutTotals = await _qtySumByItem('stock_out', 'qty');
    final lifetimeTreatmentTotals =
        await _qtySumByItem('treatment_item', 'dispensed_qty');
    final rows = await _client.from('item').select(_itemColumns).order('name');
    return rows
        .map((r) => _mapItem(r,
            pcats: pcats,
            scats: scats,
            units: units,
            purchasedItemIds: purchasedItemIds,
            donatedItemIds: donatedItemIds,
            lifetimeStockOutTotals: lifetimeStockOutTotals,
            lifetimeTreatmentTotals: lifetimeTreatmentTotals))
        .toList();
  }

  @override
  Future<InventoryItem?> fetchItem(String itemId) async {
    final row = await _client
        .from('item')
        .select(_itemColumns)
        .eq('id', itemId)
        .maybeSingle();
    if (row == null) return null;
    final pcats = await _map('primary_category', 'type');
    final scats = await _map('subcategory', 'type');
    final units = await _map('units', 'abbr_name');
    final hasPurchaseHistory = (await _client
            .from('purchase_item')
            .select('itemid')
            .eq('itemid', itemId))
        .isNotEmpty;
    final hasDonationHistory = (await _client
            .from('donation_item')
            .select('itemid')
            .eq('itemid', itemId))
        .isNotEmpty;
    final stockOutRows =
        await _client.from('stock_out').select('qty').eq('itemid', itemId);
    final lifetimeStockOutQty =
        stockOutRows.fold(0.0, (sum, r) => sum + (_toDouble(r['qty']) ?? 0));
    final treatmentRows = await _client
        .from('treatment_item')
        .select('dispensed_qty')
        .eq('itemid', itemId);
    final lifetimeTreatmentQty = treatmentRows.fold(
        0.0, (sum, r) => sum + (_toDouble(r['dispensed_qty']) ?? 0));
    return _mapItem(row,
        pcats: pcats,
        scats: scats,
        units: units,
        purchasedItemIds: hasPurchaseHistory ? {itemId} : {},
        donatedItemIds: hasDonationHistory ? {itemId} : {},
        lifetimeStockOutTotals: {itemId: lifetimeStockOutQty},
        lifetimeTreatmentTotals: {itemId: lifetimeTreatmentQty});
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
    final row = await _client
        .from('item')
        .insert({
          'name': itemName,
          'p_category': pCategoryId,
          's_category': sCategoryId,
          'purchase_unit': purchaseUnitId,
          'package_unit': packageUnitId,
          'package_quantity': packageQuantity,
          'dispense_unit': dispenseUnitId,
          'total_purchase_stocks': initialQty,
          'total_package_stocks':
              packageQuantity == null ? null : initialQty * packageQuantity,
        })
        .select('id')
        .single();
    final created = await fetchItem(row['id'] as String);
    DataChangeBus.instance.ping();
    return created!;
  }

  @override
  Future<InventoryItem> updateDetails({
    required String itemId,
    String? itemName,
    String? pCategoryId,
    String? sCategoryId,
    String? purchaseUnitId,
  }) async {
    final current = await fetchItem(itemId);
    if (current == null) throw Exception('Item not found');

    final updates = <String, dynamic>{};
    if (itemName != null) updates['name'] = itemName;
    if (pCategoryId != null && pCategoryId != current.pCategoryId) {
      updates['p_category'] = pCategoryId;
      // Subcategory belonged to the old primary category -- clear the stale FK.
      updates['s_category'] = null;
    }
    if (sCategoryId != null) updates['s_category'] = sCategoryId;
    if (purchaseUnitId != null) updates['purchase_unit'] = purchaseUnitId;

    if (updates.isNotEmpty) {
      await _client.from('item').update(updates).eq('id', itemId);
    }
    final updated = await fetchItem(itemId);
    DataChangeBus.instance.ping();
    return updated!;
  }

  /// Whole-container events (purchase, donation, waste, expired,
  /// adjustment). Keeps total_package_stocks in sync by the same
  /// proportion (delta * package_quantity) so the two pools don't drift.
  @override
  Future<InventoryItem> adjustStock({
    required String itemId,
    required double delta,
  }) async {
    final current = await fetchItem(itemId);
    if (current == null) throw Exception('Item not found');
    final next = current.stockQty + delta;
    if (next < 0) {
      throw Exception('Not enough stock: only ${formatQty(current.stockQty)} left');
    }
    final updates = <String, dynamic>{'total_purchase_stocks': next};
    final packageQuantity = current.packageQuantity;
    if (packageQuantity != null) {
      final currentPackage = current.packageStockQty ?? current.stockQty * packageQuantity;
      updates['total_package_stocks'] = currentPackage + delta * packageQuantity;
    }
    await _client.from('item').update(updates).eq('id', itemId);
    final updated = await fetchItem(itemId);
    DataChangeBus.instance.ping();
    return updated!;
  }

  /// Deducts treatment usage (already in package_unit terms) from
  /// total_package_stocks only -- total_purchase_stocks (whole containers)
  /// is untouched, since using part of a bottle doesn't remove the bottle
  /// from inventory.
  @override
  Future<InventoryItem> deductPackageStock({
    required String itemId,
    required double delta,
  }) async {
    final current = await fetchItem(itemId);
    if (current == null) throw Exception('Item not found');
    final packageQuantity = current.packageQuantity;
    final currentPackage = current.packageStockQty ??
        (packageQuantity == null ? 0 : current.stockQty * packageQuantity);
    final next = currentPackage + delta;
    if (next < 0) {
      throw Exception('Not enough stock: only ${formatQty(currentPackage)} left');
    }
    await _client
        .from('item')
        .update({'total_package_stocks': next}).eq('id', itemId);
    final updated = await fetchItem(itemId);
    DataChangeBus.instance.ping();
    return updated!;
  }

  @override
  Future<InventoryItem> stockOut({
    required String itemId,
    required double qty,
    required StockOutReason reason,
    required String recordedByUserId,
  }) async {
    await _client.from('stock_out').insert({
      'itemid': itemId,
      'qty': qty,
      'reason': stockOutReasonToString(reason),
      'recordedby': recordedByUserId,
    });
    return adjustStock(itemId: itemId, delta: -qty);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _client.from('item').delete().eq('id', itemId);
    DataChangeBus.instance.ping();
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
  Future<List<StockMovement>> fetchStockHistory(String itemId) async {
    final item = await fetchItem(itemId);
    final purchaseUnitAbbr = item?.purchaseUnitAbbr ?? '';
    final users = await _userNameMap();
    final units = await _map('units', 'abbr_name');
    final movements = <StockMovement>[];

    final purchaseRows = await _client
        .from('purchase_item')
        .select('qty, purchaseid, purchase(id, receiveddate, recordedby)')
        .eq('itemid', itemId);
    for (final r in purchaseRows) {
      final purchase = r['purchase'] as Map<String, dynamic>?;
      if (purchase == null) continue;
      movements.add(StockMovement(
        id: '${purchase['id']}-$itemId',
        date: DateTime.parse(purchase['receiveddate'] as String),
        direction: StockDirection.stockIn,
        qty: _toDouble(r['qty']) ?? 0,
        unitAbbr: purchaseUnitAbbr,
        typeLabel: 'Purchased',
        recordedByName: users[purchase['recordedby']] ?? 'Unknown user',
      ));
    }

    final donationRows = await _client
        .from('donation_item')
        .select('qty, dntid, donation(id, receiveddate, recordedby)')
        .eq('itemid', itemId);
    for (final r in donationRows) {
      final donation = r['donation'] as Map<String, dynamic>?;
      if (donation == null) continue;
      movements.add(StockMovement(
        id: '${donation['id']}-$itemId',
        date: DateTime.parse(donation['receiveddate'] as String),
        direction: StockDirection.stockIn,
        qty: _toDouble(r['qty']) ?? 0,
        unitAbbr: purchaseUnitAbbr,
        typeLabel: 'Donated',
        recordedByName: users[donation['recordedby']] ?? 'Unknown user',
      ));
    }

    final treatmentRows = await _client
        .from('treatment_item')
        .select('treatid, dispensed_qty, dispense_unit, consumeddate, '
            'recordedby, treatment(id, name)')
        .eq('itemid', itemId);
    for (final r in treatmentRows) {
      final treatment = r['treatment'] as Map<String, dynamic>?;
      final dispenseUnit = r['dispense_unit'] as String?;
      movements.add(StockMovement(
        id: '${r['treatid']}-$itemId',
        date: DateTime.parse(r['consumeddate'] as String),
        direction: StockDirection.stockOut,
        qty: _toDouble(r['dispensed_qty']) ?? 0,
        unitAbbr: (dispenseUnit == null ? null : units[dispenseUnit]) ??
            purchaseUnitAbbr,
        typeLabel: 'Treatment',
        treatmentId: r['treatid'] as String?,
        treatmentName: treatment?['name'] as String? ?? 'Unknown treatment',
        recordedByName: users[r['recordedby']] ?? 'Unknown user',
      ));
    }

    final stockOutRows = await _client
        .from('stock_out')
        .select('id, qty, reason, recordeddate, recordedby')
        .eq('itemid', itemId);
    for (final r in stockOutRows) {
      movements.add(StockMovement(
        id: r['id'] as String,
        date: DateTime.parse(r['recordeddate'] as String),
        direction: StockDirection.stockOut,
        qty: _toDouble(r['qty']) ?? 0,
        unitAbbr: purchaseUnitAbbr,
        typeLabel: _stockOutReasonLabel(
            stockOutReasonFromString(r['reason'] as String)),
        recordedByName: users[r['recordedby']] ?? 'Unknown user',
      ));
    }

    movements.sort((a, b) => b.date.compareTo(a.date));
    return movements;
  }

  @override
  Future<List<DateTime>> fetchStockOutDates() async {
    final rows = await _client.from('stock_out').select('recordeddate');
    return [
      for (final row in rows)
        DateTime.parse(row['recordeddate'] as String).toLocal(),
    ];
  }
}
