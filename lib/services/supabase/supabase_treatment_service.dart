import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/inventory_item.dart';
import '../../models/pet.dart';
import '../../models/treatment.dart';
import '../../state/data_bus.dart';
import '../inventory_service.dart';
import '../treatment_service.dart';

/// Supabase-backed access for public.treatment / treatment_item.
///
/// New treatment creation is committed through one PostgreSQL transaction:
///
/// treatment
///   → treatment_item
///   → FEFO inventory_batch deduction
///   → batch_transaction_log (txntype = TREATMENT)
///
/// Adding one item to an existing treatment continues to use the existing
/// atomic treatment-item function.
///
/// IMPORTANT DONOR IMPACT LINK:
///
/// treatment_item
///   → FEFO inventory_batch deduction
///   → batch_transaction_log (txntype = TREATMENT)
///
/// The batch transaction keeps donor impact linked to the exact physical batch
/// that supplied the treatment usage.
class SupabaseTreatmentService implements TreatmentService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  double _d(dynamic v) => v == null ? 0 : (v as num).toDouble();

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

  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select(
          'id, abbr_name',
        );

    return {
      for (final r in rows)
        r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  // ===========================================================================
  // TREATMENT STOCK VALIDATION
  // ===========================================================================
  //
  // The UI filters out unavailable items, but the stock can still change
  // after the form has loaded.
  //
  // Because of that, treatment stock is checked again before the PostgreSQL
  // transaction is started.
  //
  // PostgreSQL remains the final authority because stock may still change
  // between this validation and the database transaction.
  //
  // currentUsableStockQty is batch-aware and excludes:
  // - expired batches
  // - quarantined batches
  // - depleted batches
  // ===========================================================================

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

    // When SIYAM knows how to deduct the treatment quantity from inventory,
    // the requested treatment quantity must not exceed current usable stock.
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

  // ===========================================================================
  // ATOMIC TREATMENT ITEM
  // ===========================================================================
  //
  // Used when adding ONE item to an already-existing treatment.
  //
  // PostgreSQL performs the treatment_item insert and, when the item is
  // deductible, the complete FEFO inventory deduction in one transaction.
  //
  // This keeps the existing treatment semantics:
  // - deductible units reduce inventory
  // - unconvertible/clinical-only units are still logged without stock change
  //
  // The database is the final authority, so two Staff sessions cannot both
  // consume the same remaining stock from a stale screen.
  // ===========================================================================

  Future<String> _createTreatmentItemAtomically({
    required String treatId,
    required TreatmentItemInput input,
    required String administeredByName,
    required String performedByUserId,
    required DateTime consumedDate,
  }) async {
    final result = await _client.rpc(
      'siyam_atomic_treatment_item',
      params: {
        'p_treat_id': treatId,
        'p_item_id': input.itemId,
        'p_qty': input.qty,
        'p_dispense_unit': input.doseUnitId,
        'p_consumed_date': consumedDate.toIso8601String(),
        'p_given_by': administeredByName,
        'p_recorded_by': performedByUserId,
      },
    );

    if (result == null) {
      throw Exception(
        'Could not record treatment item.',
      );
    }

    return result.toString();
  }

  // ===========================================================================
  // FETCH TREATMENTS
  // ===========================================================================

  @override
  Future<List<TreatmentRecord>> fetchTreatments() async {
    final users = await _userNameMap();

    final rows = await _client.from('treatment').select(
          'id, name, petid, recordedby, recordeddate, notes, '
          'pet(name, species, breed)',
        );

    // First treatment_item per treatment supplies performedBy/recDate.
    final itemRows = await _client
        .from('treatment_item')
        .select(
          'treatid, givenby, consumeddate',
        )
        .order(
          'consumeddate',
          ascending: true,
        );

    final firstItem = <String, Map<String, dynamic>>{};

    for (final r in itemRows) {
      firstItem.putIfAbsent(
        r['treatid'] as String,
        () => r,
      );
    }

    final records = rows.map((r) {
      final pet = r['pet'] as Map<String, dynamic>?;

      final treatId = r['id'] as String;

      final first = firstItem[treatId];

      final recordedBy = r['recordedby'] as String;

      final loggedDate = DateTime.parse(
        r['recordeddate'] as String,
      ).toLocal();

      return TreatmentRecord(
        treatId: treatId,
        petId: r['petid'] as String,
        petName: pet?['name'] as String? ?? 'Unknown animal',
        petSpecies: petSpeciesFromString(
          pet?['species'] as String? ?? 'dog',
        ),
        petBreed: pet?['breed'] as String?,
        performedByName: first?['givenby'] as String? ?? '',
        recordedByUserId: recordedBy,
        recordedByName: users[recordedBy] ?? 'Unknown user',
        treatName: (r['name'] as String?) ?? '',
        notes: r['notes'] as String?,
        recDate: first?['consumeddate'] == null
            ? loggedDate
            : DateTime.parse(
                first!['consumeddate'] as String,
              ).toLocal(),
        loggedDate: loggedDate,
      );
    }).toList();

    records.sort(
      (a, b) => b.recDate.compareTo(
        a.recDate,
      ),
    );

    return records;
  }

  // ===========================================================================
  // FETCH ITEMS USED
  // ===========================================================================

  @override
  Future<List<TreatmentItemUsed>> fetchItemsUsed(
    String treatId,
  ) async {
    final users = await _userNameMap();

    final units = await _unitAbbrMap();

    final rows = await _client
        .from('treatment_item')
        .select(
          'itemid, dispensed_qty, dispense_unit, consumeddate, givenby, '
          'recordeddate, recordedby, item(name)',
        )
        .eq(
          'treatid',
          treatId,
        )
        .order(
          'recordeddate',
          ascending: false,
        );

    return rows.map((r) {
      final item = r['item'] as Map<String, dynamic>?;

      final dispenseUnit = r['dispense_unit'] as String?;

      return TreatmentItemUsed(
        itemId: r['itemid'] as String,
        itemName: item?['name'] as String? ?? 'Unknown item',
        dispensedQty: _d(
          r['dispensed_qty'],
        ),
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
      );
    }).toList();
  }

  // ===========================================================================
  // TOTAL ITEMS USED
  // ===========================================================================

  @override
  Future<double> fetchTotalItemsUsed() async {
    final rows = await _client.from('treatment_item').select(
          'dispensed_qty',
        );

    var total = 0.0;

    for (final r in rows) {
      total += _d(
        r['dispensed_qty'],
      );
    }

    return total;
  }

  // ===========================================================================
  // CREATE NEW TREATMENT ATOMICALLY
  // ===========================================================================
  //
  // The complete new-treatment operation is now ONE PostgreSQL transaction:
  //
  // validate current stock in PostgreSQL
  //   ↓
  // create treatment parent
  //   ↓
  // create every treatment_item
  //   ↓
  // FEFO deductions
  //   ↓
  // batch_transaction_log rows
  //   ↓
  // COMMIT
  //
  // If ANY treatment item fails, PostgreSQL rolls back everything.
  //
  // This prevents:
  // - empty/orphan treatment parents
  // - partially recorded multi-item treatments
  // - partial inventory deductions
  // ===========================================================================

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
    final consumedDate = (dateAdministered ?? DateTime.now()).toUtc();

    // ========================================================================
    // FRIENDLY PRE-VALIDATION
    // ========================================================================
    //
    // Keep the existing client-side checks so Staff gets a useful error early.
    //
    // This is NOT relied upon for concurrency safety.
    // PostgreSQL re-checks everything when the atomic RPC runs.
    // ========================================================================

    final validatedItems = <TreatmentItemInput>[];

    for (final row in items) {
      if (row.qty <= 0) {
        continue;
      }

      await _validateTreatmentStock(
        row,
      );

      validatedItems.add(row);
    }

    if (validatedItems.isEmpty) {
      throw Exception(
        'Add at least one in-stock inventory item to the treatment.',
      );
    }

    // ========================================================================
    // ONE DATABASE CALL FOR THE COMPLETE TREATMENT
    // ========================================================================

    final result = await _client.rpc(
      'siyam_atomic_create_treatment',
      params: {
        'p_pet_id': petId,
        'p_treat_name': treatName,
        'p_notes': notes,
        'p_recorded_by': performedByUserId,
        'p_given_by': administeredByName,
        'p_consumed_date': consumedDate.toIso8601String(),
        'p_items': [
          for (final row in validatedItems)
            {
              'item_id': row.itemId,
              'qty': row.qty,
              'dispense_unit': row.doseUnitId,
            },
        ],
      },
    );

    if (result == null) {
      throw Exception(
        'Could not create treatment.',
      );
    }

    final treatId = result.toString();

    final records = await fetchTreatments();

    DataChangeBus.instance.ping();

    return records.firstWhere(
      (t) => t.treatId == treatId,
    );
  }

  // ===========================================================================
  // ADD ITEM TO EXISTING TREATMENT
  // ===========================================================================
  //
  // IMPORTANT:
  // Do NOT change this to siyam_atomic_create_treatment.
  //
  // This operation adds only one item to an existing treatment, so the existing
  // siyam_atomic_treatment_item function is already the correct transaction.
  // ===========================================================================

  @override
  Future<void> addTreatmentItem({
    required String treatId,
    required TreatmentItemInput item,
    required String administeredByName,
    required String performedByUserId,
    DateTime? dateAdministered,
  }) async {
    if (item.qty <= 0) {
      throw Exception(
        'Treatment quantity must be greater than 0.',
      );
    }

    // Re-read current inventory before creating treatment_item.
    //
    // This protects against a stale page where an item had stock when the
    // dialog opened but became out of stock before staff clicked Save.
    await _validateTreatmentStock(
      item,
    );

    final consumedDate = (dateAdministered ?? DateTime.now()).toUtc();

    await _createTreatmentItemAtomically(
      treatId: treatId,
      input: item,
      administeredByName: administeredByName,
      performedByUserId: performedByUserId,
      consumedDate: consumedDate,
    );

    DataChangeBus.instance.ping();
  }

  // ===========================================================================
  // USAGE EVENT DATES
  // ===========================================================================

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

  DateTime _parseUsageDate(
    dynamic value,
  ) {
    if (value is DateTime) {
      return value.toLocal();
    }

    return DateTime.parse(
      value as String,
    ).toLocal();
  }
}