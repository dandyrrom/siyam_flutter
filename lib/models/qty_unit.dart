/// Which of an item's two units a stock-in/batch quantity is denominated
/// in -- `purchase_unit` (whole containers, e.g. box) or `package_unit`
/// (loose contents, e.g. tablet). Only ever `package_unit` for a row when
/// the item actually has a package breakdown (`packageQuantity != null`).
enum QtyUnit { purchaseUnit, packageUnit }

String qtyUnitToString(QtyUnit unit) =>
    unit == QtyUnit.purchaseUnit ? 'purchase_unit' : 'package_unit';

QtyUnit qtyUnitFromString(String value) =>
    value == 'package_unit' ? QtyUnit.packageUnit : QtyUnit.purchaseUnit;

/// Which pool an item's stock figure is displayed in on the Inventory list
/// and item detail page -- a per-item staff choice (see updated_db.md,
/// ITEM.stock_count_mode), not a per-visit view toggle. Two different
/// physical readings of the same item ("3 boxes" vs. "160 tablets"), so
/// showing a consistent one avoids two staff reading different numbers for
/// the same item at the same time.
enum StockCountMode { packageUnit, purchaseUnit }

String stockCountModeToString(StockCountMode mode) =>
    mode == StockCountMode.packageUnit ? 'package' : 'purchase';

StockCountMode? stockCountModeFromString(String? value) {
  switch (value) {
    case 'package':
      return StockCountMode.packageUnit;
    case 'purchase':
      return StockCountMode.purchaseUnit;
    default:
      return null;
  }
}
