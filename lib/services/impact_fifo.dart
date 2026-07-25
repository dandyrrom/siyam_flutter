import '../models/donation_impact.dart';
import '../models/pet.dart';
import '../models/stock_out.dart';

/// One incoming purchase_item or donation_item row, normalized to whichever
/// unit [runFifoLedger] is replaying in for this item (see the mode split in
/// impact_service.dart / supabase_impact_service.dart).
class ImpactBatch {
  final String id;
  final double qty;
  final DateTime date;

  const ImpactBatch({required this.id, required this.qty, required this.date});
}

enum ImpactEventType { treatment, stockOut }

/// One outgoing treatment_item or stock_out row, normalized to the same unit
/// as the batches it's drawn against. Treatment metadata is only present
/// when [type] is [ImpactEventType.treatment]; [stockOutReason] only when
/// [type] is [ImpactEventType.stockOut].
///
/// [consumesCapacity] is always true for stock-outs (always a precise
/// purchase_unit quantity). For treatment usage it depends on the item: true
/// when the item is deductible with a package breakdown (dispensed_qty is a
/// real measured amount), false otherwise -- a non-deductible item (e.g.
/// eardrops dosed by drop, package_unit=ml) is dispensed many times from one
/// container before it's actually empty, so treating "one treatment event"
/// as "one whole container consumed" would make a donor's batch look used up
/// after a single dose. For those items the event still attaches to whoever
/// is the current batch (see [runFifoLedger]) so it shows up in the donor's
/// list, it just doesn't drain any capacity -- only a real stock-out
/// (waste/expired/adjustment) does that.
class ImpactEvent {
  final ImpactEventType type;
  final double qty;
  final DateTime date;
  final bool consumesCapacity;
  final String? treatmentId;
  final String? treatmentName;
  final String? petId;
  final String? petName;
  final PetSpecies? petSpecies;
  final PetGender? petGender;
  final StockOutReason? stockOutReason;

  /// The raw figure for this single event, as staff entered it -- dispensed
  /// amount/unit for a treatment, or qty/purchase_unit for a stock-out.
  /// Independent of [qty] (which is normalized for the FIFO draw above) and
  /// carried straight through to [ImpactContribution] for the per-event
  /// message, since it needs no conversion or FIFO assumption.
  final double messageAmount;
  final String messageUnitAbbr;

  const ImpactEvent({
    required this.type,
    required this.qty,
    required this.date,
    required this.messageAmount,
    required this.messageUnitAbbr,
    this.consumesCapacity = true,
    this.treatmentId,
    this.treatmentName,
    this.petId,
    this.petName,
    this.petSpecies,
    this.petGender,
    this.stockOutReason,
  });
}

class ImpactBatchResult {
  final double used;
  final double discarded;
  final double remaining;
  final List<ImpactContribution> contributions;

  const ImpactBatchResult({
    required this.used,
    required this.discarded,
    required this.remaining,
    required this.contributions,
  });
}

