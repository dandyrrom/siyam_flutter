import 'pet.dart';
import 'stock_out.dart';

/// What kind of event a [ImpactContribution] represents.
enum ImpactEventKind { treatment, stockOut }

/// One outgoing event (treatment usage or stock-out) attributed, as a whole,
/// to a specific donation batch during FIFO replay -- see
/// [DonationImpactLine].
///
/// [amount]/[unitAbbr] are the raw recorded figures for this single event --
/// treatment_item's dispensed_qty/dispense_unit (e.g. "50 ml"), or
/// stock_out's qty in purchase_unit terms (e.g. "1 bottle"). Unlike
/// [DonationImpactLine]'s Used Stocks/Still in Stock figures (which are
/// whole-purchase-unit counts under the FIFO assumption), this is a direct,
/// unconverted record of what happened in that one event, used for the
/// donor-facing message.
class ImpactContribution {
  final ImpactEventKind kind;
  final double amount;
  final String unitAbbr;
  final DateTime date;

  // Treatment-only.
  final String? treatmentId;
  final String? treatmentName;
  final String? petId;
  final String? petName;
  final PetSpecies? petSpecies;
  final PetGender? petGender;

  // Stock-out-only.
  final StockOutReason? stockOutReason;

  const ImpactContribution({
    required this.kind,
    required this.amount,
    required this.unitAbbr,
    required this.date,
    this.treatmentId,
    this.treatmentName,
    this.petId,
    this.petName,
    this.petSpecies,
    this.petGender,
    this.stockOutReason,
  });
}

/// The FIFO-attributed outcome of one donation_item row: how much of what
/// this donor gave has gone to treatments vs. been stocked out vs. is still
/// in stock, plus which specific treatments/animals/stock-outs it went to.
///
/// This is a derived read model, not a stored table. The system has no
/// per-unit/per-bottle tracking (see KNOWN_LIMITATIONS.md), so consumption
/// order is *assumed* to be oldest-batch-first across every purchase and
/// donation of the same item.
///
/// [usedQty]/[discardedQty]/[remainingQty] are **whole purchase-unit
/// counts**, not fractions of a container: a bottle that's had any amount
/// drawn from it at all (even 1.5ml out of 150ml) counts as one whole "used"
/// bottle, not "0.01 bottle used". [remainingQty] only counts bottles that
/// are still fully sealed -- untouched. This mirrors
/// `InventoryItem.usedStockQty`/`.unusedStockQty`'s own convention, applied
/// to this donor's specific batch instead of the item's whole pool. The
/// precise fractional amount that was actually dispensed is not lost, it's
/// just not what these three fields represent -- see [ImpactContribution]
/// for that.
///
/// [contributions] uses a coarser rule too: each event is attributed whole
/// (not split) to whichever batch was oldest/first drawn from, so the
/// donor-facing list stays simple even when the underlying quantity math
/// happens to split a single event across two batches.
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

  /// True when [usedQty] is derived from a real measured quantity (item is
  /// deductible with a package breakdown). False when the item's dispensed
  /// amount isn't trackable (e.g. eardrops dosed by drop) -- [usedQty] is
  /// then always 0 (no capacity is drained by treatment usage for such
  /// items, only by real stock-outs), and the UI should show
  /// [contributions] instead of a quantity breakdown for "used".
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
