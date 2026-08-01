/// Mirrors the single row in public.system_settings (see updated_db.md).
class SystemSettings {
  final double lowStockThreshold;
  final int expirationWarningDays;

  const SystemSettings({
    required this.lowStockThreshold,
    required this.expirationWarningDays,
  });
}
