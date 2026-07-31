import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard_service.dart';
import '../dashboard_stock_helpers.dart';
import '../expiry_alerts.dart';
import '../settings_service.dart';

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

  Future<Map<String, String>> _map(String table, String labelCol) async {
    final rows = await _client.from(table).select('id, $labelCol');
    return {
      for (final r in rows) r['id'] as String: (r[labelCol] as String?) ?? '',
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

  Future<
      ({
        List<DashboardStockAlert> zero,
        List<DashboardStockAlert> low,
        List<DashboardStockAlert> needsRestock,
      })> _fetchStockAlerts() async {
    final units = await _unitAbbrMap();
    final rows = await _client.from('item').select(
          'id, name, total_purchase_stocks, total_package_stocks, '
          'package_quantity, purchase_unit',
        );

    final zero = <DashboardStockAlert>[];
    final low = <DashboardStockAlert>[];
    final needsRestock = <DashboardStockAlert>[];

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
      } else if (isNeedsRestockFromPools(
        purchaseStocks,
        packageStocks,
        packageQuantity,
      )) {
        needsRestock.add(alert);
      }
    }

    int compareAlerts(DashboardStockAlert a, DashboardStockAlert b) {
      final byQty = a.stockQty.compareTo(b.stockQty);
      return byQty != 0 ? byQty : a.itemName.compareTo(b.itemName);
    }

    zero.sort(compareAlerts);
    low.sort(compareAlerts);
    needsRestock.sort(compareAlerts);
    return (zero: zero, low: low, needsRestock: needsRestock);
  }

  /// Earliest `expiry_date` across [itemid]'s purchase_item/donation_item
  /// batches that still have stock remaining (`qty_remaining > 0`). Mirrors
  /// `nearestBatchExpiry` in lib/services/expiry_alerts.dart, sourced from
  /// Supabase rows instead of MockDatabase.
  Future<List<ExpiryAlert>> _fetchExpiryAlerts(int warningDays) async {
    final itemNames = await _map('item', 'name');
    final purchaseRows = await _client
        .from('purchase_item')
        .select('itemid, expiry_date, qty_remaining')
        .not('expiry_date', 'is', null)
        .gt('qty_remaining', 0);
    final donationRows = await _client
        .from('donation_item')
        .select('itemid, expiry_date, qty_remaining')
        .not('expiry_date', 'is', null)
        .gt('qty_remaining', 0);

    final nearestByItem = <String, DateTime>{};
    void consider(String itemId, String? expiryDateStr) {
      if (expiryDateStr == null) return;
      final expiryDate = DateTime.parse(expiryDateStr);
      final existing = nearestByItem[itemId];
      if (existing == null || expiryDate.isBefore(existing)) {
        nearestByItem[itemId] = expiryDate;
      }
    }

    for (final r in purchaseRows) {
      consider(r['itemid'] as String, r['expiry_date'] as String?);
    }
    for (final r in donationRows) {
      consider(r['itemid'] as String, r['expiry_date'] as String?);
    }

    final today = DateTime.now();
    final cutoff = today.add(Duration(days: warningDays));
    final alerts = <ExpiryAlert>[];
    nearestByItem.forEach((itemId, expiry) {
      if (expiry.isAfter(cutoff)) return;
      alerts.add(ExpiryAlert(
        itemId: itemId,
        itemName: itemNames[itemId] ?? 'Unknown item',
        expiryDate: expiry,
        daysUntilExpiry: expiry.difference(today).inDays,
      ));
    });
    alerts.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return alerts;
  }

  @override
  Future<ManagerDashboardStats> fetchManagerStats() async {
    final pets = await _count('pet');
    final suppliers = await _count('supplier');
    final pending = await _client.from('submission').select('id').eq('status', 'pending');
    final staff = await _client.from('users').select('id').eq('role', 'staff');
    final totalItems = await _count('item');
    final alerts = await _fetchStockAlerts();
    final settings = await SettingsService().fetchSettings();
    final expiringSoonItems =
        await _fetchExpiryAlerts(settings.expirationWarningDays);

    return ManagerDashboardStats(
      totalAnimals: pets,
      totalSuppliers: suppliers,
      pendingSubmissions: pending.length,
      staffAccounts: staff.length,
      totalItems: totalItems,
      zeroStockCount: alerts.zero.length,
      lowStockCount: alerts.low.length,
      expiringSoonCount: expiringSoonItems.length,
      expiryTrackingAvailable: true,
      zeroStockItems: alerts.zero,
      lowStockItems: alerts.low,
      expiringSoonItems: expiringSoonItems,
    );
  }

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
      for (final a in alerts.needsRestock)
        ReplenishmentAlert(
          itemId: a.itemId,
          itemName: a.itemName,
          stockQty: a.stockQty,
          unitAbbr: a.unitAbbr,
          priority: ReplenishmentPriority.medium,
        ),
    ];
  }

  /// Counts and per-window figures for one trailing [windowDays] period
  /// (e.g. 7 for "this week") plus the equal-length period right before it.
  /// Mirrors MockDashboardService._periodStats
  /// (lib/services/dashboard_service.dart), sourced from Supabase range
  /// queries instead of MockDatabase.
  Future<DashboardPeriodStats> _periodStats(int windowDays) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(days: windowDays));
    final priorStart = now.subtract(Duration(days: windowDays * 2));

    bool inCurrent(DateTime d) => d.isAfter(start);
    bool inPrior(DateTime d) => d.isAfter(priorStart) && !d.isAfter(start);

    final purchaseRows = await _client
        .from('purchase')
        .select('id, suppid, receiveddate')
        .gte('receiveddate', priorStart.toUtc().toIso8601String());
    final purchasesCur = purchaseRows
        .where((p) => inCurrent(DateTime.parse(p['receiveddate'] as String)))
        .toList();
    final purchasesPrior = purchaseRows
        .where((p) => inPrior(DateTime.parse(p['receiveddate'] as String)))
        .toList();

    final purchaseItemRows =
        await _client.from('purchase_item').select('purchaseid, qty');
    double itemsReceivedFor(List<Map<String, dynamic>> list) {
      final ids = list.map((p) => p['id'] as String).toSet();
      var total = 0.0;
      for (final pi in purchaseItemRows) {
        if (ids.contains(pi['purchaseid'])) {
          total += (pi['qty'] as num).toDouble();
        }
      }
      return total;
    }

    int suppliersFor(List<Map<String, dynamic>> list) =>
        list.map((p) => p['suppid'] as String).toSet().length;

    final treatmentRows = await _client
        .from('treatment')
        .select('id, petid, recordedby, recordeddate')
        .gte('recordeddate', priorStart.toUtc().toIso8601String());
    final treatmentsCur = treatmentRows
        .where((t) => inCurrent(DateTime.parse(t['recordeddate'] as String)))
        .toList();
    final treatmentsPrior = treatmentRows
        .where((t) => inPrior(DateTime.parse(t['recordeddate'] as String)))
        .toList();

    int animalsTreatedFor(List<Map<String, dynamic>> list) =>
        list.map((t) => t['petid'] as String).toSet().length;
    int staffFor(List<Map<String, dynamic>> list) =>
        list.map((t) => t['recordedby'] as String).toSet().length;

    final treatmentItemRows =
        await _client.from('treatment_item').select('treatid');
    int itemsDispensedFor(List<Map<String, dynamic>> list) {
      final ids = list.map((t) => t['id'] as String).toSet();
      return treatmentItemRows.where((ti) => ids.contains(ti['treatid'])).length;
    }

    final donationRows = await _client
        .from('donation')
        .select('id, donorid, donor_name, receiveddate')
        .gte('receiveddate', priorStart.toUtc().toIso8601String());
    final donationsCur = donationRows
        .where((d) => inCurrent(DateTime.parse(d['receiveddate'] as String)))
        .toList();
    final donationsPrior = donationRows
        .where((d) => inPrior(DateTime.parse(d['receiveddate'] as String)))
        .toList();

    final donationItemRows =
        await _client.from('donation_item').select('dntid, qty');
    double donationTotal(String donationId) {
      var total = 0.0;
      for (final di in donationItemRows) {
        if (di['dntid'] == donationId) total += (di['qty'] as num).toDouble();
      }
      return total;
    }

    int itemsDonatedFor(List<Map<String, dynamic>> list) => list
        .fold(0.0, (sum, d) => sum + donationTotal(d['id'] as String))
        .round();
    int donorsFor(List<Map<String, dynamic>> list) => list
        .map((d) => (d['donorid'] ?? d['donor_name'] ?? d['id']) as String)
        .toSet()
        .length;
    int largestDropoffFor(List<Map<String, dynamic>> list) => list
        .fold(
            0.0,
            (max, d) => donationTotal(d['id'] as String) > max
                ? donationTotal(d['id'] as String)
                : max)
        .round();

    return DashboardPeriodStats(
      purchaseCount: purchasesCur.length,
      purchaseCountPrior: purchasesPrior.length,
      itemsReceived: itemsReceivedFor(purchasesCur).round(),
      itemsReceivedPrior: itemsReceivedFor(purchasesPrior).round(),
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

    final underTreatment = await _client
        .from('pet')
        .select('id')
        .eq('status', 'under_treatment');
    final pendingRows = await _client
        .from('submission')
        .select('id, drop_off_sched')
        .eq('status', 'pending');
    final now = DateTime.now();
    var pendingScheduled = 0;
    var pendingOverdue = 0;
    var pendingUnscheduled = 0;
    for (final row in pendingRows) {
      final raw = row['drop_off_sched'] as String?;
      if (raw == null) {
        pendingUnscheduled++;
      } else if (DateTime.parse(raw).isBefore(now)) {
        pendingOverdue++;
      } else {
        pendingScheduled++;
      }
    }

    final mostRecentRow = await _client
        .from('purchase')
        .select('receiveddate')
        .order('receiveddate', ascending: false)
        .limit(1)
        .maybeSingle();
    final mostRecentDeliveryDate = mostRecentRow == null
        ? null
        : DateTime.parse(mostRecentRow['receiveddate'] as String);

    return StaffDashboardStats(
      totalItems: await _count('item'),
      outOfStockCount: outOfStockCount,
      lowStockCount: lowStockCount,
      needsRestockCount: needsRestockCount,
      animalsUnderTreatment: underTreatment.length,
      pendingSubmissions: pendingRows.length,
      pendingScheduled: pendingScheduled,
      pendingOverdue: pendingOverdue,
      pendingUnscheduled: pendingUnscheduled,
      mostRecentDeliveryDate: mostRecentDeliveryDate,
      week: await _periodStats(7),
      month: await _periodStats(30),
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
