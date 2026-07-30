import '../mock/mock_database.dart';
import '../models/inventory_item.dart';

/// Mirrors [InventoryItem.isOutOfStock] on a raw [ItemRow] — shared by staff
/// and manager dashboard aggregates.
bool isItemRowOutOfStock(ItemRow row) {
  if (row.purchaseStocks > 0) return false;
  if (row.packageQuantity == null) return true;
  final packageStock =
      row.packageStocks ?? row.purchaseStocks * row.packageQuantity!;
  return packageStock <= 0;
}

/// In-stock items at or below [lowStockPurchaseUnitThreshold] whole containers.
bool isItemRowLowStock(ItemRow row) {
  if (isItemRowOutOfStock(row)) return false;
  return row.purchaseStocks <= lowStockPurchaseUnitThreshold;
}

/// Same pools check as [isItemRowOutOfStock], for Supabase row maps.
bool isOutOfStockFromPools(
  double purchaseStocks,
  double? packageStocks,
  double? packageQuantity,
) {
  if (purchaseStocks > 0) return false;
  if (packageQuantity == null) return true;
  final packageStock = packageStocks ?? purchaseStocks * packageQuantity;
  return packageStock <= 0;
}

bool isLowStockFromPools(
  double purchaseStocks,
  double? packageStocks,
  double? packageQuantity,
) {
  if (isOutOfStockFromPools(purchaseStocks, packageStocks, packageQuantity)) {
    return false;
  }
  return purchaseStocks <= lowStockPurchaseUnitThreshold;
}

bool isInventoryItemLowStock(InventoryItem item) {
  if (item.isOutOfStock) return false;
  return item.stockQty <= lowStockPurchaseUnitThreshold;
}
