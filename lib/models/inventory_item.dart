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
/// without a whole container being removed -- see [unusedStockQty] and
/// [usedPurchaseUnitQty]/[usedPackageUnitQty] (whole purchase units used, plus
/// any partial amount used from the one container currently open).
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

  /// Lifetime sum of stock_out.qty for this item (waste + expired +
  /// adjustment combined, purchase_unit terms) -- unlike [stockQty], this
  /// never decreases, since a stocked-out container is gone from
  /// [stockQty]/[_containerCount] entirely and would otherwise vanish from
  /// every stock stat with no record it ever existed. See
  /// [usedPurchaseUnitQty].
  final double lifetimeStockOutQty;

  /// Lifetime sum of treatment_item.dispensed_qty for this item, in
  /// whatever unit each row was actually recorded in. Only meaningful (used
  /// by [usedPurchaseUnitQty]) for items with no package breakdown, where
  /// every dose is deducted 1:1 from [stockQty] directly -- for items with a
  /// package breakdown, treatment consumption instead draws down
  /// [packageStockQty], already fully recoverable from the current
  /// snapshot via the package-unit math in [usedPurchaseUnitQty]/
  /// [usedPackageUnitQty], so this field is ignored there.
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

  /// Cumulative package-unit quantity ever drawn down from the pool
  /// (treatment usage, mainly) -- the capacity of every container currently
  /// on hand minus what's actually left in the pool. Assumes
  /// [packageQuantity] hasn't changed since any of that stock was added
  /// (it's a fixed item attribute). 0 for items with no package breakdown.
  double get _totalConsumed {
    if (packageQuantity == null || packageQuantity == 0) return 0;
    final capacity = _containerCount * packageQuantity!;
    final remaining = packageStockQty ?? capacity;
    return (capacity - remaining).clamp(0, capacity);
  }

  /// Whole purchase units ever fully consumed, by any means, across this
  /// item's entire history -- not just what's still on the shelf. Combines:
  ///  - Every stock-out ([lifetimeStockOutQty]: waste, expired, adjustment)
  ///    -- always whole purchase-unit events, and always counted, since
  ///    using an item up (via treatment) and stocking it out (for any other
  ///    reason) are both just "this container is no longer available."
  ///  - Treatment usage: for items with no package breakdown, every dose is
  ///    itself a direct whole-purchase-unit deduction, so
  ///    [lifetimeTreatmentQty] is added straight in. For items with a
  ///    package breakdown and a deductible dispense unit, treatment instead
  ///    draws down the package pool -- `floor(total consumed / package
  ///    quantity)` (via [_totalConsumed]) gives the whole-container
  ///    equivalent of that, e.g. modulo package quantity is 0. A container
  ///    that's been opened but not yet fully depleted this way is NOT
  ///    counted here; see [usedPackageUnitQty] for that partial amount.
  ///    Non-deductible treatment usage (dispense unit differs from package
  ///    unit, no stored conversion) never draws from any pool and isn't
  ///    counted anywhere.
  /// Always a whole number; NOT clamped to the current [_containerCount],
  /// since stocked-out containers no longer count toward it at all.
  double get usedPurchaseUnitQty {
    if (packageQuantity == null || packageQuantity == 0) {
      return lifetimeStockOutQty + lifetimeTreatmentQty;
    }
    final treatmentUnits = (_totalConsumed / packageQuantity!).floorToDouble();
    return lifetimeStockOutQty + treatmentUnits;
  }

  /// Package-unit quantity consumed so far from the one container that's
  /// currently open but not yet fully depleted (e.g. 6 out of a 30-tablet
  /// box) -- `total consumed % package quantity`. 0 when nothing is
  /// currently open: either untouched, or consumption lines up exactly on a
  /// container boundary (a whole unit was just fully used up). 0 for items
  /// with no package breakdown.
  double get usedPackageUnitQty {
    if (packageQuantity == null || packageQuantity == 0) return 0;
    return _totalConsumed % packageQuantity!;
  }

  /// Human-facing "used stocks" line combining [usedPurchaseUnitQty] and
  /// [usedPackageUnitQty]:
  ///  - No package breakdown: just the purchase-unit amount used.
  ///  - Package breakdown, no whole purchase unit used yet (stocked out by
  ///    pack qty, less than one purchase unit's worth so far): just the
  ///    pack-qty amount used.
  ///  - Package breakdown, 1+ whole purchase units used already: both the
  ///    purchase-unit count and the additional pack-qty amount used.
  String get usedStockDisplay {
    if (packageQuantity == null ||
        packageQuantity == 0 ||
        packageUnitAbbr == null) {
      return '${formatQty(usedPurchaseUnitQty)} $purchaseUnitAbbr';
    }
    if (usedPurchaseUnitQty <= 0) {
      return '${formatQty(usedPackageUnitQty)} $packageUnitAbbr';
    }
    return '${formatQty(usedPurchaseUnitQty)} $purchaseUnitAbbr and '
        '${formatQty(usedPackageUnitQty)} $packageUnitAbbr';
  }

  /// Package-unit quantity remaining in the single container currently open
  /// (not yet fully depleted, and not counted in [unusedStockQty] since it's
  /// no longer sealed) -- e.g. 7 tablets left in a 10-tablet box after 3 were
  /// used. The complement of [usedPackageUnitQty] within one container: 0
  /// when nothing is currently open, either because no container has been
  /// touched yet or because consumption lines up exactly on a container
  /// boundary. 0 for items with no package breakdown.
  double get openContainerRemainingQty {
    if (packageQuantity == null || packageQuantity == 0) return 0;
    final used = usedPackageUnitQty;
    return used == 0 ? 0 : packageQuantity! - used;
  }

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
