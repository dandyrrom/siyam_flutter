import '../mock/mock_database.dart';
import '../models/app_user.dart';
import '../models/pet.dart';
import 'backend.dart';
import 'dashboard_stock_helpers.dart';
import 'expiry_alerts.dart';
import 'supabase/supabase_dashboard_service.dart';

/// One row in a zero- or low-stock alert list on the manager dashboard.
class DashboardStockAlert {
  final String itemId;
  final String itemName;
  final double stockQty;
  final String unitAbbr;

  const DashboardStockAlert({
    required this.itemId,
    required this.itemName,
    required this.stockQty,
    required this.unitAbbr,
  });
}

/// Aggregate counts for the Manager dashboard.
class ManagerDashboardStats {
  final int totalAnimals;
  final int totalSuppliers;
  final int pendingSubmissions;
  final int staffAccounts;
  final int totalItems;
  final int zeroStockCount;
  final int lowStockCount;
  final int expiringSoonCount;
  final bool expiryTrackingAvailable;
  final List<DashboardStockAlert> zeroStockItems;
  final List<DashboardStockAlert> lowStockItems;
  final List<ExpiryAlert> expiringSoonItems;

  const ManagerDashboardStats({
    required this.totalAnimals,
    required this.totalSuppliers,
    required this.pendingSubmissions,
    required this.staffAccounts,
    required this.totalItems,
    required this.zeroStockCount,
    required this.lowStockCount,
    required this.expiringSoonCount,
    required this.expiryTrackingAvailable,
    required this.zeroStockItems,
    required this.lowStockItems,
    this.expiringSoonItems = const [],
  });
}

/// Replenishment priority tier for an item -- a direct relabeling of
/// [StockLevel]'s outOfStock/low/needsRestock tiers (inStock items don't
/// appear here at all), not a new stored attribute. Shared by the Staff
/// Dashboard's Replenishment card and its social-media post generator so
/// both always agree with each other and with the Replenishment page --
/// see CLAUDE.md's Data Scope Rule: no `priority_level` column exists, so
/// this is derived, not persisted.
enum ReplenishmentPriority { critical, high, medium }

/// One item at or below its stock threshold -- same shape as
/// [DashboardStockAlert] plus which [ReplenishmentPriority] tier it's in.
class ReplenishmentAlert {
  final String itemId;
  final String itemName;
  final double stockQty;
  final String unitAbbr;
  final ReplenishmentPriority priority;

  const ReplenishmentAlert({
    required this.itemId,
    required this.itemName,
    required this.stockQty,
    required this.unitAbbr,
    required this.priority,
  });
}

/// Purchases/Treatments/Donations rolled up over a single trailing window
/// (this week or this month) plus the equal-length window immediately
/// before it, for the Staff Dashboard's Week/Month toggle. Nothing here is
/// stored -- it's recomputed from dated rows on every fetch.
class DashboardPeriodStats {
  final int purchaseCount;
  final int purchaseCountPrior;
  final int itemsReceived;
  final int itemsReceivedPrior;
  final int distinctSuppliers;
  final int distinctSuppliersPrior;

  final int treatmentCount;
  final int treatmentCountPrior;
  final int animalsTreated;
  final int animalsTreatedPrior;
  final int itemsDispensed;
  final int itemsDispensedPrior;
  final int staffWhoRecorded;

  final int donationCount;
  final int donationCountPrior;
  final int itemsDonated;
  final int itemsDonatedPrior;
  final int distinctDonors;
  final int distinctDonorsPrior;
  final int largestDropoff;

  const DashboardPeriodStats({
    required this.purchaseCount,
    required this.purchaseCountPrior,
    required this.itemsReceived,
    required this.itemsReceivedPrior,
    required this.distinctSuppliers,
    required this.distinctSuppliersPrior,
    required this.treatmentCount,
    required this.treatmentCountPrior,
    required this.animalsTreated,
    required this.animalsTreatedPrior,
    required this.itemsDispensed,
    required this.itemsDispensedPrior,
    required this.staffWhoRecorded,
    required this.donationCount,
    required this.donationCountPrior,
    required this.itemsDonated,
    required this.itemsDonatedPrior,
    required this.distinctDonors,
    required this.distinctDonorsPrior,
    required this.largestDropoff,
  });
}

