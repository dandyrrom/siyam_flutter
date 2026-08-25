import '../../models/replenishment_item.dart' as rop;
import '../dashboard_service.dart';
import '../replenishment_service.dart';
import 'supabase_dashboard_service.dart' as legacy;

/// ROP-aware dashboard adapter.
///
/// The existing Supabase dashboard service still provides all non-ROP
/// aggregates (animals, suppliers, expiry alerts, period stats, donor stats).
/// Stock-attention classification is replaced with the same
/// [ReplenishmentService] used by Ordering and Manager Reports.
///
/// This makes the following screens use one source of truth:
/// - Ordering -> Replenishment
/// - Inventory Low Stock
/// - Manager Dashboard Low Stock
/// - Staff Dashboard Stock Attention / priority counts
/// - Manager/Staff Notifications
/// - Social-media replenishment template
///
/// Low Stock now means:
///   usable stock > 0 AND usable stock <= calculated ROP
///
/// Zero Stock remains a separate physical-stock condition.
class SupabaseDashboardService implements DashboardService {
  final legacy.SupabaseDashboardService _base =
      legacy.SupabaseDashboardService();

  final ReplenishmentService _replenishmentService =
      ReplenishmentService();

  ReplenishmentPriority _dashboardPriority(
    rop.ReplenishmentPriority priority,
  ) {
    switch (priority) {
      case rop.ReplenishmentPriority.critical:
        return ReplenishmentPriority.critical;

      case rop.ReplenishmentPriority.high:
        return ReplenishmentPriority.high;

      case rop.ReplenishmentPriority.medium:
        return ReplenishmentPriority.medium;
    }
  }

  Future<List<rop.ReplenishmentItem>> _fetchRopRows() {
    return _replenishmentService.fetchReplenishmentItems();
  }

  @override
  Future<ManagerDashboardStats> fetchManagerStats() async {
    final results = await Future.wait<Object?>([
      _base.fetchManagerStats(),
      _fetchRopRows(),
    ]);

    final base =
        results[0] as ManagerDashboardStats;

    final ropRows =
        results[1] as List<rop.ReplenishmentItem>;

    // Zero stock is a physical-stock condition and remains sourced from the
    // existing batch-aware dashboard implementation.
    final zeroIds = base.zeroStockItems
        .map((alert) => alert.itemId)
        .toSet();

    // Low Stock is now exclusively ROP-driven.
    //
    // Exclude zero-stock rows here because Manager Dashboard already displays
    // those in its dedicated Zero Stock card/list.
    final lowStockItems = <DashboardStockAlert>[
      for (final row in ropRows)
        if (!zeroIds.contains(row.item.itemId) &&
            row.currentStockPurchaseUnits > 0)
          DashboardStockAlert(
            itemId: row.item.itemId,
            itemName: row.item.itemName,
            stockQty: row.currentStockPurchaseUnits,
            unitAbbr: row.item.purchaseUnitAbbr,
          ),
    ];

    lowStockItems.sort((a, b) {
      final byQty = a.stockQty.compareTo(b.stockQty);

      return byQty != 0
          ? byQty
          : a.itemName
              .toLowerCase()
              .compareTo(
                b.itemName.toLowerCase(),
              );
    });

    return ManagerDashboardStats(
      totalAnimals: base.totalAnimals,
      totalSuppliers: base.totalSuppliers,
      pendingSubmissions:
          base.pendingSubmissions,
      staffAccounts: base.staffAccounts,
      totalItems: base.totalItems,
      zeroStockCount:
          base.zeroStockItems.length,
      lowStockCount:
          lowStockItems.length,
      expiringSoonCount:
          base.expiringSoonCount,
      expiryTrackingAvailable:
          base.expiryTrackingAvailable,
      zeroStockItems:
          base.zeroStockItems,
      lowStockItems:
          lowStockItems,
      expiringSoonItems:
          base.expiringSoonItems,
    );
  }

  @override
  Future<List<ReplenishmentAlert>>
      fetchReplenishmentAlerts() async {
    final rows = await _fetchRopRows();

    return [
      for (final row in rows)
        ReplenishmentAlert(
          itemId: row.item.itemId,
          itemName: row.item.itemName,
          stockQty:
              row.currentStockPurchaseUnits,
          unitAbbr:
              row.item.purchaseUnitAbbr,
          priority:
              _dashboardPriority(row.priority),
        ),
    ];
  }

  @override
  Future<StaffDashboardStats> fetchStaffStats() async {
    final results = await Future.wait<Object?>([
      _base.fetchStaffStats(),
      _fetchRopRows(),
    ]);

    final base =
        results[0] as StaffDashboardStats;

    final rows =
        results[1] as List<rop.ReplenishmentItem>;

    final criticalCount = rows
        .where(
          (row) =>
              row.priority ==
              rop.ReplenishmentPriority.critical,
        )
        .length;

    final highCount = rows
        .where(
          (row) =>
              row.priority ==
              rop.ReplenishmentPriority.high,
        )
        .length;

    final mediumCount = rows
        .where(
          (row) =>
              row.priority ==
              rop.ReplenishmentPriority.medium,
        )
        .length;

    return StaffDashboardStats(
      totalItems: base.totalItems,
      outOfStockCount: criticalCount,
      lowStockCount: highCount,
      needsRestockCount: mediumCount,
      animalsUnderTreatment:
          base.animalsUnderTreatment,
      pendingSubmissions:
          base.pendingSubmissions,
      pendingScheduled:
          base.pendingScheduled,
      pendingOverdue:
          base.pendingOverdue,
      pendingUnscheduled:
          base.pendingUnscheduled,
      mostRecentDeliveryDate:
          base.mostRecentDeliveryDate,
      week: base.week,
      month: base.month,
    );
  }

  @override
  Future<DonorDashboardStats> fetchDonorStats(
    String donorId,
  ) {
    return _base.fetchDonorStats(donorId);
  }
}
