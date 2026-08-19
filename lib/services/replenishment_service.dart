import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inventory_item.dart';
import '../models/item_rop_settings.dart';
import '../models/qty_unit.dart';
import '../models/replenishment_item.dart';
import '../models/system_settings.dart';
import 'inventory_service.dart';
import 'settings_service.dart';
import 'supabase/supabase_rop_service.dart';

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
// =============================================================================

class ReplenishmentService {
  static const int usageWindowDays = 30;

  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();
  final SettingsService _settingsService = SettingsService();
  final SupabaseRopService _ropService = SupabaseRopService();

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
  //
  // A treatment is included only when the item's configured treatment unit is
  // stock-deductible. This mirrors the treatment UI/service behavior:
  //
  // - package-unit treatment: divide by packageQuantity
  // - purchase-unit treatment: already in purchase-unit terms
  // - unconvertible/custom treatment unit: logged clinically but excluded from
  //   inventory demand because it does not deduct stock
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

    // No reliable conversion exists for this historical row.
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

  // ===========================================================================
  // WHICH STOCK-OUT EVENTS COUNT TOWARD ADU
  // ===========================================================================
  //
  // Adjustment:
  //   excluded because it corrects recorded inventory rather than representing
  //   operational consumption.
  //
  // Expired:
  //   excluded because removing already-expired stock is not recurring demand.
  //
  // Waste and any future normal dispense reason:
  //   included because it physically consumes usable inventory.
  // ===========================================================================

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

    final results = await Future.wait<Object?>([
      _inventoryService.fetchItems(),
      _settingsService.fetchSettings(),
      _ropService.fetchOverrides(),

      _client
          .from('treatment_item')
          .select(
            'itemid, dispensed_qty, dispense_unit, consumeddate',
          )
          .gte(
            'consumeddate',
            _dateOnly(startLocal),
          ),

      _client
          .from('stock_out')
          .select(
            'itemid, qty, qtyunit, reason, recordeddate',
          )
          .gte(
            'recordeddate',
            startLocal.toUtc().toIso8601String(),
          ),
    ]);

    final items = results[0] as List<InventoryItem>;
    final settings = results[1] as SystemSettings;
    final overrides = results[2] as List<ItemRopSettings>;
    final treatmentRows = results[3] as List<dynamic>;
    final stockOutRows = results[4] as List<dynamic>;

    final itemById = <String, InventoryItem>{
      for (final item in items) item.itemId: item,
    };

    final overrideByItemId = <String, ItemRopSettings>{
      for (final ropOverride in overrides)
        ropOverride.itemId: ropOverride,
    };

    final usageByItemId = <String, double>{};

    // -------------------------------------------------------------------------
    // TREATMENT USAGE
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // NON-TREATMENT DISPENSE / STOCK-OUT USAGE
    // -------------------------------------------------------------------------

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

    // -------------------------------------------------------------------------
    // BUILD ROP ROWS
    // -------------------------------------------------------------------------

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

      // -----------------------------------------------------------------------
      // OPERATIONAL WHOLE-UNIT ROP
      // -----------------------------------------------------------------------
      //
      // The raw formula can produce fractions such as:
      //   0.84 bag
      //   5.133 box
      //
      // Those values are mathematically valid, but a purchase/replenishment
      // decision must be actionable in whole PURCHASE UNITS. We therefore
      // always round UP, never to the nearest whole number.
      //
      // Example:
      //   raw ROP = 5.133 boxes
      //   operational ROP = 6 boxes
      //
      // Rounding down could leave the shelter below the calculated threshold.
      // -----------------------------------------------------------------------

      final rawReorderPoint =
          (adu * leadTimeDays) +
          safetyStockQty;

      final reorderPoint =
          rawReorderPoint.ceilToDouble();

      // If there is no demand and no safety stock, there is no meaningful ROP
      // to act on.
      if (reorderPoint <= 0) {
        continue;
      }

      final currentStock =
          item.currentPurchaseUnitEquivalent;

      // Use the actionable whole-unit ROP as the actual trigger point.
      if (currentStock >
          reorderPoint + 0.000000001) {
        continue;
      }

      // Suggested procurement is also a whole PURCHASE UNIT.
      //
      // Example:
      //   operational ROP = 6 boxes
      //   current stock   = 2 boxes
      //   suggested       = 4 boxes
      //
      // If current stock is a partial purchase-unit equivalent, ceil() ensures
      // the next purchase still reaches/exceeds the operational ROP.
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

    // Critical → High → Medium, then largest shortage first.
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
