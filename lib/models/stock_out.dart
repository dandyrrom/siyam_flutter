import 'qty_unit.dart';

// ============================================================================
// STOCK OUT REASON
// ============================================================================

/// Mirrors the Postgres `stock_out_reason` enum:
/// - waste
/// - expired
/// - adjustment
enum StockOutReason {
  waste,
  expired,
  adjustment,
}

// ============================================================================
// STOCK OUT REASON → DATABASE STRING
// ============================================================================

String stockOutReasonToString(
  StockOutReason reason,
) =>
    reason.name;

// ============================================================================
// DATABASE STRING → STOCK OUT REASON
// ============================================================================

StockOutReason stockOutReasonFromString(
  String value,
) {
  switch (value) {
    case 'expired':
      return StockOutReason.expired;

    case 'adjustment':
      return StockOutReason.adjustment;

    case 'waste':
    default:
      return StockOutReason.waste;
  }
}

// ============================================================================
// STOCK OUT MODEL
// ============================================================================

/// Mirrors a row in public.stock_out.
///
/// Stock Out covers inventory leaving the shelter for a non-treatment reason:
///
/// - Waste
/// - Expired
/// - Manual Adjustment
///
/// Unlike the old implementation, Stock Out is no longer restricted to
/// purchase-unit / whole-container quantities.
///
/// Examples:
///
/// Dog Food:
///   purchase unit = bag
///   package unit = kg
///
///   Stock Out 1 bag → QtyUnit.purchaseUnit
///   Stock Out 3 kg  → QtyUnit.packageUnit
///
/// Medicine:
///   purchase unit = bottle
///   package unit = ml
///
///   Stock Out 1 bottle → QtyUnit.purchaseUnit
///   Stock Out 100 ml   → QtyUnit.packageUnit
///
/// Treatment usage remains separate and continues through treatment_item.
class StockOut {
  final String id;
  final String itemId;
  final double qty;

  // ==========================================================================
  // STOCK OUT UNIT
  // ==========================================================================
  //
  // Records which unit the staff actually used when entering the Stock Out.
  //
  // purchaseUnit:
  //   bag, bottle, box, sack, piece, etc.
  //
  // packageUnit:
  //   kg, ml, tablet, piece, etc.
  //
  // This is important because qty = 5 alone is ambiguous:
  //
  //   5 bags
  //   versus
  //   5 kg
  //
  final QtyUnit qtyUnit;

  final StockOutReason reason;
  final DateTime recordedDate;
  final String recordedByUserId;

  const StockOut({
    required this.id,
    required this.itemId,
    required this.qty,

    // ========================================================================
    // BACKWARD-COMPATIBLE DEFAULT
    // ========================================================================
    //
    // Existing Stock Out records were always recorded using purchase units.
    // Keeping purchaseUnit as the default prevents old code and old mock data
    // from immediately breaking while we migrate the remaining files.
    //
    this.qtyUnit = QtyUnit.purchaseUnit,

    required this.reason,
    required this.recordedDate,
    required this.recordedByUserId,
  });
}