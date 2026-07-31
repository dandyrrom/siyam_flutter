import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard_service.dart';
import '../dashboard_stock_helpers.dart';

/// Supabase-backed dashboard aggregates. Counts are derived from small
/// filtered selects (the data volume here is modest).
class SupabaseDashboardService implements DashboardService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<int> _count(String table) async {
    final rows = await _client.from(table).select('id');
    return rows.length;
  }

  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select('id, abbr_name');
    return {
      for (final r in rows) r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  double? _toDouble(dynamic v) => v == null ? null : (v as num).toDouble();

  DashboardStockAlert _alertFromRow(
    Map<String, dynamic> row,
    Map<String, String> units,
  ) {
    final purchaseUnitId = row['purchase_unit'] as String;
    return DashboardStockAlert(
      itemId: row['id'] as String,
      itemName: (row['name'] as String?) ?? '',
      stockQty: _toDouble(row['total_purchase_stocks']) ?? 0,
      unitAbbr: units[purchaseUnitId] ?? '',
    );
  }

  Future<({List<DashboardStockAlert> zero, List<DashboardStockAlert> low})>
      _fetchStockAlerts() async {
    final units = await _unitAbbrMap();
    final rows = await _client.from('item').select(
          'id, name, total_purchase_stocks, total_package_stocks, '
          'package_quantity, purchase_unit',
        );

    final zero = <DashboardStockAlert>[];
    final low = <DashboardStockAlert>[];

    for (final row in rows) {
      final purchaseStocks = _toDouble(row['total_purchase_stocks']) ?? 0;
      final packageStocks = _toDouble(row['total_package_stocks']);
      final packageQuantity = _toDouble(row['package_quantity']);
      final alert = _alertFromRow(row, units);

      if (isOutOfStockFromPools(purchaseStocks, packageStocks, packageQuantity)) {
        zero.add(alert);
      } else if (isLowStockFromPools(
        purchaseStocks,
        packageStocks,
        packageQuantity,
      )) {
        low.add(alert);
      }
    }

    int compareAlerts(DashboardStockAlert a, DashboardStockAlert b) {
      final byQty = a.stockQty.compareTo(b.stockQty);
      return byQty != 0 ? byQty : a.itemName.compareTo(b.itemName);
    }

    zero.sort(compareAlerts);
    low.sort(compareAlerts);
    return (zero: zero, low: low);
  }

  @override
  Future<ManagerDashboardStats> fetchManagerStats() async {
    final pets = await _count('pet');
    final suppliers = await _count('supplier');
    final pending = await _client.from('submission').select('id').eq('status', 'pending');
    final staff = await _client.from('users').select('id').eq('role', 'staff');
    final totalItems = await _count('item');
    final alerts = await _fetchStockAlerts();

    return ManagerDashboardStats(
      totalAnimals: pets,
      totalSuppliers: suppliers,
      pendingSubmissions: pending.length,
      staffAccounts: staff.length,
      totalItems: totalItems,
      zeroStockCount: alerts.zero.length,
      lowStockCount: alerts.low.length,
      expiringSoonCount: 0,
      expiryTrackingAvailable: false,
      zeroStockItems: alerts.zero,
      lowStockItems: alerts.low,
    );
  }

  // not yet migrated -- see KNOWN_LIMITATIONS.md ("Staff Dashboard
  // week/month period stats -- mock-only for now"). Priority tiers only go
  // as far as zero/low, matching _fetchStockAlerts; there's no needsRestock
  // tier here yet.
  @override
  Future<List<ReplenishmentAlert>> fetchReplenishmentAlerts() async {
    final alerts = await _fetchStockAlerts();
    return [
      for (final a in alerts.zero)
        ReplenishmentAlert(
          itemId: a.itemId,
          itemName: a.itemName,
          stockQty: a.stockQty,
          unitAbbr: a.unitAbbr,
          priority: ReplenishmentPriority.critical,
        ),
      for (final a in alerts.low)
        ReplenishmentAlert(
          itemId: a.itemId,
          itemName: a.itemName,
          stockQty: a.stockQty,
          unitAbbr: a.unitAbbr,
          priority: ReplenishmentPriority.high,
        ),
    ];
  }

  @override
  Future<StaffDashboardStats> fetchStaffStats() async {
    final alerts = await fetchReplenishmentAlerts();
    final outOfStockCount =
        alerts.where((a) => a.priority == ReplenishmentPriority.critical).length;
    final lowStockCount =
        alerts.where((a) => a.priority == ReplenishmentPriority.high).length;

    final underTreatment = await _client
        .from('pet')
        .select('id')
        .eq('status', 'under_treatment');
    final pendingRows = await _client
        .from('submission')
        .select('id, scheddate')
        .eq('status', 'pending');
    final now = DateTime.now();
    var pendingScheduled = 0;
    var pendingOverdue = 0;
    var pendingUnscheduled = 0;
    for (final row in pendingRows) {
      final raw = row['scheddate'] as String?;
      if (raw == null) {
        pendingUnscheduled++;
      } else if (DateTime.parse(raw).isBefore(now)) {
        pendingOverdue++;
      } else {
        pendingScheduled++;
      }
    }

    // not yet migrated -- see KNOWN_LIMITATIONS.md. Purchases/Treatments/
    // Donations week-over-week and month-over-month breakdowns are only
    // implemented against the mock data layer for now; the Supabase
    // dashboard shows a zeroed period so the Week/Month toggle renders
    // without crashing rather than lying with fabricated deltas.
    const emptyPeriod = DashboardPeriodStats(
      purchaseCount: 0,
      purchaseCountPrior: 0,
      itemsReceived: 0,
      itemsReceivedPrior: 0,
      distinctSuppliers: 0,
      distinctSuppliersPrior: 0,
      treatmentCount: 0,
      treatmentCountPrior: 0,
      animalsTreated: 0,
      animalsTreatedPrior: 0,
      itemsDispensed: 0,
      itemsDispensedPrior: 0,
      staffWhoRecorded: 0,
      donationCount: 0,
      donationCountPrior: 0,
      itemsDonated: 0,
      itemsDonatedPrior: 0,
      distinctDonors: 0,
      distinctDonorsPrior: 0,
      largestDropoff: 0,
    );

    return StaffDashboardStats(
      totalItems: await _count('item'),
      outOfStockCount: outOfStockCount,
      lowStockCount: lowStockCount,
      needsRestockCount: 0,
      animalsUnderTreatment: underTreatment.length,
      pendingSubmissions: pendingRows.length,
      pendingScheduled: pendingScheduled,
      pendingOverdue: pendingOverdue,
      pendingUnscheduled: pendingUnscheduled,
      mostRecentDeliveryDate: null,
      week: emptyPeriod,
      month: emptyPeriod,
    );
  }

  @override
  Future<DonorDashboardStats> fetchDonorStats(String donorId) async {
    final donations = await _client
        .from('donation')
        .select('id, receiveddate')
        .eq('donorid', donorId)
        .order('receiveddate', ascending: false);

    final itemRows = await _client
        .from('donation_item')
        .select('qty, donation!inner(donorid)')
        .eq('donation.donorid', donorId);
    var itemsDonated = 0;
    for (final r in itemRows) {
      itemsDonated += ((r['qty'] as num?)?.toDouble() ?? 0).round();
    }

    final pending = await _client
        .from('submission')
        .select('id')
        .eq('donorid', donorId)
        .eq('status', 'pending');

    return DonorDashboardStats(
      totalDonations: donations.length,
      itemsDonated: itemsDonated,
      pendingSubmissions: pending.length,
      lastDonation: donations.isEmpty
          ? null
          : DateTime.parse(donations.first['receiveddate'] as String),
    );
  }
}
