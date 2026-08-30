import '../mock/mock_database.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'inventory_service.dart';
import 'supabase/supabase_treatment_service.dart';
import 'unit_conversion.dart';

// =============================================================================
// TREATMENT SERVICE
// =============================================================================

abstract interface class TreatmentService {
  factory TreatmentService() =>
      kUseMock ? MockTreatmentService() : SupabaseTreatmentService();

  Future<List<TreatmentRecord>> fetchTreatments();

  Future<List<TreatmentOccurrence>> fetchOccurrences(
    String treatId,
  );

  Future<List<TreatmentItemUsed>> fetchItemsUsed(
    String treatId,
  );

  Future<double> fetchTotalItemsUsed();

  Future<TreatmentRecord> createTreatment({
    required String petId,
    required String administeredByName,
    required String performedByUserId,
    required String treatName,
    String? notes,
    DateTime? dateAdministered,
    required List<TreatmentItemInput> items,
    FollowUpScheduleInput? followUp,
  });

  /// Adds one later item/dose as its own administration occurrence under an
  /// existing treatment.
  Future<void> addTreatmentItem({
    required String treatId,
    required TreatmentItemInput item,
    required String administeredByName,
    required String performedByUserId,
    DateTime? dateAdministered,
  });

  /// Records the actual follow-up treatment. This is not a reminder-only
  /// action: every supplied item is written and deducted from inventory, then
  /// the current reminder advances only after the whole transaction succeeds.
  Future<void> recordFollowUpOccurrence({
    required String treatId,
    required String administeredByName,
    required String performedByUserId,
    DateTime? dateAdministered,
    String? notes,
    required List<TreatmentItemInput> items,
  });

  Future<void> rescheduleFollowUp({
    required String treatId,
    required DateTime nextDate,
  });

  Future<void> stopFollowUp({
    required String treatId,
    String? reason,
  });

  /// One date per treatment_item row — used by the manager dashboard usage
  /// chart and existing operational reports.
  Future<List<DateTime>> fetchUsageEventDates();
}

// =============================================================================
// MOCK IMPLEMENTATION
// =============================================================================

class MockTreatmentService implements TreatmentService {
  final MockDatabase _db = MockDatabase.instance;
  final InventoryService _inventoryService = MockInventoryService();

  static final Map<String, FollowUpScheduleInput> _followUps = {};
  static final Set<String> _inactiveFollowUps = {};
  static final Map<String, List<TreatmentOccurrence>> _occurrences = {};
  static final Map<String, String> _occurrenceByTreatmentItemId = {};

  String _userName(String userId) {
    final user = firstWhereOrNull(
      _db.users,
      (u) => u.userId == userId,
    );

    return user?.fullName ?? 'Unknown user';
  }

  DateTime _nextDate(
    DateTime base,
    int value,
    FollowUpIntervalUnit unit,
  ) {
    switch (unit) {
      case FollowUpIntervalUnit.days:
        return base.add(Duration(days: value));
      case FollowUpIntervalUnit.weeks:
        return base.add(Duration(days: value * 7));
      case FollowUpIntervalUnit.months:
        final targetMonth = base.month - 1 + value;
        final year = base.year + targetMonth ~/ 12;
        final month = targetMonth % 12 + 1;
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(
          year,
          month,
          base.day > lastDay ? lastDay : base.day,
        );
      case FollowUpIntervalUnit.years:
        final year = base.year + value;
        final lastDay = DateTime(year, base.month + 1, 0).day;
        return DateTime(
          year,
          base.month,
          base.day > lastDay ? lastDay : base.day,
        );
    }
  }

  TreatmentRecord _toTreatmentRecord(TreatmentRow row) {
    final pet = firstWhereOrNull(
      _db.pets,
      (p) => p.petId == row.petId,
    );

    final occurrences = _occurrences[row.id] ?? const <TreatmentOccurrence>[];

    final sorted = [...occurrences]
      ..sort(
        (a, b) => b.administeredDate.compareTo(a.administeredDate),
      );

    final firstItem = firstWhereOrNull(
      _db.treatmentItems,
      (i) => i.treatId == row.id,
    );

    final latestOccurrence = sorted.isEmpty ? null : sorted.first;
    final followUp = _followUps[row.id];
    final active = followUp != null && !_inactiveFollowUps.contains(row.id);

    return TreatmentRecord(
      treatId: row.id,
      petId: row.petId,
      petName: pet?.petName ?? 'Unknown animal',
      petSpecies: pet?.species ?? PetSpecies.dog,
      petBreed: pet?.breed,
      performedByName:
          latestOccurrence?.administeredBy ?? firstItem?.givenBy ?? '',
      recordedByUserId: row.recordedByUserId,
      recordedByName: _userName(row.recordedByUserId),
      treatName: row.name,
      notes: row.notes,
      recDate: latestOccurrence?.administeredDate ??
          firstItem?.consumedDate ??
          row.recordedDate,
      loggedDate: row.recordedDate,
      administrationCount: occurrences.isEmpty ? 1 : occurrences.length,
      followUpRequired: followUp != null,
      followUpType: followUp?.type,
      nextFollowUpDate: active ? followUp.nextFollowUpDate : null,
      followUpIntervalValue: followUp?.intervalValue,
      followUpIntervalUnit: followUp?.intervalUnit,
      followUpEndDate: followUp?.endDate,
      followUpNote: followUp?.note,
      followUpActive: active,
    );
  }

