import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/item_rop_settings.dart';
import '../../state/data_bus.dart';
import '../rop_service.dart';

// =============================================================================
// SUPABASE ROP SERVICE
// =============================================================================
//
// Table:
//
// public.item_rop_settings
//
// No row for an item:
//   -> use system_settings defaults
//
// Row exists:
//   -> use the item's custom lead time and safety stock
// =============================================================================

class SupabaseRopService implements RopService {
  final SupabaseClient _client =
      Supabase.instance.client;

  static const String _table =
      'item_rop_settings';

  static const String _columns =
      'itemid, lead_time_days, safety_stock_qty';

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  void _validate({
    required int leadTimeDays,
    required double safetyStockQty,
  }) {
    if (leadTimeDays < 0) {
      throw Exception(
        'Lead time cannot be negative.',
      );
    }

    if (safetyStockQty < 0) {
      throw Exception(
        'Safety stock cannot be negative.',
      );
    }

    if (!safetyStockQty.isFinite) {
      throw Exception(
        'Safety stock must be a valid number.',
      );
    }
  }

  // ===========================================================================
  // FETCH ALL OVERRIDES
  // ===========================================================================

  @override
  Future<List<ItemRopSettings>> fetchOverrides() async {
    final rows = await _client
        .from(_table)
        .select(_columns);

    return rows
        .map(
          (row) => ItemRopSettings.fromMap(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList();
  }

  // ===========================================================================
  // FETCH ONE OVERRIDE
  // ===========================================================================

  @override
  Future<ItemRopSettings?> fetchOverride(
    String itemId,
  ) async {
    final row = await _client
        .from(_table)
        .select(_columns)
        .eq('itemid', itemId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return ItemRopSettings.fromMap(
      Map<String, dynamic>.from(row),
    );
  }

  // ===========================================================================
  // SAVE OVERRIDE
  // ===========================================================================

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

    final existing = await _client
        .from(_table)
        .select('itemid')
        .eq('itemid', itemId)
        .maybeSingle();

    final now = DateTime.now()
        .toUtc()
        .toIso8601String();

    Map<String, dynamic> row;

    // =========================================================================
    // CREATE OVERRIDE
    // =========================================================================

    if (existing == null) {
      final inserted = await _client
          .from(_table)
          .insert({
            'itemid': itemId,
            'lead_time_days': leadTimeDays,
            'safety_stock_qty': safetyStockQty,
            'updatedat': now,
          })
          .select(_columns)
          .single();

      row = Map<String, dynamic>.from(
        inserted,
      );
    }

    // =========================================================================
    // UPDATE OVERRIDE
    // =========================================================================

    else {
      final updated = await _client
          .from(_table)
          .update({
            'lead_time_days': leadTimeDays,
            'safety_stock_qty': safetyStockQty,
            'updatedat': now,
          })
          .eq('itemid', itemId)
          .select(_columns)
          .single();

      row = Map<String, dynamic>.from(
        updated,
      );
    }

    DataChangeBus.instance.ping();

    return ItemRopSettings.fromMap(
      row,
    );
  }

  // ===========================================================================
  // DELETE OVERRIDE
  // ===========================================================================

  @override
  Future<void> deleteOverride(
    String itemId,
  ) async {
    await _client
        .from(_table)
        .delete()
        .eq('itemid', itemId);

    DataChangeBus.instance.ping();
  }
}