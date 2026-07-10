enum StockLevel { inStock, needsRestock, low, outOfStock }

/// Formats a quantity for display, trimming a trailing ".0" so whole
/// numbers don't render with a spurious decimal (schema stores these as
/// float4 to allow fractional doses/stock, but most values are whole).
String formatQty(double qty) {
  return qty == qty.roundToDouble() ? qty.toStringAsFixed(0) : qty.toString();
}

class InventoryItem {
  final String itemId;
  final String itemName;
  final String itemCategory;
  final String itemUom; // unit of measure, e.g. 'kg', 'pcs', 'boxes'
  final double stockQty;

  const InventoryItem({
    required this.itemId,
    required this.itemName,
    required this.itemCategory,
    required this.itemUom,
    required this.stockQty,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      itemId: map['itemid'] as String,
      itemName: map['name'] as String? ?? '',
      itemCategory: map['category'] as String? ?? '',
      itemUom: map['uom'] as String? ?? '',
      stockQty: (map['currentstock'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Short human-facing ID shown in the Inventory table, e.g. "ITM-3FA8".
  /// Derived from the UUID since there's no separate sequential-ID
  /// column in the schema -- swap this out if one gets added later.
  String get displayId =>
      'ITM-${itemId.replaceAll('-', '').substring(0, 4).toUpperCase()}';

  /// Stock-level tier thresholds are a placeholder assumption (no
  /// reorder-point column exists on `item` yet). Adjust here, or move
  /// to a per-item `reorder_point` column if you want these tunable
  /// per item instead of globally.
  StockLevel get stockLevel {
    if (stockQty <= 0) return StockLevel.outOfStock;
    if (stockQty <= 10) return StockLevel.low;
    if (stockQty <= 30) return StockLevel.needsRestock;
    return StockLevel.inStock;
  }
}