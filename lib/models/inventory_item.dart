enum StockLevel { inStock, needsRestock, low, outOfStock }

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
///    (box, bottle, bag) -- [stockQty] (purchase_stocks) is counted in this
///    unit.
///  - [packageUnitId]/[packageUnitAbbr] + [packageQuantity]: what's inside
///    one purchase unit (1 box = 30 tablet, 1 bottle = 200 ml). Both null
///    for items with no breakdown (mop, food bowl).
///  - [dispenseUnitId]/[dispenseUnitAbbr]: the unit doses are actually
///    recorded in. Usually equals the package unit, but can differ (e.g.
///    package_unit=ml, dispense_unit=drop) with no stored conversion between
///    them -- see [stockOutIsDeductible].
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
  final double stockQty; // purchase_stocks, in purchaseUnit terms

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
  });

  /// Combined category label for display, e.g. "Medical Supplies > Tablets".
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

  /// Short human-facing ID shown in the Inventory table, e.g. "ITM-3FA8".
  /// Derived from the id since there's no separate sequential-ID column.
  String get displayId =>
      'ITM-${itemId.replaceAll('-', '').padRight(4, '0').substring(0, 4).toUpperCase()}';

  /// Stock-level tier thresholds are a placeholder assumption (no
  /// reorder-point column exists on `item`). Adjust here, or move to a
  /// per-item `reorder_point` column if you want these tunable per item.
  StockLevel get stockLevel {
    if (stockQty <= 0) return StockLevel.outOfStock;
    if (stockQty <= 10) return StockLevel.low;
    if (stockQty <= 30) return StockLevel.needsRestock;
    return StockLevel.inStock;
  }
}
