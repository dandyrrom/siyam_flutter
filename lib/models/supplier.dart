/// Mirrors a row in public.supplier.
///
/// Note: there's no `category`, `email`, `rating`, or `status` column on
/// this table, so those React-mock fields are dropped here. "Orders" and
/// "last order" are derived from public.purchase_trans instead of being
/// stored directly.
class Supplier {
  final String suppId;
  final String suppName;
  final String? contactNum;
  final String? address;

  const Supplier({
    required this.suppId,
    required this.suppName,
    this.contactNum,
    this.address,
  });

  factory Supplier.fromMap(Map<String, dynamic> map) {
    return Supplier(
      suppId: map['suppid'] as String,
      suppName: map['suppname'] as String? ?? '',
      contactNum: map['contactnum'] as String?,
      address: map['address'] as String?,
    );
  }
}

/// Mirrors a row in public.purchase_trans, joined with the user who
/// placed it.
class PurchaseOrder {
  final String purId;
  final String suppId;
  final String userId;
  final String buyerName;
  final DateTime purDate;

  const PurchaseOrder({
    required this.purId,
    required this.suppId,
    required this.userId,
    required this.buyerName,
    required this.purDate,
  });

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) {
    final user = map['users'] as Map<String, dynamic>? ?? const {};
    final fname = user['userfname'] as String? ?? '';
    final lname = user['userlname'] as String? ?? '';
    return PurchaseOrder(
      purId: map['purid'] as String,
      suppId: map['suppid'] as String,
      userId: map['userid'] as String,
      buyerName: [fname, lname].where((s) => s.isNotEmpty).join(' '),
      purDate: DateTime.tryParse(map['purdate'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// A single line item on a purchase order (joined public.order_item with
/// public.item for its name/unit).
class OrderLineItem {
  final String itemId;
  final String itemName;
  final String itemUom;
  final int qty;
  final double unitCost;

  const OrderLineItem({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    required this.qty,
    required this.unitCost,
  });

  factory OrderLineItem.fromMap(Map<String, dynamic> map) {
    final item = map['item'] as Map<String, dynamic>? ?? const {};
    return OrderLineItem(
      itemId: item['itemid'] as String? ?? '',
      itemName: item['itemname'] as String? ?? 'Unknown item',
      itemUom: item['item_uom'] as String? ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
      unitCost: (map['unitcost'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// A single order_item row's spend, with its parent order's date --
/// used to bucket purchase spend by month on the Reports page.
class OrderSpendEntry {
  final DateTime purDate;
  final double amount;

  const OrderSpendEntry({required this.purDate, required this.amount});

  factory OrderSpendEntry.fromMap(Map<String, dynamic> map) {
    final order = map['purchase_trans'] as Map<String, dynamic>? ?? const {};
    final qty = (map['qty'] as num?)?.toInt() ?? 0;
    final unitCost = (map['unitcost'] as num?)?.toDouble() ?? 0;
    return OrderSpendEntry(
      purDate: DateTime.tryParse(order['purdate'] as String? ?? '') ?? DateTime.now(),
      amount: qty * unitCost,
    );
  }
}

/// Form-side input for one row on a new purchase order, before it's
/// written to order_item.
class OrderItemInput {
  final String itemId;
  final String itemName;
  final String itemUom;
  int qty;
  double unitCost;

  OrderItemInput({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    this.qty = 1,
    this.unitCost = 0,
  });
}
