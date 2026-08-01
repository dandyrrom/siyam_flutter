import '../mock/mock_database.dart';

/// One item's nearest upcoming (or already past) batch expiry, for the
/// Expiry Warnings alert. [daysUntilExpiry] is negative when [expiryDate] has
/// already passed.
class ExpiryAlert {
  final String itemId;
  final String itemName;
  final DateTime expiryDate;
  final int daysUntilExpiry;

  const ExpiryAlert({
    required this.itemId,
    required this.itemName,
    required this.expiryDate,
    required this.daysUntilExpiry,
  });
}

/// The earliest `expiry_date` across [itemId]'s purchase_item/donation_item
/// batches that still have stock remaining (`qty_remaining > 0`), or null if
/// none of its batches have an expiry_date at all. Mirrors the FEFO ordering
/// used by `deductFefo` in `lib/services/inventory_service.dart`, but only
/// needs the single soonest date here rather than a full sort.
DateTime? nearestBatchExpiry(MockDatabase db, String itemId) {
  DateTime? nearest;
  void consider(DateTime? expiryDate, double qtyRemaining) {
    if (expiryDate == null || qtyRemaining <= 0) return;
    if (nearest == null || expiryDate.isBefore(nearest!)) nearest = expiryDate;
  }

  for (final p in db.purchaseItems) {
    if (p.itemId == itemId) consider(p.expiryDate, p.qtyRemaining);
  }
  for (final d in db.donationItems) {
    if (d.itemId == itemId) consider(d.expiryDate, d.qtyRemaining);
  }
  return nearest;
}

/// Items whose nearest batch expiry falls within [warningDays] of today
/// (including already-expired batches), soonest first.
List<ExpiryAlert> expiryAlerts(MockDatabase db, int warningDays) {
  final today = DateTime.now();
  final cutoff = today.add(Duration(days: warningDays));
  final alerts = <ExpiryAlert>[];

  for (final item in db.items) {
    final expiry = nearestBatchExpiry(db, item.id);
    if (expiry == null || expiry.isAfter(cutoff)) continue;
    alerts.add(ExpiryAlert(
      itemId: item.id,
      itemName: item.name,
      expiryDate: expiry,
      daysUntilExpiry: expiry.difference(today).inDays,
    ));
  }

  alerts.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
  return alerts;
}
