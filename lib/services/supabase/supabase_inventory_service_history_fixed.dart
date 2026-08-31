import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/qty_unit.dart';
import '../../models/stock_movement.dart';
import '../../models/stock_out.dart';
import 'supabase_inventory_service.dart' as base;

// =============================================================================
// UNIT-AWARE SUPABASE INVENTORY SERVICE
// =============================================================================
//
// Purpose:
// Keep the existing, working SupabaseInventoryService completely unchanged,
// but correct the display unit used by Stock History for PURCHASE movements.
//
// The purchase flow already stores purchase_item.qty_unit as either:
//
//   purchase_unit
//   package_unit
//
// The old fetchStockHistory() reader ignored that field for purchases and
// always displayed the item's purchase unit. For example:
//
//   Goods Received: 85 tab
//
// could incorrectly appear as:
//
//   Purchased +85 box
//
// This adapter inherits every existing inventory operation unchanged and
// overrides ONLY fetchStockHistory().
//
// No stock calculation, FEFO, batch, ROP, Goods Received, Dispense, Treatment,
// or database-write behavior is changed.
// =============================================================================

class SupabaseInventoryService extends base.SupabaseInventoryService {
  final SupabaseClient _historyClient = Supabase.instance.client;

  // ===========================================================================
  // DISPLAY HELPERS
  // ===========================================================================

  Future<Map<String, String>> _historyUserNameMap() async {
    final rows =
        await _historyClient.from('users').select('id, fname, lname');

    return {
      for (final row in rows)
        row['id'] as String:
            '${(row['fname'] as String?) ?? ''} '
                    '${(row['lname'] as String?) ?? ''}'
                .trim(),
    };
  }

  Future<Map<String, String>> _historyUnitMap() async {
    final rows =
        await _historyClient.from('units').select('id, abbr_name');

    return {
      for (final row in rows)
        row['id'] as String: (row['abbr_name'] as String?) ?? '',
    };
  }

  double _historyDouble(dynamic value) {
    if (value == null) return 0;
    return (value as num).toDouble();
  }

  String _historyStockOutReasonLabel(
    StockOutReason reason,
  ) {
    switch (reason) {
      case StockOutReason.waste:
        return 'Waste';

      case StockOutReason.expired:
        return 'Expired';

      case StockOutReason.adjustment:
        return 'Adjustment';
    }
  }

  // ===========================================================================
  // STOCK MOVEMENT HISTORY
  // ===========================================================================
  //
  // IMPORTANT FIX:
  //
  // PURCHASE_ITEM now reads qty_unit, exactly like DONATION_ITEM already did.
  //
  // purchase_unit:
  //   +2 box
  //
  // package_unit:
  //   +85 tab
  //
  // Older rows with a null qty_unit safely fall back to purchase_unit.
  // ===========================================================================

