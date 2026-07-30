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

/// `system_settings` has not been migrated onto the real backend yet (see
/// KNOWN_LIMITATIONS.md) -- this falls back to the same hardcoded defaults
/// the mock layer seeds, and keeps edits in a session-only in-memory cache
/// rather than pretending to persist them.
class SupabaseSettingsService implements SettingsService {
  static double _lowStockThreshold = 10;
  static int _expirationWarningDays = 30;

  @override
  Future<SystemSettings> fetchSettings() async => SystemSettings(
        lowStockThreshold: _lowStockThreshold,
        expirationWarningDays: _expirationWarningDays,
      );

  @override
  Future<SystemSettings> updateSettings({
    required double lowStockThreshold,
    required int expirationWarningDays,
  }) async {
    _lowStockThreshold = lowStockThreshold;
    _expirationWarningDays = expirationWarningDays;
    DataChangeBus.instance.ping();
    return SystemSettings(
      lowStockThreshold: _lowStockThreshold,
      expirationWarningDays: _expirationWarningDays,
    );
  }
}
