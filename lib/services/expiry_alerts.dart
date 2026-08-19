import '../mock/mock_database.dart';

// ============================================================================
// EXPIRY ALERT TYPE
// ============================================================================

enum ExpiryAlertKind {
  expiredStock,
  expiringSoon,
}

/// One actionable expiry condition for an inventory item.
///
/// An item may now legitimately produce TWO alerts at the same time:
///
/// 1. expiredStock
///    Physical expired stock remains and must be removed by staff.
///
/// 2. expiringSoon
///    A valid batch is approaching its expiry date and FEFO should prioritize it.
///
/// [qty] and [unitAbbr] are optional so the Mock backend remains compatible.
/// The real Supabase implementation supplies them from inventory_batch.
class ExpiryAlert {
  final ExpiryAlertKind kind;
  final String itemId;
  final String itemName;
  final DateTime expiryDate;
  final int daysUntilExpiry;
  final double? qty;
  final String? unitAbbr;

  const ExpiryAlert({
    required this.kind,
    required this.itemId,
    required this.itemName,
    required this.expiryDate,
    required this.daysUntilExpiry,
    this.qty,
    this.unitAbbr,
  });

  bool get isExpired => kind == ExpiryAlertKind.expiredStock;
  bool get isExpiringSoon => kind == ExpiryAlertKind.expiringSoon;
}

// ============================================================================
// MOCK BACKEND EXPIRY SUPPORT
// ============================================================================
//
// The real Supabase backend now derives expiry alerts from inventory_batch.
//
// These helpers remain only so MockDashboardService continues compiling and
// behaving consistently during mock-mode development.
// ============================================================================

DateTime? nearestBatchExpiry(MockDatabase db, String itemId) {
  DateTime? nearest;

  void consider(DateTime? expiryDate, double qtyRemaining) {
    if (expiryDate == null || qtyRemaining <= 0) return;

    if (nearest == null || expiryDate.isBefore(nearest!)) {
      nearest = expiryDate;
    }
  }

  for (final p in db.purchaseItems) {
    if (p.itemId == itemId) {
      consider(p.expiryDate, p.qtyRemaining);
    }
  }

  for (final d in db.donationItems) {
    if (d.itemId == itemId) {
      consider(d.expiryDate, d.qtyRemaining);
    }
  }

  return nearest;
}

/// Mock-mode expiry alerts.
///
/// Supabase mode uses inventory_batch and can produce both an expired-stock
/// alert and an upcoming-expiry alert for the same item.
List<ExpiryAlert> expiryAlerts(MockDatabase db, int warningDays) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final cutoff = today.add(Duration(days: warningDays));
  final alerts = <ExpiryAlert>[];

  for (final item in db.items) {
    final rawExpiry = nearestBatchExpiry(db, item.id);
    if (rawExpiry == null) continue;

    final expiry = DateTime(
      rawExpiry.year,
      rawExpiry.month,
      rawExpiry.day,
    );

    if (expiry.isAfter(cutoff)) continue;

    final daysUntilExpiry = expiry.difference(today).inDays;

    alerts.add(
      ExpiryAlert(
        kind: daysUntilExpiry < 0
            ? ExpiryAlertKind.expiredStock
            : ExpiryAlertKind.expiringSoon,
        itemId: item.id,
        itemName: item.name,
        expiryDate: expiry,
        daysUntilExpiry: daysUntilExpiry,
      ),
    );
  }

  alerts.sort((a, b) {
    if (a.kind != b.kind) {
      return a.kind.index.compareTo(b.kind.index);
    }

    return a.expiryDate.compareTo(b.expiryDate);
  });

  return alerts;
}