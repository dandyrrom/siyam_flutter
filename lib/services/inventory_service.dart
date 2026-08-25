import '../mock/mock_database.dart';
import '../models/inventory_item.dart';
import '../models/qty_unit.dart';
import '../models/stock_movement.dart';
import '../models/stock_out.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'supabase/supabase_inventory_service_history_fixed.dart';

/// Data-access interface for inventory items and stock movements.
///
/// The factory resolves to either the mock or Supabase implementation
/// depending on [kUseMock].
abstract interface class InventoryService {
  factory InventoryService() =>
      kUseMock
          ? MockInventoryService()
          : SupabaseInventoryService();

  Future<List<InventoryItem>> fetchItems();

  Future<InventoryItem?> fetchItem(
    String itemId,
  );

  Future<InventoryItem> createItem({
    required String itemName,
    required String pCategoryId,
    required String purchaseUnitId,
    String? sCategoryId,
    String? packageUnitId,
    double? packageQuantity,
    String? dispenseUnitId,
    StockCountMode? stockCountMode,
    double initialQty,
  });

  Future<InventoryItem> updateDetails({
    required String itemId,
    String? itemName,
    String? pCategoryId,
    String? sCategoryId,
    String? purchaseUnitId,
    StockCountMode? stockCountMode,
  });

  Future<InventoryItem> adjustStock({
    required String itemId,
    required double delta,
  });

  Future<InventoryItem> deductPackageStock({
    required String itemId,
    required double delta,
  });

  // ==========================================================================
  // STOCK IN
  // ==========================================================================

  /// Records one purchase_item/donation_item stock-in batch and applies its
  /// stock effect.
  ///
  /// [qtyUnit] decides which pool moves:
  ///
  /// purchaseUnit:
  ///   Whole containers such as:
  ///   - bag
  ///   - bottle
  ///   - box
  ///
  /// packageUnit:
  ///   Loose contents such as:
  ///   - kg
  ///   - ml
  ///   - tablet
  ///
  /// Purchase-unit stock-in moves both pools.
  /// Package-unit stock-in only adds to package stock.
  Future<InventoryItem> stockIn({
    required String itemId,
    required double qty,
    required QtyUnit qtyUnit,
  });

  // ==========================================================================
  // FEFO DEDUCTION
  // ==========================================================================

  /// Draws down [qty] already expressed in canonical terms:
  ///
  /// - package_unit for an item with a package breakdown
  /// - purchase_unit otherwise
  ///
  /// Batches are drained in FEFO order.
  Future<InventoryItem> deductFefo({
    required String itemId,
    required double qty,
  });

  // ==========================================================================
  // STOCK OUT
  // ==========================================================================

  /// Records a non-treatment Stock Out.
  ///
  /// Unlike the old implementation, Stock Out can now be entered using:
  ///
  /// [QtyUnit.purchaseUnit]
  ///   Whole container:
  ///   bag, bottle, box, sack, etc.
  ///
  /// [QtyUnit.packageUnit]
  ///   Loose/base amount:
  ///   kg, ml, tablet, etc.
  ///
  /// Examples:
  ///
  /// Dog Food:
  ///   1 bag = 10 kg
  ///
  ///   qty: 1
  ///   qtyUnit: purchaseUnit
  ///   → removes 1 bag / 10 kg
  ///
  ///   qty: 3
  ///   qtyUnit: packageUnit
  ///   → removes 3 kg only
  ///
  Future<InventoryItem> stockOut({
    required String itemId,
    required double qty,

    // ========================================================================
    // STOCK OUT UNIT
    // ========================================================================
    required QtyUnit qtyUnit,

    required StockOutReason reason,
    required String recordedByUserId,
  });

  Future<void> deleteItem(
    String itemId,
  );

  Future<List<StockMovement>> fetchStockHistory(
    String itemId,
  );

  /// One date per stock_out row.
  ///
  /// Used by the manager dashboard usage chart.
  Future<List<DateTime>> fetchStockOutDates();
}

// =============================================================================
// MOCK INVENTORY SERVICE
// =============================================================================