/// (arrow+percent label, direction) for a period-over-period change, or
/// null when there's no prior-period data to compare against (dividing by
/// a zero prior would be a nonsensical "+inf%").
({String label, bool isUp, bool isFlat})? percentChange(int current, int prior) {
  if (prior == 0) {
    return current == 0 ? (label: '–0%', isUp: false, isFlat: true) : null;
  }
  final pct = (current - prior) / prior * 100;
  final rounded = pct.round();
  if (rounded == 0) return (label: '–0%', isUp: false, isFlat: true);
  final arrow = rounded > 0 ? '↑' : '↓';
  return (label: '$arrow${rounded.abs()}%', isUp: rounded > 0, isFlat: false);
}

/// Aggregate counts for the Staff dashboard. Stock tiers mirror
/// [StockLevel] (outOfStock/low/needsRestock) via [ReplenishmentAlert] --
/// the same list backs the Replenishment card's counts and the social-post
/// generator, so they can't drift apart.
class StaffDashboardStats {
  final int totalItems;
  final int outOfStockCount;
  final int lowStockCount;
  final int needsRestockCount;

  final int animalsUnderTreatment;

  final int pendingSubmissions;
  final int pendingScheduled;
  final int pendingOverdue;
  final int pendingUnscheduled;

  final DateTime? mostRecentDeliveryDate;

  final DashboardPeriodStats week;
  final DashboardPeriodStats month;

  const StaffDashboardStats({
    required this.totalItems,
    required this.outOfStockCount,
    required this.lowStockCount,
    required this.needsRestockCount,
    required this.animalsUnderTreatment,
    required this.pendingSubmissions,
    required this.pendingScheduled,
    required this.pendingOverdue,
    required this.pendingUnscheduled,
    required this.mostRecentDeliveryDate,
    required this.week,
    required this.month,
  });

  /// Items above the low-stock line (needsRestock + inStock) -- the
  /// numerator for the dashboard's Inventory Health bar.
  int get healthyItemCount => totalItems - outOfStockCount - lowStockCount;

  double get inventoryHealthPct =>
      totalItems == 0 ? 0 : healthyItemCount / totalItems * 100;
}

/// Aggregate stats for the signed-in donor.
class DonorDashboardStats {
  final int totalDonations;
  final int itemsDonated;
  final int pendingSubmissions;
  final DateTime? lastDonation;

  const DonorDashboardStats({
    required this.totalDonations,
    required this.itemsDonated,
    required this.pendingSubmissions,
    this.lastDonation,
  });
}

/// Data-access interface for dashboard aggregates. The factory resolves to
/// the mock or Supabase implementation based on [kUseMock], chosen at build
/// time.
abstract interface class DashboardService {
  factory DashboardService() =>
      kUseMock ? MockDashboardService() : SupabaseDashboardService();

  Future<ManagerDashboardStats> fetchManagerStats();
  Future<StaffDashboardStats> fetchStaffStats();
  Future<DonorDashboardStats> fetchDonorStats(String donorId);

  /// The current Replenishment list -- same data the Replenishment page and
  /// the Staff Dashboard's social-post generator both read from.
  Future<List<ReplenishmentAlert>> fetchReplenishmentAlerts();
}

class MockDashboardService implements DashboardService {
  final MockDatabase _db = MockDatabase.instance;

  DashboardStockAlert _alertFromRow(ItemRow row) {
    final unit =
        firstWhereOrNull(_db.units, (u) => u.id == row.purchaseUnitId);
    return DashboardStockAlert(
      itemId: row.id,
      itemName: row.name,
      stockQty: row.purchaseStocks,
      unitAbbr: unit?.abbrName ?? '',
    );
  }

  List<DashboardStockAlert> _stockAlerts(bool Function(ItemRow) test) {
    final alerts = _db.items.where(test).map(_alertFromRow).toList();
    alerts.sort((a, b) {
      final byQty = a.stockQty.compareTo(b.stockQty);
      return byQty != 0 ? byQty : a.itemName.compareTo(b.itemName);
    });
    return alerts;
  }

