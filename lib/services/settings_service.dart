import 'package:supabase_flutter/supabase_flutter.dart';

import '../mock/mock_database.dart';
import '../models/system_settings.dart';
import '../state/data_bus.dart';
import 'backend.dart';

/// Data-access interface for the single app-wide settings row.
///
/// Existing settings:
/// - low stock threshold
/// - expiration warning days
///
/// ROP defaults:
/// - default lead time
/// - default safety stock
abstract interface class SettingsService {
  factory SettingsService() =>
      kUseMock
          ? MockSettingsService()
          : SupabaseSettingsService();

  Future<SystemSettings> fetchSettings();

  Future<SystemSettings> updateSettings({
    required double lowStockThreshold,
    required int expirationWarningDays,

    // ========================================================================
    // ROP SETTINGS
    // ========================================================================
    //
    // Optional temporarily so the existing SettingsPage remains compatible
    // until we update its UI in the next step.
    // ========================================================================

    int? defaultLeadTimeDays,
    double? defaultSafetyStockQty,
  });
}

// =============================================================================
// MOCK SETTINGS SERVICE
// =============================================================================
//
// SIYAM's production path uses Supabase.
//
// These fallback ROP values exist only so the existing mock architecture keeps
// compiling while the real implementation uses public.system_settings.
// =============================================================================

class MockSettingsService implements SettingsService {
  final MockDatabase _db =
      MockDatabase.instance;

  // Mock-only fallbacks for the new fields.
  int _defaultLeadTimeDays = 7;
  double _defaultSafetyStockQty = 0;

  SystemSettings _toSettings() {
    return SystemSettings(
      lowStockThreshold:
          _db.systemSettings.lowStockThreshold,
      expirationWarningDays:
          _db.systemSettings.expirationWarningDays,
      defaultLeadTimeDays:
          _defaultLeadTimeDays,
      defaultSafetyStockQty:
          _defaultSafetyStockQty,
    );
  }

  @override
  Future<SystemSettings> fetchSettings() async {
    return _toSettings();
  }

  @override
  Future<SystemSettings> updateSettings({
    required double lowStockThreshold,
    required int expirationWarningDays,
    int? defaultLeadTimeDays,
    double? defaultSafetyStockQty,
  }) async {
    _db.systemSettings.lowStockThreshold =
        lowStockThreshold;

    _db.systemSettings.expirationWarningDays =
        expirationWarningDays;

    if (defaultLeadTimeDays != null) {
      _defaultLeadTimeDays =
          defaultLeadTimeDays;
    }

    if (defaultSafetyStockQty != null) {
      _defaultSafetyStockQty =
          defaultSafetyStockQty;
    }

    DataChangeBus.instance.ping();

    return _toSettings();
  }
}

// =============================================================================
// SUPABASE SETTINGS SERVICE
// =============================================================================
//
// Backed by the single row in public.system_settings.
// =============================================================================

class SupabaseSettingsService implements SettingsService {
  final SupabaseClient _client =
      Supabase.instance.client;

  static const String _columns =
      'low_stock_threshold, '
      'expiration_warning_days, '
      'default_lead_time_days, '
      'default_safety_stock_qty';

  // ===========================================================================
  // MAP SETTINGS
  // ===========================================================================

  SystemSettings _toSettings(
    Map<String, dynamic> row,
  ) {
    return SystemSettings(
      lowStockThreshold:
          (row['low_stock_threshold'] as num)
              .toDouble(),

      expirationWarningDays:
          (row['expiration_warning_days'] as num)
              .toInt(),

      defaultLeadTimeDays:
          (row['default_lead_time_days'] as num)
              .toInt(),

      defaultSafetyStockQty:
          (row['default_safety_stock_qty'] as num)
              .toDouble(),
    );
  }

  // ===========================================================================
  // FETCH SETTINGS
  // ===========================================================================

  @override
  Future<SystemSettings> fetchSettings() async {
    final row = await _client
        .from('system_settings')
        .select(_columns)
        .eq('id', true)
        .single();

    return _toSettings(row);
  }

  // ===========================================================================
  // UPDATE SETTINGS
  // ===========================================================================

  @override
  Future<SystemSettings> updateSettings({
    required double lowStockThreshold,
    required int expirationWarningDays,
    int? defaultLeadTimeDays,
    double? defaultSafetyStockQty,
  }) async {
    // -------------------------------------------------------------------------
    // ONLY UPDATE ROP FIELDS WHEN PROVIDED
    // -------------------------------------------------------------------------
    //
    // This allows the existing SettingsPage to continue updating the old
    // fields without accidentally overwriting ROP defaults.
    // -------------------------------------------------------------------------

    final updates = <String, dynamic>{
      'low_stock_threshold':
          lowStockThreshold,
      'expiration_warning_days':
          expirationWarningDays,
    };

    if (defaultLeadTimeDays != null) {
      updates['default_lead_time_days'] =
          defaultLeadTimeDays;
    }

    if (defaultSafetyStockQty != null) {
      updates['default_safety_stock_qty'] =
          defaultSafetyStockQty;
    }

    final row = await _client
        .from('system_settings')
        .update(updates)
        .eq('id', true)
        .select(_columns)
        .single();

    DataChangeBus.instance.ping();

    return _toSettings(row);
  }
}