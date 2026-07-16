import '../mock/mock_database.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import 'inventory_service.dart';
import 'unit_conversion.dart';

/// In-memory equivalent of the old public.treatment / treatment_item access
/// layer.
///
/// Logging a treatment with items used always writes a treatment_item row
/// per item (the usage itself is always recorded), and additionally
/// decrements item.purchase_stocks via [InventoryService] -- but only when
/// [toPurchaseUnits] can compute a safe conversion. When an item's
/// dispense_unit differs from its package_unit (no known conversion), the
/// row is still written for history, stock is just left untouched.
class TreatmentService {
  final MockDatabase _db = MockDatabase.instance;
  final InventoryService _inventoryService = InventoryService();

  String _userName(String userId) {
    final user = firstWhereOrNull(_db.users, (u) => u.userId == userId);
    return user?.fullName ?? 'Unknown user';
  }

  TreatmentRecord _toTreatmentRecord(TreatmentRow row) {
    final pet = firstWhereOrNull(_db.pets, (p) => p.petId == row.petId);
    final firstItem =
        firstWhereOrNull(_db.treatmentItems, (i) => i.treatId == row.id);

    return TreatmentRecord(
      treatId: row.id,
      petId: row.petId,
      petName: pet?.petName ?? 'Unknown animal',
      petSpecies: pet?.species ?? PetSpecies.dog,
      petBreed: pet?.breed,
      performedByName: firstItem?.givenBy ?? '',
      recordedByUserId: row.recordedByUserId,
      recordedByName: _userName(row.recordedByUserId),
      treatName: row.name,
      notes: row.notes,
      recDate: firstItem?.consumedDate ?? row.recordedDate,
      loggedDate: row.recordedDate,
    );
  }

  Future<List<TreatmentRecord>> fetchTreatments() async {
    final records = _db.treatments.map(_toTreatmentRecord).toList();
    records.sort((a, b) => b.recDate.compareTo(a.recDate));
    return records;
  }

  Future<List<TreatmentItemUsed>> fetchItemsUsed(String treatId) async {
    final rows = _db.treatmentItems.where((i) => i.treatId == treatId);
    final result = <TreatmentItemUsed>[];
    for (final row in rows) {
      final item = await _inventoryService.fetchItem(row.itemId);
      final unitAbbr = item?.dispenseUnitAbbr ?? item?.itemUom ?? '';
      result.add(TreatmentItemUsed(
        itemId: row.itemId,
        itemName: item?.itemName ?? 'Unknown item',
        dispensedQty: row.dispensedQty,
        dispenseUnitAbbr: unitAbbr,
        consumedDate: row.consumedDate,
        givenBy: row.givenBy,
        recordedByName: _userName(row.recordedByUserId),
        recordedDate: row.recordedDate,
      ));
    }
    return result;
  }

  Future<double> fetchTotalItemsUsed() async {
    var total = 0.0;
    for (final row in _db.treatmentItems) {
      total += row.dispensedQty;
    }
    return total;
  }

  Future<TreatmentRecord> createTreatment({
    required String petId,
    required String administeredByName,
    required String performedByUserId,
    required String treatName,
    String? notes,
    DateTime? dateAdministered,
    required List<TreatmentItemInput> items,
  }) async {
    final treatId = newMockId('treatment');
    final now = DateTime.now();
    final consumedDate = dateAdministered ?? now;

    final treatmentRow = TreatmentRow(
      id: treatId,
      name: treatName,
      petId: petId,
      recordedByUserId: performedByUserId,
      recordedDate: now,
      notes: notes,
    );
    _db.treatments.add(treatmentRow);

    for (final row in items) {
      if (row.qty <= 0) continue;
      final item = await _inventoryService.fetchItem(row.itemId);
      if (item == null) continue;

      _db.treatmentItems.add(TreatmentItemRow(
        treatId: treatId,
        itemId: row.itemId,
        dispensedQty: row.qty,
        dispenseUnitId: row.doseUnitId,
        consumedDate: consumedDate,
        givenBy: administeredByName,
        recordedDate: now,
        recordedByUserId: performedByUserId,
      ));

      final purchaseUnitsUsed = toPurchaseUnits(item, row.qty);
      if (purchaseUnitsUsed != null) {
        await _inventoryService.adjustStock(
            itemId: row.itemId, delta: -purchaseUnitsUsed);
      }
    }

    return _toTreatmentRecord(treatmentRow);
  }
}
