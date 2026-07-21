import '../models/donation_impact.dart';
import '../models/pet.dart';

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
/// when [type] is [ImpactEventType.treatment].
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
/// list of treatments helped, it just doesn't drain any capacity -- only a
/// real stock-out (waste/expired/adjustment) does that.
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

  const ImpactEvent({
    required this.type,
    required this.qty,
    required this.date,
    this.consumesCapacity = true,
    this.treatmentId,
    this.treatmentName,
    this.petId,
    this.petName,
    this.petSpecies,
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
/// that's kept precise. [ImpactBatchResult.contributions] instead attributes
/// each whole event to only the *first* batch it touched, so the donor-facing
/// list of treatments/animals stays simple to read.
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
      // item's terms, so no capacity is drained.
      if (event.type == ImpactEventType.treatment) {
        contributions[sortedBatches[queueIndex].id]!.add(ImpactContribution(
          treatmentId: event.treatmentId!,
          treatmentName: event.treatmentName!,
          petId: event.petId!,
          petName: event.petName!,
          petSpecies: event.petSpecies!,
          date: event.date,
        ));
      }
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

    if (event.type == ImpactEventType.treatment && firstBatchTouched != null) {
      contributions[firstBatchTouched]!.add(ImpactContribution(
        treatmentId: event.treatmentId!,
        treatmentName: event.treatmentName!,
        petId: event.petId!,
        petName: event.petName!,
        petSpecies: event.petSpecies!,
        date: event.date,
      ));
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
