/// Which way stock moved.
enum StockDirection { stockIn, stockOut }

/// One row in an item's stock history -- a unified view across
/// PURCHASE_ITEM, DONATION_ITEM, TREATMENT_ITEM, and STOCK_OUT, the four
/// tables that together record everything that ever changed an item's
/// purchase_stocks.
class StockMovement {
  final String id;
  final DateTime date;
  final StockDirection direction;
  final double qty;
  final String unitAbbr;

  /// 'Purchased' | 'Donated' | 'Treatment' | 'Waste' | 'Expired' | 'Adjustment'
  final String typeLabel;

  /// Set only when [typeLabel] is 'Treatment'.
  final String? treatmentId;
  final String? treatmentName;

  final String recordedByName;

  const StockMovement({
    required this.id,
    required this.date,
    required this.direction,
    required this.qty,
    required this.unitAbbr,
    required this.typeLabel,
    this.treatmentId,
    this.treatmentName,
    required this.recordedByName,
  });
}
