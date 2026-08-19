// =============================================================================
// ITEM ROP SETTINGS
// =============================================================================
//
// Mirrors one row in:
//
// public.item_rop_settings
//
// If an item has no row in item_rop_settings, it uses the system-wide
// ROP defaults stored in public.system_settings.
//
// If a row exists, these values override the system defaults for that item.
// =============================================================================

class ItemRopSettings {
  final String itemId;

  /// Number of days normally required to replenish this item.
  final int leadTimeDays;

  /// Safety stock expressed in the item's PURCHASE UNIT.
  ///
  /// Examples:
  /// 3 bags
  /// 2 bottles
  /// 10 boxes
  final double safetyStockQty;

  const ItemRopSettings({
    required this.itemId,
    required this.leadTimeDays,
    required this.safetyStockQty,
  });

  factory ItemRopSettings.fromMap(
    Map<String, dynamic> map,
  ) {
    return ItemRopSettings(
      itemId: map['itemid'] as String,
      leadTimeDays:
          (map['lead_time_days'] as num).toInt(),
      safetyStockQty:
          (map['safety_stock_qty'] as num).toDouble(),
    );
  }
}