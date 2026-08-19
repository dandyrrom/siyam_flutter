import 'inventory_item.dart';

class MonthlyUsageRow {
  final InventoryItem item;
  final double usedQty;
  final double lossQty;
  final int usageEvents;
  final int lossEvents;

  const MonthlyUsageRow({
    required this.item,
    required this.usedQty,
    required this.lossQty,
    required this.usageEvents,
    required this.lossEvents,
  });

  int get totalEvents => usageEvents + lossEvents;
}

class MonthlyUsageReport {
  final DateTime month;
  final List<MonthlyUsageRow> rows;

  const MonthlyUsageReport({
    required this.month,
    required this.rows,
  });

  int get itemsUsed => rows.where((row) => row.usedQty > 0).length;

  int get usageEvents =>
      rows.fold(0, (sum, row) => sum + row.usageEvents);

  int get lossEvents =>
      rows.fold(0, (sum, row) => sum + row.lossEvents);

  int get itemsWithLosses =>
      rows.where((row) => row.lossQty > 0).length;
}
