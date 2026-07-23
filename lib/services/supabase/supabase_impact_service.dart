import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/donation_impact.dart';
import '../../models/inventory_item.dart';
import '../../models/pet.dart';
import '../../models/stock_out.dart';
import '../impact_fifo.dart';
import '../impact_service.dart';
import '../inventory_service.dart';

/// Supabase-backed equivalent of [MockImpactService] -- see that class and
/// [DonationImpactLine] for the FIFO assumption behind this ledger.
class SupabaseImpactService implements ImpactService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select('id, abbr_name');
    return {
      for (final r in rows) r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  @override
  Future<List<DonationImpactLine>> fetchDonorImpact(String donorId) async {
    final donationRows =
        await _client.from('donation').select('id, receiveddate').eq('donorid', donorId);
    final donationDates = {
      for (final r in donationRows)
        r['id'] as String: DateTime.parse(r['receiveddate'] as String),
    };
    if (donationDates.isEmpty) return [];

    final donationItemRows = await _client
        .from('donation_item')
        .select('dntid, itemid, qty')
        .inFilter('dntid', donationDates.keys.toList());
    if (donationItemRows.isEmpty) return [];

    final itemIds = donationItemRows.map((r) => r['itemid'] as String).toSet();

    final result = <DonationImpactLine>[];
    for (final itemId in itemIds) {
      final item = await _inventoryService.fetchItem(itemId);
      if (item == null) continue;
      final (ledger, quantityPrecise) = await _computeItemLedger(item);

      for (final row in donationItemRows.where((r) => r['itemid'] == itemId)) {
        final donId = row['dntid'] as String;
        final res = ledger['$donId-$itemId'];
        if (res == null) continue;
        final donatedQty = _d(row['qty']);

        // The ledger runs in package_unit terms for quantity-precise items
        // (see _computeItemLedger) -- convert to whole purchase_unit counts
        // for display (see wholeUnitBreakdown). Count-mode items are already
        // in purchase_unit terms with no fractional-container concept.
        final breakdown = quantityPrecise
            ? wholeUnitBreakdown(
                donatedQty: donatedQty,
                ledgerResult: res,
                packageQuantity: item.packageQuantity!,
              )
            : (used: res.used, discarded: res.discarded, remaining: res.remaining);

        result.add(DonationImpactLine(
          itemId: item.itemId,
          itemName: item.itemName,
          itemUom: item.itemUom,
          donatedQty: donatedQty,
          receivedDate: donationDates[donId]!,
          usedQty: breakdown.used,
          discardedQty: breakdown.discarded,
          remainingQty: breakdown.remaining,
          contributions: res.contributions,
          isQuantityPrecise: quantityPrecise,
        ));
      }
    }

    result.sort((a, b) => b.receivedDate.compareTo(a.receivedDate));
    return result;
  }

  /// See [MockImpactService._computeItemLedger] for the quantity-mode vs.
  /// count-mode split this mirrors.
  Future<(Map<String, ImpactBatchResult>, bool)> _computeItemLedger(InventoryItem item) async {
    final quantityMode = item.packageQuantity != null && item.stockOutIsDeductible;
    final packageQty = item.packageQuantity ?? 1;

    final batches = <ImpactBatch>[];

    final purchaseRows = await _client
        .from('purchase_item')
        .select('purchaseid, qty, purchase(receiveddate)')
        .eq('itemid', item.itemId);
    for (final r in purchaseRows) {
      final purchase = r['purchase'] as Map<String, dynamic>?;
      if (purchase == null) continue;
      final qty = _d(r['qty']);
      batches.add(ImpactBatch(
        id: '${r['purchaseid']}-${item.itemId}',
        qty: quantityMode ? qty * packageQty : qty,
        date: DateTime.parse(purchase['receiveddate'] as String),
      ));
    }

    final donationRows = await _client
        .from('donation_item')
        .select('dntid, qty, donation(receiveddate)')
        .eq('itemid', item.itemId);
    for (final r in donationRows) {
      final donation = r['donation'] as Map<String, dynamic>?;
      if (donation == null) continue;
      final qty = _d(r['qty']);
      batches.add(ImpactBatch(
        id: '${r['dntid']}-${item.itemId}',
        qty: quantityMode ? qty * packageQty : qty,
        date: DateTime.parse(donation['receiveddate'] as String),
      ));
    }

    final events = <ImpactEvent>[];

    final units = await _unitAbbrMap();
    final treatmentRows = await _client
        .from('treatment_item')
        .select('treatid, dispensed_qty, dispense_unit, consumeddate, '
            'treatment(id, name, petid, pet(name, species, gender))')
        .eq('itemid', item.itemId);
    for (final r in treatmentRows) {
      final treatment = r['treatment'] as Map<String, dynamic>?;
      if (treatment == null) continue;
      final pet = treatment['pet'] as Map<String, dynamic>?;
      final dispenseUnitId = r['dispense_unit'] as String?;
      events.add(ImpactEvent(
        type: ImpactEventType.treatment,
        qty: quantityMode ? _d(r['dispensed_qty']) : 0.0,
        consumesCapacity: quantityMode,
        date: DateTime.parse(r['consumeddate'] as String),
        messageAmount: _d(r['dispensed_qty']),
        messageUnitAbbr: dispenseUnitId == null ? '' : (units[dispenseUnitId] ?? ''),
        treatmentId: r['treatid'] as String,
        treatmentName: treatment['name'] as String? ?? 'Treatment',
        petId: treatment['petid'] as String?,
        petName: pet?['name'] as String? ?? 'Unknown animal',
        petSpecies: petSpeciesFromString(pet?['species'] as String? ?? 'dog'),
        petGender: petGenderFromString(pet?['gender'] as String? ?? 'male'),
      ));
    }

    final stockOutRows = await _client
        .from('stock_out')
        .select('qty, reason, recordeddate')
        .eq('itemid', item.itemId);
    for (final r in stockOutRows) {
      final qty = _d(r['qty']);
      events.add(ImpactEvent(
        type: ImpactEventType.stockOut,
        qty: quantityMode ? qty * packageQty : qty,
        date: DateTime.parse(r['recordeddate'] as String),
        messageAmount: qty,
        messageUnitAbbr: item.itemUom,
        stockOutReason: stockOutReasonFromString(r['reason'] as String),
      ));
    }

    return (runFifoLedger(batches: batches, events: events), quantityMode);
  }
}
