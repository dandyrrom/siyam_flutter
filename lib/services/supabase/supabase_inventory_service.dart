import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/inventory_item.dart';
import '../../models/qty_unit.dart';
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
      'total_package_stocks, total_package_stock_ins, stock_count_mode';

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
      totalPackageStockIns: _toDouble(r['total_package_stock_ins']) ?? 0,
      stockCountMode: stockCountModeFromString(r['stock_count_mode'] as String?),
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
        .map((r) => _mapItem(
              r,
              pcats: pcats,
              scats: scats,
              units: units,
              purchasedItemIds: purchasedItemIds,
              donatedItemIds: donatedItemIds,
              lifetimeStockOutTotals: lifetimeStockOutTotals,
              lifetimeTreatmentTotals: lifetimeTreatmentTotals,
            ))
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

    return _mapItem(
      row,
      pcats: pcats,
      scats: scats,
      units: units,
      purchasedItemIds: hasPurchaseHistory ? {itemId} : {},
      donatedItemIds: hasDonationHistory ? {itemId} : {},
      lifetimeStockOutTotals: {itemId: lifetimeStockOutQty},
      lifetimeTreatmentTotals: {itemId: lifetimeTreatmentQty},
    );
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
    StockCountMode? stockCountMode,
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
          'stock_count_mode': stockCountMode == null
              ? null
              : stockCountModeToString(stockCountMode),
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
    StockCountMode? stockCountMode,
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

    if (stockCountMode != null) {
      updates['stock_count_mode'] = stockCountModeToString(stockCountMode);
    }

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
      throw Exception(
          'Not enough stock: only ${formatQty(current.stockQty)} left');
    }

    final updates = <String, dynamic>{
      'total_purchase_stocks': next,
    };

    final packageQuantity = current.packageQuantity;

    if (packageQuantity != null) {
      final currentPackage =
          current.packageStockQty ?? current.stockQty * packageQuantity;

      updates['total_package_stocks'] =
          currentPackage + delta * packageQuantity;
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
        .update({'total_package_stocks': next})
        .eq('id', itemId);

    final updated = await fetchItem(itemId);

    DataChangeBus.instance.ping();

    return updated!;
  }

  /// Records one purchase_item/donation_item stock-in batch's stock effect.
  /// A purchase_unit stock-in is a whole-container event handled exactly
  /// like [adjustStock]. A package_unit stock-in (loose stock, no whole
  /// container) only ever adds to total_package_stocks and
  /// total_package_stock_ins -- total_purchase_stocks is never touched.
  @override
  Future<InventoryItem> stockIn({
    required String itemId,
    required double qty,
    required QtyUnit qtyUnit,
  }) async {
    final current = await fetchItem(itemId);
    if (current == null) throw Exception('Item not found');

    if (qtyUnit == QtyUnit.purchaseUnit || current.packageQuantity == null) {
      return adjustStock(
        itemId: itemId,
        delta: qty,
      );
    }

    final currentPackage =
        current.packageStockQty ?? current.stockQty * current.packageQuantity!;

    await _client.from('item').update({
      'total_package_stocks': currentPackage + qty,
      'total_package_stock_ins': current.totalPackageStockIns + qty,
    }).eq('id', itemId);

    final updated = await fetchItem(itemId);

    DataChangeBus.instance.ping();

    return updated!;
  }

  /// Returns the batch transaction type used for a non-treatment stock-out.
  ///
  /// Waste removes unusable stock through DISPOSAL, expired stock through
  /// EXPIRE, and manual inventory corrections through ADJUSTMENT.
  String _stockOutTransactionType(StockOutReason reason) {
    switch (reason) {
      case StockOutReason.waste:
        return 'DISPOSAL';
      case StockOutReason.expired:
        return 'EXPIRE';
      case StockOutReason.adjustment:
        return 'ADJUSTMENT';
    }
  }

  /// Drains [canonicalQty] from inventory_batch in FEFO order.
  ///
  /// inventory_batch is now the physical source of stock. Batches with the
  /// nearest expiry are consumed first, while batches without expiry dates
  /// are consumed last. receiveddate is used as the tie-breaker.
  ///
  /// Every batch deduction also creates its own batch_transaction_log row,
  /// linked to the parent stock_out through [stockOutId].
  Future<void> _drainBatchesFefoForStockOut({
    required String itemId,
    required double canonicalQty,
    required StockOutReason reason,
    required String stockOutId,
    required String recordedByUserId,
  }) async {
    final rows = await _client
        .from('inventory_batch')
        .select(
          'inventorybatchid, expirydate, receiveddate, qtyavailable, qtyunit, status',
        )
        .eq('itemid', itemId)
        .gt('qtyavailable', 0);

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final batches = rows.where((r) {
      final status = (r['status'] as String?) ?? 'ACTIVE';

      // Quarantined stock should never be automatically issued.
      if (status == 'QUARANTINED') return false;

      final expiryRaw = r['expirydate'] as String?;
      final expiryDate =
          expiryRaw == null ? null : DateTime.parse(expiryRaw);

      // An "expired" stock-out specifically removes expired batches.
      if (reason == StockOutReason.expired) {
        return expiryDate != null && expiryDate.isBefore(todayOnly);
      }

      // Normal waste/adjustment should not silently consume an expired batch.
      if (expiryDate != null && expiryDate.isBefore(todayOnly)) {
        return false;
      }

      return true;
    }).toList();

    // FEFO: nearest expiry first. Non-expiring batches are drawn last.
    // receiveddate breaks ties between batches with the same expiry.
    batches.sort((a, b) {
      final aExpiry = a['expirydate'] == null
          ? null
          : DateTime.parse(a['expirydate'] as String);

      final bExpiry = b['expirydate'] == null
          ? null
          : DateTime.parse(b['expirydate'] as String);

      if (aExpiry == null && bExpiry != null) return 1;
      if (aExpiry != null && bExpiry == null) return -1;

      if (aExpiry != null && bExpiry != null) {
        final expiryCompare = aExpiry.compareTo(bExpiry);
        if (expiryCompare != 0) return expiryCompare;
      }

      final aReceived = DateTime.parse(a['receiveddate'] as String);
      final bReceived = DateTime.parse(b['receiveddate'] as String);

      return aReceived.compareTo(bReceived);
    });

    final totalAvailable = batches.fold<double>(
      0,
      (sum, batch) =>
          sum + (_toDouble(batch['qtyavailable']) ?? 0),
    );

    // Do not partially perform a stock-out if the eligible batches cannot
    // satisfy the full requested quantity.
    if (totalAvailable < canonicalQty) {
      throw Exception(
        'Not enough eligible batch stock: only ${formatQty(totalAvailable)} available',
      );
    }

    var remaining = canonicalQty;

    for (final batch in batches) {
      if (remaining <= 0) break;

      final inventoryBatchId =
          batch['inventorybatchid'] as String;

      final available =
          _toDouble(batch['qtyavailable']) ?? 0;

      if (available <= 0) continue;

      final draw =
          remaining < available ? remaining : available;

      final nextAvailable =
          available - draw;

      // Update the exact physical batch that supplied this portion of the
      // stock-out.
      await _client
          .from('inventory_batch')
          .update({
            'qtyavailable': nextAvailable,
            'status': nextAvailable <= 0 ? 'DEPLETED' : 'ACTIVE',
            'updatedat': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('inventorybatchid', inventoryBatchId);

      // One stock_out can consume several batches, so each affected batch
      // receives a separate transaction log linked by the same stockoutid.
      await _client.from('batch_transaction_log').insert({
        'inventorybatchid': inventoryBatchId,
        'treatmentitemid': null,
        'stockoutid': stockOutId,
        'txntype': _stockOutTransactionType(reason),
        'qtychange': -draw,
        'qtyunit': batch['qtyunit'],
        'txndate': DateTime.now().toUtc().toIso8601String(),
        'performedby': recordedByUserId,
        'notes': 'Stock out: ${stockOutReasonToString(reason)}',
      });

      remaining -= draw;
    }
  }

  /// Draws [qty] (already canonical -- package_unit for items with a
  /// package breakdown, purchase_unit otherwise) from inventory_batch in
  /// FEFO order, then applies the matching aggregate deduction.
  ///
  /// This method is currently retained for treatment usage. Treatment's own
  /// batch_transaction_log linkage will be added when treatment_item is
  /// migrated to the new batch flow.
  @override
  Future<InventoryItem> deductFefo({
    required String itemId,
    required double qty,
  }) async {
    final current = await fetchItem(itemId);

    if (current == null) {
      throw Exception('Item not found');
    }

    final rows = await _client
        .from('inventory_batch')
        .select(
          'inventorybatchid, expirydate, receiveddate, qtyavailable, status',
        )
        .eq('itemid', itemId)
        .gt('qtyavailable', 0);

    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    final batches = rows.where((r) {
      final status = (r['status'] as String?) ?? 'ACTIVE';

      if (status == 'QUARANTINED') return false;

      final expiryRaw = r['expirydate'] as String?;

      if (expiryRaw == null) return true;

      final expiryDate = DateTime.parse(expiryRaw);

      return !expiryDate.isBefore(todayOnly);
    }).toList();

    batches.sort((a, b) {
      final aExpiry = a['expirydate'] == null
          ? null
          : DateTime.parse(a['expirydate'] as String);

      final bExpiry = b['expirydate'] == null
          ? null
          : DateTime.parse(b['expirydate'] as String);

      if (aExpiry == null && bExpiry != null) return 1;
      if (aExpiry != null && bExpiry == null) return -1;

      if (aExpiry != null && bExpiry != null) {
        final expiryCompare = aExpiry.compareTo(bExpiry);

        if (expiryCompare != 0) {
          return expiryCompare;
        }
      }

      final aReceived =
          DateTime.parse(a['receiveddate'] as String);

      final bReceived =
          DateTime.parse(b['receiveddate'] as String);

      return aReceived.compareTo(bReceived);
    });

    final totalAvailable = batches.fold<double>(
      0,
      (sum, batch) =>
          sum + (_toDouble(batch['qtyavailable']) ?? 0),
    );

    if (totalAvailable < qty) {
      throw Exception(
        'Not enough eligible batch stock: only ${formatQty(totalAvailable)} available',
      );
    }

    var remaining = qty;

    for (final batch in batches) {
      if (remaining <= 0) break;

      final inventoryBatchId =
          batch['inventorybatchid'] as String;

      final available =
          _toDouble(batch['qtyavailable']) ?? 0;

      if (available <= 0) continue;

      final draw =
          remaining < available ? remaining : available;

      final nextAvailable =
          available - draw;

      await _client
          .from('inventory_batch')
          .update({
            'qtyavailable': nextAvailable,
            'status': nextAvailable <= 0 ? 'DEPLETED' : 'ACTIVE',
            'updatedat': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('inventorybatchid', inventoryBatchId);

      remaining -= draw;
    }

    if (current.packageQuantity != null) {
      return deductPackageStock(
        itemId: itemId,
        delta: -qty,
      );
    }

    return adjustStock(
      itemId: itemId,
      delta: -qty,
    );
  }

  /// Records a non-treatment stock-out (waste/expired/adjustment), creates
  /// one parent stock_out row, then deducts the corresponding canonical
  /// quantity from inventory_batch using FEFO.
  ///
  /// Each physical batch consumed receives its own batch_transaction_log row
  /// linked back to the same stock_out through stockoutid. The old item-level
  /// aggregate stock is still updated temporarily while the UI is migrated
  /// to inventory_batch as its authoritative stock source.
  @override
  Future<InventoryItem> stockOut({
    required String itemId,
    required double qty,
    required StockOutReason reason,
    required String recordedByUserId,
  }) async {
    if (qty <= 0) {
      throw Exception('Stock-out quantity must be greater than 0');
    }

    final current = await fetchItem(itemId);

    if (current == null) {
      throw Exception('Item not found');
    }

    final canonicalQty = current.packageQuantity != null
        ? qty * current.packageQuantity!
        : qty;

    // Create the parent stock_out first and retain its UUID so every affected
    // batch transaction can point back to the same stock-out event.
    final stockOutRow = await _client
        .from('stock_out')
        .insert({
          'itemid': itemId,
          'qty': qty,
          'reason': stockOutReasonToString(reason),
          'recordedby': recordedByUserId,
        })
        .select('id')
        .single();

    final stockOutId =
        stockOutRow['id'] as String;

    await _drainBatchesFefoForStockOut(
      itemId: itemId,
      canonicalQty: canonicalQty,
      reason: reason,
      stockOutId: stockOutId,
      recordedByUserId: recordedByUserId,
    );

    // TEMPORARY:
    // Keep the existing item-level aggregate stock synchronized until all
    // inventory displays are migrated to SUM(inventory_batch.qtyavailable).
    return adjustStock(
      itemId: itemId,
      delta: -qty,
    );
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
    final packageUnitAbbr = item?.packageUnitAbbr ?? purchaseUnitAbbr;
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

      movements.add(
        StockMovement(
          id: '${purchase['id']}-$itemId',
          date: DateTime.parse(purchase['receiveddate'] as String),
          direction: StockDirection.stockIn,
          qty: _toDouble(r['qty']) ?? 0,
          unitAbbr: purchaseUnitAbbr,
          typeLabel: 'Purchased',
          recordedByName: users[purchase['recordedby']] ?? 'Unknown user',
        ),
      );
    }

    final donationRows = await _client
        .from('donation_item')
        .select('qty, qty_unit, dntid, donation(id, receiveddate, recordedby)')
        .eq('itemid', itemId);

    for (final r in donationRows) {
      final donation = r['donation'] as Map<String, dynamic>?;

      if (donation == null) continue;

      movements.add(
        StockMovement(
          id: '${donation['id']}-$itemId',
          date: DateTime.parse(donation['receiveddate'] as String),
          direction: StockDirection.stockIn,
          qty: _toDouble(r['qty']) ?? 0,
          unitAbbr: r['qty_unit'] == 'package_unit'
              ? packageUnitAbbr
              : purchaseUnitAbbr,
          typeLabel: 'Donated',
          recordedByName: users[donation['recordedby']] ?? 'Unknown user',
        ),
      );
    }

    final treatmentRows = await _client
        .from('treatment_item')
        .select(
          'treatid, dispensed_qty, dispense_unit, consumeddate, '
          'recordedby, treatment(id, name)',
        )
        .eq('itemid', itemId);

    for (final r in treatmentRows) {
      final treatment = r['treatment'] as Map<String, dynamic>?;
      final dispenseUnit = r['dispense_unit'] as String?;

      movements.add(
        StockMovement(
          id: '${r['treatid']}-$itemId',
          date: DateTime.parse(r['consumeddate'] as String),
          direction: StockDirection.stockOut,
          qty: _toDouble(r['dispensed_qty']) ?? 0,
          unitAbbr:
              (dispenseUnit == null ? null : units[dispenseUnit]) ??
                  purchaseUnitAbbr,
          typeLabel: 'Treatment',
          treatmentId: r['treatid'] as String?,
          treatmentName:
              treatment?['name'] as String? ?? 'Unknown treatment',
          recordedByName: users[r['recordedby']] ?? 'Unknown user',
        ),
      );
    }

    final stockOutRows = await _client
        .from('stock_out')
        .select('id, qty, reason, recordeddate, recordedby')
        .eq('itemid', itemId);

    for (final r in stockOutRows) {
      movements.add(
        StockMovement(
          id: r['id'] as String,
          date: DateTime.parse(r['recordeddate'] as String),
          direction: StockDirection.stockOut,
          qty: _toDouble(r['qty']) ?? 0,
          unitAbbr: purchaseUnitAbbr,
          typeLabel: _stockOutReasonLabel(
            stockOutReasonFromString(r['reason'] as String),
          ),
          recordedByName: users[r['recordedby']] ?? 'Unknown user',
        ),
      );
    }

    movements.sort((a, b) => b.date.compareTo(a.date));

    return movements;
  }

  @override
  Future<List<DateTime>> fetchStockOutDates() async {
    final rows =
        await _client.from('stock_out').select('recordeddate');

    return [
      for (final row in rows)
        DateTime.parse(row['recordeddate'] as String).toLocal(),
    ];
  }
}