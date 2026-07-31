import 'package:supabase_flutter/supabase_flutter.dart';

import '../mock/mock_database.dart';
import '../models/system_settings.dart';
import '../state/data_bus.dart';
import 'backend.dart';

/// Data-access interface for the single app-wide settings row (see
/// updated_db.md's SYSTEM_SETTINGS). The factory resolves to the mock or
/// Supabase implementation based on [kUseMock], chosen at build time.
abstract interface class SettingsService {
  factory SettingsService() =>
      kUseMock ? MockSettingsService() : SupabaseSettingsService();

  Future<SystemSettings> fetchSettings();
  Future<SystemSettings> updateSettings({
    required double lowStockThreshold,
    required int expirationWarningDays,
  });
}

class MockSettingsService implements SettingsService {
  final MockDatabase _db = MockDatabase.instance;

  SystemSettings _toSettings() => SystemSettings(
        lowStockThreshold: _db.systemSettings.lowStockThreshold,
        expirationWarningDays: _db.systemSettings.expirationWarningDays,
      );

  @override
  Future<SystemSettings> fetchSettings() async => _toSettings();

  @override
  Future<SystemSettings> updateSettings({
    required double lowStockThreshold,
    required int expirationWarningDays,
  }) async {
    _db.systemSettings.lowStockThreshold = lowStockThreshold;
    _db.systemSettings.expirationWarningDays = expirationWarningDays;
    DataChangeBus.instance.ping();
    return _toSettings();
  }
}

/// Backed by the single-row `public.system_settings` table (see
/// updated_db.md and supabase/migrations/0014_system_settings.sql).
class SupabaseSettingsService implements SettingsService {
  final SupabaseClient _client = Supabase.instance.client;

  SystemSettings _toSettings(Map<String, dynamic> row) => SystemSettings(
        lowStockThreshold: (row['low_stock_threshold'] as num).toDouble(),
        expirationWarningDays: row['expiration_warning_days'] as int,
      );

  @override
  Future<SystemSettings> fetchSettings() async {
    final row = await _client
        .from('system_settings')
        .select('low_stock_threshold, expiration_warning_days')
        .eq('id', true)
        .single();
    return _toSettings(row);
  }

  @override
  Future<SystemSettings> updateSettings({
    required double lowStockThreshold,
    required int expirationWarningDays,
  }) async {
    final row = await _client
        .from('system_settings')
        .update({
          'low_stock_threshold': lowStockThreshold,
          'expiration_warning_days': expirationWarningDays,
        })
        .eq('id', true)
        .select('low_stock_threshold, expiration_warning_days')
        .single();
    DataChangeBus.instance.ping();
    return _toSettings(row);
  }
}
