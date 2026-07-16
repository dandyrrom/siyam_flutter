import '../models/inventory_item.dart';

/// Converts a dose/usage quantity (recorded in an item's dispense unit) back
/// into purchase_unit terms, so it can be subtracted from purchase_stocks.
///
/// Returns null when there's no safe conversion -- [item.dispenseUnitId] is
/// set and differs from [item.packageUnitId] (e.g. package_unit=ml,
/// dispense_unit=drop, with no stored ml-per-drop factor). Callers should log
/// the usage regardless and simply skip the stock deduction in that case.
double? toPurchaseUnits(InventoryItem item, double qty) {
  if (item.dispenseUnitId == null) {
    // No dispense breakdown at all (e.g. a mop) -- dispensed 1:1 in
    // purchase_unit terms.
    return qty;
  }
  if (item.dispenseUnitId == item.packageUnitId && item.packageQuantity != null) {
    return qty / item.packageQuantity!;
  }
  return null;
}
