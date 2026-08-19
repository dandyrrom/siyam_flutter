import '../models/item_rop_settings.dart';

// =============================================================================
// ROP SERVICE
// =============================================================================
//
// Contract for item-specific ROP settings.
//
// IMPORTANT:
// System-wide defaults are handled by SettingsService.
//
// This service handles only:
// public.item_rop_settings
// =============================================================================

abstract interface class RopService {
  /// Returns every item-specific ROP override.
  Future<List<ItemRopSettings>> fetchOverrides();

  /// Returns the override for one item.
  ///
  /// Null means the item is using the system-wide ROP defaults.
  Future<ItemRopSettings?> fetchOverride(
    String itemId,
  );

  /// Creates or updates an item-specific ROP override.
  Future<ItemRopSettings> saveOverride({
    required String itemId,
    required int leadTimeDays,
    required double safetyStockQty,
  });

  /// Deletes an item's custom ROP settings.
  ///
  /// After deletion, the item uses the system-wide defaults again.
  Future<void> deleteOverride(
    String itemId,
  );
}