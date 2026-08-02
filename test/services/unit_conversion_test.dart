import 'package:flutter_test/flutter_test.dart';
import 'package:siyam_flutter/models/inventory_item.dart';
import 'package:siyam_flutter/services/inventory_service.dart';
import 'package:siyam_flutter/services/unit_conversion.dart';

/// Records whether/with-what [deductFefo] was called, without needing a real
/// backend -- every other method is unused by [applyTreatmentDeduction] and
/// throws if accidentally invoked.
class _RecordingInventoryService implements InventoryService {
  String? deductedItemId;
  double? deductedQty;

  @override
  Future<InventoryItem> deductFefo({required String itemId, required double qty}) async {
    deductedItemId = itemId;
    deductedQty = qty;
    return _dummyItem;
  }

  @override
  Never noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

const _dummyItem = InventoryItem(
  itemId: 'itm-1',
  itemName: 'Test Item',
  pCategoryId: 'pcat-1',
  pCategoryName: 'Medical',
  purchaseUnitId: 'unit-bottle',
  purchaseUnitAbbr: 'btl',
  stockQty: 0,
);

InventoryItem _item({String? packageUnitId, String? dispenseUnitId, double? packageQuantity}) {
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
    stockQty: 5,
  );
}

void main() {
  group('applyTreatmentDeduction', () {
    test('deducts via FEFO when dispense unit equals package unit', () async {
      final service = _RecordingInventoryService();
      final item = _item(
        packageUnitId: 'unit-ml',
        dispenseUnitId: 'unit-ml',
        packageQuantity: 200,
      );

      await applyTreatmentDeduction(service, item, 5.0);

      expect(service.deductedItemId, 'itm-1');
      expect(service.deductedQty, 5.0);
    });

    test('deducts 1:1 from purchase stock when there is no dispense unit (per-piece item)', () async {
      final service = _RecordingInventoryService();
      final item = _item(); // no package/dispense breakdown at all

      await applyTreatmentDeduction(service, item, 1.0);

      expect(service.deductedItemId, 'itm-1');
      expect(service.deductedQty, 1.0);
    });

    test('leaves stock untouched when dispense unit differs from package unit (unknown conversion)', () async {
      final service = _RecordingInventoryService();
      final item = _item(
        packageUnitId: 'unit-ml',
        dispenseUnitId: 'unit-drop',
        packageQuantity: 200,
      );

      await applyTreatmentDeduction(service, item, 3.0);

      expect(service.deductedItemId, isNull);
      expect(service.deductedQty, isNull);
    });
  });
}
