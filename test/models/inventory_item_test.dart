import 'package:flutter_test/flutter_test.dart';
import 'package:siyam_flutter/models/inventory_item.dart';
import 'package:siyam_flutter/models/qty_unit.dart';

InventoryItem _item({
  String? packageUnitId,
  String? dispenseUnitId,
  double? packageQuantity,
  double stockQty = 10,
  double? packageStockQty,
  StockCountMode? stockCountMode,
}) {
  return InventoryItem(
    itemId: 'itm-1',
    itemName: 'Test Item',
    pCategoryId: 'pcat-1',
    pCategoryName: 'Medical',
    purchaseUnitId: 'unit-bottle',
    purchaseUnitAbbr: 'btl',
    packageUnitId: packageUnitId,
    packageUnitAbbr: packageUnitId != null ? 'ml' : null,
    packageQuantity: packageQuantity,
    dispenseUnitId: dispenseUnitId,
    dispenseUnitAbbr: dispenseUnitId != null ? 'drop' : null,
    stockQty: stockQty,
    packageStockQty: packageStockQty,
    stockCountMode: stockCountMode,
  );
}

void main() {
  group('formatQty', () {
    test('trims trailing .0 for whole numbers', () {
      expect(formatQty(5.0), '5');
    });

    test('keeps decimals for fractional values', () {
      expect(formatQty(2.5), '2.5');
    });
  });

  group('stockOutIsDeductible', () {
    test('true when there is no dispense unit', () {
      final item = _item(packageUnitId: 'unit-ml', packageQuantity: 200);
      expect(item.stockOutIsDeductible, isTrue);
    });

    test('true when dispense unit equals package unit', () {
      final item = _item(
        packageUnitId: 'unit-ml',
        dispenseUnitId: 'unit-ml',
        packageQuantity: 200,
      );
      expect(item.stockOutIsDeductible, isTrue);
    });

    test('false when dispense unit differs from package unit (e.g. drop vs ml)', () {
      final item = _item(
        packageUnitId: 'unit-ml',
        dispenseUnitId: 'unit-drop',
        packageQuantity: 200,
      );
      expect(item.stockOutIsDeductible, isFalse);
    });
  });

  group('effectiveCountMode / displayStockQty', () {
    test('defaults to packageUnit for deductible items with a breakdown', () {
      final item = _item(
        packageUnitId: 'unit-ml',
        dispenseUnitId: 'unit-ml',
        packageQuantity: 200,
        stockQty: 3,
        packageStockQty: 450,
      );
      expect(item.effectiveCountMode, StockCountMode.packageUnit);
      expect(item.displayStockQty, 450);
      expect(item.displayStockUnit, 'ml');
    });

    test('falls back to stockQty * packageQuantity when packageStockQty is null', () {
      final item = _item(
        packageUnitId: 'unit-ml',
        dispenseUnitId: 'unit-ml',
        packageQuantity: 200,
        stockQty: 3,
      );
      expect(item.displayStockQty, 600);
    });

    test('defaults to purchaseUnit for non-deductible items', () {
      final item = _item(
        packageUnitId: 'unit-ml',
        dispenseUnitId: 'unit-drop',
        packageQuantity: 200,
        stockQty: 7,
      );
      expect(item.effectiveCountMode, StockCountMode.purchaseUnit);
      expect(item.displayStockQty, 7);
    });

    test('explicit stockCountMode overrides the derived default', () {
      final item = _item(
        packageUnitId: 'unit-ml',
        dispenseUnitId: 'unit-ml',
        packageQuantity: 200,
        stockQty: 3,
        packageStockQty: 450,
        stockCountMode: StockCountMode.purchaseUnit,
      );
      expect(item.effectiveCountMode, StockCountMode.purchaseUnit);
      expect(item.displayStockQty, 3);
    });
  });

  group('isOutOfStock / stockLevel', () {
    test('out of stock when both pools are empty', () {
      final item = _item(stockQty: 0);
      expect(item.isOutOfStock, isTrue);
      expect(item.stockLevel, StockLevel.outOfStock);
    });

    test('not out of stock when a partial package remains, even with 0 whole containers', () {
      final item = _item(
        packageUnitId: 'unit-ml',
        packageQuantity: 200,
        stockQty: 0,
        packageStockQty: 15,
      );
      expect(item.isOutOfStock, isFalse);
    });

    test('low tier at/under the configurable threshold', () {
      final original = lowStockPurchaseUnitThreshold;
      lowStockPurchaseUnitThreshold = 10;
      addTearDown(() => lowStockPurchaseUnitThreshold = original);

      final item = _item(stockQty: 10);
      expect(item.stockLevel, StockLevel.low);
    });

    test('needsRestock tier above the low threshold but at/under 30', () {
      final item = _item(stockQty: 25);
      expect(item.stockLevel, StockLevel.needsRestock);
    });

    test('inStock above 30', () {
      final item = _item(stockQty: 31);
      expect(item.stockLevel, StockLevel.inStock);
    });
  });

  group('packageLabel', () {
    test('null when there is no package breakdown', () {
      final item = _item();
      expect(item.packageLabel, isNull);
    });

    test('formats quantity, unit, and purchase unit', () {
      final item = _item(packageUnitId: 'unit-ml', packageQuantity: 200);
      expect(item.packageLabel, '(200 ml per btl)');
    });
  });
}
