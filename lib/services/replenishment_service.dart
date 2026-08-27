import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../mock/mock_database.dart';
import '../models/inventory_item.dart';
import '../models/item_rop_settings.dart';
import '../models/qty_unit.dart';
import '../models/replenishment_item.dart';
import '../models/stock_out.dart';
import '../models/system_settings.dart';
import 'backend.dart';
import 'inventory_service.dart';
import 'rop_service.dart';
import 'settings_service.dart';

// =============================================================================
// REPLENISHMENT SERVICE
// =============================================================================
//
// REAL SUPABASE CALCULATION
//
// Usage window: previous 30 days, including today.
//
// ADU = normalized 30-day usage / 30
//
// Raw ROP = (ADU × lead time days) + safety stock
// Operational ROP = ceil(Raw ROP) to a whole purchase unit
//
// Current Stock = InventoryItem.currentPurchaseUnitEquivalent
// Suggested Purchase Qty = ceil(max(0, Operational ROP - Current Stock))
//
// An item is shown when:
//   ROP > 0
//   AND Current Stock <= ROP
//
// IMPORTANT:
// SIYAM only recommends replenishment. It does not automatically create a
// purchase record/order.
//
// Mock mode never touches Supabase.instance (including at construction).
// =============================================================================

class ReplenishmentService {
  static const int usageWindowDays = 30;

