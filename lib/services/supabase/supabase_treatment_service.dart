import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/inventory_item.dart';
import '../../models/pet.dart';
import '../../models/treatment.dart';
import '../../state/data_bus.dart';
import '../inventory_service.dart';
import '../treatment_service.dart';

/// Supabase-backed access for public.treatment / treatment_occurrence /
/// treatment_item.
///
/// Existing FEFO inventory protection remains inside the PostgreSQL atomic
/// treatment functions. Follow-up reminders only control when the next real
/// treatment occurrence is due.
class SupabaseTreatmentService implements TreatmentService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

  // Returns a local date from a Postgres date-only value.
  DateTime? _dateFromDateOnly(dynamic value) {
    if (value == null) return null;

    final text = value.toString();
    final parsed = DateTime.tryParse(text);

    if (parsed == null) return null;

    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  // Formats a local calendar date for a Postgres date parameter.
  String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  // Loads display names for user IDs used by medical history.
  Future<Map<String, String>> _userNameMap() async {
    final rows = await _client.from('users').select(
          'id, fname, lname',
        );

    return {
      for (final r in rows)
        r['id'] as String: '${(r['fname'] as String?) ?? ''} '
                '${(r['lname'] as String?) ?? ''}'
            .trim(),
    };
  }

  // Loads unit abbreviations for treatment-item display.
  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select(
          'id, abbr_name',
        );

    return {
      for (final r in rows)
        r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  // Re-reads usable stock before the database transaction for friendly errors.
  Future<InventoryItem> _validateTreatmentStock(
    TreatmentItemInput input,
  ) async {
    if (input.qty <= 0) {
      throw Exception(
        'Treatment quantity must be greater than 0.',
      );
    }

    final item = await _inventoryService.fetchItem(
      input.itemId,
    );

    if (item == null) {
      throw Exception(
        '${input.itemName} is no longer available in inventory.',
      );
    }

    final available = item.currentUsableStockQty;

    if (available <= 0) {
      throw Exception(
        '${item.itemName} is out of stock and cannot be used for treatment.',
      );
    }

    if (item.stockOutIsDeductible && input.qty > available) {
      throw Exception(
        'Not enough usable stock for '
        '${item.itemName}. Only '
        '${formatQty(available)} '
        '${item.currentUsableStockUnit} available.',
      );
    }

    return item;
  }

  // Validates every treatment item before starting a multi-item RPC.
  Future<List<TreatmentItemInput>> _validatedItems(
    List<TreatmentItemInput> items,
  ) async {
    final result = <TreatmentItemInput>[];

    for (final row in items) {
      if (row.qty <= 0) continue;

      await _validateTreatmentStock(row);
      result.add(row);
    }

    if (result.isEmpty) {
      throw Exception(
        'Add at least one in-stock inventory item to the treatment.',
      );
    }

    return result;
  }

  // Maps treatment item form rows to the JSON accepted by PostgreSQL RPCs.
  List<Map<String, dynamic>> _itemsJson(
    List<TreatmentItemInput> items,
  ) {
    return [
      for (final row in items)
        {
          'item_id': row.itemId,
          'qty': row.qty,
          'dispense_unit': row.doseUnitId,
        },
    ];
  }

  // Fetches all treatments and attaches the latest occurrence + schedule data.
  @override
  Future<List<TreatmentRecord>> fetchTreatments() async {
    final results = await Future.wait<Object?>([
      _userNameMap(),
      _client.from('treatment').select(
            'id, name, petid, recordedby, recordeddate, notes, '
            'followup_required, followup_type, next_followup_date, '
            'followup_interval_value, followup_interval_unit, '
            'followup_end_date, followup_note, followup_active, '
            'followup_stopped_at, followup_stop_reason, '
            'pet(name, species, breed)',
          ),
      _client.from('treatment_occurrence').select(
            'occurrenceid, treatid, administereddate, administeredby, '
            'recordedby, recordeddate',
          ),
    ]);

    final users = results[0] as Map<String, String>;
    final rows = results[1] as List<dynamic>;
    final occurrenceRows = results[2] as List<dynamic>;

    final latestOccurrence = <String, Map<String, dynamic>>{};
    final occurrenceCount = <String, int>{};

    for (final raw in occurrenceRows) {
      final row = Map<String, dynamic>.from(raw as Map);
      final treatId = row['treatid'] as String;

      occurrenceCount[treatId] = (occurrenceCount[treatId] ?? 0) + 1;

      final current = latestOccurrence[treatId];
      final currentDate = current == null
          ? null
          : DateTime.parse(current['administereddate'] as String);
      final rowDate = DateTime.parse(row['administereddate'] as String);

      if (currentDate == null || rowDate.isAfter(currentDate)) {
        latestOccurrence[treatId] = row;
      }
    }

    final records = rows.map((raw) {
      final r = Map<String, dynamic>.from(raw as Map);
      final pet = r['pet'] as Map<String, dynamic>?;
      final treatId = r['id'] as String;
      final latest = latestOccurrence[treatId];
      final recordedBy = r['recordedby'] as String;
      final loggedDate = DateTime.parse(
        r['recordeddate'] as String,
      ).toLocal();

      final latestDate = latest == null
          ? loggedDate
          : DateTime.parse(
              latest['administereddate'] as String,
            ).toLocal();

      return TreatmentRecord(
        treatId: treatId,
        petId: r['petid'] as String,
        petName: pet?['name'] as String? ?? 'Unknown animal',
        petSpecies: petSpeciesFromString(
          pet?['species'] as String? ?? 'dog',
        ),
        petBreed: pet?['breed'] as String?,
        performedByName: (latest?['administeredby'] as String?) ?? '',
        recordedByUserId: recordedBy,
        recordedByName: users[recordedBy] ?? 'Unknown user',
        treatName: (r['name'] as String?) ?? '',
        notes: r['notes'] as String?,
        recDate: latestDate,
        loggedDate: loggedDate,
        administrationCount: occurrenceCount[treatId] ?? 0,
        followUpRequired: (r['followup_required'] as bool?) ?? false,
        followUpType: followUpTypeFromString(
          r['followup_type']?.toString(),
        ),
        nextFollowUpDate: _dateFromDateOnly(r['next_followup_date']),
        followUpIntervalValue: (r['followup_interval_value'] as num?)?.toInt(),
        followUpIntervalUnit: followUpIntervalUnitFromString(
          r['followup_interval_unit']?.toString(),
        ),
        followUpEndDate: _dateFromDateOnly(r['followup_end_date']),
        followUpNote: r['followup_note'] as String?,
        followUpActive: (r['followup_active'] as bool?) ?? false,
        followUpStoppedAt: r['followup_stopped_at'] == null
            ? null
            : DateTime.parse(
                r['followup_stopped_at'] as String,
              ).toLocal(),
        followUpStopReason: r['followup_stop_reason'] as String?,
      );
    }).toList();

    records.sort(
      (a, b) => b.recDate.compareTo(a.recDate),
    );

    return records;
  }

  // Fetches actual administrations for one treatment series.
  @override
  Future<List<TreatmentOccurrence>> fetchOccurrences(
    String treatId,
  ) async {
    final users = await _userNameMap();

    final rows = await _client
        .from('treatment_occurrence')
        .select(
          'occurrenceid, treatid, administereddate, administeredby, '
          'recordedby, recordeddate, notes, isfollowup, scheduleddate',
        )
        .eq('treatid', treatId)
        .order('administereddate', ascending: false)
        .order('recordeddate', ascending: false);

    return [
      for (final raw in rows)
        (() {
          final r = Map<String, dynamic>.from(raw);
          final recordedBy = r['recordedby'] as String;

          return TreatmentOccurrence(
            occurrenceId: r['occurrenceid'] as String,
            treatId: r['treatid'] as String,
            administeredDate: DateTime.parse(
              r['administereddate'] as String,
            ).toLocal(),
            administeredBy: (r['administeredby'] as String?) ?? '',
            recordedByUserId: recordedBy,
            recordedByName: users[recordedBy] ?? 'Unknown user',
            recordedDate: DateTime.parse(
              r['recordeddate'] as String,
            ).toLocal(),
            notes: r['notes'] as String?,
            isFollowUp: (r['isfollowup'] as bool?) ?? false,
            scheduledDate: _dateFromDateOnly(r['scheduleddate']),
          );
        })(),
    ];
  }

  // Fetches all inventory items used under one treatment series.
  @override
  Future<List<TreatmentItemUsed>> fetchItemsUsed(
    String treatId,
  ) async {
    final usersFuture = _userNameMap();
    final unitsFuture = _unitAbbrMap();

    final rows = await _client
        .from('treatment_item')
        .select(
          'itemid, dispensed_qty, dispense_unit, consumeddate, givenby, '
          'recordeddate, recordedby, occurrenceid, item(name)',
        )
        .eq('treatid', treatId)
        .order('recordeddate', ascending: false);

    final users = await usersFuture;
    final units = await unitsFuture;

    return rows.map((raw) {
      final r = Map<String, dynamic>.from(raw);
      final item = r['item'] as Map<String, dynamic>?;
      final dispenseUnit = r['dispense_unit'] as String?;

      return TreatmentItemUsed(
        itemId: r['itemid'] as String,
        itemName: item?['name'] as String? ?? 'Unknown item',
        dispensedQty: _d(r['dispensed_qty']),
        dispenseUnitAbbr:
            dispenseUnit == null ? '' : (units[dispenseUnit] ?? ''),
        consumedDate: DateTime.parse(
          r['consumeddate'] as String,
        ).toLocal(),
        givenBy: (r['givenby'] as String?) ?? '',
        recordedByName: users[r['recordedby']] ?? 'Unknown user',
        recordedDate: DateTime.parse(
          r['recordeddate'] as String,
        ).toLocal(),
        occurrenceId: r['occurrenceid'] as String?,
      );
    }).toList();
  }

  // Returns the total raw quantity logged across treatment items.
  @override
  Future<double> fetchTotalItemsUsed() async {
    final rows = await _client.from('treatment_item').select(
          'dispensed_qty',
        );

    var total = 0.0;

    for (final r in rows) {
      total += _d(r['dispensed_qty']);
    }

    return total;
  }

  // Creates one treatment, one initial occurrence, all items, and its optional
  // reminder schedule in one database transaction.
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
    final consumedDate = (dateAdministered ?? DateTime.now()).toUtc();
    final validatedItems = await _validatedItems(items);

    final result = await _client.rpc(
      'siyam_atomic_create_treatment_v2',
      params: {
        'p_pet_id': petId,
        'p_treat_name': treatName,
        'p_notes': notes,
        'p_recorded_by': performedByUserId,
        'p_given_by': administeredByName,
        'p_consumed_date': consumedDate.toIso8601String(),
        'p_items': _itemsJson(validatedItems),
        'p_followup_required': followUp != null,
        'p_followup_type':
            followUp == null ? null : followUpTypeToString(followUp.type),
        'p_next_followup_date':
            followUp == null ? null : _dateOnly(followUp.nextFollowUpDate),
        'p_followup_interval_value': followUp?.intervalValue,
        'p_followup_interval_unit': followUp?.intervalUnit == null
            ? null
            : followUpIntervalUnitToString(followUp!.intervalUnit!),
        'p_followup_end_date':
            followUp?.endDate == null ? null : _dateOnly(followUp!.endDate!),
        'p_followup_note': followUp?.note,
      },
    );

    if (result == null) {
      throw Exception('Could not create treatment.');
    }

    final treatId = result.toString();
    final records = await fetchTreatments();

    DataChangeBus.instance.ping();

    return records.firstWhere(
      (t) => t.treatId == treatId,
    );
  }

  // Adds one later item/dose as its own atomic administration occurrence.
  @override
  Future<void> addTreatmentItem({
    required String treatId,
    required TreatmentItemInput item,
    required String administeredByName,
    required String performedByUserId,
    DateTime? dateAdministered,
  }) async {
    await _validateTreatmentStock(item);

    final consumedDate = (dateAdministered ?? DateTime.now()).toUtc();

    await _client.rpc(
      'siyam_atomic_add_treatment_item_occurrence',
      params: {
        'p_treat_id': treatId,
        'p_item_id': item.itemId,
        'p_qty': item.qty,
        'p_dispense_unit': item.doseUnitId,
        'p_consumed_date': consumedDate.toIso8601String(),
        'p_given_by': administeredByName,
        'p_recorded_by': performedByUserId,
      },
    );

    DataChangeBus.instance.ping();
  }

  // Records the real follow-up administration, deducts every item, and only
  // then advances/stops the reminder schedule.
  @override
  Future<void> recordFollowUpOccurrence({
    required String treatId,
    required String administeredByName,
    required String performedByUserId,
    DateTime? dateAdministered,
    String? notes,
    required List<TreatmentItemInput> items,
  }) async {
    final consumedDate = (dateAdministered ?? DateTime.now()).toUtc();
    final validatedItems = await _validatedItems(items);

    await _client.rpc(
      'siyam_atomic_record_followup_occurrence',
      params: {
        'p_treat_id': treatId,
        'p_given_by': administeredByName,
        'p_recorded_by': performedByUserId,
        'p_consumed_date': consumedDate.toIso8601String(),
        'p_notes': notes,
        'p_items': _itemsJson(validatedItems),
      },
    );

    DataChangeBus.instance.ping();
  }

  // Moves the current reminder without recording a treatment.
  @override
  Future<void> rescheduleFollowUp({
    required String treatId,
    required DateTime nextDate,
  }) async {
    await _client.rpc(
      'siyam_reschedule_treatment_followup',
      params: {
        'p_treat_id': treatId,
        'p_new_date': _dateOnly(nextDate),
      },
    );

    DataChangeBus.instance.ping();
  }

  // Stops future reminders while preserving the treatment and its history.
  @override
  Future<void> stopFollowUp({
    required String treatId,
    String? reason,
  }) async {
    await _client.rpc(
      'siyam_stop_treatment_followup',
      params: {
        'p_treat_id': treatId,
        'p_reason': reason,
      },
    );

    DataChangeBus.instance.ping();
  }

  // Keeps the existing treatment-usage reporting behavior unchanged.
  @override
  Future<List<DateTime>> fetchUsageEventDates() async {
    final rows = await _client.from('treatment_item').select(
          'consumeddate, recordeddate',
        );

    return [
      for (final row in rows)
        _parseUsageDate(
          row['consumeddate'] ?? row['recordeddate'],
        ),
    ];
  }

  DateTime _parseUsageDate(dynamic value) {
    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.parse(value as String).toLocal();
  }
}
