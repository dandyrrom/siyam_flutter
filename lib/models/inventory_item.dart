import 'qty_unit.dart';

enum StockLevel { inStock, needsRestock, low, outOfStock }

/// Global reorder threshold (purchase-unit containers), backed by
/// `SYSTEM_SETTINGS.low_stock_threshold` (see updated_db.md). Mutable rather
/// than a per-item column -- set once at app startup and again whenever the
/// Manager saves the Settings page (see `SettingsService`); not a
/// ChangeNotifier since every reader re-evaluates on its own next build.
double lowStockPurchaseUnitThreshold = 10;

/// How an item's stock has been acquired, derived from whether it has any
/// rows in `purchase_item` and/or `donation_item` -- not a stored column.
/// An item can carry both (restocked once by purchase, once by donation), so
/// this is not a single fixed attribute of the item.
enum AcquisitionSource { purchased, donated, both, none }

/// Formats a quantity for display, trimming a trailing ".0" so whole
/// numbers don't render with a spurious decimal (stock is stored as a float
/// to allow fractional doses/stock, but most values are whole).
String formatQty(double qty) {
  return qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toString();
}

/// Mirrors a row in public.item, joined with its category/unit lookups.
///
/// Three independent units, per updated_db.md:
///  - [purchaseUnitId]/[purchaseUnitAbbr]: the container actually bought
///    (box, bottle, bag) -- [stockQty] (total_purchase_stocks) counts
///    containers physically present. Treatment usage does NOT change this;
///    it only changes via stock in/out (purchase, donation, waste, expired,
///    adjustment).
///  - [packageUnitId]/[packageUnitAbbr] + [packageQuantity]: what's inside
///    one purchase unit (1 box = 30 tablet, 1 bottle = 200 ml). Both null
///    for items with no breakdown (mop, food bowl).
///  - [dispenseUnitId]/[dispenseUnitAbbr]: the unit doses are actually
///    recorded in. Usually equals the package unit, but can differ (e.g.
///    package_unit=ml, dispense_unit=drop) with no stored conversion between
///    them -- see [stockOutIsDeductible].
///
/// [packageStockQty] (total_package_stocks) tracks the running remainder in
/// package-unit terms and IS decremented by treatment usage (for deductible
/// items with a package breakdown). It starts in sync with
/// `stockQty * packageQuantity` but diverges from it as doses are consumed
/// without a whole container being removed. It can also be increased
/// directly by a package-unit stock-in that never touches [stockQty] at all
/// (see [totalPackageStockIns]) -- there is deliberately no rolled-up
/// "unused/used/in-use" breakdown of these two pools; see [displayStockQty]
/// for the single figure shown to staff, and KNOWN_LIMITATIONS.md for why
/// that breakdown was removed rather than patched.
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
  final double stockQty; // total_purchase_stocks, in purchaseUnit terms
  final double? packageStockQty; // total_package_stocks, in packageUnit terms

  /// Cumulative loose package-unit qty ever stocked in directly (not via a
  /// whole container) -- see updated_db.md's total_package_stock_ins.
  final double totalPackageStockIns;

  /// Staff-chosen display mode for this item, or null if not explicitly
  /// set -- see [effectiveCountMode].
  final StockCountMode? stockCountMode;

  /// Whether this item has ever appeared in a purchase_item / donation_item
  /// row -- see [AcquisitionSource].
  final bool hasPurchaseHistory;
  final bool hasDonationHistory;

  /// Lifetime sum of stock_out.qty for this item (waste + expired +
  /// adjustment combined, purchase_unit terms). Kept for the Stock Movement
  /// history; not rolled into any current-stock figure.
  final double lifetimeStockOutQty;

  /// Lifetime sum of treatment_item.dispensed_qty for this item, in
  /// whatever unit each row was actually recorded in. Kept for the Stock
  /// Movement history; not used by any rolled-up stock stat (see
  /// KNOWN_LIMITATIONS.md -- Unused/Used/In-Use stocks were removed in
  /// favor of the movement log as the single source for "how much used").
  final double lifetimeTreatmentQty;

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
  });

  /// See [AcquisitionSource] -- derived from [hasPurchaseHistory] /
  /// [hasDonationHistory], not a stored attribute.
  AcquisitionSource get acquisitionSource {
    if (hasPurchaseHistory && hasDonationHistory) return AcquisitionSource.both;
    if (hasPurchaseHistory) return AcquisitionSource.purchased;
    if (hasDonationHistory) return AcquisitionSource.donated;
    return AcquisitionSource.none;
  }

  /// Package quantity + unit for display beside the item name, e.g.
  /// "(60 tab per box)". Null when the item has no package breakdown.
  String? get packageLabel {
    if (packageQuantity == null || packageUnitAbbr == null) return null;
    return '(${formatQty(packageQuantity!)} $packageUnitAbbr per $purchaseUnitAbbr)';
  }

  /// Combined category label for display, e.g. "Medical > Tablets".
  String get itemCategory =>
      sCategoryName == null ? pCategoryName : '$pCategoryName > $sCategoryName';

  /// The unit shown alongside [stockQty] wherever the app just displays a
  /// quantity -- the purchase unit, since that's what stock is counted in.
  String get itemUom => purchaseUnitAbbr;

  /// False when [dispenseUnitId] is set and differs from [packageUnitId] --
  /// there's no stored conversion between the two, so a dose recorded in the
  /// dispense unit can't be safely converted back to purchase_stocks. Usage
  /// is still logged on treatment_item in that case, just not deducted.
  bool get stockOutIsDeductible =>
      dispenseUnitId == null || dispenseUnitId == packageUnitId;

  /// Which pool this item's stock figure is displayed in -- a staff choice
  /// per item ([stockCountMode]) when set, otherwise a default derived from
  /// whether the item is deductible with a package breakdown (that's the
  /// unit doses are actually tracked in, so it's the natural default for
  /// those items; everything else defaults to purchase_unit).
  StockCountMode get effectiveCountMode {
    if (stockCountMode != null) return stockCountMode!;
    return (packageQuantity != null && stockOutIsDeductible)
        ? StockCountMode.packageUnit
        : StockCountMode.purchaseUnit;
  }

  /// The stock figure to show wherever the app displays "how much of this
  /// item is on hand" as a single number, per [effectiveCountMode]. Unused/
  /// In-Use/Used Stocks breakdowns were removed (see KNOWN_LIMITATIONS.md)
  /// in favor of this single figure plus the Stock Movement history.
  double get displayStockQty => effectiveCountMode == StockCountMode.packageUnit
      ? (packageStockQty ?? stockQty * (packageQuantity ?? 1))
      : stockQty;

  String get displayStockUnit => effectiveCountMode == StockCountMode.packageUnit
      ? (packageUnitAbbr ?? purchaseUnitAbbr)
      : purchaseUnitAbbr;

  /// True only when there's nothing usable left by either measure: no
  /// sealed containers AND no partial amount remaining in an opened one.
  bool get isOutOfStock =>
      stockQty <= 0 && (packageStockQty == null || packageStockQty! <= 0);

  /// Short human-facing ID shown in the Inventory table, e.g. "ITM-3FA8".
  /// Derived from the id since there's no separate sequential-ID column.
  String get displayId =>
      'ITM-${itemId.replaceAll('-', '').padRight(4, '0').substring(0, 4).toUpperCase()}';

  /// [needsRestock]'s "30" tier is a coarser visual cue above the
  /// configurable [lowStockPurchaseUnitThreshold] -- only the low-stock tier
  /// is backed by a real setting today.
  StockLevel get stockLevel {
    if (isOutOfStock) return StockLevel.outOfStock;
    if (stockQty <= lowStockPurchaseUnitThreshold) return StockLevel.low;
    if (stockQty <= 30) return StockLevel.needsRestock;
    return StockLevel.inStock;
  }
}
