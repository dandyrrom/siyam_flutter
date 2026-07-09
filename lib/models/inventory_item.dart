enum StockLevel { inStock, needsRestock, low, outOfStock }

class InventoryItem {
  final String itemId;
  final String itemName;
  final String itemCategory;
  final String itemUom; // unit of measure, e.g. 'kg', 'pcs', 'boxes'
  final int stockQty;

  // The `item` table itself still has no supplier column -- this is
  // populated separately by InventoryService, which derives each item's
  // most recent supplier from purchase_trans/order_item history (via
  // the `item_last_supplier` view). Null means the item has never been
  // purchased yet, so the UI shows "—".
  final String? supplierName;

  const InventoryItem({
    required this.itemId,
    required this.itemName,
    required this.itemCategory,
    required this.itemUom,
    required this.stockQty,
    this.supplierName,
  });

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      itemId: map['itemid'] as String,
      itemName: map['itemname'] as String? ?? '',
      itemCategory: map['itemcategory'] as String? ?? '',
      itemUom: map['item_uom'] as String? ?? '',
      stockQty: (map['stockqty'] as num?)?.toInt() ?? 0,
    );
  }

  InventoryItem copyWith({String? supplierName}) {
    return InventoryItem(
      itemId: itemId,
      itemName: itemName,
      itemCategory: itemCategory,
      itemUom: itemUom,
      stockQty: stockQty,
      supplierName: supplierName ?? this.supplierName,
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