// =============================================================================
// SYSTEM SETTINGS
// =============================================================================
//
// Mirrors the single row in:
//
// public.system_settings
//
// Contains:
// - low-stock alert threshold
// - expiration warning window
// - system-wide ROP defaults
// =============================================================================

class SystemSettings {
  final double lowStockThreshold;
  final int expirationWarningDays;

  // ===========================================================================
  // ROP SYSTEM DEFAULTS
  // ===========================================================================

  /// Default supplier lead time used when an item does not have its own
  /// item_rop_settings override.
  final int defaultLeadTimeDays;

  /// Default safety stock expressed in the item's PURCHASE UNIT.
  ///
  /// Examples:
  /// - 3 bags
  /// - 2 bottles
  /// - 10 boxes
  final double defaultSafetyStockQty;

  const SystemSettings({
    required this.lowStockThreshold,
    required this.expirationWarningDays,
    required this.defaultLeadTimeDays,
    required this.defaultSafetyStockQty,
  });
}