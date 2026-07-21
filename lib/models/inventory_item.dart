enum StockLevel { inStock, needsRestock, low, outOfStock }

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
/// without a whole container being removed -- see [unusedStockQty] /
/// [usedStockQty].
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

  /// Whether this item has ever appeared in a purchase_item / donation_item
  /// row -- see [AcquisitionSource].
  final bool hasPurchaseHistory;
  final bool hasDonationHistory;

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
    this.hasPurchaseHistory = false,
    this.hasDonationHistory = false,
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

  /// [stockQty] rounded to a whole container count. Containers are only
  /// ever added/removed in whole units, so this should already be a whole
  /// number -- rounding here is a defensive guard against leftover
  /// fractional values (e.g. stock deducted fractionally by older app
  /// versions before total_package_stocks existed).
  double get _containerCount => stockQty.roundToDouble();

  /// Whole containers still fully sealed/untouched, e.g. 198.5ml remaining
  /// at 100ml/bottle = 1 unopened bottle. Falls back to [stockQty] for items
  /// with no package breakdown (nothing to "open"). Always a whole number.
  double get unusedStockQty {
    if (packageQuantity == null || packageQuantity == 0) return _containerCount;
    final packageStock = packageStockQty ?? (stockQty * packageQuantity!);
    final unused = (packageStock / packageQuantity!).floorToDouble();
    return unused.clamp(0, _containerCount);
  }

  /// Containers that have been opened/started by treatment usage but not
  /// (yet) fully consumed and discarded -- `_containerCount -
  /// unusedStockQty`. Always 0 for items with no package breakdown, and
  /// always a whole number.
  double get usedStockQty => packageQuantity == null
      ? 0
      : (_containerCount - unusedStockQty).clamp(0, _containerCount);

  /// True only when there's nothing usable left by either measure: no
  /// sealed containers AND no partial amount remaining in an opened one.
  bool get isOutOfStock =>
      stockQty <= 0 && (packageStockQty == null || packageStockQty! <= 0);

  /// Short human-facing ID shown in the Inventory table, e.g. "ITM-3FA8".
  /// Derived from the id since there's no separate sequential-ID column.
  String get displayId =>
      'ITM-${itemId.replaceAll('-', '').padRight(4, '0').substring(0, 4).toUpperCase()}';

  /// Stock-level tier thresholds are a placeholder assumption (no
  /// reorder-point column exists on `item`). Adjust here, or move to a
  /// per-item `reorder_point` column if you want these tunable per item.
  StockLevel get stockLevel {
    if (isOutOfStock) return StockLevel.outOfStock;
    if (stockQty <= 10) return StockLevel.low;
    if (stockQty <= 30) return StockLevel.needsRestock;
    return StockLevel.inStock;
  }
}
