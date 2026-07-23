import '../mock/mock_database.dart';
import '../models/donation_impact.dart';
import '../models/inventory_item.dart';
import '../models/pet.dart';
import 'backend.dart';
import 'impact_fifo.dart';
import 'inventory_service.dart';
import 'supabase/supabase_impact_service.dart';

/// Data-access interface for a donor's per-donation impact -- see
/// [DonationImpactLine] for what this represents and its FIFO assumption.
abstract interface class ImpactService {
  factory ImpactService() =>
      kUseMock ? MockImpactService() : SupabaseImpactService();

  Future<List<DonationImpactLine>> fetchDonorImpact(String donorId);
}

/// In-memory equivalent of the Supabase impact ledger -- replays
/// purchase_item/donation_item/treatment_item/stock_out for each item this
/// donor has ever given, oldest batch first, via [runFifoLedger].
class MockImpactService implements ImpactService {
  final MockDatabase _db = MockDatabase.instance;
  final InventoryService _inventoryService = MockInventoryService();

  String _unitAbbr(String unitId) =>
      firstWhereOrNull(_db.units, (u) => u.id == unitId)?.abbrName ?? '';

  @override
  Future<List<DonationImpactLine>> fetchDonorImpact(String donorId) async {
    final donorDonationIds =
        _db.donations.where((d) => d.donorId == donorId).map((d) => d.id).toSet();
    if (donorDonationIds.isEmpty) return [];

    final donorDonationItems =
        _db.donationItems.where((di) => donorDonationIds.contains(di.donId)).toList();
    final itemIds = donorDonationItems.map((di) => di.itemId).toSet();

    final result = <DonationImpactLine>[];
    for (final itemId in itemIds) {
      final item = await _inventoryService.fetchItem(itemId);
      if (item == null) continue;
      final (ledger, quantityPrecise) = _computeItemLedger(item);

      for (final di in donorDonationItems.where((d) => d.itemId == itemId)) {
        final donation = firstWhereOrNull(_db.donations, (d) => d.id == di.donId);
        if (donation == null) continue;
        final res = ledger['${di.donId}-${di.itemId}'];
        if (res == null) continue;

        // The ledger runs in package_unit terms for quantity-precise items
        // (see _computeItemLedger) -- convert to whole purchase_unit counts
        // for display (see wholeUnitBreakdown). Count-mode items are already
        // in purchase_unit terms with no fractional-container concept.
        final breakdown = quantityPrecise
            ? wholeUnitBreakdown(
                donatedQty: di.qty,
                ledgerResult: res,
                packageQuantity: item.packageQuantity!,
              )
            : (used: res.used, discarded: res.discarded, remaining: res.remaining);

        result.add(DonationImpactLine(
          itemId: item.itemId,
          itemName: item.itemName,
          itemUom: item.itemUom,
          donatedQty: di.qty,
          receivedDate: donation.receivedDate,
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

  /// Builds the FIFO queue for one item -- batches (purchase + donation) and
  /// events (treatment usage + stock-out), normalized to whichever unit this
  /// item can actually be measured in. Returns the per-batch ledger plus
  /// whether this item's "used" figures are a real measured quantity.
  ///
  /// Deductible items with a package breakdown (e.g. syrup dosed in ml) are
  /// replayed in package_unit terms, where treatment usage is a precise
  /// measured quantity that drains batch capacity. Everything else -- no
  /// package breakdown at all (e.g. a mop), or a package breakdown but a
  /// dispense_unit that doesn't convert to it (e.g. eardrops by drop,
  /// package_unit=ml) -- is replayed in whole purchase_unit terms instead,
  /// and treatment events don't drain capacity at all (see
  /// [ImpactEvent.consumesCapacity]): the system knows the item was used and
  /// can say so, it just can't measure how much, so only real stock-outs
  /// (waste/expired/adjustment) mark a batch as depleted for these items.
  (Map<String, ImpactBatchResult>, bool) _computeItemLedger(InventoryItem item) {
    final quantityMode = item.packageQuantity != null && item.stockOutIsDeductible;
    final packageQty = item.packageQuantity ?? 1;

    final batches = <ImpactBatch>[];
    for (final row in _db.purchaseItems.where((p) => p.itemId == item.itemId)) {
      final purchase = firstWhereOrNull(_db.purchases, (p) => p.id == row.purchaseId);
      if (purchase == null) continue;
      batches.add(ImpactBatch(
        id: '${row.purchaseId}-${row.itemId}',
        qty: quantityMode ? row.qty * packageQty : row.qty,
        date: purchase.receivedDate,
      ));
    }
    for (final row in _db.donationItems.where((d) => d.itemId == item.itemId)) {
      final donation = firstWhereOrNull(_db.donations, (d) => d.id == row.donId);
      if (donation == null) continue;
      batches.add(ImpactBatch(
        id: '${row.donId}-${row.itemId}',
        qty: quantityMode ? row.qty * packageQty : row.qty,
        date: donation.receivedDate,
      ));
    }

    final events = <ImpactEvent>[];
    for (final row in _db.treatmentItems.where((t) => t.itemId == item.itemId)) {
      final treatment = firstWhereOrNull(_db.treatments, (t) => t.id == row.treatId);
      if (treatment == null) continue;
      final pet = firstWhereOrNull(_db.pets, (p) => p.petId == treatment.petId);
      events.add(ImpactEvent(
        type: ImpactEventType.treatment,
        qty: quantityMode ? row.dispensedQty : 0.0,
        consumesCapacity: quantityMode,
        date: row.consumedDate,
        messageAmount: row.dispensedQty,
        messageUnitAbbr: _unitAbbr(row.dispenseUnitId),
        treatmentId: treatment.id,
        treatmentName: treatment.name,
        petId: treatment.petId,
        petName: pet?.petName ?? 'Unknown animal',
        petSpecies: pet?.species ?? PetSpecies.dog,
        petGender: pet?.gender ?? PetGender.male,
      ));
    }
    for (final row in _db.stockOuts.where((s) => s.itemId == item.itemId)) {
      events.add(ImpactEvent(
        type: ImpactEventType.stockOut,
        qty: quantityMode ? row.qty * packageQty : row.qty,
        date: row.recordedDate,
        messageAmount: row.qty,
        messageUnitAbbr: item.itemUom,
        stockOutReason: row.reason,
      ));
    }

    return (runFifoLedger(batches: batches, events: events), quantityMode);
  }
}
