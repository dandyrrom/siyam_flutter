import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_item.dart';
import '../models/monthly_usage_report.dart';
import '../models/qty_unit.dart';
import 'inventory_service.dart';

class ReportService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  double _d(dynamic value) {
    if (value == null) return 0;
    return (value as num).toDouble();
  }

  String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _nextMonth(DateTime month) {
    return month.month == 12
        ? DateTime(month.year + 1, 1, 1)
        : DateTime(month.year, month.month + 1, 1);
  }

  double _treatmentPurchaseEquivalent(
    Map<String, dynamic> row,
    InventoryItem item,
  ) {
    if (!item.stockOutIsDeductible) return 0;

    final qty = _d(row['dispensed_qty']);
    if (qty <= 0) return 0;

    if (!item.hasPackageBreakdown) return qty;

    final packageQuantity = item.packageQuantity!;
    if (packageQuantity <= 0) return 0;

    final recordedUnitId = row['dispense_unit'] as String?;

    final effectiveUnitId =
        recordedUnitId ??
        item.dispenseUnitId ??
        item.packageUnitId ??
        item.purchaseUnitId;

    if (effectiveUnitId == item.purchaseUnitId) {
      return qty;
    }

    if (effectiveUnitId == item.packageUnitId) {
      return qty / packageQuantity;
    }

    return 0;
  }

  double _stockOutPurchaseEquivalent(
    Map<String, dynamic> row,
    InventoryItem item,
  ) {
    final qty = _d(row['qty']);
    if (qty <= 0) return 0;

    final qtyUnit = qtyUnitFromString(
      (row['qtyunit'] as String?) ?? 'purchase_unit',
    );

    if (qtyUnit == QtyUnit.packageUnit &&
        item.hasPackageBreakdown &&
        item.packageQuantity! > 0) {
      return qty / item.packageQuantity!;
    }

    return qty;
  }

  Future<MonthlyUsageReport> fetchMonthlyUsage(
    DateTime selectedMonth,
  ) async {
    final monthStart = DateTime(
      selectedMonth.year,
      selectedMonth.month,
      1,
    );

    final nextMonth = _nextMonth(monthStart);

    final results = await Future.wait<Object?>([
      _inventoryService.fetchItems(),
      _client
          .from('treatment_item')
          .select(
            'itemid, dispensed_qty, dispense_unit, consumeddate',
          )
          .gte('consumeddate', _dateOnly(monthStart))
          .lt('consumeddate', _dateOnly(nextMonth)),
      _client
          .from('stock_out')
          .select(
            'itemid, qty, qtyunit, reason, recordeddate',
          )
          .gte(
            'recordeddate',
            monthStart.toUtc().toIso8601String(),
          )
          .lt(
            'recordeddate',
            nextMonth.toUtc().toIso8601String(),
          ),
    ]);

    final items = results[0] as List<InventoryItem>;
    final treatmentRows = results[1] as List<dynamic>;
    final stockOutRows = results[2] as List<dynamic>;

    final itemById = <String, InventoryItem>{
      for (final item in items) item.itemId: item,
    };

    final usedByItem = <String, double>{};
    final lossByItem = <String, double>{};
    final usageEventsByItem = <String, int>{};
    final lossEventsByItem = <String, int>{};

    for (final raw in treatmentRows) {
      final row = Map<String, dynamic>.from(raw);
      final itemId = row['itemid'] as String?;
      if (itemId == null) continue;

      final item = itemById[itemId];
      if (item == null) continue;

      final qty = _treatmentPurchaseEquivalent(row, item);
      if (qty <= 0) continue;

      usedByItem[itemId] =
          (usedByItem[itemId] ?? 0) + qty;

      usageEventsByItem[itemId] =
          (usageEventsByItem[itemId] ?? 0) + 1;
    }

    for (final raw in stockOutRows) {
      final row = Map<String, dynamic>.from(raw);
      final itemId = row['itemid'] as String?;
      if (itemId == null) continue;

      final item = itemById[itemId];
      if (item == null) continue;

      final qty = _stockOutPurchaseEquivalent(row, item);
      if (qty <= 0) continue;

      final reason =
          ((row['reason'] as String?) ?? '')
              .trim()
              .toLowerCase();

      if (reason == 'adjustment') {
        continue;
      }

      if (reason == 'waste' || reason == 'expired') {
        lossByItem[itemId] =
            (lossByItem[itemId] ?? 0) + qty;

        lossEventsByItem[itemId] =
            (lossEventsByItem[itemId] ?? 0) + 1;

        continue;
      }

      usedByItem[itemId] =
          (usedByItem[itemId] ?? 0) + qty;

      usageEventsByItem[itemId] =
          (usageEventsByItem[itemId] ?? 0) + 1;
    }

    final rows = <MonthlyUsageRow>[];

    for (final item in items) {
      final used = usedByItem[item.itemId] ?? 0;
      final losses = lossByItem[item.itemId] ?? 0;

      if (used <= 0 && losses <= 0) continue;

      rows.add(
        MonthlyUsageRow(
          item: item,
          usedQty: used,
          lossQty: losses,
          usageEvents:
              usageEventsByItem[item.itemId] ?? 0,
          lossEvents:
              lossEventsByItem[item.itemId] ?? 0,
        ),
      );
    }

    rows.sort((a, b) {
      final byUsed = b.usedQty.compareTo(a.usedQty);
      if (byUsed != 0) return byUsed;

      final byLoss = b.lossQty.compareTo(a.lossQty);
      if (byLoss != 0) return byLoss;

      return a.item.itemName
          .toLowerCase()
          .compareTo(b.item.itemName.toLowerCase());
    });

    return MonthlyUsageReport(
      month: monthStart,
      rows: rows,
    );
  }
}
