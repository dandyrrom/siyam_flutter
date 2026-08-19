import 'inventory_item.dart';

// =============================================================================
// REPLENISHMENT ITEM
// =============================================================================
//
// One calculated row in the Replenishment view.
//
// Nothing in this model is persisted. It is derived from:
// - current usable inventory batches
// - the previous 30 days of usage
// - system ROP defaults
// - optional item-specific ROP overrides
// =============================================================================

enum ReplenishmentPriority {
  critical,
  high,
  medium,
}

class ReplenishmentItem {
  final InventoryItem item;

  /// Previous 30 days of stock-consuming usage, normalized back into the
  /// item's PURCHASE UNIT.
  final double usage30PurchaseUnits;

  /// Average Daily Usage = usage30PurchaseUnits / 30.
  final double averageDailyUsage;

  final int leadTimeDays;

  /// Safety stock expressed in the item's PURCHASE UNIT.
  final double safetyStockQty;

  /// ROP = (ADU × Lead Time) + Safety Stock.
  final double reorderPoint;

  /// Current usable stock expressed in purchase-unit equivalents.
  final double currentStockPurchaseUnits;

  /// Shortfall to the ROP.
  ///
  /// SIYAM does not automatically create a supplier order from this value.
  /// It is a recommendation/reference for staff.
  final double suggestedQty;

  final bool usesCustomRop;

  final ReplenishmentPriority priority;

  const ReplenishmentItem({
    required this.item,
    required this.usage30PurchaseUnits,
    required this.averageDailyUsage,
    required this.leadTimeDays,
    required this.safetyStockQty,
    required this.reorderPoint,
    required this.currentStockPurchaseUnits,
    required this.suggestedQty,
    required this.usesCustomRop,
    required this.priority,
  });

  bool get isAtReorderPoint =>
      suggestedQty.abs() < 0.000000001 &&
      currentStockPurchaseUnits <= reorderPoint + 0.000000001;
}