  @override
  Future<ManagerDashboardStats> fetchManagerStats() async {
    final zeroStockItems = _stockAlerts(isItemRowOutOfStock);
    final lowStockItems = _stockAlerts(isItemRowLowStock);
    final expiringSoonItems =
        expiryAlerts(_db, _db.systemSettings.expirationWarningDays);

    return ManagerDashboardStats(
      totalAnimals: _db.pets.length,
      totalSuppliers: _db.suppliers.length,
      pendingSubmissions: _db.submissions.where((s) => s.status == 'pending').length,
      staffAccounts: _db.users.where((u) => u.role == AppRole.staff).length,
      totalItems: _db.items.length,
      zeroStockCount: zeroStockItems.length,
      lowStockCount: lowStockItems.length,
      expiringSoonCount: expiringSoonItems.length,
      expiryTrackingAvailable: true,
      zeroStockItems: zeroStockItems,
      lowStockItems: lowStockItems,
      expiringSoonItems: expiringSoonItems,
    );
  }

  @override
  Future<List<ReplenishmentAlert>> fetchReplenishmentAlerts() async {
    final alerts = <ReplenishmentAlert>[];
    for (final row in _db.items) {
      ReplenishmentPriority? priority;
      if (isItemRowOutOfStock(row)) {
        priority = ReplenishmentPriority.critical;
      } else if (isItemRowLowStock(row)) {
        priority = ReplenishmentPriority.high;
      } else if (isItemRowNeedsRestock(row)) {
        priority = ReplenishmentPriority.medium;
      }
      if (priority == null) continue;

      final unit = firstWhereOrNull(_db.units, (u) => u.id == row.purchaseUnitId);
      alerts.add(ReplenishmentAlert(
        itemId: row.id,
        itemName: row.name,
        stockQty: row.purchaseStocks,
        unitAbbr: unit?.abbrName ?? '',
        priority: priority,
      ));
    }
    alerts.sort((a, b) {
      final byPriority = a.priority.index.compareTo(b.priority.index);
      if (byPriority != 0) return byPriority;
      final byQty = a.stockQty.compareTo(b.stockQty);
      return byQty != 0 ? byQty : a.itemName.compareTo(b.itemName);
    });
    return alerts;
  }