/// Replays every incoming batch and outgoing event for one item, oldest
/// first, and drains outgoing events from the oldest batch with anything
/// left -- the FIFO assumption described in [DonationImpactLine]: since
/// there's no per-unit/per-bottle tracking, the system can't know which
/// physical batch a given treatment or stock-out actually drew from, so it
/// assumes stock is consumed in the order it arrived.
///
/// Quantity math (used/discarded/remaining) can split a single event across
/// two batches when it drains the tail of one and the head of the next --
/// that's kept precise (whole-unit rounding for display happens separately,
/// see [wholeUnitBreakdown]). [ImpactBatchResult.contributions] instead
/// attributes each whole event to only the *first* batch it touched, so the
/// donor-facing list stays simple to read.
Map<String, ImpactBatchResult> runFifoLedger({
  required List<ImpactBatch> batches,
  required List<ImpactEvent> events,
}) {
  final sortedBatches = [...batches]..sort((a, b) => a.date.compareTo(b.date));
  final sortedEvents = [...events]..sort((a, b) => a.date.compareTo(b.date));

  final remaining = {for (final b in sortedBatches) b.id: b.qty};
  final used = {for (final b in sortedBatches) b.id: 0.0};
  final discarded = {for (final b in sortedBatches) b.id: 0.0};
  final contributions = {for (final b in sortedBatches) b.id: <ImpactContribution>[]};

  const epsilon = 1e-9;
  var queueIndex = 0;

  void addContribution(String batchId, ImpactEvent event) {
    contributions[batchId]!.add(ImpactContribution(
      kind: event.type == ImpactEventType.treatment
          ? ImpactEventKind.treatment
          : ImpactEventKind.stockOut,
      amount: event.messageAmount,
      unitAbbr: event.messageUnitAbbr,
      date: event.date,
      treatmentId: event.treatmentId,
      treatmentName: event.treatmentName,
      petId: event.petId,
      petName: event.petName,
      petSpecies: event.petSpecies,
      petGender: event.petGender,
      stockOutReason: event.stockOutReason,
    ));
  }

  for (final event in sortedEvents) {
    // Advance past any already-exhausted batches to find the current front
    // of the queue, regardless of whether this event will draw from it.
    while (queueIndex < sortedBatches.length && remaining[sortedBatches[queueIndex].id]! <= epsilon) {
      queueIndex++;
    }
    if (queueIndex >= sortedBatches.length) continue; // nothing left to attribute to

    if (!event.consumesCapacity) {
      // Non-deductible treatment usage: attaches to the current batch as a
      // contribution, but the amount dispensed is unmeasurable in this
      // item's terms, so no capacity is drained. (Stock-outs always
      // consumeCapacity, so this branch is treatment-only in practice.)
      addContribution(sortedBatches[queueIndex].id, event);
      continue;
    }

    var toDraw = event.qty;
    String? firstBatchTouched;

    while (toDraw > epsilon && queueIndex < sortedBatches.length) {
      final batch = sortedBatches[queueIndex];
      final available = remaining[batch.id]!;
      if (available <= epsilon) {
        queueIndex++;
        continue;
      }
      firstBatchTouched ??= batch.id;
      final draw = toDraw < available ? toDraw : available;
      remaining[batch.id] = available - draw;
      toDraw -= draw;
      if (event.type == ImpactEventType.treatment) {
        used[batch.id] = used[batch.id]! + draw;
      } else {
        discarded[batch.id] = discarded[batch.id]! + draw;
      }
    }

    if (firstBatchTouched != null) {
      addContribution(firstBatchTouched, event);
    }
  }

  return {
    for (final b in sortedBatches)
      b.id: ImpactBatchResult(
        used: used[b.id]!,
        discarded: discarded[b.id]!,
        remaining: remaining[b.id]!,
        contributions: contributions[b.id]!,
      ),
  };
}

/// Converts one batch's package-unit-precise ledger result into whole
/// purchase-unit counts for donor display -- any container touched at all
/// (partially used or fully drained but not yet stocked out) counts as one
/// whole "used" container. This is a deliberately simpler, donor-facing
/// convention than the staff-facing `InventoryItem.usedPurchaseUnitQty` (which
/// only counts *fully* depleted containers, with the partial amount shown
/// separately via `.usedPackageUnitQty`): donors are told "1 bottle used",
/// not "0.01 bottle used" for 1.5ml out of a 150ml bottle, and not left wondering
/// where a partially-used bottle went. [remaining] only counts bottles that
/// are still fully sealed; [discarded] is already an exact whole-container
/// count (stock-outs are always whole purchase_unit events).
({double used, double discarded, double remaining}) wholeUnitBreakdown({
  required double donatedQty,
  required ImpactBatchResult ledgerResult,
  required double packageQuantity,
}) {
  final sealedRemaining = (ledgerResult.remaining / packageQuantity).floorToDouble();
  final discardedUnits = (ledgerResult.discarded / packageQuantity).roundToDouble();
  final usedUnits = (donatedQty - discardedUnits - sealedRemaining).clamp(0.0, donatedQty);
  return (used: usedUnits, discarded: discardedUnits, remaining: sealedRemaining);
}