  void _addOccurrence({
    required String treatId,
    required String occurrenceId,
    required DateTime administeredDate,
    required String administeredBy,
    required String recordedByUserId,
    required bool isFollowUp,
    DateTime? scheduledDate,
    String? notes,
  }) {
    (_occurrences[treatId] ??= []).add(
      TreatmentOccurrence(
        occurrenceId: occurrenceId,
        treatId: treatId,
        administeredDate: administeredDate,
        administeredBy: administeredBy,
        recordedByUserId: recordedByUserId,
        recordedByName: _userName(recordedByUserId),
        recordedDate: DateTime.now(),
        notes: notes,
        isFollowUp: isFollowUp,
        scheduledDate: scheduledDate,
      ),
    );
  }

  @override
  Future<List<TreatmentRecord>> fetchTreatments() async {
    final records = _db.treatments.map(_toTreatmentRecord).toList();

    records.sort(
      (a, b) => b.recDate.compareTo(a.recDate),
    );

    return records;
  }

  @override
  Future<List<TreatmentOccurrence>> fetchOccurrences(
    String treatId,
  ) async {
    final rows = [...(_occurrences[treatId] ?? const <TreatmentOccurrence>[])];

    rows.sort(
      (a, b) => b.administeredDate.compareTo(a.administeredDate),
    );

    return rows;
  }

