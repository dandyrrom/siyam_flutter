import '../models/inventory_item.dart';
import 'inventory_service.dart';

/// Applies the stock effect of one treatment_item row to [item]'s inventory,
/// via [service]. Shared by the mock and Supabase treatment services so the
/// branching logic can't drift between them.
///
///  - Package breakdown + dispense_unit == package_unit (e.g. syrup dosed in
///    ml, package_unit=ml): [qty] is already in package_unit terms, so it's
///    drawn from the item's batches in expiry order (FEFO) and deducted from
///    total_package_stocks. total_purchase_stocks (whole bottles) is
///    untouched -- using part of a bottle doesn't remove it from inventory.
///  - No dispense_unit at all (e.g. a mop, counted per-piece): [qty] is
///    entered directly in purchase_unit terms, so it's drawn from batches
///    the same way and deducted 1:1 from total_purchase_stocks.
///  - dispense_unit set and differs from package_unit (e.g. package_unit=ml,
///    dispense_unit=drop): no known conversion between them -- usage is
///    still logged on treatment_item by the caller, stock is left untouched.
Future<void> applyTreatmentDeduction(
  InventoryService service,
  InventoryItem item,
  double qty,
) async {
  if (item.dispenseUnitId != null &&
      item.dispenseUnitId == item.packageUnitId &&
      item.packageQuantity != null) {
    await service.deductFefo(itemId: item.itemId, qty: qty);
  } else if (item.dispenseUnitId == null) {
    await service.deductFefo(itemId: item.itemId, qty: qty);
  }
  // else: not deductible -- logged only, handled by the caller.
}
