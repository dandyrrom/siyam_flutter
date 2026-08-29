import 'inventory_item.dart';

// =============================================================================
// REPLENISHMENT ITEM
// =============================================================================
//
// One calculated row in the Replenishment view.
//
// Nothing in this model is persisted. It is derived from:
// - current usable inventory batches
// - stock-consuming usage from a rolling window of up to 30 days
// - system ROP defaults
// - optional item-specific ROP overrides
//
// New items use the number of days since their first received inventory batch
// as the ADU observation period, capped at 30 days. Established items continue
// using the normal 30-day window.
// =============================================================================

enum ReplenishmentPriority {
  critical,
  high,
  medium,
}

class ReplenishmentItem {
  final InventoryItem item;

  /// Stock-consuming usage collected within the rolling window, normalized
  /// back into the item's PURCHASE UNIT.
  ///
  /// The field name is kept for compatibility with the existing Ordering UI.
  /// The maximum usage window remains 30 days.
  final double usage30PurchaseUnits;

  /// Number of calendar days used as the ADU denominator.
  ///
  /// - Established item: 30
  /// - New item: days since first received inventory batch, capped at 30
  /// - No batch history: 30
  final int observationDays;

  /// Average Daily Usage =
  /// usage30PurchaseUnits / observationDays.
  final double averageDailyUsage;

  final int leadTimeDays;

  /// Safety stock expressed in the item's PURCHASE UNIT.
  final double safetyStockQty;

  /// ROP = (ADU × Lead Time) + Safety Stock.
  final double reorderPoint;

  /// Current usable stock expressed in purchase-unit equivalents.
  final double currentStockPurchaseUnits;

  /// Minimum shortfall to the operational ROP.
  ///
  /// SIYAM does not automatically create a supplier order from this value.
  /// It is a recommendation/reference for staff.
  final double suggestedQty;

  final bool usesCustomRop;

  final ReplenishmentPriority priority;

  const ReplenishmentItem({
    required this.item,
    required this.usage30PurchaseUnits,
    required this.observationDays,
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