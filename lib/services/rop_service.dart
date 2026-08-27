import '../models/item_rop_settings.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'supabase/supabase_rop_service.dart';

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
  factory RopService() =>
      kUseMock ? MockRopService() : SupabaseRopService();

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

/// In-memory item_rop_settings store for mock mode.
class MockRopService implements RopService {
  static final Map<String, ItemRopSettings> _overrides = {};

  void _validate({
    required int leadTimeDays,
    required double safetyStockQty,
  }) {
    if (leadTimeDays < 0) {
      throw Exception('Lead time cannot be negative.');
    }
    if (safetyStockQty < 0) {
      throw Exception('Safety stock cannot be negative.');
    }
    if (!safetyStockQty.isFinite) {
      throw Exception('Safety stock must be a valid number.');
    }
  }

  @override
  Future<List<ItemRopSettings>> fetchOverrides() async {
    return _overrides.values.toList();
  }

  @override
  Future<ItemRopSettings?> fetchOverride(String itemId) async {
    return _overrides[itemId];
  }

  @override
  Future<ItemRopSettings> saveOverride({
    required String itemId,
    required int leadTimeDays,
    required double safetyStockQty,
  }) async {
    _validate(
      leadTimeDays: leadTimeDays,
      safetyStockQty: safetyStockQty,
    );

    final saved = ItemRopSettings(
      itemId: itemId,
      leadTimeDays: leadTimeDays,
      safetyStockQty: safetyStockQty,
    );
    _overrides[itemId] = saved;
    DataChangeBus.instance.ping();
    return saved;
  }

  @override
  Future<void> deleteOverride(String itemId) async {
    _overrides.remove(itemId);
    DataChangeBus.instance.ping();
  }
}
