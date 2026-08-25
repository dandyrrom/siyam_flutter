import '../models/inventory_item.dart';
import 'inventory_service.dart';

/// Applies the stock effect of one treatment_item row to [item]'s inventory,
/// via [service]. Shared by the mock and Supabase treatment services so the
/// branching logic can't drift between them.
///
/// Deductible treatment quantities are already expressed in the item's
/// canonical inventory unit:
///
/// - package unit when the item has a package breakdown
/// - purchase unit when the item has no package breakdown
///
/// Examples:
///
/// - Syrup: bottle -> ml, dispense unit = ml
///   [qty] is deducted from usable batches in FEFO order.
///
/// - Tablets stored directly as tablets, dispense unit = tablet
///   [qty] is deducted 1:1 from usable batches in FEFO order.
///
/// - No explicit dispense unit
///   The caller falls back to the item's canonical inventory unit, so [qty]
///   is also safe to deduct.
///
/// - Stocked in ml but administered in drops
///   No reliable conversion exists, so the treatment usage is logged by the
///   caller but inventory is intentionally left unchanged.
Future<void> applyTreatmentDeduction(
  InventoryService service,
  InventoryItem item,
  double qty,
) async {
  if (!item.stockOutIsDeductible) {
    return;
  }

  await service.deductFefo(
    itemId: item.itemId,
    qty: qty,
  );
}
