import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/inventory_item.dart';
import '../../models/qty_unit.dart';
import '../../models/stock_movement.dart';
import '../../models/stock_out.dart';
import '../../state/data_bus.dart';
import '../inventory_service.dart';

// ============================================================================
// PRIVATE BATCH SUMMARY
// ============================================================================

class _BatchStockSummary {
  final bool hasBatchHistory;
  final double usableQty;
  final double expiredQty;
  final DateTime? nearestExpiryDate;

  const _BatchStockSummary({
    this.hasBatchHistory = false,
    this.usableQty = 0,
    this.expiredQty = 0,
    this.nearestExpiryDate,
  });
}

class _MutableBatchStockSummary {
  bool hasBatchHistory = false;
  double usableQty = 0;
  double expiredQty = 0;
  DateTime? nearestExpiryDate;

  _BatchStockSummary freeze() {
    return _BatchStockSummary(
      hasBatchHistory: hasBatchHistory,
      usableQty: usableQty,
      expiredQty: expiredQty,
      nearestExpiryDate: nearestExpiryDate,
    );
  }
}

/// Supabase-backed inventory access.
///
/// CURRENT INVENTORY ARCHITECTURE:
///
/// ITEM
///   Cached/legacy aggregate quantities.
///
/// INVENTORY_BATCH
///   Authoritative physical stock, expiry, and FEFO source.
///
/// BATCH_TRANSACTION_LOG
///   Exact movement against a physical batch.
class SupabaseInventoryService implements InventoryService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _itemColumns =
      'id, name, p_category, s_category, purchase_unit, package_unit, '
      'package_quantity, dispense_unit, total_purchase_stocks, '
      'total_package_stocks, total_package_stock_ins, stock_count_mode';

  // ==========================================================================
  // GENERIC HELPERS
  // ==========================================================================

  Future<Map<String, String>> _map(
    String table,
    String labelCol,
  ) async {
    final rows = await _client
        .from(table)
        .select('id, $labelCol');

    return {
      for (final r in rows)
        r['id'] as String: (r[labelCol] as String?) ?? '',
    };
  }

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

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    return (value as num).toDouble();
  }

  DateTime _todayOnly() {
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  DateTime? _parseDateOnly(dynamic value) {
    if (value == null) return null;

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;

    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    );
  }

  Future<Set<String>> _itemIdsIn(String table) async {
    final rows = await _client
        .from(table)
        .select('itemid');

    return rows
        .map((r) => r['itemid'] as String)
        .toSet();
  }

  // ==========================================================================
  // NORMAL QUANTITY SUM
  // ==========================================================================

  Future<Map<String, double>> _qtySumByItem(
    String table,
    String qtyCol,
  ) async {
    final rows = await _client
        .from(table)
        .select('itemid, $qtyCol');

    final totals = <String, double>{};

    for (final r in rows) {
      final itemId = r['itemid'] as String;

      totals[itemId] =
          (totals[itemId] ?? 0) +
          (_toDouble(r[qtyCol]) ?? 0);
    }

    return totals;
  }

  // ==========================================================================
  // STOCK OUT LIFETIME TOTAL NORMALIZATION
  // ==========================================================================

  Future<Map<String, double>> _stockOutTotalsInPurchaseUnits(
    Map<String, double?> packageQuantityByItem,
  ) async {
    final rows = await _client
        .from('stock_out')
        .select('itemid, qty, qtyunit');

    final totals = <String, double>{};

    for (final row in rows) {
      final itemId = row['itemid'] as String;
      final qty = _toDouble(row['qty']) ?? 0;

      final qtyUnit = qtyUnitFromString(
        (row['qtyunit'] as String?) ?? 'purchase_unit',
      );

      final packageQuantity =
          packageQuantityByItem[itemId];

      double purchaseEquivalent = qty;

      if (qtyUnit == QtyUnit.packageUnit &&
          packageQuantity != null &&
          packageQuantity > 0) {
        purchaseEquivalent =
            qty / packageQuantity;
      }

      totals[itemId] =
          (totals[itemId] ?? 0) +
          purchaseEquivalent;
    }

    return totals;
  }

  // ==========================================================================
  // BATCH UNIT
  // ==========================================================================

  QtyUnit _batchQtyUnit(
    Map<String, dynamic> batch,
  ) {
    return qtyUnitFromString(
      (batch['qtyunit'] as String?) ??
          'purchase_unit',
    );
  }

  // ==========================================================================
  // BATCH QUANTITY -> CANONICAL QUANTITY
  // ==========================================================================

  double _batchCanonicalAvailableForPackageQuantity(
    Map<String, dynamic> batch,
    double? packageQuantity,
  ) {
    final available =
        _toDouble(batch['qtyavailable']) ?? 0;

    if (packageQuantity == null) {
      return available;
    }

    if (packageQuantity <= 0) {
      throw Exception(
        'Invalid package quantity configured.',
      );
    }

    if (_batchQtyUnit(batch) ==
        QtyUnit.purchaseUnit) {
      return available * packageQuantity;
    }

    return available;
  }

  double _batchCanonicalAvailable(
    Map<String, dynamic> batch,
    InventoryItem item,
  ) {
    return _batchCanonicalAvailableForPackageQuantity(
      batch,
      item.packageQuantity,
    );
  }

  // ==========================================================================
  // BATCH STOCK SUMMARY
  // ==========================================================================
  //
  // This is the new central expiry/usable-stock calculation.
  //
  // USABLE:
  // - qtyavailable > 0
  // - not depleted
  // - not quarantined
  // - not expired
  //
  // EXPIRED:
  // - qtyavailable > 0
  // - expirydate before today
  //
  // NEAREST EXPIRY:
  // - earliest expiry among usable dated batches
  // ==========================================================================

  Map<String, _BatchStockSummary> _buildBatchStockSummaries(
    List<dynamic> rows,
    Map<String, double?> packageQuantityByItem,
  ) {
    final today = _todayOnly();

    final mutable =
        <String, _MutableBatchStockSummary>{};

    for (final raw in rows) {
      final row =
          Map<String, dynamic>.from(raw);

      final itemId =
          row['itemid'] as String;

      final summary = mutable.putIfAbsent(
        itemId,
        _MutableBatchStockSummary.new,
      );

      // At least one batch record exists for the item.
      summary.hasBatchHistory = true;

      final qtyAvailable =
          _toDouble(row['qtyavailable']) ?? 0;

      if (qtyAvailable <= 0) {
        continue;
      }

      final status =
          ((row['status'] as String?) ?? 'ACTIVE')
              .toUpperCase();

      // A depleted batch should never contribute to stock even if bad data
      // accidentally leaves a positive qtyavailable.
      if (status == 'DEPLETED') {
        continue;
      }

      final packageQuantity =
          packageQuantityByItem[itemId];

      final canonicalQty =
          _batchCanonicalAvailableForPackageQuantity(
        row,
        packageQuantity,
      );

      final expiryDate =
          _parseDateOnly(row['expirydate']);

      // ----------------------------------------------------------------------
      // EXPIRED PHYSICAL STOCK
      // ----------------------------------------------------------------------
      //
      // Expired stock remains physically present until staff records its
      // removal. It does NOT count as usable stock.
      //
      if (expiryDate != null &&
          expiryDate.isBefore(today)) {
        summary.expiredQty += canonicalQty;
        continue;
      }

      // ----------------------------------------------------------------------
      // QUARANTINED STOCK
      // ----------------------------------------------------------------------

      if (status == 'QUARANTINED') {
        continue;
      }

      // ----------------------------------------------------------------------
      // CURRENT USABLE STOCK
      // ----------------------------------------------------------------------

      summary.usableQty += canonicalQty;

      // ----------------------------------------------------------------------
      // NEAREST USABLE EXPIRY
      // ----------------------------------------------------------------------

      if (expiryDate != null) {
        final currentNearest =
            summary.nearestExpiryDate;

        if (currentNearest == null ||
            expiryDate.isBefore(currentNearest)) {
          summary.nearestExpiryDate =
              expiryDate;
        }
      }
    }

    return {
      for (final entry in mutable.entries)
        entry.key: entry.value.freeze(),
    };
  }

  Future<Map<String, _BatchStockSummary>>
      _fetchBatchStockSummaries(
    Map<String, double?> packageQuantityByItem,
  ) async {
    final rows = await _client
        .from('inventory_batch')
        .select(
          'itemid, expirydate, qtyavailable, qtyunit, status',
        );

    return _buildBatchStockSummaries(
      rows,
      packageQuantityByItem,
    );
  }

  Future<_BatchStockSummary> _fetchBatchStockSummaryForItem(
    String itemId,
    double? packageQuantity,
  ) async {
    final rows = await _client
        .from('inventory_batch')
        .select(
          'itemid, expirydate, qtyavailable, qtyunit, status',
        )
        .eq('itemid', itemId);

    final summaries =
        _buildBatchStockSummaries(
      rows,
      {
        itemId: packageQuantity,
      },
    );

    return summaries[itemId] ??
        const _BatchStockSummary();
  }

  // ==========================================================================
  // SYNC LEGACY ITEM AGGREGATES FROM AUTHORITATIVE BATCH STOCK
  // ==========================================================================
  //
  // inventory_batch is the source of truth.
  //
  // The old item-level totals are kept only for compatibility with older
  // screens/services. They must therefore be REPLACED with the current usable
  // batch total after a batch deduction, not independently deducted again.
  //
  // This avoids false failures such as:
  //   batch stock: 8 -> 6   (success)
  //   legacy item stock: 0 -> -2   (throws after the real deduction succeeded)
  // ==========================================================================

  Future<InventoryItem> _syncLegacyItemStockFromBatches(
    InventoryItem item,
  ) async {
    final summary =
        await _fetchBatchStockSummaryForItem(
      item.itemId,
      item.packageQuantity,
    );

    final updates = <String, dynamic>{};

    final packageQuantity =
        item.packageQuantity;

    if (packageQuantity != null &&
        packageQuantity > 0) {
      // Batch summaries are canonical package-unit quantities when an item
      // has a package breakdown.
      updates['total_package_stocks'] =
          summary.usableQty;

      updates['total_purchase_stocks'] =
          summary.usableQty /
          packageQuantity;
    } else {
      // Without a package breakdown, batch quantities are already expressed
      // in the item's purchase unit.
      updates['total_purchase_stocks'] =
          summary.usableQty;
    }

    await _client
        .from('item')
        .update(updates)
        .eq('id', item.itemId);

    final updated =
        await fetchItem(item.itemId);

    if (updated == null) {
      throw Exception('Item not found');
    }

    DataChangeBus.instance.ping();

    return updated;
  }

  // ==========================================================================
  // MAP DATABASE ITEM
  // ==========================================================================

  InventoryItem _mapItem(
    Map<String, dynamic> r, {
    required Map<String, String> pcats,
    required Map<String, String> scats,
    required Map<String, String> units,
    required Set<String> purchasedItemIds,
    required Set<String> donatedItemIds,
    required Map<String, double> lifetimeStockOutTotals,
    required Map<String, double> lifetimeTreatmentTotals,
    required Map<String, _BatchStockSummary> batchStockSummaries,
  }) {
    final itemId = r['id'] as String;

    final sCategoryId =
        r['s_category'] as String?;

    final packageUnitId =
        r['package_unit'] as String?;

    final dispenseUnitId =
        r['dispense_unit'] as String?;

    final batchSummary =
        batchStockSummaries[itemId] ??
        const _BatchStockSummary();

    return InventoryItem(
      itemId: itemId,
      itemName: (r['name'] as String?) ?? '',

      pCategoryId:
          r['p_category'] as String,

      pCategoryName:
          pcats[r['p_category']] ??
          'Unknown category',

      sCategoryId: sCategoryId,

      sCategoryName: sCategoryId == null
          ? null
          : scats[sCategoryId],

      purchaseUnitId:
          r['purchase_unit'] as String,

      purchaseUnitAbbr:
          units[r['purchase_unit']] ?? '',

      packageUnitId: packageUnitId,

      packageUnitAbbr: packageUnitId == null
          ? null
          : units[packageUnitId],

      packageQuantity:
          _toDouble(r['package_quantity']),

      dispenseUnitId: dispenseUnitId,

      dispenseUnitAbbr: dispenseUnitId == null
          ? null
          : units[dispenseUnitId],

      stockQty:
          _toDouble(r['total_purchase_stocks']) ?? 0,

      packageStockQty:
          _toDouble(r['total_package_stocks']),

      totalPackageStockIns:
          _toDouble(r['total_package_stock_ins']) ?? 0,

      stockCountMode:
          stockCountModeFromString(
        r['stock_count_mode'] as String?,
      ),

      hasPurchaseHistory:
          purchasedItemIds.contains(itemId),

      hasDonationHistory:
          donatedItemIds.contains(itemId),

      lifetimeStockOutQty:
          lifetimeStockOutTotals[itemId] ?? 0,

      lifetimeTreatmentQty:
          lifetimeTreatmentTotals[itemId] ?? 0,

      // ======================================================================
      // BATCH-DERIVED STOCK + EXPIRY
      // ======================================================================

      hasBatchHistory:
          batchSummary.hasBatchHistory,

      usableBatchStockQty:
          batchSummary.usableQty,

      expiredBatchStockQty:
          batchSummary.expiredQty,

      nearestExpiryDate:
          batchSummary.nearestExpiryDate,
    );
  }

  // ==========================================================================
  // FETCH ITEMS
  // ==========================================================================

  @override
  Future<List<InventoryItem>> fetchItems() async {
    final pcats = await _map(
      'primary_category',
      'type',
    );

    final scats = await _map(
      'subcategory',
      'type',
    );

    final units = await _map(
      'units',
      'abbr_name',
    );

    final purchasedItemIds =
        await _itemIdsIn('purchase_item');

    final donatedItemIds =
        await _itemIdsIn('donation_item');

    final rows = await _client
        .from('item')
        .select(_itemColumns)
        .order('name');

    final packageQuantityByItem =
        <String, double?>{
      for (final row in rows)
        row['id'] as String:
            _toDouble(row['package_quantity']),
    };

    final lifetimeStockOutTotals =
        await _stockOutTotalsInPurchaseUnits(
      packageQuantityByItem,
    );

    final lifetimeTreatmentTotals =
        await _qtySumByItem(
      'treatment_item',
      'dispensed_qty',
    );

    // ========================================================================
    // BATCH STOCK + EXPIRY SUMMARY
    // ========================================================================

    final batchStockSummaries =
        await _fetchBatchStockSummaries(
      packageQuantityByItem,
    );

    return rows
        .map(
          (r) => _mapItem(
            r,
            pcats: pcats,
            scats: scats,
            units: units,
            purchasedItemIds:
                purchasedItemIds,
            donatedItemIds:
                donatedItemIds,
            lifetimeStockOutTotals:
                lifetimeStockOutTotals,
            lifetimeTreatmentTotals:
                lifetimeTreatmentTotals,
            batchStockSummaries:
                batchStockSummaries,
          ),
        )
        .toList();
  }

  // ==========================================================================
  // FETCH ONE ITEM
  // ==========================================================================

  @override
  Future<InventoryItem?> fetchItem(
    String itemId,
  ) async {
    final row = await _client
        .from('item')
        .select(_itemColumns)
        .eq('id', itemId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    final pcats = await _map(
      'primary_category',
      'type',
    );

    final scats = await _map(
      'subcategory',
      'type',
    );

    final units = await _map(
      'units',
      'abbr_name',
    );

    final hasPurchaseHistory =
        (await _client
                .from('purchase_item')
                .select('itemid')
                .eq('itemid', itemId))
            .isNotEmpty;

    final hasDonationHistory =
        (await _client
                .from('donation_item')
                .select('itemid')
                .eq('itemid', itemId))
            .isNotEmpty;

    final stockOutRows = await _client
        .from('stock_out')
        .select('qty, qtyunit')
        .eq('itemid', itemId);

    final packageQuantity =
        _toDouble(row['package_quantity']);

    double lifetimeStockOutQty = 0;

    for (final stockOut in stockOutRows) {
      final qty =
          _toDouble(stockOut['qty']) ?? 0;

      final qtyUnit = qtyUnitFromString(
        (stockOut['qtyunit'] as String?) ??
            'purchase_unit',
      );

      if (qtyUnit == QtyUnit.packageUnit &&
          packageQuantity != null &&
          packageQuantity > 0) {
        lifetimeStockOutQty +=
            qty / packageQuantity;
      } else {
        lifetimeStockOutQty += qty;
      }
    }

    final treatmentRows = await _client
        .from('treatment_item')
        .select('dispensed_qty')
        .eq('itemid', itemId);

    final lifetimeTreatmentQty =
        treatmentRows.fold<double>(
      0,
      (sum, treatment) =>
          sum +
          (_toDouble(
                treatment['dispensed_qty'],
              ) ??
              0),
    );

    // ========================================================================
    // BATCH STOCK + EXPIRY FOR ONE ITEM
    // ========================================================================

    final batchSummary =
        await _fetchBatchStockSummaryForItem(
      itemId,
      packageQuantity,
    );

    return _mapItem(
      row,
      pcats: pcats,
      scats: scats,
      units: units,
      purchasedItemIds:
          hasPurchaseHistory ? {itemId} : {},
      donatedItemIds:
          hasDonationHistory ? {itemId} : {},
      lifetimeStockOutTotals: {
        itemId: lifetimeStockOutQty,
      },
      lifetimeTreatmentTotals: {
        itemId: lifetimeTreatmentQty,
      },
      batchStockSummaries: {
        itemId: batchSummary,
      },
    );
  }

  // ==========================================================================
  // CREATE ITEM
  // ==========================================================================

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
          'total_package_stocks': packageQuantity == null
              ? null
              : initialQty * packageQuantity,
          'stock_count_mode': stockCountMode == null
              ? null
              : stockCountModeToString(
                  stockCountMode,
                ),
        })
        .select('id')
        .single();

    final created =
        await fetchItem(row['id'] as String);

    DataChangeBus.instance.ping();

    return created!;
  }

  // ==========================================================================
  // UPDATE ITEM DETAILS
  // ==========================================================================

  @override
  Future<InventoryItem> updateDetails({
    required String itemId,
    String? itemName,
    String? pCategoryId,
    String? sCategoryId,
    String? purchaseUnitId,
    StockCountMode? stockCountMode,
  }) async {
    final current =
        await fetchItem(itemId);

    if (current == null) {
      throw Exception('Item not found');
    }

    final updates =
        <String, dynamic>{};

    if (itemName != null) {
      updates['name'] = itemName;
    }

    if (pCategoryId != null &&
        pCategoryId != current.pCategoryId) {
      updates['p_category'] = pCategoryId;
      updates['s_category'] = null;
    }

    if (sCategoryId != null) {
      updates['s_category'] = sCategoryId;
    }

    if (purchaseUnitId != null) {
      updates['purchase_unit'] =
          purchaseUnitId;
    }

    if (stockCountMode != null) {
      updates['stock_count_mode'] =
          stockCountModeToString(
        stockCountMode,
      );
    }

    if (updates.isNotEmpty) {
      await _client
          .from('item')
          .update(updates)
          .eq('id', itemId);
    }

    final updated =
        await fetchItem(itemId);

    DataChangeBus.instance.ping();

    return updated!;
  }

  // ==========================================================================
  // WHOLE-CONTAINER STOCK ADJUSTMENT
  // ==========================================================================

  @override
  Future<InventoryItem> adjustStock({
    required String itemId,
    required double delta,
  }) async {
    final current =
        await fetchItem(itemId);

    if (current == null) {
      throw Exception('Item not found');
    }

    final next =
        current.stockQty + delta;

    if (next < 0) {
      throw Exception(
        'Not enough stock: only '
        '${formatQty(current.stockQty)} '
        '${current.purchaseUnitAbbr} left',
      );
    }

    final updates =
        <String, dynamic>{
      'total_purchase_stocks': next,
    };

    final packageQuantity =
        current.packageQuantity;

    if (packageQuantity != null) {
      final currentPackage =
          current.packageStockQty ??
          current.stockQty *
              packageQuantity;

      final nextPackage =
          currentPackage +
          delta * packageQuantity;

      if (nextPackage < 0) {
        throw Exception(
          'Not enough stock: only '
          '${formatQty(currentPackage)} '
          '${current.packageUnitAbbr ?? ''} left',
        );
      }

      updates['total_package_stocks'] =
          nextPackage;
    }

    await _client
        .from('item')
        .update(updates)
        .eq('id', itemId);

    final updated =
        await fetchItem(itemId);

    DataChangeBus.instance.ping();

    return updated!;
  }

  // ==========================================================================
  // PACKAGE / LOOSE STOCK ADJUSTMENT
  // ==========================================================================

  @override
  Future<InventoryItem> deductPackageStock({
    required String itemId,
    required double delta,
  }) async {
    final current =
        await fetchItem(itemId);

    if (current == null) {
      throw Exception('Item not found');
    }

    final packageQuantity =
        current.packageQuantity;

    final currentPackage =
        current.packageStockQty ??
        (packageQuantity == null
            ? 0
            : current.stockQty *
                packageQuantity);

    final next =
        currentPackage + delta;

    if (next < 0) {
      throw Exception(
        'Not enough stock: only '
        '${formatQty(currentPackage)} '
        '${current.packageUnitAbbr ?? ''} left',
      );
    }

    await _client
        .from('item')
        .update({
          'total_package_stocks': next,
        })
        .eq('id', itemId);

    final updated =
        await fetchItem(itemId);

    DataChangeBus.instance.ping();

    return updated!;
  }

  // ==========================================================================
  // STOCK IN
  // ==========================================================================

  @override
  Future<InventoryItem> stockIn({
    required String itemId,
    required double qty,
    required QtyUnit qtyUnit,
  }) async {
    final current =
        await fetchItem(itemId);

    if (current == null) {
      throw Exception('Item not found');
    }

    // ========================================================================
    // BATCH-BASED STOCK IN
    // ========================================================================
    //
    // Purchase and donation services create inventory_batch first, then call
    // stockIn() only to keep the old item-level aggregate fields synchronized.
    //
    // Once batch history exists, inventory_batch is already the source of
    // truth. Do not add [qty] to the legacy aggregate independently because
    // that can drift when the cache was already stale.
    // ========================================================================

    if (current.hasBatchHistory) {
      return _syncLegacyItemStockFromBatches(
        current,
      );
    }

    // ========================================================================
    // LEGACY / NON-BATCH FALLBACK
    // ========================================================================
    //
    // Retained for older/mock-compatible flows where no inventory_batch exists.
    // ========================================================================

    if (qtyUnit == QtyUnit.purchaseUnit ||
        current.packageQuantity == null) {
      return adjustStock(
        itemId: itemId,
        delta: qty,
      );
    }

    final currentPackage =
        current.packageStockQty ??
        current.stockQty *
            current.packageQuantity!;

    await _client
        .from('item')
        .update({
          'total_package_stocks':
              currentPackage + qty,
          'total_package_stock_ins':
              current.totalPackageStockIns + qty,
        })
        .eq('id', itemId);

    final updated =
        await fetchItem(itemId);

    DataChangeBus.instance.ping();

    return updated!;
  }

  // ==========================================================================
  // STOCK OUT TRANSACTION TYPE
  // ==========================================================================

  String _stockOutTransactionType(
    StockOutReason reason,
  ) {
    switch (reason) {
      case StockOutReason.waste:
        return 'DISPOSAL';

      case StockOutReason.expired:
        return 'EXPIRE';

      case StockOutReason.adjustment:
        return 'ADJUSTMENT';
    }
  }

  // ==========================================================================
  // CANONICAL QUANTITY -> BATCH QUANTITY
  // ==========================================================================

  double _canonicalToBatchQty(
    double canonicalQty,
    Map<String, dynamic> batch,
    InventoryItem item,
  ) {
    final packageQuantity =
        item.packageQuantity;

    if (packageQuantity == null) {
      return canonicalQty;
    }

    if (packageQuantity <= 0) {
      throw Exception(
        'Invalid package quantity configured for ${item.itemName}.',
      );
    }

    if (_batchQtyUnit(batch) ==
        QtyUnit.purchaseUnit) {
      return canonicalQty /
          packageQuantity;
    }

    return canonicalQty;
  }

  // ==========================================================================
  // FETCH ELIGIBLE DISPENSE BATCHES
  // ==========================================================================

  /// NORMAL DISPENSE:
  ///
  /// - skips expired batches
  /// - skips quarantined batches
  /// - FEFO among usable batches
  ///
  /// EXPIRED DISPENSE:
  ///
  /// - targets ONLY expired batches
  /// - explicitly allows staff to remove an expired batch even if it had
  ///   previously been quarantined
  Future<List<Map<String, dynamic>>>
      _fetchEligibleBatchesForStockOut({
    required String itemId,
    required StockOutReason reason,
  }) async {
    final rows = await _client
        .from('inventory_batch')
        .select(
          'inventorybatchid, expirydate, receiveddate, '
          'qtyavailable, qtyunit, status',
        )
        .eq('itemid', itemId)
        .gt('qtyavailable', 0);

    final today = _todayOnly();

    final batches = rows
        .where((r) {
          final status =
              ((r['status'] as String?) ?? 'ACTIVE')
                  .toUpperCase();

          if (status == 'DEPLETED') {
            return false;
          }

          final expiryDate =
              _parseDateOnly(r['expirydate']);

          // ==================================================================
          // EXPIRED REMOVAL
          // ==================================================================
          //
          // Explicit staff removal:
          // only actual expired physical stock is eligible.
          //
          if (reason == StockOutReason.expired) {
            return expiryDate != null &&
                expiryDate.isBefore(today);
          }

          // ==================================================================
          // NORMAL DISPENSE
          // ==================================================================

          if (status == 'QUARANTINED') {
            return false;
          }

          if (expiryDate != null &&
              expiryDate.isBefore(today)) {
            return false;
          }

          return true;
        })
        .map(
          (r) => Map<String, dynamic>.from(r),
        )
        .toList();

    // ========================================================================
    // FEFO
    // ========================================================================

    batches.sort((a, b) {
      final aExpiry =
          _parseDateOnly(a['expirydate']);

      final bExpiry =
          _parseDateOnly(b['expirydate']);

      if (aExpiry == null &&
          bExpiry != null) {
        return 1;
      }

      if (aExpiry != null &&
          bExpiry == null) {
        return -1;
      }

      if (aExpiry != null &&
          bExpiry != null) {
        final expiryCompare =
            aExpiry.compareTo(bExpiry);

        if (expiryCompare != 0) {
          return expiryCompare;
        }
      }

      final aReceived = DateTime.parse(
        a['receiveddate'] as String,
      );

      final bReceived = DateTime.parse(
        b['receiveddate'] as String,
      );

      return aReceived.compareTo(bReceived);
    });

    return batches;
  }

  // ==========================================================================
  // DRAIN PRE-VALIDATED DISPENSE BATCHES
  // ==========================================================================

  Future<void> _drainBatchesFefoForStockOut({
    required List<Map<String, dynamic>> batches,
    required InventoryItem item,
    required double canonicalQty,
    required StockOutReason reason,
    required String stockOutId,
    required String recordedByUserId,
  }) async {
    var remaining = canonicalQty;

    for (final batch in batches) {
      if (remaining <= 0) break;

      final inventoryBatchId =
          batch['inventorybatchid'] as String;

      final canonicalAvailable =
          _batchCanonicalAvailable(
        batch,
        item,
      );

      if (canonicalAvailable <= 0) {
        continue;
      }

      final canonicalDraw =
          remaining < canonicalAvailable
              ? remaining
              : canonicalAvailable;

      final batchDraw =
          _canonicalToBatchQty(
        canonicalDraw,
        batch,
        item,
      );

      final availableInBatchUnit =
          _toDouble(batch['qtyavailable']) ?? 0;

      var nextAvailable =
          availableInBatchUnit - batchDraw;

      if (nextAvailable.abs() <
          0.000000001) {
        nextAvailable = 0;
      }

      await _client
          .from('inventory_batch')
          .update({
            'qtyavailable': nextAvailable,
            'status': nextAvailable <= 0
                ? 'DEPLETED'
                : 'ACTIVE',
            'updatedat': DateTime.now()
                .toUtc()
                .toIso8601String(),
          })
          .eq(
            'inventorybatchid',
            inventoryBatchId,
          );

      await _client
          .from('batch_transaction_log')
          .insert({
            'inventorybatchid':
                inventoryBatchId,
            'treatmentitemid': null,
            'stockoutid': stockOutId,
            'txntype':
                _stockOutTransactionType(reason),
            'qtychange': -batchDraw,
            'qtyunit': qtyUnitToString(
              _batchQtyUnit(batch),
            ),
            'txndate': DateTime.now()
                .toUtc()
                .toIso8601String(),
            'performedby':
                recordedByUserId,
            'notes':
                'Dispense: ${stockOutReasonToString(reason)}',
          });

      remaining -= canonicalDraw;
    }
  }

  // ==========================================================================
  // TREATMENT / GENERIC FEFO DEDUCTION
  // ==========================================================================

  @override
  Future<InventoryItem> deductFefo({
    required String itemId,
    required double qty,
  }) async {
    final current =
        await fetchItem(itemId);

    if (current == null) {
      throw Exception('Item not found');
    }

    final rows = await _client
        .from('inventory_batch')
        .select(
          'inventorybatchid, expirydate, receiveddate, '
          'qtyavailable, qtyunit, status',
        )
        .eq('itemid', itemId)
        .gt('qtyavailable', 0);

    final today = _todayOnly();

    final batches = rows
        .where((r) {
          final status =
              ((r['status'] as String?) ?? 'ACTIVE')
                  .toUpperCase();

          if (status == 'DEPLETED' ||
              status == 'QUARANTINED') {
            return false;
          }

          final expiryDate =
              _parseDateOnly(r['expirydate']);

          if (expiryDate == null) {
            return true;
          }

          return !expiryDate.isBefore(today);
        })
        .map(
          (r) => Map<String, dynamic>.from(r),
        )
        .toList();

    // ========================================================================
    // FEFO SORT
    // ========================================================================

    batches.sort((a, b) {
      final aExpiry =
          _parseDateOnly(a['expirydate']);

      final bExpiry =
          _parseDateOnly(b['expirydate']);

      if (aExpiry == null &&
          bExpiry != null) {
        return 1;
      }

      if (aExpiry != null &&
          bExpiry == null) {
        return -1;
      }

      if (aExpiry != null &&
          bExpiry != null) {
        final compare =
            aExpiry.compareTo(bExpiry);

        if (compare != 0) {
          return compare;
        }
      }

      final aReceived = DateTime.parse(
        a['receiveddate'] as String,
      );

      final bReceived = DateTime.parse(
        b['receiveddate'] as String,
      );

      return aReceived.compareTo(bReceived);
    });

    final totalAvailable =
        batches.fold<double>(
      0,
      (sum, batch) =>
          sum +
          _batchCanonicalAvailable(
            batch,
            current,
          ),
    );

    if (totalAvailable < qty) {
      throw Exception(
        'Not enough usable batch stock. Only '
        '${formatQty(totalAvailable)} '
        '${current.hasPackageBreakdown ? current.packageUnitAbbr : current.purchaseUnitAbbr} '
        'available.',
      );
    }

    var remaining = qty;

    for (final batch in batches) {
      if (remaining <= 0) break;

      final inventoryBatchId =
          batch['inventorybatchid'] as String;

      final canonicalAvailable =
          _batchCanonicalAvailable(
        batch,
        current,
      );

      if (canonicalAvailable <= 0) {
        continue;
      }

      final canonicalDraw =
          remaining < canonicalAvailable
              ? remaining
              : canonicalAvailable;

      final batchDraw =
          _canonicalToBatchQty(
        canonicalDraw,
        batch,
        current,
      );

      final availableInBatchUnit =
          _toDouble(batch['qtyavailable']) ?? 0;

      var nextAvailable =
          availableInBatchUnit - batchDraw;

      if (nextAvailable.abs() <
          0.000000001) {
        nextAvailable = 0;
      }

      await _client
          .from('inventory_batch')
          .update({
            'qtyavailable': nextAvailable,
            'status': nextAvailable <= 0
                ? 'DEPLETED'
                : 'ACTIVE',
            'updatedat': DateTime.now()
                .toUtc()
                .toIso8601String(),
          })
          .eq(
            'inventorybatchid',
            inventoryBatchId,
          );

      remaining -= canonicalDraw;
    }

    // ========================================================================
    // LEGACY ITEM AGGREGATE SYNC
    // ========================================================================
    //
    // The batch deduction above already changed the real stock.
    // Recalculate the compatibility totals FROM the batch ledger instead of
    // deducting the old item totals a second time.
    // ========================================================================

    return _syncLegacyItemStockFromBatches(
      current,
    );
  }

  // ==========================================================================
  // DISPENSE / STOCK OUT
  // ==========================================================================

  @override
  Future<InventoryItem> stockOut({
    required String itemId,
    required double qty,
    required QtyUnit qtyUnit,
    required StockOutReason reason,
    required String recordedByUserId,
  }) async {
    if (qty <= 0) {
      throw Exception(
        'Dispense quantity must be greater than 0.',
      );
    }

    final current =
        await fetchItem(itemId);

    if (current == null) {
      throw Exception('Item not found');
    }

    final packageQuantity =
        current.packageQuantity;

    // =========================================================================
    // DETERMINE AVAILABLE STOCK FOR THIS DISPENSE TYPE
    // =========================================================================
    //
    // NORMAL:
    //   usable, unexpired stock
    //
    // EXPIRED:
    //   expired physical stock awaiting staff removal
    // =========================================================================

    final double availableCanonical;

    if (reason == StockOutReason.expired) {
      availableCanonical =
          current.hasBatchHistory
              ? current.expiredBatchStockQty
              : 0;
    } else {
      availableCanonical =
          current.currentUsableStockQty;
    }

    // =========================================================================
    // PACKAGE-UNIT VALIDATION
    // =========================================================================

    if (qtyUnit == QtyUnit.packageUnit) {
      if (packageQuantity == null ||
          packageQuantity <= 0 ||
          current.packageUnitId == null) {
        throw Exception(
          '${current.itemName} does not have a package unit configured.',
        );
      }

      if (qty > availableCanonical) {
        final label =
            reason == StockOutReason.expired
                ? 'expired'
                : 'usable';

        throw Exception(
          'Not enough $label stock. Only '
          '${formatQty(availableCanonical)} '
          '${current.packageUnitAbbr ?? ''} '
          'available.',
        );
      }
    }

    // =========================================================================
    // PURCHASE-UNIT VALIDATION
    // =========================================================================

    if (qtyUnit == QtyUnit.purchaseUnit) {
      final purchaseAvailable =
          packageQuantity != null &&
                  packageQuantity > 0
              ? availableCanonical /
                  packageQuantity
              : availableCanonical;

      if (qty > purchaseAvailable) {
        final label =
            reason == StockOutReason.expired
                ? 'expired'
                : 'usable';

        throw Exception(
          'Not enough $label stock. Only '
          '${formatQty(purchaseAvailable)} '
          '${current.purchaseUnitAbbr} '
          'equivalent available.',
        );
      }
    }

    // =========================================================================
    // NORMALIZE TO CANONICAL UNIT
    // =========================================================================

    final double canonicalQty;

    if (packageQuantity != null) {
      if (packageQuantity <= 0) {
        throw Exception(
          'Invalid package quantity configured for ${current.itemName}.',
        );
      }

      canonicalQty =
          qtyUnit == QtyUnit.purchaseUnit
              ? qty * packageQuantity
              : qty;
    } else {
      canonicalQty = qty;
    }

    // =========================================================================
    // ELIGIBLE FEFO BATCHES
    // =========================================================================

    final batches =
        await _fetchEligibleBatchesForStockOut(
      itemId: itemId,
      reason: reason,
    );

    final totalBatchAvailable =
        batches.fold<double>(
      0,
      (sum, batch) =>
          sum +
          _batchCanonicalAvailable(
            batch,
            current,
          ),
    );

    if (totalBatchAvailable <
        canonicalQty) {
      final canonicalUnit =
          packageQuantity != null
              ? current.packageUnitAbbr
              : current.purchaseUnitAbbr;

      final label =
          reason == StockOutReason.expired
              ? 'expired batch'
              : 'usable batch';

      throw Exception(
        'Not enough $label stock. '
        'Only ${formatQty(totalBatchAvailable)} '
        '${canonicalUnit ?? ''} available.',
      );
    }

    // =========================================================================
    // CREATE PARENT STOCK OUT
    // =========================================================================

    final stockOutRow = await _client
        .from('stock_out')
        .insert({
          'itemid': itemId,
          'qty': qty,
          'qtyunit':
              qtyUnitToString(qtyUnit),
          'reason':
              stockOutReasonToString(reason),
          'recordedby':
              recordedByUserId,
        })
        .select('id')
        .single();

    final stockOutId =
        stockOutRow['id'] as String;

    // =========================================================================
    // FEFO BATCH DEDUCTION
    // =========================================================================

    await _drainBatchesFefoForStockOut(
      batches: batches,
      item: current,
      canonicalQty: canonicalQty,
      reason: reason,
      stockOutId: stockOutId,
      recordedByUserId:
          recordedByUserId,
    );

    // =========================================================================
    // LEGACY ITEM AGGREGATE SYNC
    // =========================================================================
    //
    // inventory_batch has already been deducted. Keep the old item totals as a
    // derived compatibility cache by replacing them with the authoritative
    // usable batch balance.
    // =========================================================================

    return _syncLegacyItemStockFromBatches(
      current,
    );
  }

  // ==========================================================================
  // DELETE ITEM
  // ==========================================================================

  @override
  Future<void> deleteItem(
    String itemId,
  ) async {
    await _client
        .from('item')
        .delete()
        .eq('id', itemId);

    DataChangeBus.instance.ping();
  }

  // ==========================================================================
  // STOCK OUT REASON LABEL
  // ==========================================================================

  String _stockOutReasonLabel(
    StockOutReason reason,
  ) {
    switch (reason) {
      case StockOutReason.waste:
        return 'Waste';

      case StockOutReason.expired:
        return 'Expired';

      case StockOutReason.adjustment:
        return 'Adjustment';
    }
  }

  // ==========================================================================
  // STOCK MOVEMENT HISTORY
  // ==========================================================================

  @override
  Future<List<StockMovement>> fetchStockHistory(
    String itemId,
  ) async {
    final item =
        await fetchItem(itemId);

    final purchaseUnitAbbr =
        item?.purchaseUnitAbbr ?? '';

    final packageUnitAbbr =
        item?.packageUnitAbbr ??
        purchaseUnitAbbr;

    final users =
        await _userNameMap();

    final units = await _map(
      'units',
      'abbr_name',
    );

    final movements =
        <StockMovement>[];

    // =========================================================================
    // PURCHASE
    // =========================================================================

    final purchaseRows = await _client
        .from('purchase_item')
        .select(
          'qty, purchaseid, purchase(id, receiveddate, recordedby)',
        )
        .eq('itemid', itemId);

    for (final r in purchaseRows) {
      final purchase =
          r['purchase']
              as Map<String, dynamic>?;

      if (purchase == null) {
        continue;
      }

      movements.add(
        StockMovement(
          id: '${purchase['id']}-$itemId',
          date: DateTime.parse(
            purchase['receiveddate'] as String,
          ),
          direction:
              StockDirection.stockIn,
          qty:
              _toDouble(r['qty']) ?? 0,
          unitAbbr:
              purchaseUnitAbbr,
          typeLabel: 'Purchased',
          recordedByName:
              users[purchase['recordedby']] ??
              'Unknown user',
        ),
      );
    }

    // =========================================================================
    // DONATION
    // =========================================================================

    final donationRows = await _client
        .from('donation_item')
        .select(
          'qty, qty_unit, dntid, donation(id, receiveddate, recordedby)',
        )
        .eq('itemid', itemId);

    for (final r in donationRows) {
      final donation =
          r['donation']
              as Map<String, dynamic>?;

      if (donation == null) {
        continue;
      }

      movements.add(
        StockMovement(
          id: '${donation['id']}-$itemId',
          date: DateTime.parse(
            donation['receiveddate'] as String,
          ),
          direction:
              StockDirection.stockIn,
          qty:
              _toDouble(r['qty']) ?? 0,
          unitAbbr:
              r['qty_unit'] == 'package_unit'
                  ? packageUnitAbbr
                  : purchaseUnitAbbr,
          typeLabel: 'Donated',
          recordedByName:
              users[donation['recordedby']] ??
              'Unknown user',
        ),
      );
    }

    // =========================================================================
    // TREATMENT
    // =========================================================================

    final treatmentRows = await _client
        .from('treatment_item')
        .select(
          'treatid, dispensed_qty, dispense_unit, consumeddate, '
          'recordedby, treatment(id, name)',
        )
        .eq('itemid', itemId);

    for (final r in treatmentRows) {
      final treatment =
          r['treatment']
              as Map<String, dynamic>?;

      final dispenseUnit =
          r['dispense_unit']
              as String?;

      movements.add(
        StockMovement(
          id: '${r['treatid']}-$itemId',
          date: DateTime.parse(
            r['consumeddate'] as String,
          ),
          direction:
              StockDirection.stockOut,
          qty:
              _toDouble(
                    r['dispensed_qty'],
                  ) ??
                  0,
          unitAbbr:
              (dispenseUnit == null
                      ? null
                      : units[dispenseUnit]) ??
                  purchaseUnitAbbr,
          typeLabel: 'Treatment',
          treatmentId:
              r['treatid'] as String?,
          treatmentName:
              treatment?['name']
                      as String? ??
                  'Unknown treatment',
          recordedByName:
              users[r['recordedby']] ??
              'Unknown user',
        ),
      );
    }

    // =========================================================================
    // DISPENSE: WASTE / EXPIRED / ADJUSTMENT
    // =========================================================================

    final stockOutRows = await _client
        .from('stock_out')
        .select(
          'id, qty, qtyunit, reason, recordeddate, recordedby',
        )
        .eq('itemid', itemId);

    for (final r in stockOutRows) {
      final qtyUnit =
          qtyUnitFromString(
        (r['qtyunit'] as String?) ??
            'purchase_unit',
      );

      movements.add(
        StockMovement(
          id: r['id'] as String,
          date: DateTime.parse(
            r['recordeddate'] as String,
          ),
          direction:
              StockDirection.stockOut,
          qty:
              _toDouble(r['qty']) ?? 0,
          unitAbbr:
              qtyUnit == QtyUnit.packageUnit
                  ? packageUnitAbbr
                  : purchaseUnitAbbr,
          typeLabel:
              _stockOutReasonLabel(
            stockOutReasonFromString(
              r['reason'] as String,
            ),
          ),
          recordedByName:
              users[r['recordedby']] ??
              'Unknown user',
        ),
      );
    }

    movements.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return movements;
  }

  // ==========================================================================
  // STOCK OUT DATES
  // ==========================================================================

  @override
  Future<List<DateTime>> fetchStockOutDates() async {
    final rows = await _client
        .from('stock_out')
        .select('recordeddate');

    return [
      for (final row in rows)
        DateTime.parse(
          row['recordeddate'] as String,
        ).toLocal(),
    ];
  }
}