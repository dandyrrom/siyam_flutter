import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/donation_impact.dart';
import '../../models/inventory_item.dart';
import '../../models/pet.dart';
import '../../models/stock_out.dart';
import '../impact_service.dart';
import '../inventory_service.dart';

/// Supabase-backed donor impact access.
///
/// Donor impact is now derived from the actual physical inventory batches and
/// their recorded batch transactions rather than replaying FIFO after the fact.
///
/// The donor path is:
///
/// donation
///   → donation_item
///   → inventory_batch
///   → batch_transaction_log
///
/// Because stock-out/treatment operations record the exact inventorybatchid
/// they consumed, donor attribution no longer needs to guess which donation
/// batch was used.
class SupabaseImpactService implements ImpactService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select('id, abbr_name');

    return {
      for (final r in rows)
        r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  @override
  Future<List<DonationImpactLine>> fetchDonorImpact(String donorId) async {
    // ============================================================
    // Get every donation belonging to this donor
    // ============================================================
    final donationRows = await _client
        .from('donation')
        .select('id, receiveddate')
        .eq('donorid', donorId);

    if (donationRows.isEmpty) return [];

    final donationDates = {
      for (final r in donationRows)
        r['id'] as String: DateTime.parse(r['receiveddate'] as String),
    };

    // ============================================================
    // Get the donor's donation_item rows
    // ============================================================
    final donationItemRows = await _client
        .from('donation_item')
        .select('donationitemid, dntid, itemid, qty, qty_unit')
        .inFilter('dntid', donationDates.keys.toList());

    if (donationItemRows.isEmpty) return [];

    final result = <DonationImpactLine>[];

    for (final donationItem in donationItemRows) {
      final donationItemId = donationItem['donationitemid'] as String;
      final donationId = donationItem['dntid'] as String;
      final itemId = donationItem['itemid'] as String;

      final item = await _inventoryService.fetchItem(itemId);
      if (item == null) continue;

      // ============================================================
      // Find the physical batch/batches created from this donation_item
      // ============================================================
      //
      // Normally one donation_item creates one inventory_batch, but this
      // intentionally supports several batches in case a received donation
      // is later split by lot number or expiry date.
      final batchRows = await _client
          .from('inventory_batch')
          .select(
            'inventorybatchid, qtyreceived, qtyavailable, qtyunit, '
            'expirydate, receiveddate',
          )
          .eq('donationitemid', donationItemId);

      if (batchRows.isEmpty) continue;

      final batchIds = batchRows
          .map((r) => r['inventorybatchid'] as String)
          .toList();

      final totalReceived = batchRows.fold<double>(
        0,
        (sum, r) => sum + _d(r['qtyreceived']),
      );

      final totalRemaining = batchRows.fold<double>(
        0,
        (sum, r) => sum + _d(r['qtyavailable']),
      );

      // ============================================================
      // Read the actual movements that happened to these donated batches
      // ============================================================
      final transactionRows = await _client
          .from('batch_transaction_log')
          .select(
            'batchtransactionid, inventorybatchid, treatmentitemid, '
            'stockoutid, txntype, qtychange, qtyunit, txndate',
          )
          .inFilter('inventorybatchid', batchIds)
          .order('txndate');

      double usedCanonical = 0;
      double discardedCanonical = 0;

      final treatmentTransactions = <Map<String, dynamic>>[];
      final stockOutTransactions = <Map<String, dynamic>>[];

      for (final transaction in transactionRows) {
        final type = transaction['txntype'] as String?;
        final qtyChange = _d(transaction['qtychange']);

        // RECEIVE and other positive movements are not donor "impact".
        if (qtyChange >= 0) continue;

        final amount = qtyChange.abs();

        switch (type) {
          case 'TREATMENT':
            usedCanonical += amount;
            treatmentTransactions.add(transaction);
            break;

          case 'DISPOSAL':
          case 'EXPIRE':
          case 'ADJUSTMENT':
            discardedCanonical += amount;
            stockOutTransactions.add(transaction);
            break;
        }
      }

      // ============================================================
      // Build donor-facing contribution messages
      // ============================================================
      final contributions = <ImpactContribution>[];

      await _addTreatmentContributions(
        transactions: treatmentTransactions,
        item: item,
        contributions: contributions,
      );

      await _addStockOutContributions(
        transactions: stockOutTransactions,
        item: item,
        contributions: contributions,
      );

      // ============================================================
      // Convert canonical batch quantities into donor-facing units
      // ============================================================
      //
      // Batches use package_unit quantities when an item has a package
      // breakdown. The impact page currently displays its summary using
      // purchase units, so convert those quantities back for display.
      final quantityPrecise =
          item.packageQuantity != null && item.stockOutIsDeductible;

      double donatedQty;
      double usedQty;
      double discardedQty;
      double remainingQty;

      if (quantityPrecise) {
        final packageQuantity = item.packageQuantity!;

        donatedQty = totalReceived / packageQuantity;

        // A container that has been touched by treatment usage counts as
        // "used" for the donor-facing summary, matching the existing impact
        // page convention.
        final sealedRemaining =
            (totalRemaining / packageQuantity).floorToDouble();

        final discardedUnits =
            (discardedCanonical / packageQuantity).roundToDouble();

        usedQty =
            (donatedQty - discardedUnits - sealedRemaining)
                .clamp(0.0, donatedQty)
                .toDouble();

        discardedQty = discardedUnits;

        remainingQty = sealedRemaining;
      } else {
        donatedQty = totalReceived;
        usedQty = usedCanonical;
        discardedQty = discardedCanonical;
        remainingQty = totalRemaining;
      }

      result.add(
        DonationImpactLine(
          itemId: item.itemId,
          itemName: item.itemName,
          itemUom: item.itemUom,
          donatedQty: donatedQty,
          receivedDate: donationDates[donationId]!,
          usedQty: usedQty,
          discardedQty: discardedQty,
          remainingQty: remainingQty,
          contributions: contributions,
          isQuantityPrecise: quantityPrecise,
        ),
      );
    }

    result.sort(
      (a, b) => b.receivedDate.compareTo(a.receivedDate),
    );

    return result;
  }

  /// Adds treatment contribution details for transactions that consumed this
  /// donor's exact inventory batch.
  ///
  /// This starts producing results once treatment stock deductions are
  /// migrated to batch_transaction_log with txntype = TREATMENT and a
  /// treatmentitemid.
  Future<void> _addTreatmentContributions({
    required List<Map<String, dynamic>> transactions,
    required InventoryItem item,
    required List<ImpactContribution> contributions,
  }) async {
    if (transactions.isEmpty) return;

    final treatmentItemIds = transactions
        .map((r) => r['treatmentitemid'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    if (treatmentItemIds.isEmpty) return;

    final units = await _unitAbbrMap();

    final treatmentItemRows = await _client
        .from('treatment_item')
        .select(
          'treatmentitemid, treatid, dispensed_qty, dispense_unit, '
          'consumeddate, treatment(id, name, petid, '
          'pet(name, species, gender))',
        )
        .inFilter('treatmentitemid', treatmentItemIds);

    final treatmentItemMap = {
      for (final r in treatmentItemRows)
        r['treatmentitemid'] as String: r,
    };

    for (final transaction in transactions) {
      final treatmentItemId =
          transaction['treatmentitemid'] as String?;

      if (treatmentItemId == null) continue;

      final row = treatmentItemMap[treatmentItemId];
      if (row == null) continue;

      final treatment =
          row['treatment'] as Map<String, dynamic>?;

      if (treatment == null) continue;

      final pet =
          treatment['pet'] as Map<String, dynamic>?;

      final dispenseUnitId =
          row['dispense_unit'] as String?;

      // qtychange is the exact portion supplied by this donor's batch.
      // This avoids crediting the donor for the entire treatment when a
      // treatment happened to span several batches.
      final exactBatchAmount =
          _d(transaction['qtychange']).abs();

      contributions.add(
        ImpactContribution(
          kind: ImpactEventKind.treatment,
          amount: exactBatchAmount,
          unitAbbr: dispenseUnitId == null
              ? item.packageUnitAbbr ?? item.itemUom
              : (units[dispenseUnitId] ?? item.packageUnitAbbr ?? item.itemUom),
          date: DateTime.parse(
            transaction['txndate'] as String,
          ),
          treatmentId: row['treatid'] as String?,
          treatmentName:
              treatment['name'] as String? ?? 'Treatment',
          petId: treatment['petid'] as String?,
          petName:
              pet?['name'] as String? ?? 'Unknown animal',
          petSpecies: petSpeciesFromString(
            pet?['species'] as String? ?? 'dog',
          ),
          petGender: petGenderFromString(
            pet?['gender'] as String? ?? 'male',
          ),
        ),
      );
    }
  }

  /// Adds waste/expired/adjustment contribution details for stock-out
  /// transactions that consumed this donor's exact batch.
  Future<void> _addStockOutContributions({
    required List<Map<String, dynamic>> transactions,
    required InventoryItem item,
    required List<ImpactContribution> contributions,
  }) async {
    if (transactions.isEmpty) return;

    final stockOutIds = transactions
        .map((r) => r['stockoutid'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    final stockOutMap = <String, Map<String, dynamic>>{};

    if (stockOutIds.isNotEmpty) {
      final stockOutRows = await _client
          .from('stock_out')
          .select('id, qty, reason, recordeddate')
          .inFilter('id', stockOutIds);

      for (final row in stockOutRows) {
        stockOutMap[row['id'] as String] = row;
      }
    }

    for (final transaction in transactions) {
      final stockOutId =
          transaction['stockoutid'] as String?;

      final stockOut =
          stockOutId == null ? null : stockOutMap[stockOutId];

      final type =
          transaction['txntype'] as String?;

      StockOutReason reason;

      if (stockOut != null) {
        reason = stockOutReasonFromString(
          stockOut['reason'] as String,
        );
      } else {
        // Fallback for a transaction whose stock_out parent is unavailable.
        switch (type) {
          case 'EXPIRE':
            reason = StockOutReason.expired;
            break;
          case 'ADJUSTMENT':
            reason = StockOutReason.adjustment;
            break;
          case 'DISPOSAL':
          default:
            reason = StockOutReason.waste;
            break;
        }
      }

      var amount =
          _d(transaction['qtychange']).abs();

      String unitAbbr =
          item.packageUnitAbbr ?? item.itemUom;

      // Stock-out entries are entered in purchase-unit terms, while the
      // batch ledger may hold canonical package-unit quantities. Convert the
      // exact batch allocation back to purchase units for the donor message.
      if (item.packageQuantity != null &&
          item.packageQuantity! > 0) {
        amount /= item.packageQuantity!;
        unitAbbr = item.itemUom;
      }

      contributions.add(
        ImpactContribution(
          kind: ImpactEventKind.stockOut,
          amount: amount,
          unitAbbr: unitAbbr,
          date: DateTime.parse(
            transaction['txndate'] as String,
          ),
          stockOutReason: reason,
        ),
      );
    }
  }
}