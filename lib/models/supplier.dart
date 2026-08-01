import 'qty_unit.dart';

/// Mirrors a row in public.supplier.
class Supplier {
  final String suppId;
  final String suppName;
  final String? contactNum;
  final String? contactTel;
  final String? address;

  const Supplier({
    required this.suppId,
    required this.suppName,
    this.contactNum,
    this.contactTel,
    this.address,
  });
}

/// Mirrors a row in public.purchase, joined with the user who recorded it
/// and the supplier it was placed with.
class PurchaseOrder {
  final String purId;
  final String suppId;
  final String suppName;
  final String recordedByUserId;
  final String buyerName;
  final String receivedBy;
  final DateTime receivedDate;

  const PurchaseOrder({
    required this.purId,
    required this.suppId,
    required this.suppName,
    required this.recordedByUserId,
    required this.buyerName,
    required this.receivedBy,
    required this.receivedDate,
  });
}

/// A single line item on a purchase order (joined public.purchase_item with
/// public.item for its name/unit).
class OrderLineItem {
  final String itemId;
  final String itemName;
  final String itemUom;
  final double qty;
  final double unitCost;

  const OrderLineItem({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    required this.qty,
    required this.unitCost,
  });
}

/// A single purchase_item row's spend, with its parent purchase's date --
/// used to bucket total purchase spend by month on the Reports page.
class OrderSpendEntry {
  final DateTime purDate;
  final double amount;

  const OrderSpendEntry({required this.purDate, required this.amount});
}

/// Form-side input for one row on a new purchase order, before it's
/// written to purchase_item. [qty]/[unitCost] are in [qtyUnit] terms --
/// purchase_unit (whole box/bottle) by default, or package_unit (loose
/// tablet/ml) for a restock entered by prescribed/needed amount rather than
/// whole containers. [expiryDate] is optional -- see updated_db.md.
class OrderItemInput {
  final String itemId;
  final String itemName;
  final String itemUom;
  double qty;
  double unitCost;
  QtyUnit qtyUnit;
  DateTime? expiryDate;

  OrderItemInput({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    this.qty = 1,
    this.unitCost = 0,
    this.qtyUnit = QtyUnit.purchaseUnit,
    this.expiryDate,
  });
}
