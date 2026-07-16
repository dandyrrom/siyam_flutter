/// Mirrors the Postgres `stock_out_reason` enum: 'waste', 'expired', 'adjustment'.
enum StockOutReason { waste, expired, adjustment }

String stockOutReasonToString(StockOutReason reason) => reason.name;

StockOutReason stockOutReasonFromString(String value) {
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

/// Mirrors a row in public.stock_out -- covers stock leaving inventory for a
/// non-treatment reason (waste, expired stock, manual adjustment). Always at
/// purchase_unit granularity -- these are whole-package events, not partial
/// doses (those go through treatment_item instead).
class StockOut {
  final String id;
  final String itemId;
  final double qty;
  final StockOutReason reason;
  final DateTime recordedDate;
  final String recordedByUserId;

  const StockOut({
    required this.id,
    required this.itemId,
    required this.qty,
    required this.reason,
    required this.recordedDate,
    required this.recordedByUserId,
  });
}