  @override
  Future<List<StockMovement>> fetchStockHistory(
    String itemId,
  ) async {
    final item = await fetchItem(itemId);

    final purchaseUnitAbbr = item?.purchaseUnitAbbr ?? '';

    final packageUnitAbbr = item?.packageUnitAbbr ?? purchaseUnitAbbr;

    final users = await _historyUserNameMap();

    final units = await _historyUnitMap();

    final movements = <StockMovement>[];

    // =========================================================================
    // PURCHASE
    // =========================================================================

    final purchaseRows = await _historyClient
        .from('purchase_item')
        .select(
          'qty, qty_unit, purchaseid, '
          'purchase(id, receiveddate, recordedby)',
        )
        .eq('itemid', itemId);

    for (final row in purchaseRows) {
      final purchase = row['purchase'] as Map<String, dynamic>?;

      if (purchase == null) {
        continue;
      }

      final qtyUnit = qtyUnitFromString(
        (row['qty_unit'] as String?) ?? 'purchase_unit',
      );

      movements.add(
        StockMovement(
          id: '${purchase['id']}-$itemId',
          date: DateTime.parse(
            purchase['receiveddate'] as String,
          ),
          direction: StockDirection.stockIn,
          qty: _historyDouble(row['qty']),
          unitAbbr: qtyUnit == QtyUnit.packageUnit
              ? packageUnitAbbr
              : purchaseUnitAbbr,
          typeLabel: 'Purchased',
          recordedByName:
              users[purchase['recordedby']] ?? 'Unknown user',
        ),
      );
    }

    // =========================================================================
    // DONATION
    // =========================================================================

    final donationRows = await _historyClient
        .from('donation_item')
        .select(
          'qty, qty_unit, dntid, '
          'donation(id, receiveddate, recordedby)',
        )
        .eq('itemid', itemId);

    for (final row in donationRows) {
      final donation = row['donation'] as Map<String, dynamic>?;

      if (donation == null) {
        continue;
      }

      final qtyUnit = qtyUnitFromString(
        (row['qty_unit'] as String?) ?? 'purchase_unit',
      );

      movements.add(
        StockMovement(
          id: '${donation['id']}-$itemId',
          date: DateTime.parse(
            donation['receiveddate'] as String,
          ),
          direction: StockDirection.stockIn,
          qty: _historyDouble(row['qty']),
          unitAbbr: qtyUnit == QtyUnit.packageUnit
              ? packageUnitAbbr
              : purchaseUnitAbbr,
          typeLabel: 'Donated',
          recordedByName:
              users[donation['recordedby']] ?? 'Unknown user',
        ),
      );
    }

    // =========================================================================
    // TREATMENT
    // =========================================================================
    //
    // A deductible treatment creates one or more TREATMENT rows in
    // batch_transaction_log linked by treatmentitemid.
    //
    // A non-convertible treatment is still saved in Medical Records but does
    // not reduce inventory. It is displayed as "Logged Treatment".
    // =========================================================================

    final treatmentRows = await _historyClient
        .from('treatment_item')
        .select(
          'treatmentitemid, treatid, dispensed_qty, dispense_unit, '
          'consumeddate, recordedby, treatment(id, name)',
        )
        .eq('itemid', itemId);

    final treatmentItemIds = treatmentRows
        .map(
          (row) => row['treatmentitemid'] as String?,
        )
        .whereType<String>()
        .toList();

    final deductedTreatmentItemIds = <String>{};

    if (treatmentItemIds.isNotEmpty) {
      final transactionRows = await _historyClient
          .from('batch_transaction_log')
          .select('treatmentitemid')
          .eq('txntype', 'TREATMENT')
          .inFilter(
            'treatmentitemid',
            treatmentItemIds,
          );

      for (final transaction in transactionRows) {
        final treatmentItemId =
            transaction['treatmentitemid'] as String?;

        if (treatmentItemId != null) {
          deductedTreatmentItemIds.add(
            treatmentItemId,
          );
        }
      }
    }

    for (final row in treatmentRows) {
      final treatmentItemId =
          row['treatmentitemid'] as String?;

      // A linked TREATMENT transaction means actual stock was deducted.
      // Otherwise the medication was only logged clinically.
      final affectsStock = treatmentItemId != null &&
          deductedTreatmentItemIds.contains(
            treatmentItemId,
          );

      final treatment = row['treatment'] as Map<String, dynamic>?;

      final dispenseUnit = row['dispense_unit'] as String?;

      movements.add(
        StockMovement(
          id: treatmentItemId ?? '${row['treatid']}-$itemId',
          date: DateTime.parse(
            row['consumeddate'] as String,
          ),
          direction: StockDirection.stockOut,
          qty: _historyDouble(
            row['dispensed_qty'],
          ),
          unitAbbr: (dispenseUnit == null ? null : units[dispenseUnit]) ??
              purchaseUnitAbbr,
          typeLabel: affectsStock
              ? 'Treatment'
              : 'Logged Treatment',
          treatmentId: row['treatid'] as String?,
          treatmentName:
              treatment?['name'] as String? ?? 'Unknown treatment',
          recordedByName:
              users[row['recordedby']] ?? 'Unknown user',
        ),
      );
    }

    // =========================================================================
    // DISPENSE: WASTE / EXPIRED / ADJUSTMENT
    // =========================================================================

    final stockOutRows = await _historyClient
        .from('stock_out')
        .select(
          'id, qty, qtyunit, reason, recordeddate, recordedby',
        )
        .eq('itemid', itemId);

    for (final row in stockOutRows) {
      final qtyUnit = qtyUnitFromString(
        (row['qtyunit'] as String?) ?? 'purchase_unit',
      );

      movements.add(
        StockMovement(
          id: row['id'] as String,
          date: DateTime.parse(
            row['recordeddate'] as String,
          ),
          direction: StockDirection.stockOut,
          qty: _historyDouble(row['qty']),
          unitAbbr: qtyUnit == QtyUnit.packageUnit
              ? packageUnitAbbr
              : purchaseUnitAbbr,
          typeLabel: _historyStockOutReasonLabel(
            stockOutReasonFromString(
              row['reason'] as String,
            ),
          ),
          recordedByName:
              users[row['recordedby']] ?? 'Unknown user',
        ),
      );
    }

    movements.sort(
      (a, b) => b.date.compareTo(a.date),
    );

    return movements;
  }
}