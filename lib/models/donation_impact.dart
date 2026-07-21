import 'pet.dart';

/// One treatment event attributed, as a whole, to a specific donation batch
/// during FIFO replay -- see [DonationImpactLine].
class ImpactContribution {
  final String treatmentId;
  final String treatmentName;
  final String petId;
  final String petName;
  final PetSpecies petSpecies;
  final DateTime date;

  const ImpactContribution({
    required this.treatmentId,
    required this.treatmentName,
    required this.petId,
    required this.petName,
    required this.petSpecies,
    required this.date,
  });
}

/// The FIFO-attributed outcome of one donation_item row: how much of what
/// this donor gave has gone to treatments vs. been stocked out vs. is still
/// in stock, plus which specific treatments/animals it helped.
///
/// This is a derived read model, not a stored table. The system has no
/// per-unit/per-bottle tracking (see KNOWN_LIMITATIONS.md), so consumption
/// order is *assumed* to be oldest-batch-first across every purchase and
/// donation of the same item -- [usedQty]/[discardedQty]/[remainingQty] are
/// precise fractions under that FIFO assumption, not a measurement of the
/// literal physical unit donated.
///
/// [contributions] uses a coarser rule: each treatment event is attributed
/// whole (not split) to whichever batch was oldest/first drawn from, so the
/// donor-facing "helped treat X" list stays simple even when the precise
/// quantity math above happens to split a single event across two batches.
class DonationImpactLine {
  final String itemId;
  final String itemName;
  final String itemUom; // purchase_unit abbr -- the unit every *Qty field below is in
  final double donatedQty;
  final DateTime receivedDate;
  final double usedQty;
  final double discardedQty;
  final double remainingQty;
  final List<ImpactContribution> contributions;

  /// True when [usedQty] is a real measured quantity (item is deductible
  /// with a package breakdown). False when the item's dispensed amount
  /// isn't trackable (e.g. eardrops dosed by drop) -- [usedQty] is then
  /// always 0 (no capacity is drained by treatment usage for such items,
  /// only by real stock-outs), and the UI should show [contributions]
  /// instead of a quantity breakdown for "used".
  final bool isQuantityPrecise;

  const DonationImpactLine({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    required this.donatedQty,
    required this.receivedDate,
    required this.usedQty,
    required this.discardedQty,
    required this.remainingQty,
    required this.contributions,
    required this.isQuantityPrecise,
  });
}
