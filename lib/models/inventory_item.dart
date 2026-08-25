import 'qty_unit.dart';

enum StockLevel {
  inStock,
  needsRestock,
  low,
  outOfStock,
}

/// Default number of days used to classify a batch as "expiring soon".
///
/// This can later be moved into Manager Settings if you want the shelter
/// to configure its own warning period.
const int expiryWarningDays = 30;

/// Global reorder threshold in purchase-unit equivalents.
double lowStockPurchaseUnitThreshold = 10;

enum AcquisitionSource {
  purchased,
  donated,
  both,
  none,
}

/// Formats quantities for display.
///
/// Examples:
/// 5.0       -> 5
/// 3.8       -> 3.8
/// 4.175000  -> 4.175
///
/// This is display-only and does not alter stored database precision.
String formatQty(double qty) {
  if (!qty.isFinite) return qty.toString();

  if ((qty - qty.roundToDouble()).abs() < 0.000000001) {
    return qty.round().toString();
  }

  return qty
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Inventory item joined with its category/unit information.
///
/// IMPORTANT INVENTORY ARCHITECTURE:
///
/// public.item still contains the old aggregate stock fields:
///
/// - total_purchase_stocks
/// - total_package_stocks
///
/// These are currently kept synchronized for compatibility with older
/// screens and workflows.
///
/// However, when inventory_batch records exist, the physical batch ledger is
/// treated as the more authoritative source for current usable stock,
/// expired stock, and expiry information.
class InventoryItem {
  final String itemId;
  final String itemName;

  final String pCategoryId;
  final String pCategoryName;

  final String? sCategoryId;
  final String? sCategoryName;

  final String purchaseUnitId;
  final String purchaseUnitAbbr;

  final String? packageUnitId;
  final String? packageUnitAbbr;
  final double? packageQuantity;

  final String? dispenseUnitId;
  final String? dispenseUnitAbbr;

  // ===========================================================================
  // LEGACY / CACHED ITEM AGGREGATES
  // ===========================================================================

  /// total_purchase_stocks.
  ///
  /// This remains for compatibility but should not be treated as the final
  /// authority when batch inventory exists.
  final double stockQty;

  /// total_package_stocks.
  ///
  /// Also maintained while older screens/services are still being migrated.
  final double? packageStockQty;

  /// Cumulative package-unit quantity ever stocked directly.
  final double totalPackageStockIns;

  final StockCountMode? stockCountMode;

  final bool hasPurchaseHistory;
  final bool hasDonationHistory;

  final double lifetimeStockOutQty;
  final double lifetimeTreatmentQty;

  // ===========================================================================
  // BATCH-DERIVED CURRENT INVENTORY
  // ===========================================================================

  /// True when this item has at least one inventory_batch record.
  ///
  /// When true, batch-derived stock should be preferred over item aggregates.
  final bool hasBatchHistory;

  /// Current usable inventory derived from inventory_batch.
  ///
  /// Canonical unit:
  ///
  /// - package unit when packageQuantity exists
  /// - purchase unit otherwise
  ///
  /// Excludes:
  ///
  /// - expired batches
  /// - quarantined batches
  /// - depleted batches
  final double usableBatchStockQty;

  /// Physical stock that has already expired but still exists in the shelter
  /// and is waiting for staff to record an Expired dispense/removal.
  ///
  /// Uses the same canonical unit as [usableBatchStockQty].
  final double expiredBatchStockQty;

  /// Earliest expiry date among CURRENT USABLE batches.
  ///
  /// Expired and quarantined batches are ignored.
  ///
  /// Null means:
  ///
  /// - no usable dated batches exist, or
  /// - the item's usable batches do not have expiry dates.
  final DateTime? nearestExpiryDate;

  const InventoryItem({
    required this.itemId,
    required this.itemName,
    required this.pCategoryId,
    required this.pCategoryName,
    this.sCategoryId,
    this.sCategoryName,
    required this.purchaseUnitId,
    required this.purchaseUnitAbbr,
    this.packageUnitId,
    this.packageUnitAbbr,
    this.packageQuantity,
    this.dispenseUnitId,
    this.dispenseUnitAbbr,
    required this.stockQty,
    this.packageStockQty,
    this.totalPackageStockIns = 0,
    this.stockCountMode,
    this.hasPurchaseHistory = false,
    this.hasDonationHistory = false,
    this.lifetimeStockOutQty = 0,
    this.lifetimeTreatmentQty = 0,

    // Batch-derived fields use safe defaults so mock/older constructors
    // continue compiling while we migrate the rest of the application.
    this.hasBatchHistory = false,
    this.usableBatchStockQty = 0,
    this.expiredBatchStockQty = 0,
    this.nearestExpiryDate,
  });

  // ===========================================================================
  // ACQUISITION SOURCE
  // ===========================================================================

  AcquisitionSource get acquisitionSource {
    if (hasPurchaseHistory && hasDonationHistory) {
      return AcquisitionSource.both;
    }

    if (hasPurchaseHistory) {
      return AcquisitionSource.purchased;
    }

    if (hasDonationHistory) {
      return AcquisitionSource.donated;
    }

    return AcquisitionSource.none;
  }

  // ===========================================================================
  // ITEM DISPLAY
  // ===========================================================================

  String? get packageLabel {
    if (packageQuantity == null || packageUnitAbbr == null) {
      return null;
    }

    return '(${formatQty(packageQuantity!)} '
        '$packageUnitAbbr per $purchaseUnitAbbr)';
  }

  String get itemCategory {
    return sCategoryName == null
        ? pCategoryName
        : '$pCategoryName > $sCategoryName';
  }

  String get itemUom => purchaseUnitAbbr;

  // ===========================================================================
  // UNIT CONFIGURATION
  // ===========================================================================

  bool get hasPackageBreakdown {
    return packageQuantity != null &&
        packageQuantity! > 0 &&
        packageUnitAbbr != null;
  }

  bool get stockOutIsDeductible {
    return dispenseUnitId == null ||
        dispenseUnitId == packageUnitId;
  }

  StockCountMode get effectiveCountMode {
    if (stockCountMode != null) {
      return stockCountMode!;
    }

    return (packageQuantity != null && stockOutIsDeductible)
        ? StockCountMode.packageUnit
        : StockCountMode.purchaseUnit;
  }

  // ===========================================================================
  // CURRENT USABLE STOCK
  // ===========================================================================
  //
  // This is the important new source-of-truth getter for UI pages.
  //
  // If inventory batches exist:
  //   use batch-derived usable stock.
  //
  // If this is legacy/mock data without batches:
  //   fall back to the old aggregate values.
  // ===========================================================================

  double get currentUsableStockQty {
    if (hasBatchHistory) {
      return usableBatchStockQty;
    }

    if (hasPackageBreakdown) {
      return packageStockQty ??
          stockQty * packageQuantity!;
    }

    return stockQty;
  }

  String get currentUsableStockUnit {
    if (hasPackageBreakdown) {
      return packageUnitAbbr!;
    }

    return purchaseUnitAbbr;
  }

  /// Current usable stock expressed back in purchase-unit equivalents.
  ///
  /// Example:
  ///
  /// 25 kg remaining
  /// 1 bag = 10 kg
  ///
  /// = 2.5 bag equivalent.
  double get currentPurchaseUnitEquivalent {
    if (hasPackageBreakdown) {
      return currentUsableStockQty / packageQuantity!;
    }

    return currentUsableStockQty;
  }

  // ===========================================================================
  // DISPLAY STOCK
  // ===========================================================================

  double get displayStockQty {
    // -------------------------------------------------------------------------
    // BATCH-AWARE DISPLAY
    // -------------------------------------------------------------------------

    if (hasBatchHistory) {
      if (effectiveCountMode == StockCountMode.packageUnit &&
          hasPackageBreakdown) {
        return usableBatchStockQty;
      }

      if (effectiveCountMode == StockCountMode.purchaseUnit &&
          hasPackageBreakdown) {
        return usableBatchStockQty / packageQuantity!;
      }

      return usableBatchStockQty;
    }

    // -------------------------------------------------------------------------
    // LEGACY FALLBACK
    // -------------------------------------------------------------------------

    return effectiveCountMode == StockCountMode.packageUnit
        ? (packageStockQty ?? stockQty * (packageQuantity ?? 1))
        : stockQty;
  }

  String get displayStockUnit {
    return effectiveCountMode == StockCountMode.packageUnit
        ? (packageUnitAbbr ?? purchaseUnitAbbr)
        : purchaseUnitAbbr;
  }

  // ===========================================================================
  // EXPIRY
  // ===========================================================================

  bool get hasExpiredStock => expiredBatchStockQty > 0;

  bool get hasNearestExpiry => nearestExpiryDate != null;

  /// Days remaining until the nearest usable dated batch expires.
  ///
  /// 0  = expires today
  /// 1  = expires tomorrow
  /// 30 = expires in 30 days
  int? get daysUntilNearestExpiry {
    final expiry = nearestExpiryDate;

    if (expiry == null) {
      return null;
    }

    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final expiryDay = DateTime(
      expiry.year,
      expiry.month,
      expiry.day,
    );

    return expiryDay.difference(today).inDays;
  }

  bool get expiresToday => daysUntilNearestExpiry == 0;

  bool get isExpiringSoon {
    final days = daysUntilNearestExpiry;

    return days != null &&
        days >= 0 &&
        days <= expiryWarningDays;
  }

  // ===========================================================================
  // STOCK STATUS
  // ===========================================================================

  /// An item containing only expired/quarantined stock is considered out of
  /// USABLE stock even if physical expired stock still awaits removal.
  bool get isOutOfStock => currentUsableStockQty <= 0;

  String get displayId {
    return 'ITM-${itemId.replaceAll('-', '').padRight(4, '0').substring(0, 4).toUpperCase()}';
  }

  /// Legacy/model-only physical availability status.
  ///
  /// IMPORTANT:
  /// Low Stock is now ROP-driven and cannot be calculated correctly inside
  /// this model because ROP depends on:
  ///
  /// - trailing 30-day usage
  /// - lead time
  /// - safety stock
  /// - optional item-specific ROP settings
  ///
  /// Pages that need Low Stock must use ReplenishmentService, which is the
  /// single source of truth for the ROP calculation.
  ///
  /// This getter therefore only answers the model-level question:
  /// "Is any usable stock physically available?"
  StockLevel get stockLevel {
    if (isOutOfStock) {
      return StockLevel.outOfStock;
    }

    return StockLevel.inStock;
  }
}