  /// Counts and per-window figures for one trailing [windowDays] period
  /// (e.g. 7 for "this week") plus the equal-length period right before it.
  DashboardPeriodStats _periodStats(int windowDays) {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: windowDays));
    final priorStart = now.subtract(Duration(days: windowDays * 2));

    bool inCurrent(DateTime d) => d.isAfter(start);
    bool inPrior(DateTime d) => d.isAfter(priorStart) && !d.isAfter(start);

    final purchasesCur =
        _db.purchases.where((p) => inCurrent(p.receivedDate)).toList();
    final purchasesPrior =
        _db.purchases.where((p) => inPrior(p.receivedDate)).toList();

    int itemsReceivedFor(List<PurchaseRow> list) {
      final ids = list.map((p) => p.id).toSet();
      var total = 0.0;
      for (final pi in _db.purchaseItems) {
        if (ids.contains(pi.purchaseId)) total += pi.qty;
      }
      return total.round();
    }

    int suppliersFor(List<PurchaseRow> list) =>
        list.map((p) => p.suppId).toSet().length;

    final treatmentsCur =
        _db.treatments.where((t) => inCurrent(t.recordedDate)).toList();
    final treatmentsPrior =
        _db.treatments.where((t) => inPrior(t.recordedDate)).toList();

    int animalsTreatedFor(List<TreatmentRow> list) =>
        list.map((t) => t.petId).toSet().length;
    int staffFor(List<TreatmentRow> list) =>
        list.map((t) => t.recordedByUserId).toSet().length;
    int itemsDispensedFor(List<TreatmentRow> list) {
      final ids = list.map((t) => t.id).toSet();
      return _db.treatmentItems.where((ti) => ids.contains(ti.treatId)).length;
    }

    final donationsCur =
        _db.donations.where((d) => inCurrent(d.receivedDate)).toList();
    final donationsPrior =
        _db.donations.where((d) => inPrior(d.receivedDate)).toList();

    double donationTotal(String donationId) {
      var total = 0.0;
      for (final di in _db.donationItems) {
        if (di.donId == donationId) total += di.qty;
      }
      return total;
    }

    int itemsDonatedFor(List<DonationRow> list) =>
        list.fold(0.0, (sum, d) => sum + donationTotal(d.id)).round();
    int donorsFor(List<DonationRow> list) =>
        list.map((d) => d.donorId ?? d.donorName ?? d.id).toSet().length;
    int largestDropoffFor(List<DonationRow> list) => list
        .fold(0.0, (max, d) => donationTotal(d.id) > max ? donationTotal(d.id) : max)
        .round();

    return DashboardPeriodStats(
      purchaseCount: purchasesCur.length,
      purchaseCountPrior: purchasesPrior.length,
      itemsReceived: itemsReceivedFor(purchasesCur),
      itemsReceivedPrior: itemsReceivedFor(purchasesPrior),
      distinctSuppliers: suppliersFor(purchasesCur),
      distinctSuppliersPrior: suppliersFor(purchasesPrior),
      treatmentCount: treatmentsCur.length,
      treatmentCountPrior: treatmentsPrior.length,
      animalsTreated: animalsTreatedFor(treatmentsCur),
      animalsTreatedPrior: animalsTreatedFor(treatmentsPrior),
      itemsDispensed: itemsDispensedFor(treatmentsCur),
      itemsDispensedPrior: itemsDispensedFor(treatmentsPrior),
      staffWhoRecorded: staffFor(treatmentsCur),
      donationCount: donationsCur.length,
      donationCountPrior: donationsPrior.length,
      itemsDonated: itemsDonatedFor(donationsCur),
      itemsDonatedPrior: itemsDonatedFor(donationsPrior),
      distinctDonors: donorsFor(donationsCur),
      distinctDonorsPrior: donorsFor(donationsPrior),
      largestDropoff: largestDropoffFor(donationsCur),
    );
  }

  @override
  Future<StaffDashboardStats> fetchStaffStats() async {
    final alerts = await fetchReplenishmentAlerts();
    final outOfStockCount =
        alerts.where((a) => a.priority == ReplenishmentPriority.critical).length;
    final lowStockCount =
        alerts.where((a) => a.priority == ReplenishmentPriority.high).length;
    final needsRestockCount =
        alerts.where((a) => a.priority == ReplenishmentPriority.medium).length;

    final pending = _db.submissions.where((s) => s.status == 'pending').toList();
    final now = DateTime.now();
    final pendingScheduled = pending
        .where((s) => s.schedDate != null && !s.schedDate!.isBefore(now))
        .length;
    final pendingOverdue =
        pending.where((s) => s.schedDate != null && s.schedDate!.isBefore(now)).length;
    final pendingUnscheduled = pending.where((s) => s.schedDate == null).length;

    DateTime? mostRecentDelivery;
    for (final p in _db.purchases) {
      if (mostRecentDelivery == null || p.receivedDate.isAfter(mostRecentDelivery)) {
        mostRecentDelivery = p.receivedDate;
      }
    }

    return StaffDashboardStats(
      totalItems: _db.items.length,
      outOfStockCount: outOfStockCount,
      lowStockCount: lowStockCount,
      needsRestockCount: needsRestockCount,
      animalsUnderTreatment:
          _db.pets.where((p) => p.status == PetStatus.underTreatment).length,
      pendingSubmissions: pending.length,
      pendingScheduled: pendingScheduled,
      pendingOverdue: pendingOverdue,
      pendingUnscheduled: pendingUnscheduled,
      mostRecentDeliveryDate: mostRecentDelivery,
      week: _periodStats(7),
      month: _periodStats(30),
    );
  }

  @override
  Future<DonorDashboardStats> fetchDonorStats(String donorId) async {
    final donations = _db.donations.where((d) => d.donorId == donorId).toList()
      ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));

    final donationIds = donations.map((d) => d.id).toSet();
    var itemsDonated = 0;
    for (final row in _db.donationItems) {
      if (donationIds.contains(row.donId)) itemsDonated += row.qty.round();
    }

    final pendingCount = _db.submissions
        .where((s) => s.donorId == donorId && s.status == 'pending')
        .length;

    return DonorDashboardStats(
      totalDonations: donations.length,
      itemsDonated: itemsDonated,
      pendingSubmissions: pendingCount,
      lastDonation: donations.isEmpty ? null : donations.first.receivedDate,
    );
  }
}