  @override
  Future<List<TreatmentItemUsed>> fetchItemsUsed(String treatId) async {
    final rows = _db.treatmentItems.where((i) => i.treatId == treatId);
    final result = <TreatmentItemUsed>[];

    for (final row in rows) {
      final item = await _inventoryService.fetchItem(row.itemId);
      final unitAbbr = item?.dispenseUnitAbbr ?? item?.itemUom ?? '';

      result.add(
        TreatmentItemUsed(
          itemId: row.itemId,
          itemName: item?.itemName ?? 'Unknown item',
          dispensedQty: row.dispensedQty,
          dispenseUnitAbbr: unitAbbr,
          consumedDate: row.consumedDate,
          givenBy: row.givenBy,
          recordedByName: _userName(row.recordedByUserId),
          recordedDate: row.recordedDate,
          occurrenceId: _occurrenceByTreatmentItemId[row.id],
        ),
      );
    }

    result.sort(
      (a, b) => b.recordedDate.compareTo(a.recordedDate),
    );

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
    FollowUpScheduleInput? followUp,
  }) async {
    final treatId = newMockId('treatment');
    final occurrenceId = newMockId('occurrence');
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

    _addOccurrence(
      treatId: treatId,
      occurrenceId: occurrenceId,
      administeredDate: consumedDate,
      administeredBy: administeredByName,
      recordedByUserId: performedByUserId,
      isFollowUp: false,
      notes: notes,
    );

    if (followUp != null) {
      _followUps[treatId] = followUp;
      _inactiveFollowUps.remove(treatId);
    }

    for (final row in items) {
      if (row.qty <= 0) continue;

      final item = await _inventoryService.fetchItem(row.itemId);
      if (item == null) continue;

      final treatmentItemId = newMockId('treatitem');

      _db.treatmentItems.add(
        TreatmentItemRow(
          id: treatmentItemId,
          treatId: treatId,
          itemId: row.itemId,
          dispensedQty: row.qty,
          dispenseUnitId: row.doseUnitId,
          consumedDate: consumedDate,
          givenBy: administeredByName,
          recordedDate: now,
          recordedByUserId: performedByUserId,
        ),
      );

      _occurrenceByTreatmentItemId[treatmentItemId] = occurrenceId;

      await applyTreatmentDeduction(
        _inventoryService,
        item,
        row.qty,
      );
    }

    DataChangeBus.instance.ping();

    return _toTreatmentRecord(treatmentRow);
  }

  @override
  Future<void> addTreatmentItem({
    required String treatId,
    required TreatmentItemInput item,
    required String administeredByName,
    required String performedByUserId,
    DateTime? dateAdministered,
  }) async {
    if (item.qty <= 0) return;

    if (firstWhereOrNull(_db.treatments, (t) => t.id == treatId) == null) {
      throw Exception('Treatment not found');
    }

    final invItem = await _inventoryService.fetchItem(item.itemId);
    if (invItem == null) throw Exception('Item not found');

    final now = DateTime.now();
    final consumedDate = dateAdministered ?? now;
    final occurrenceId = newMockId('occurrence');
    final treatmentItemId = newMockId('treatitem');

    _addOccurrence(
      treatId: treatId,
      occurrenceId: occurrenceId,
      administeredDate: consumedDate,
      administeredBy: administeredByName,
      recordedByUserId: performedByUserId,
      isFollowUp: false,
    );

    _db.treatmentItems.add(
      TreatmentItemRow(
        id: treatmentItemId,
        treatId: treatId,
        itemId: item.itemId,
        dispensedQty: item.qty,
        dispenseUnitId: item.doseUnitId,
        consumedDate: consumedDate,
        givenBy: administeredByName,
        recordedDate: now,
        recordedByUserId: performedByUserId,
      ),
    );

    _occurrenceByTreatmentItemId[treatmentItemId] = occurrenceId;

    await applyTreatmentDeduction(
      _inventoryService,
      invItem,
      item.qty,
    );

    DataChangeBus.instance.ping();
  }

  @override
  Future<void> recordFollowUpOccurrence({
    required String treatId,
    required String administeredByName,
    required String performedByUserId,
    DateTime? dateAdministered,
    String? notes,
    required List<TreatmentItemInput> items,
  }) async {
    final schedule = _followUps[treatId];

    if (schedule == null || _inactiveFollowUps.contains(treatId)) {
      throw Exception('This treatment has no active follow-up reminder.');
    }

    final now = DateTime.now();
    final administeredDate = dateAdministered ?? now;
    final occurrenceId = newMockId('occurrence');

    _addOccurrence(
      treatId: treatId,
      occurrenceId: occurrenceId,
      administeredDate: administeredDate,
      administeredBy: administeredByName,
      recordedByUserId: performedByUserId,
      isFollowUp: true,
      scheduledDate: schedule.nextFollowUpDate,
      notes: notes,
    );

    for (final row in items) {
      if (row.qty <= 0) continue;

      final invItem = await _inventoryService.fetchItem(row.itemId);
      if (invItem == null) {
        throw Exception('${row.itemName} is no longer available.');
      }

      final treatmentItemId = newMockId('treatitem');

      _db.treatmentItems.add(
        TreatmentItemRow(
          id: treatmentItemId,
          treatId: treatId,
          itemId: row.itemId,
          dispensedQty: row.qty,
          dispenseUnitId: row.doseUnitId,
          consumedDate: administeredDate,
          givenBy: administeredByName,
          recordedDate: now,
          recordedByUserId: performedByUserId,
        ),
      );

      _occurrenceByTreatmentItemId[treatmentItemId] = occurrenceId;

      await applyTreatmentDeduction(
        _inventoryService,
        invItem,
        row.qty,
      );
    }

    if (schedule.type == FollowUpType.oneTime) {
      _inactiveFollowUps.add(treatId);
    } else {
      final value = schedule.intervalValue!;
      final unit = schedule.intervalUnit!;
      final next = _nextDate(administeredDate, value, unit);

      if (schedule.endDate != null && next.isAfter(schedule.endDate!)) {
        _inactiveFollowUps.add(treatId);
      } else {
        _followUps[treatId] = FollowUpScheduleInput(
          type: schedule.type,
          nextFollowUpDate: next,
          intervalValue: value,
          intervalUnit: unit,
          endDate: schedule.endDate,
          note: schedule.note,
        );
      }
    }

    DataChangeBus.instance.ping();
  }

  @override
  Future<void> rescheduleFollowUp({
    required String treatId,
    required DateTime nextDate,
  }) async {
    final schedule = _followUps[treatId];

    if (schedule == null || _inactiveFollowUps.contains(treatId)) {
      throw Exception('This treatment has no active follow-up reminder.');
    }

    _followUps[treatId] = FollowUpScheduleInput(
      type: schedule.type,
      nextFollowUpDate: nextDate,
      intervalValue: schedule.intervalValue,
      intervalUnit: schedule.intervalUnit,
      endDate: schedule.endDate,
      note: schedule.note,
    );

    DataChangeBus.instance.ping();
  }

  @override
  Future<void> stopFollowUp({
    required String treatId,
    String? reason,
  }) async {
    if (!_followUps.containsKey(treatId)) {
      throw Exception('This treatment has no follow-up schedule.');
    }

    _inactiveFollowUps.add(treatId);
    DataChangeBus.instance.ping();
  }

  @override
  Future<List<DateTime>> fetchUsageEventDates() async {
    return _db.treatmentItems.map((t) => t.consumedDate).toList();
  }
}