  final InventoryService _inventoryService = InventoryService();
  final SettingsService _settingsService = SettingsService();
  final RopService _ropService = RopService();

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    return (value as num).toDouble();
  }

  String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // ===========================================================================
  // TREATMENT QUANTITY -> PURCHASE UNIT EQUIVALENT
  // ===========================================================================

  double _treatmentPurchaseEquivalent(
    Map<String, dynamic> row,
    InventoryItem item,
  ) {
    if (!item.stockOutIsDeductible) {
      return 0;
    }

    final qty = _toDouble(row['dispensed_qty']);
    if (qty <= 0) return 0;

    if (!item.hasPackageBreakdown) {
      return qty;
    }

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

  // ===========================================================================
  // STOCK-OUT QUANTITY -> PURCHASE UNIT EQUIVALENT
  // ===========================================================================

  double _stockOutPurchaseEquivalent(
    Map<String, dynamic> row,
    InventoryItem item,
  ) {
    final qty = _toDouble(row['qty']);
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

  bool _stockOutCountsTowardUsage(String? reason) {
    final normalized = (reason ?? '').trim().toLowerCase();

    return normalized != 'adjustment' &&
        normalized != 'expired';
  }

  ReplenishmentPriority _priorityFor({
    required double currentStock,
    required double reorderPoint,
    required double safetyStock,
  }) {
    if (currentStock <= 0) {
      return ReplenishmentPriority.critical;
    }

    final highBoundary = math.max(
      safetyStock,
      reorderPoint * 0.5,
    );

    if (currentStock <= highBoundary) {
      return ReplenishmentPriority.high;
    }

    return ReplenishmentPriority.medium;
  }

  /// Builds usage rows from MockDatabase for the mock path.
  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _mockUsageRows(
    DateTime startLocal,
  ) {
    final db = MockDatabase.instance;

    final treatmentRows = <Map<String, dynamic>>[];
    for (final row in db.treatmentItems) {
      final consumed = DateTime(
        row.consumedDate.year,
        row.consumedDate.month,
        row.consumedDate.day,
      );
      if (consumed.isBefore(startLocal)) continue;
      treatmentRows.add({
        'itemid': row.itemId,
        'dispensed_qty': row.dispensedQty,
        'dispense_unit': row.dispenseUnitId,
        'consumeddate': _dateOnly(row.consumedDate),
      });
    }

    final stockOutRows = <Map<String, dynamic>>[];
    for (final row in db.stockOuts) {
      if (row.recordedDate.isBefore(startLocal)) continue;
      stockOutRows.add({
        'itemid': row.itemId,
        'qty': row.qty,
        'qtyunit': qtyUnitToString(row.qtyUnit),
        'reason': stockOutReasonToString(row.reason),
        'recordeddate': row.recordedDate.toUtc().toIso8601String(),
      });
    }

    return (treatmentRows, stockOutRows);
  }

  // ===========================================================================
  // FETCH CALCULATED REPLENISHMENT LIST
  // ===========================================================================

  Future<List<ReplenishmentItem>> fetchReplenishmentItems() async {
    final now = DateTime.now();

    // Includes today + previous 29 calendar days.
    final startLocal = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(
      const Duration(days: usageWindowDays - 1),
    );

    late final List<InventoryItem> items;
    late final SystemSettings settings;
    late final List<ItemRopSettings> overrides;
    late final List<dynamic> treatmentRows;
    late final List<dynamic> stockOutRows;

    if (kUseMock) {
      final results = await Future.wait<Object?>([
        _inventoryService.fetchItems(),
        _settingsService.fetchSettings(),
        _ropService.fetchOverrides(),
      ]);

      items = results[0] as List<InventoryItem>;
      settings = results[1] as SystemSettings;
      overrides = results[2] as List<ItemRopSettings>;

      final mockUsage = _mockUsageRows(startLocal);
      treatmentRows = mockUsage.$1;
      stockOutRows = mockUsage.$2;
    } else {
      final client = Supabase.instance.client;

      final results = await Future.wait<Object?>([
        _inventoryService.fetchItems(),
        _settingsService.fetchSettings(),
        _ropService.fetchOverrides(),
        client
            .from('treatment_item')
            .select(
              'itemid, dispensed_qty, dispense_unit, consumeddate',
            )
            .gte(
              'consumeddate',
              _dateOnly(startLocal),
            ),
        client
            .from('stock_out')
            .select(
              'itemid, qty, qtyunit, reason, recordeddate',
            )
            .gte(
              'recordeddate',
              startLocal.toUtc().toIso8601String(),
            ),
      ]);

      items = results[0] as List<InventoryItem>;
      settings = results[1] as SystemSettings;
      overrides = results[2] as List<ItemRopSettings>;
      treatmentRows = results[3] as List<dynamic>;
      stockOutRows = results[4] as List<dynamic>;
    }

    final itemById = <String, InventoryItem>{
      for (final item in items) item.itemId: item,
    };

    final overrideByItemId = <String, ItemRopSettings>{
      for (final ropOverride in overrides)
        ropOverride.itemId: ropOverride,
    };

    final usageByItemId = <String, double>{};

    for (final raw in treatmentRows) {
      final row = Map<String, dynamic>.from(raw);
      final itemId = row['itemid'] as String?;
      if (itemId == null) continue;

      final item = itemById[itemId];
      if (item == null) continue;

      final purchaseEquivalent =
          _treatmentPurchaseEquivalent(row, item);

      if (purchaseEquivalent <= 0) continue;

      usageByItemId[itemId] =
          (usageByItemId[itemId] ?? 0) +
          purchaseEquivalent;
    }

    for (final raw in stockOutRows) {
      final row = Map<String, dynamic>.from(raw);

      if (!_stockOutCountsTowardUsage(
        row['reason'] as String?,
      )) {
        continue;
      }

      final itemId = row['itemid'] as String?;
      if (itemId == null) continue;

      final item = itemById[itemId];
      if (item == null) continue;

      final purchaseEquivalent =
          _stockOutPurchaseEquivalent(row, item);

      if (purchaseEquivalent <= 0) continue;

      usageByItemId[itemId] =
          (usageByItemId[itemId] ?? 0) +
          purchaseEquivalent;
    }

    final rows = <ReplenishmentItem>[];

    for (final item in items) {
      final ropOverride =
          overrideByItemId[item.itemId];

      final leadTimeDays =
          ropOverride?.leadTimeDays ??
          settings.defaultLeadTimeDays;

      final safetyStockQty =
          ropOverride?.safetyStockQty ??
          settings.defaultSafetyStockQty;

      final usage30 =
          usageByItemId[item.itemId] ?? 0;

      final adu =
          usage30 / usageWindowDays;

      final rawReorderPoint =
          (adu * leadTimeDays) +
          safetyStockQty;

      // Mock fallback: when there is no usage-based ROP yet, use the
      // low-stock threshold so Inventory can still surface out/low items.
      final effectiveRaw = kUseMock && rawReorderPoint <= 0
          ? settings.lowStockThreshold
          : rawReorderPoint;

      final reorderPoint =
          effectiveRaw.ceilToDouble();

      if (reorderPoint <= 0) {
        continue;
      }

      final currentStock =
          item.currentPurchaseUnitEquivalent;

      if (currentStock >
          reorderPoint + 0.000000001) {
        continue;
      }

      final suggestedQty = math
          .max(
            0.0,
            reorderPoint - currentStock,
          )
          .ceilToDouble();

      rows.add(
        ReplenishmentItem(
          item: item,
          usage30PurchaseUnits: usage30,
          averageDailyUsage: adu,
          leadTimeDays: leadTimeDays,
          safetyStockQty: safetyStockQty,
          reorderPoint: reorderPoint,
          currentStockPurchaseUnits: currentStock,
          suggestedQty: suggestedQty,
          usesCustomRop: ropOverride != null,
          priority: _priorityFor(
            currentStock: currentStock,
            reorderPoint: reorderPoint,
            safetyStock: safetyStockQty,
          ),
        ),
      );
    }

    rows.sort((a, b) {
      final byPriority =
          a.priority.index.compareTo(
        b.priority.index,
      );

      if (byPriority != 0) {
        return byPriority;
      }

      final byShortage =
          b.suggestedQty.compareTo(
        a.suggestedQty,
      );

      if (byShortage != 0) {
        return byShortage;
      }

      return a.item.itemName
          .toLowerCase()
          .compareTo(
            b.item.itemName.toLowerCase(),
          );
    });

    return rows;
  }
}
