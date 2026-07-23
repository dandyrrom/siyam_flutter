import '../mock/mock_database.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'inventory_service.dart';
import 'supabase/supabase_treatment_service.dart';
import 'unit_conversion.dart';

/// Data-access interface for treatments and treatment items. The factory
/// resolves to the mock or Supabase implementation based on [kUseMock], chosen
/// at build time.
abstract interface class TreatmentService {
  factory TreatmentService() =>
      kUseMock ? MockTreatmentService() : SupabaseTreatmentService();

  Future<List<TreatmentRecord>> fetchTreatments();
  Future<List<TreatmentItemUsed>> fetchItemsUsed(String treatId);
  Future<double> fetchTotalItemsUsed();
  Future<TreatmentRecord> createTreatment({
    required String petId,
    required String administeredByName,
    required String performedByUserId,
    required String treatName,
    String? notes,
    DateTime? dateAdministered,
    required List<TreatmentItemInput> items,
  });
}

/// In-memory equivalent of the old public.treatment / treatment_item access
/// layer.
///
/// Logging a treatment with items used always writes a treatment_item row
/// per item (the usage itself is always recorded), and additionally
/// applies the stock effect via [applyTreatmentDeduction] -- see that
/// function for the package-stock vs. purchase-stock vs. not-deductible
/// branching.
class MockTreatmentService implements TreatmentService {
  final MockDatabase _db = MockDatabase.instance;
  final InventoryService _inventoryService = MockInventoryService();

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

  @override
  Future<List<TreatmentRecord>> fetchTreatments() async {
    final records = _db.treatments.map(_toTreatmentRecord).toList();
    records.sort((a, b) => b.recDate.compareTo(a.recDate));
    return records;
  }

  @override
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

  @override
  Future<double> fetchTotalItemsUsed() async {
    var total = 0.0;
    for (final row in _db.treatmentItems) {
      total += row.dispensedQty;
    }
    return total;
  }

  @override
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

      await applyTreatmentDeduction(_inventoryService, item, row.qty);
    }

    DataChangeBus.instance.ping();
    return _toTreatmentRecord(treatmentRow);
  }
}
