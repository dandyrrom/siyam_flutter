import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/inventory_item.dart';
import '../dashboard_service.dart';
import '../expiry_alerts.dart';
import '../settings_service.dart';

/// Supabase-backed dashboard aggregates.
///
/// INVENTORY ALERT SOURCE OF TRUTH:
///
/// inventory_batch
///
/// - usable stock excludes expired/quarantined/depleted batches
/// - expired physical stock remains alertable until staff removes it
/// - nearest valid expiry is used for Expiring Soon
class SupabaseDashboardService implements DashboardService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<int> _count(String table) async {
    final rows = await _client.from(table).select('id');
    return rows.length;
  }

  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select('id, abbr_name');

    return {
      for (final r in rows)
        r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    return (value as num).toDouble();
  }

  DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _dateOnly(dynamic value) {
    if (value == null) return null;

    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return null;

    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    );
  }

  bool _hasPackageBreakdown(Map<String, dynamic> item) {
    final packageQuantity = _toDouble(item['package_quantity']);

    return packageQuantity != null &&
        packageQuantity > 0 &&
        item['package_unit'] != null;
  }

  double _canonicalBatchQty(
    Map<String, dynamic> batch,
    Map<String, dynamic> item,
  ) {
    final qty = _toDouble(batch['qtyavailable']) ?? 0;

    if (!_hasPackageBreakdown(item)) {
      return qty;
    }

    final packageQuantity =
        _toDouble(item['package_quantity'])!;

    final qtyUnit =
        (batch['qtyunit'] as String?) ?? 'purchase_unit';

    return qtyUnit == 'purchase_unit'
        ? qty * packageQuantity
        : qty;
  }

  String _canonicalUnitAbbr(
    Map<String, dynamic> item,
    Map<String, String> units,
  ) {
    if (_hasPackageBreakdown(item)) {
      return units[item['package_unit']] ?? '';
    }

    return units[item['purchase_unit']] ?? '';
  }

  // ==========================================================================
  // BATCH-AWARE STOCK ALERTS
  // ==========================================================================

  Future<
      ({
        List<DashboardStockAlert> zero,
        List<DashboardStockAlert> low,
        List<DashboardStockAlert> needsRestock,
      })> _fetchStockAlerts() async {
    final units = await _unitAbbrMap();

    final itemRows = await _client.from('item').select(
      'id, name, total_purchase_stocks, total_package_stocks, '
      'package_quantity, purchase_unit, package_unit',
    );

    // Load all batches, including zero/depleted rows, so merely having batch
    // history is enough to switch the item away from legacy aggregate fallback.
    final rawBatchRows = await _client.from('inventory_batch').select(
      'itemid, qtyavailable, qtyunit, status, expirydate',
    );

    final batchesByItem =
        <String, List<Map<String, dynamic>>>{};

    for (final raw in rawBatchRows) {
      final batch =
          Map<String, dynamic>.from(raw);

      final itemId =
          batch['itemid'] as String;

      batchesByItem
          .putIfAbsent(itemId, () => [])
          .add(batch);
    }

    final today = _todayOnly();

    final zero = <DashboardStockAlert>[];
    final low = <DashboardStockAlert>[];
    final needsRestock = <DashboardStockAlert>[];

    for (final rawItem in itemRows) {
      final item =
          Map<String, dynamic>.from(rawItem);

      final itemId = item['id'] as String;
      final itemName =
          (item['name'] as String?) ?? '';

      final purchaseUnitAbbr =
          units[item['purchase_unit']] ?? '';

      final packageQuantity =
          _toDouble(item['package_quantity']);

      final itemBatches =
          batchesByItem[itemId] ?? const [];

      final hasBatchHistory =
          itemBatches.isNotEmpty;

      double purchaseEquivalent;

      if (hasBatchHistory) {
        // ====================================================================
        // AUTHORITATIVE USABLE BATCH STOCK
        // ====================================================================

        double usableCanonical = 0;

        for (final batch in itemBatches) {
          final qty =
              _toDouble(batch['qtyavailable']) ?? 0;

          if (qty <= 0) continue;

          final status =
              ((batch['status'] as String?) ?? 'ACTIVE')
                  .toUpperCase();

          if (status == 'DEPLETED' ||
              status == 'QUARANTINED') {
            continue;
          }

          final expiry =
              _dateOnly(batch['expirydate']);

          if (expiry != null &&
              expiry.isBefore(today)) {
            continue;
          }

          usableCanonical +=
              _canonicalBatchQty(batch, item);
        }

        if (_hasPackageBreakdown(item)) {
          purchaseEquivalent =
              usableCanonical / packageQuantity!;
        } else {
          purchaseEquivalent =
              usableCanonical;
        }
      } else {
        // ====================================================================
        // LEGACY FALLBACK
        // ====================================================================
        //
        // Only used by items that genuinely have no inventory_batch history.
        // ====================================================================

        final purchaseStock =
            _toDouble(item['total_purchase_stocks']) ?? 0;

        final packageStock =
            _toDouble(item['total_package_stocks']);

        if (_hasPackageBreakdown(item) &&
            packageStock != null) {
          purchaseEquivalent =
              packageStock / packageQuantity!;
        } else {
          purchaseEquivalent = purchaseStock;
        }
      }

      final alert = DashboardStockAlert(
        itemId: itemId,
        itemName: itemName,
        stockQty: purchaseEquivalent,
        unitAbbr: purchaseUnitAbbr,
      );

      if (purchaseEquivalent <= 0) {
        zero.add(alert);
      } else if (purchaseEquivalent <=
          lowStockPurchaseUnitThreshold) {
        low.add(alert);
      } else if (purchaseEquivalent <= 30) {
        needsRestock.add(alert);
      }
    }

    int compareAlerts(
      DashboardStockAlert a,
      DashboardStockAlert b,
    ) {
      final byQty =
          a.stockQty.compareTo(b.stockQty);

      return byQty != 0
          ? byQty
          : a.itemName.compareTo(b.itemName);
    }

    zero.sort(compareAlerts);
    low.sort(compareAlerts);
    needsRestock.sort(compareAlerts);

    return (
      zero: zero,
      low: low,
      needsRestock: needsRestock,
    );
  }

  // ==========================================================================
  // INVENTORY-BATCH EXPIRY ALERTS
  // ==========================================================================
  //
  // One item may produce BOTH:
  //
  // EXPIRED STOCK
  //   Stock is physically present but its expiry date is past.
  //
  // EXPIRING SOON
  //   Earliest VALID batch expires within warningDays.
  //
  // Expired batches are NOT considered for the upcoming FEFO alert.
  // ==========================================================================

  Future<List<ExpiryAlert>> _fetchExpiryAlerts(
    int warningDays,
  ) async {
    final units = await _unitAbbrMap();

    final rawItemRows = await _client.from('item').select(
      'id, name, purchase_unit, package_unit, package_quantity',
    );

    final itemsById =
        <String, Map<String, dynamic>>{
      for (final raw in rawItemRows)
        raw['id'] as String:
            Map<String, dynamic>.from(raw),
    };

    final rawBatchRows = await _client
        .from('inventory_batch')
        .select(
          'itemid, expirydate, qtyavailable, qtyunit, status',
        );

    final today = _todayOnly();
    final cutoff =
        today.add(Duration(days: warningDays));

    final expiredQtyByItem =
        <String, double>{};

    final oldestExpiredByItem =
        <String, DateTime>{};

    final nearestUpcomingByItem =
        <String, DateTime>{};

    final nearestUpcomingQtyByItem =
        <String, double>{};

    for (final raw in rawBatchRows) {
      final batch =
          Map<String, dynamic>.from(raw);

      final itemId =
          batch['itemid'] as String;

      final item = itemsById[itemId];
      if (item == null) continue;

      final qty =
          _toDouble(batch['qtyavailable']) ?? 0;

      if (qty <= 0) continue;

      final status =
          ((batch['status'] as String?) ?? 'ACTIVE')
              .toUpperCase();

      if (status == 'DEPLETED') {
        continue;
      }

      final expiry =
          _dateOnly(batch['expirydate']);

      if (expiry == null) continue;

      final canonicalQty =
          _canonicalBatchQty(batch, item);

      // ======================================================================
      // EXPIRED STOCK
      // ======================================================================
      //
      // Count expired stock even if it was quarantined, because it is still
      // physically present and must be removed by staff.
      // ======================================================================

      if (expiry.isBefore(today)) {
        expiredQtyByItem[itemId] =
            (expiredQtyByItem[itemId] ?? 0) +
                canonicalQty;

        final currentOldest =
            oldestExpiredByItem[itemId];

        if (currentOldest == null ||
            expiry.isBefore(currentOldest)) {
          oldestExpiredByItem[itemId] = expiry;
        }

        continue;
      }

      // ======================================================================
      // UPCOMING EXPIRY
      // ======================================================================

      if (status == 'QUARANTINED') {
        continue;
      }

      if (expiry.isAfter(cutoff)) {
        continue;
      }

      final currentNearest =
          nearestUpcomingByItem[itemId];

      if (currentNearest == null ||
          expiry.isBefore(currentNearest)) {
        nearestUpcomingByItem[itemId] = expiry;
        nearestUpcomingQtyByItem[itemId] =
            canonicalQty;
      } else if (expiry == currentNearest) {
        nearestUpcomingQtyByItem[itemId] =
            (nearestUpcomingQtyByItem[itemId] ?? 0) +
                canonicalQty;
      }
    }

    final alerts = <ExpiryAlert>[];

    for (final entry in itemsById.entries) {
      final itemId = entry.key;
      final item = entry.value;

      final itemName =
          (item['name'] as String?) ??
          'Unknown item';

      final unitAbbr =
          _canonicalUnitAbbr(item, units);

      // ======================================================================
      // EXPIRED STOCK ALERT
      // ======================================================================

      final expiredQty =
          expiredQtyByItem[itemId];

      final oldestExpired =
          oldestExpiredByItem[itemId];

      if (expiredQty != null &&
          expiredQty > 0 &&
          oldestExpired != null) {
        alerts.add(
          ExpiryAlert(
            kind:
                ExpiryAlertKind.expiredStock,
            itemId: itemId,
            itemName: itemName,
            expiryDate: oldestExpired,
            daysUntilExpiry:
                oldestExpired
                    .difference(today)
                    .inDays,
            qty: expiredQty,
            unitAbbr: unitAbbr,
          ),
        );
      }

      // ======================================================================
      // EXPIRING SOON ALERT
      // ======================================================================

      final nearestUpcoming =
          nearestUpcomingByItem[itemId];

      if (nearestUpcoming != null) {
        alerts.add(
          ExpiryAlert(
            kind:
                ExpiryAlertKind.expiringSoon,
            itemId: itemId,
            itemName: itemName,
            expiryDate: nearestUpcoming,
            daysUntilExpiry:
                nearestUpcoming
                    .difference(today)
                    .inDays,
            qty:
                nearestUpcomingQtyByItem[itemId],
            unitAbbr: unitAbbr,
          ),
        );
      }
    }

    // Expired-removal work first, then nearest upcoming expiries.
    alerts.sort((a, b) {
      if (a.kind != b.kind) {
        return a.kind.index.compareTo(
          b.kind.index,
        );
      }

      return a.expiryDate.compareTo(
        b.expiryDate,
      );
    });

    return alerts;
  }

  // ==========================================================================
  // MANAGER STATS
  // ==========================================================================

  @override
  Future<ManagerDashboardStats> fetchManagerStats() async {
    final pets = await _count('pet');
    final suppliers = await _count('supplier');

    final pending = await _client
        .from('submission')
        .select('id')
        .eq('status', 'pending');

    final staff = await _client
        .from('users')
        .select('id')
        .eq('role', 'staff');

    final totalItems = await _count('item');

    final alerts = await _fetchStockAlerts();

    final settings =
        await SettingsService().fetchSettings();

    final expiryAlerts =
        await _fetchExpiryAlerts(
      settings.expirationWarningDays,
    );

    return ManagerDashboardStats(
      totalAnimals: pets,
      totalSuppliers: suppliers,
      pendingSubmissions: pending.length,
      staffAccounts: staff.length,
      totalItems: totalItems,
      zeroStockCount: alerts.zero.length,
      lowStockCount: alerts.low.length,

      // Includes both expired-stock work and upcoming expiry warnings.
      expiringSoonCount: expiryAlerts.length,

      expiryTrackingAvailable: true,
      zeroStockItems: alerts.zero,
      lowStockItems: alerts.low,
      expiringSoonItems: expiryAlerts,
    );
  }

  // ==========================================================================
  // REPLENISHMENT
  // ==========================================================================

  @override
  Future<List<ReplenishmentAlert>>
      fetchReplenishmentAlerts() async {
    final alerts = await _fetchStockAlerts();

    return [
      for (final a in alerts.zero)
        ReplenishmentAlert(
          itemId: a.itemId,
          itemName: a.itemName,
          stockQty: a.stockQty,
          unitAbbr: a.unitAbbr,
          priority:
              ReplenishmentPriority.critical,
        ),
      for (final a in alerts.low)
        ReplenishmentAlert(
          itemId: a.itemId,
          itemName: a.itemName,
          stockQty: a.stockQty,
          unitAbbr: a.unitAbbr,
          priority:
              ReplenishmentPriority.high,
        ),
      for (final a in alerts.needsRestock)
        ReplenishmentAlert(
          itemId: a.itemId,
          itemName: a.itemName,
          stockQty: a.stockQty,
          unitAbbr: a.unitAbbr,
          priority:
              ReplenishmentPriority.medium,
        ),
    ];
  }

  // ==========================================================================
  // PERIOD STATS
  // ==========================================================================

  Future<DashboardPeriodStats> _periodStats(
    int windowDays,
  ) async {
    final now = DateTime.now();

    final start =
        now.subtract(Duration(days: windowDays));

    final priorStart = now.subtract(
      Duration(days: windowDays * 2),
    );

    bool inCurrent(DateTime d) =>
        d.isAfter(start);

    bool inPrior(DateTime d) =>
        d.isAfter(priorStart) &&
        !d.isAfter(start);

    final purchaseRows = await _client
        .from('purchase')
        .select('id, suppid, receiveddate')
        .gte(
          'receiveddate',
          priorStart.toUtc().toIso8601String(),
        );

    final purchasesCur = purchaseRows
        .where(
          (p) => inCurrent(
            DateTime.parse(
              p['receiveddate'] as String,
            ),
          ),
        )
        .toList();

    final purchasesPrior = purchaseRows
        .where(
          (p) => inPrior(
            DateTime.parse(
              p['receiveddate'] as String,
            ),
          ),
        )
        .toList();

    final purchaseItemRows =
        await _client
            .from('purchase_item')
            .select('purchaseid, qty');

    double itemsReceivedFor(
      List<Map<String, dynamic>> list,
    ) {
      final ids =
          list
              .map((p) => p['id'] as String)
              .toSet();

      var total = 0.0;

      for (final pi in purchaseItemRows) {
        if (ids.contains(pi['purchaseid'])) {
          total +=
              (pi['qty'] as num).toDouble();
        }
      }

      return total;
    }

    int suppliersFor(
      List<Map<String, dynamic>> list,
    ) {
      return list
          .map((p) => p['suppid'] as String)
          .toSet()
          .length;
    }

    final treatmentRows = await _client
        .from('treatment')
        .select(
          'id, petid, recordedby, recordeddate',
        )
        .gte(
          'recordeddate',
          priorStart.toUtc().toIso8601String(),
        );

    final treatmentsCur = treatmentRows
        .where(
          (t) => inCurrent(
            DateTime.parse(
              t['recordeddate'] as String,
            ),
          ),
        )
        .toList();

    final treatmentsPrior = treatmentRows
        .where(
          (t) => inPrior(
            DateTime.parse(
              t['recordeddate'] as String,
            ),
          ),
        )
        .toList();

    int animalsTreatedFor(
      List<Map<String, dynamic>> list,
    ) {
      return list
          .map((t) => t['petid'] as String)
          .toSet()
          .length;
    }

    int staffFor(
      List<Map<String, dynamic>> list,
    ) {
      return list
          .map((t) => t['recordedby'] as String)
          .toSet()
          .length;
    }

    final treatmentItemRows =
        await _client
            .from('treatment_item')
            .select('treatid');

    int itemsDispensedFor(
      List<Map<String, dynamic>> list,
    ) {
      final ids =
          list
              .map((t) => t['id'] as String)
              .toSet();

      return treatmentItemRows
          .where(
            (ti) =>
                ids.contains(ti['treatid']),
          )
          .length;
    }

    final donationRows = await _client
        .from('donation')
        .select(
          'id, donorid, donor_name, receiveddate',
        )
        .gte(
          'receiveddate',
          priorStart.toUtc().toIso8601String(),
        );

    final donationsCur = donationRows
        .where(
          (d) => inCurrent(
            DateTime.parse(
              d['receiveddate'] as String,
            ),
          ),
        )
        .toList();

    final donationsPrior = donationRows
        .where(
          (d) => inPrior(
            DateTime.parse(
              d['receiveddate'] as String,
            ),
          ),
        )
        .toList();

    final donationItemRows =
        await _client
            .from('donation_item')
            .select('dntid, qty');

    double donationTotal(String donationId) {
      var total = 0.0;

      for (final di in donationItemRows) {
        if (di['dntid'] == donationId) {
          total +=
              (di['qty'] as num).toDouble();
        }
      }

      return total;
    }

    int itemsDonatedFor(
      List<Map<String, dynamic>> list,
    ) {
      return list
          .fold<double>(
            0,
            (sum, d) =>
                sum +
                donationTotal(
                  d['id'] as String,
                ),
          )
          .round();
    }

    int donorsFor(
      List<Map<String, dynamic>> list,
    ) {
      return list
          .map(
            (d) =>
                (d['donorid'] ??
                        d['donor_name'] ??
                        d['id'])
                    as String,
          )
          .toSet()
          .length;
    }

    int largestDropoffFor(
      List<Map<String, dynamic>> list,
    ) {
      return list
          .fold<double>(
            0,
            (max, d) {
              final total =
                  donationTotal(
                d['id'] as String,
              );

              return total > max
                  ? total
                  : max;
            },
          )
          .round();
    }

    return DashboardPeriodStats(
      purchaseCount: purchasesCur.length,
      purchaseCountPrior:
          purchasesPrior.length,
      itemsReceived:
          itemsReceivedFor(purchasesCur)
              .round(),
      itemsReceivedPrior:
          itemsReceivedFor(purchasesPrior)
              .round(),
      distinctSuppliers:
          suppliersFor(purchasesCur),
      distinctSuppliersPrior:
          suppliersFor(purchasesPrior),
      treatmentCount:
          treatmentsCur.length,
      treatmentCountPrior:
          treatmentsPrior.length,
      animalsTreated:
          animalsTreatedFor(treatmentsCur),
      animalsTreatedPrior:
          animalsTreatedFor(treatmentsPrior),
      itemsDispensed:
          itemsDispensedFor(treatmentsCur),
      itemsDispensedPrior:
          itemsDispensedFor(treatmentsPrior),
      staffWhoRecorded:
          staffFor(treatmentsCur),
      donationCount:
          donationsCur.length,
      donationCountPrior:
          donationsPrior.length,
      itemsDonated:
          itemsDonatedFor(donationsCur),
      itemsDonatedPrior:
          itemsDonatedFor(donationsPrior),
      distinctDonors:
          donorsFor(donationsCur),
      distinctDonorsPrior:
          donorsFor(donationsPrior),
      largestDropoff:
          largestDropoffFor(donationsCur),
    );
  }

  // ==========================================================================
  // STAFF STATS
  // ==========================================================================

  @override
  Future<StaffDashboardStats> fetchStaffStats() async {
    final alerts =
        await fetchReplenishmentAlerts();

    final outOfStockCount = alerts
        .where(
          (a) =>
              a.priority ==
              ReplenishmentPriority.critical,
        )
        .length;

    final lowStockCount = alerts
        .where(
          (a) =>
              a.priority ==
              ReplenishmentPriority.high,
        )
        .length;

    final needsRestockCount = alerts
        .where(
          (a) =>
              a.priority ==
              ReplenishmentPriority.medium,
        )
        .length;

    final underTreatment = await _client
        .from('pet')
        .select('id')
        .eq(
          'status',
          'under_treatment',
        );

    final pendingRows = await _client
        .from('submission')
        .select('id, drop_off_sched')
        .eq('status', 'pending');

    final now = DateTime.now();

    var pendingScheduled = 0;
    var pendingOverdue = 0;
    var pendingUnscheduled = 0;

    for (final row in pendingRows) {
      final raw =
          row['drop_off_sched'] as String?;

      if (raw == null) {
        pendingUnscheduled++;
      } else if (DateTime.parse(raw)
          .isBefore(now)) {
        pendingOverdue++;
      } else {
        pendingScheduled++;
      }
    }

    final mostRecentRow = await _client
        .from('purchase')
        .select('receiveddate')
        .order(
          'receiveddate',
          ascending: false,
        )
        .limit(1)
        .maybeSingle();

    final mostRecentDeliveryDate =
        mostRecentRow == null
            ? null
            : DateTime.parse(
                mostRecentRow['receiveddate']
                    as String,
              );

    return StaffDashboardStats(
      totalItems: await _count('item'),
      outOfStockCount: outOfStockCount,
      lowStockCount: lowStockCount,
      needsRestockCount: needsRestockCount,
      animalsUnderTreatment:
          underTreatment.length,
      pendingSubmissions:
          pendingRows.length,
      pendingScheduled:
          pendingScheduled,
      pendingOverdue: pendingOverdue,
      pendingUnscheduled:
          pendingUnscheduled,
      mostRecentDeliveryDate:
          mostRecentDeliveryDate,
      week: await _periodStats(7),
      month: await _periodStats(30),
    );
  }

  // ==========================================================================
  // DONOR STATS
  // ==========================================================================

  @override
  Future<DonorDashboardStats> fetchDonorStats(
    String donorId,
  ) async {
    final donations = await _client
        .from('donation')
        .select('id, receiveddate')
        .eq('donorid', donorId)
        .order(
          'receiveddate',
          ascending: false,
        );

    final itemRows = await _client
        .from('donation_item')
        .select(
          'qty, donation!inner(donorid)',
        )
        .eq(
          'donation.donorid',
          donorId,
        );

    var itemsDonated = 0;

    for (final r in itemRows) {
      itemsDonated +=
          ((r['qty'] as num?)
                      ?.toDouble() ??
                  0)
              .round();
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
          : DateTime.parse(
              donations.first['receiveddate']
                  as String,
            ),
    );
  }
}