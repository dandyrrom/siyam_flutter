class InventoryItem {
  final String itemId;
  final String itemName;
  final String itemCategory;
  final String itemUom; // unit of measure, e.g. 'kg', 'pcs', 'boxes'
  final int stockQty;

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
      itemName: map['itemname'] as String? ?? '',
      itemCategory: map['itemcategory'] as String? ?? '',
      itemUom: map['item_uom'] as String? ?? '',
      stockQty: (map['stockqty'] as num?)?.toInt() ?? 0,
    );
  }
}