class MockInventoryService
    implements InventoryService {
  final MockDatabase _db =
      MockDatabase.instance;

  // ==========================================================================
  // CONVERT MOCK ROW → INVENTORY ITEM
  // ==========================================================================

  InventoryItem _toInventoryItem(
    ItemRow row,
  ) {
    final hasPurchaseHistory =
        _db.purchaseItems.any(
      (p) => p.itemId == row.id,
    );

    final hasDonationHistory =
        _db.donationItems.any(
      (d) => d.itemId == row.id,
    );

    // =========================================================================
    // LIFETIME STOCK OUT NORMALIZATION
    // =========================================================================
    //
    // stock_out can now contain BOTH:
    //
    //   purchase_unit quantities
    //   package_unit quantities
    //
    // We cannot simply add:
    //
    //   1 bag + 3 kg
    //
    // because they are different units.
    //
    // InventoryItem.lifetimeStockOutQty historically represents
    // purchase-unit-equivalent stock.
    //
    // Therefore package-unit Stock Outs are converted back into their
    // purchase-unit equivalent before being accumulated.
    //
    // Example:
    //
    //   1 bag = 10 kg
    //   Stock Out = 5 kg
    //
    //   purchase-unit equivalent = 0.5 bag
    //
    final lifetimeStockOutQty =
        _db.stockOuts
            .where(
              (s) => s.itemId == row.id,
            )
            .fold<double>(
              0.0,
              (sum, stockOut) {
                if (stockOut.qtyUnit ==
                        QtyUnit.packageUnit &&
                    row.packageQuantity !=
                        null &&
                    row.packageQuantity! >
                        0) {
                  return sum +
                      (stockOut.qty /
                          row.packageQuantity!);
                }

                return sum +
                    stockOut.qty;
              },
            );

    final lifetimeTreatmentQty =
        _db.treatmentItems
            .where(
              (t) => t.itemId == row.id,
            )
            .fold<double>(
              0.0,
              (
                sum,
                treatment,
              ) =>
                  sum +
                  treatment.dispensedQty,
            );

    final pCategory =
        firstWhereOrNull(
      _db.primaryCategories,
      (c) =>
          c.id == row.pCategoryId,
    );

    final sCategory =
        row.sCategoryId == null
            ? null
            : firstWhereOrNull(
                _db.subcategories,
                (c) =>
                    c.id ==
                    row.sCategoryId,
              );

    final purchaseUnit =
        firstWhereOrNull(
      _db.units,
      (u) =>
          u.id ==
          row.purchaseUnitId,
    );

    final packageUnit =
        row.packageUnitId == null
            ? null
            : firstWhereOrNull(
                _db.units,
                (u) =>
                    u.id ==
                    row.packageUnitId,
              );

    final dispenseUnit =
        row.dispenseUnitId == null
            ? null
            : firstWhereOrNull(
                _db.units,
                (u) =>
                    u.id ==
                    row.dispenseUnitId,
              );

    return InventoryItem(
      itemId: row.id,
      itemName: row.name,

      pCategoryId:
          row.pCategoryId,
      pCategoryName:
          pCategory?.type ??
          'Unknown category',

      sCategoryId:
          row.sCategoryId,
      sCategoryName:
          sCategory?.type,

      purchaseUnitId:
          row.purchaseUnitId,
      purchaseUnitAbbr:
          purchaseUnit?.abbrName ??
          '',

      packageUnitId:
          row.packageUnitId,
      packageUnitAbbr:
          packageUnit?.abbrName,

      packageQuantity:
          row.packageQuantity,

      dispenseUnitId:
          row.dispenseUnitId,
      dispenseUnitAbbr:
          dispenseUnit?.abbrName,

      stockQty:
          row.purchaseStocks,

      packageStockQty:
          row.packageStocks,

      totalPackageStockIns:
          row.totalPackageStockIns,

      stockCountMode:
          stockCountModeFromString(
        row.stockCountMode,
      ),

      hasPurchaseHistory:
          hasPurchaseHistory,

      hasDonationHistory:
          hasDonationHistory,

      lifetimeStockOutQty:
          lifetimeStockOutQty,

      lifetimeTreatmentQty:
          lifetimeTreatmentQty,
    );
  }

  // ==========================================================================
  // REQUIRE ITEM ROW
  // ==========================================================================

  ItemRow _requireRow(
    String itemId,
  ) {
    final row =
        firstWhereOrNull(
      _db.items,
      (i) => i.id == itemId,
    );

    if (row == null) {
      throw Exception(
        'Item not found',
      );
    }

    return row;
  }

  // ==========================================================================
  // USER NAME
  // ==========================================================================

  String _userName(
    String userId,
  ) {
    final user =
        firstWhereOrNull(
      _db.users,
      (u) =>
          u.userId == userId,
    );

    return user?.fullName ??
        'Unknown user';
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
  // FETCH ITEMS
  // ==========================================================================

  @override
  Future<List<InventoryItem>>
      fetchItems() async {
    final list =
        _db.items
            .map(
              _toInventoryItem,
            )
            .toList();

    list.sort(
      (a, b) =>
          a.itemName.compareTo(
        b.itemName,
      ),
    );

    return list;
  }

  // ==========================================================================
  // FETCH ITEM
  // ==========================================================================

  @override
  Future<InventoryItem?> fetchItem(
    String itemId,
  ) async {
    final row =
        firstWhereOrNull(
      _db.items,
      (i) => i.id == itemId,
    );

    return row == null
        ? null
        : _toInventoryItem(
            row,
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
    final row =
        ItemRow(
      id: newMockId('item'),
      name: itemName,

      pCategoryId:
          pCategoryId,

      sCategoryId:
          sCategoryId,

      purchaseUnitId:
          purchaseUnitId,

      packageUnitId:
          packageUnitId,

      packageQuantity:
          packageQuantity,

      dispenseUnitId:
          dispenseUnitId,

      purchaseStocks:
          initialQty,

      packageStocks:
          packageQuantity == null
              ? null
              : initialQty *
                  packageQuantity,

      stockCountMode:
          stockCountMode == null
              ? null
              : stockCountModeToString(
                  stockCountMode,
                ),
    );

    _db.items.add(row);

    DataChangeBus.instance
        .ping();

    return _toInventoryItem(
      row,
    );
  }

  // ==========================================================================
  // UPDATE ITEM DETAILS
  // ==========================================================================

  @override
  Future<InventoryItem>
      updateDetails({
    required String itemId,
    String? itemName,
    String? pCategoryId,
    String? sCategoryId,
    String? purchaseUnitId,
    StockCountMode? stockCountMode,
  }) async {
    final row =
        _requireRow(itemId);

    if (itemName != null) {
      row.name = itemName;
    }

    if (pCategoryId != null &&
        pCategoryId !=
            row.pCategoryId) {
      row.pCategoryId =
          pCategoryId;

      // The old subcategory may belong to the previous
      // primary category, so clear it.
      row.sCategoryId = null;
    }

    if (sCategoryId != null) {
      row.sCategoryId =
          sCategoryId;
    }

    if (purchaseUnitId !=
        null) {
      row.purchaseUnitId =
          purchaseUnitId;
    }

    if (stockCountMode !=
        null) {
      row.stockCountMode =
          stockCountModeToString(
        stockCountMode,
      );
    }

    DataChangeBus.instance
        .ping();

    return _toInventoryItem(
      row,
    );
  }

  // ==========================================================================
  // ADJUST WHOLE-CONTAINER STOCK
  // ==========================================================================

  /// Adjusts purchase_stocks by [delta].
  ///
  /// Positive = Stock In
  /// Negative = Stock Out
  ///
  /// When an item has a package breakdown, package stock is moved by the
  /// corresponding amount as well.
  @override
  Future<InventoryItem>
      adjustStock({
    required String itemId,
    required double delta,
  }) async {
    final row =
        _requireRow(itemId);

    final next =
        row.purchaseStocks +
        delta;

    if (next < 0) {
      throw Exception(
        'Not enough stock: only '
        '${formatQty(row.purchaseStocks)} left',
      );
    }

    row.purchaseStocks =
        next;

    if (row.packageQuantity !=
        null) {
      final currentPackage =
          row.packageStocks ??
          (
            row.purchaseStocks -
                delta
          ) *
              row.packageQuantity!;

      row.packageStocks =
          currentPackage +
          delta *
              row.packageQuantity!;
    }

    DataChangeBus.instance
        .ping();

    return _toInventoryItem(
      row,
    );
  }

  // ==========================================================================
  // DEDUCT / ADJUST PACKAGE STOCK
  // ==========================================================================

  /// Adjusts package-unit stock only.
  ///
  /// This is used for loose quantities such as:
  ///
  /// - kg
  /// - ml
  /// - tablet
  ///
  /// It deliberately does NOT change purchase_stocks.
  @override
  Future<InventoryItem>
      deductPackageStock({
    required String itemId,
    required double delta,
  }) async {
    final row =
        _requireRow(itemId);

    final current =
        row.packageStocks ??
        (
          row.packageQuantity ==
                  null
              ? 0
              : row.purchaseStocks *
                  row.packageQuantity!
        );

    final next =
        current + delta;

    if (next < 0) {
      throw Exception(
        'Not enough stock: only '
        '${formatQty(current)} left',
      );
    }

    row.packageStocks =
        next;

    DataChangeBus.instance
        .ping();

    return _toInventoryItem(
      row,
    );
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
    final row =
        _requireRow(itemId);

    // ========================================================================
    // WHOLE-CONTAINER STOCK IN
    // ========================================================================

    if (qtyUnit ==
            QtyUnit.purchaseUnit ||
        row.packageQuantity ==
            null) {
      return adjustStock(
        itemId: itemId,
        delta: qty,
      );
    }

    // ========================================================================
    // PACKAGE / LOOSE-UNIT STOCK IN
    // ========================================================================
    //
    // Example:
    //
    // Dog Food:
    //   bag = purchase unit
    //   kg  = package unit
    //
    // Donation:
    //   +8 kg
    //
    // Only package stock changes.
    //
    final current =
        row.packageStocks ??
        (
          row.purchaseStocks *
          row.packageQuantity!
        );

    row.packageStocks =
        current + qty;

    row.totalPackageStockIns +=
        qty;

    DataChangeBus.instance
        .ping();

    return _toInventoryItem(
      row,
    );
  }

  // ==========================================================================
  // MOCK FEFO BATCH DRAIN
  // ==========================================================================

  /// Drains canonical quantity from the mock purchase/donation batches in
  /// expiry order.
  ///
  /// Canonical means:
  ///
  /// - package unit if the item has a package breakdown
  /// - purchase unit otherwise
  ///
  void _drainBatchesFefo(
    String itemId,
    double canonicalQty,
  ) {
    final batches =
        <
            (
              DateTime?,
              double Function(),
              void Function(double),
            )
        >[
      for (final p
          in _db.purchaseItems.where(
        (p) =>
            p.itemId == itemId,
      ))
        (
          p.expiryDate,
          () => p.qtyRemaining,
          (v) =>
              p.qtyRemaining = v,
        ),

      for (final d
          in _db.donationItems.where(
        (d) =>
            d.itemId == itemId,
      ))
        (
          d.expiryDate,
          () => d.qtyRemaining,
          (v) =>
              d.qtyRemaining = v,
        ),
    ]..sort(
        (
          a,
          b,
        ) {
          final aExpiry =
              a.$1;

          final bExpiry =
              b.$1;

          if (aExpiry == null &&
              bExpiry == null) {
            return 0;
          }

          if (aExpiry == null) {
            return 1;
          }

          if (bExpiry == null) {
            return -1;
          }

          return aExpiry.compareTo(
            bExpiry,
          );
        },
      );

    var remaining =
        canonicalQty;

    for (final (
          _,
          getRemaining,
          setRemaining,
        ) in batches) {
      if (remaining <= 0) {
        break;
      }

      final available =
          getRemaining();

      if (available <= 0) {
        continue;
      }

      final draw =
          remaining < available
              ? remaining
              : available;

      setRemaining(
        available - draw,
      );

      remaining -= draw;
    }
  }

  // ==========================================================================
  // FEFO DEDUCTION
  // ==========================================================================

  @override
  Future<InventoryItem>
      deductFefo({
    required String itemId,
    required double qty,
  }) async {
    final row =
        _requireRow(itemId);

    _drainBatchesFefo(
      itemId,
      qty,
    );

    if (row.packageQuantity !=
        null) {
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

  // ==========================================================================
  // STOCK OUT
  // ==========================================================================

  @override
  Future<InventoryItem> stockOut({
    required String itemId,
    required double qty,

    // ========================================================================
    // STOCK OUT UNIT
    // ========================================================================
    required QtyUnit qtyUnit,

    required StockOutReason reason,
    required String recordedByUserId,
  }) async {
    if (qty <= 0) {
      throw Exception(
        'Quantity must be greater than 0.',
      );
    }

    final row =
        _requireRow(itemId);

    final item =
        _toInventoryItem(row);

    // =========================================================================
    // PACKAGE-UNIT STOCK OUT
    // =========================================================================
    //
    // Example:
    //
    // Dog Food:
    //   purchase unit = bag
    //   package unit  = kg
    //
    // Current:
    //   8 kg
    //
    // Stock Out:
    //   3 kg
    //
    // Result:
    //   package stock = 5 kg
    //   whole-container stock is NOT decremented
    //
    if (qtyUnit ==
        QtyUnit.packageUnit) {
      // ======================================================================
      // PACKAGE UNIT MUST EXIST
      // ======================================================================

      if (row.packageQuantity ==
              null ||
          row.packageUnitId ==
              null) {
        throw Exception(
          '${item.itemName} does not have a smaller '
          'package unit configured.',
        );
      }

      final currentPackage =
          row.packageStocks ??
          (
            row.purchaseStocks *
            row.packageQuantity!
          );

      // ======================================================================
      // PACKAGE-UNIT AVAILABILITY VALIDATION
      // ======================================================================

      if (qty >
          currentPackage) {
        throw Exception(
          'Not enough stock. Only '
          '${formatQty(currentPackage)} '
          '${item.packageUnitAbbr ?? item.purchaseUnitAbbr} '
          'available.',
        );
      }

      // ======================================================================
      // SAVE STOCK OUT AUDIT ROW
      // ======================================================================
      //
      // Save the ORIGINAL staff-entered amount and unit.
      //
      // Example:
      //
      // qty     = 3
      // qtyUnit = packageUnit
      //
      // Means 3 kg / 3 ml / 3 tablets, depending on item configuration.
      //
      _db.stockOuts.add(
        StockOut(
          id: newMockId(
            'stockout',
          ),
          itemId: itemId,
          qty: qty,
          qtyUnit:
              QtyUnit.packageUnit,
          reason: reason,
          recordedDate:
              DateTime.now(),
          recordedByUserId:
              recordedByUserId,
        ),
      );

      // ======================================================================
      // FEFO BATCH DEDUCTION
      // ======================================================================
      //
      // qty is already canonical because package_unit is the canonical unit
      // when a package breakdown exists.
      //
      _drainBatchesFefo(
        itemId,
        qty,
      );

      // ======================================================================
      // DEDUCT LOOSE / PACKAGE STOCK ONLY
      // ======================================================================

      return deductPackageStock(
        itemId: itemId,
        delta: -qty,
      );
    }

    // =========================================================================
    // PURCHASE-UNIT STOCK OUT
    // =========================================================================
    //
    // Example:
    //
    // Dog Food:
    //   1 bag = 10 kg
    //
    // Stock Out:
    //   1 bag
    //
    // Result:
    //
    //   purchase stock -1 bag
    //   package stock  -10 kg
    //
    // =========================================================================

    // -------------------------------------------------------------------------
    // CHECK WHOLE-CONTAINER STOCK
    // -------------------------------------------------------------------------

    if (qty >
        row.purchaseStocks) {
      throw Exception(
        'Not enough stock. Only '
        '${formatQty(row.purchaseStocks)} '
        '${item.purchaseUnitAbbr} '
        'available.',
      );
    }

    // =========================================================================
    // CONVERT PURCHASE UNIT → CANONICAL UNIT
    // =========================================================================
    //
    // Example:
    //
    // 1 bag × 10 kg
    // = 10 kg canonical quantity
    //
    final canonicalQty =
        row.packageQuantity !=
                null
            ? qty *
                row.packageQuantity!
            : qty;

    // =========================================================================
    // VALIDATE PACKAGE STOCK BEFORE REMOVING A WHOLE CONTAINER
    // =========================================================================
    //
    // This matters when treatment usage has already consumed some of the
    // package contents.
    //
    // Example:
    //
    // 1 bottle = 500 ml
    // package stock remaining = 300 ml
    //
    // Trying to Stock Out 1 complete bottle would require 500 ml, so the
    // transaction is rejected rather than allowing package stock to become
    // negative.
    //
    if (row.packageQuantity !=
        null) {
      final currentPackage =
          row.packageStocks ??
          (
            row.purchaseStocks *
            row.packageQuantity!
          );

      if (canonicalQty >
          currentPackage) {
        throw Exception(
          'Not enough '
          '${item.packageUnitAbbr ?? 'package-unit'} '
          'stock. '
          'Only ${formatQty(currentPackage)} '
          '${item.packageUnitAbbr ?? ''} available. '
          '${formatQty(qty)} ${item.purchaseUnitAbbr} '
          'requires ${formatQty(canonicalQty)} '
          '${item.packageUnitAbbr ?? ''}.',
        );
      }
    }

    // =========================================================================
    // SAVE STOCK OUT AUDIT ROW
    // =========================================================================

    _db.stockOuts.add(
      StockOut(
        id: newMockId(
          'stockout',
        ),
        itemId: itemId,
        qty: qty,
        qtyUnit:
            QtyUnit.purchaseUnit,
        reason: reason,
        recordedDate:
            DateTime.now(),
        recordedByUserId:
            recordedByUserId,
      ),
    );

    // =========================================================================
    // FEFO BATCH DEDUCTION
    // =========================================================================
    //
    // Batches are drained in canonical terms.
    //
    _drainBatchesFefo(
      itemId,
      canonicalQty,
    );

    // =========================================================================
    // DEDUCT WHOLE-CONTAINER STOCK
    // =========================================================================
    //
    // adjustStock() also deducts the package-unit equivalent.
    //
    return adjustStock(
      itemId: itemId,
      delta: -qty,
    );
  }

  // ==========================================================================
  // DELETE ITEM
  // ==========================================================================

  @override
  Future<void> deleteItem(
    String itemId,
  ) async {
    _db.items.removeWhere(
      (i) => i.id == itemId,
    );

    DataChangeBus.instance
        .ping();
  }

  // ==========================================================================
  // STOCK MOVEMENT HISTORY
  // ==========================================================================

  /// Unified movement history for one item.
  ///
  /// Each Stock Out now keeps its ORIGINAL unit.
  ///
  /// Example:
  ///
  /// Waste      -3 kg
  /// Expired    -1 bag
  /// Adjustment -500 ml
  ///
  @override
  Future<List<StockMovement>>
      fetchStockHistory(
    String itemId,
  ) async {
    final item =
        await fetchItem(
      itemId,
    );

    final purchaseUnitAbbr =
        item?.purchaseUnitAbbr ??
        '';

    final packageUnitAbbr =
        item?.packageUnitAbbr ??
        purchaseUnitAbbr;

    final movements =
        <StockMovement>[];

    // =========================================================================
    // PURCHASE MOVEMENTS
    // =========================================================================

    for (final row
        in _db.purchaseItems.where(
      (p) =>
          p.itemId == itemId,
    )) {
      final purchase =
          firstWhereOrNull(
        _db.purchases,
        (p) =>
            p.id ==
            row.purchaseId,
      );

      if (purchase == null) {
        continue;
      }

      movements.add(
        StockMovement(
          id:
              '${purchase.id}-${row.itemId}',
          date:
              purchase.receivedDate,
          direction:
              StockDirection.stockIn,
          qty: row.qty,
          unitAbbr:
              purchaseUnitAbbr,
          typeLabel:
              'Purchased',
          recordedByName:
              _userName(
            purchase.recordedByUserId,
          ),
        ),
      );
    }

    // =========================================================================
    // DONATION MOVEMENTS
    // =========================================================================

    for (final row
        in _db.donationItems.where(
      (d) =>
          d.itemId == itemId,
    )) {
      final donation =
          firstWhereOrNull(
        _db.donations,
        (d) =>
            d.id ==
            row.donId,
      );

      if (donation == null) {
        continue;
      }

      movements.add(
        StockMovement(
          id:
              '${donation.id}-${row.itemId}',
          date:
              donation.receivedDate,
          direction:
              StockDirection.stockIn,
          qty: row.qty,

          unitAbbr:
              row.qtyUnit ==
                      QtyUnit.packageUnit
                  ? packageUnitAbbr
                  : purchaseUnitAbbr,

          typeLabel:
              'Donated',

          recordedByName:
              _userName(
            donation.recordedByUserId,
          ),
        ),
      );
    }

    // =========================================================================
    // TREATMENT MOVEMENTS
    // =========================================================================

    for (final row
        in _db.treatmentItems.where(
      (t) =>
          t.itemId == itemId,
    )) {
      final treatment =
          firstWhereOrNull(
        _db.treatments,
        (t) =>
            t.id ==
            row.treatId,
      );

      final unit =
          firstWhereOrNull(
        _db.units,
        (u) =>
            u.id ==
            row.dispenseUnitId,
      );

      movements.add(
        StockMovement(
          id:
              '${row.treatId}-${row.itemId}',
          date:
              row.consumedDate,
          direction:
              StockDirection.stockOut,
          qty:
              row.dispensedQty,
          unitAbbr:
              unit?.abbrName ??
              purchaseUnitAbbr,
          typeLabel:
              'Treatment',
          treatmentId:
              row.treatId,
          treatmentName:
              treatment?.name ??
              'Unknown treatment',
          recordedByName:
              _userName(
            row.recordedByUserId,
          ),
        ),
      );
    }

    // =========================================================================
    // NON-TREATMENT STOCK OUT MOVEMENTS
    // =========================================================================
    //
    // IMPORTANT:
    //
    // Previously every Stock Out was displayed using purchaseUnitAbbr.
    //
    // That would make:
    //
    // qty = 3
    // qtyUnit = packageUnit
    //
    // incorrectly appear as:
    //
    // 3 bags
    //
    // It must instead appear as:
    //
    // 3 kg
    //
    for (final row
        in _db.stockOuts.where(
      (s) =>
          s.itemId == itemId,
    )) {
      movements.add(
        StockMovement(
          id: row.id,
          date:
              row.recordedDate,
          direction:
              StockDirection.stockOut,
          qty: row.qty,

          // ===================================================================
          // CORRECT STOCK OUT UNIT DISPLAY
          // ===================================================================
          unitAbbr:
              row.qtyUnit ==
                      QtyUnit.packageUnit
                  ? packageUnitAbbr
                  : purchaseUnitAbbr,

          typeLabel:
              _stockOutReasonLabel(
            row.reason,
          ),

          recordedByName:
              _userName(
            row.recordedByUserId,
          ),
        ),
      );
    }

    movements.sort(
      (a, b) =>
          b.date.compareTo(
        a.date,
      ),
    );

    return movements;
  }

  // ==========================================================================
  // STOCK OUT DATES
  // ==========================================================================

  @override
  Future<List<DateTime>>
      fetchStockOutDates() async {
    return _db.stockOuts
        .map(
          (s) =>
              s.recordedDate,
        )
        .toList();
  }
}