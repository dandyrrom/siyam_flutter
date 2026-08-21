import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/inventory_item.dart';
import '../../models/pet.dart';
import '../../models/treatment.dart';
import '../../state/data_bus.dart';
import '../inventory_service.dart';
import '../treatment_service.dart';
import '../unit_conversion.dart';

/// Supabase-backed access for public.treatment / treatment_item.
///
/// Logging a treatment always writes a treatment_item row per item, and
/// additionally applies the stock effect via [applyTreatmentDeduction] --
/// see that function for the package-stock vs. purchase-stock vs.
/// not-deductible branching.
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
        r['id'] as String:
            '${(r['fname'] as String?) ?? ''} '
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
        r['id'] as String:
            (r['abbr_name'] as String?) ?? '',
    };
  }

  // ===========================================================================
  // TREATMENT STOCK VALIDATION
  // ===========================================================================
  //
  // The UI filters out unavailable items, but the stock can still change
  // after the form has loaded.
  //
  // Because of that, treatment stock must always be checked again immediately
  // before a treatment or treatment item is written.
  //
  // currentUsableStockQty is batch-aware and excludes:
  // - expired batches
  // - quarantined batches
  // - depleted batches
  //
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
    if (item.stockOutIsDeductible &&
        input.qty > available) {
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
  // FETCH TREATMENTS
  // ===========================================================================

  @override
  Future<List<TreatmentRecord>> fetchTreatments() async {
    final users = await _userNameMap();

    final rows = await _client
        .from('treatment')
        .select(
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

    final firstItem =
        <String, Map<String, dynamic>>{};

    for (final r in itemRows) {
      firstItem.putIfAbsent(
        r['treatid'] as String,
        () => r,
      );
    }

    final records = rows.map((r) {
      final pet =
          r['pet'] as Map<String, dynamic>?;

      final treatId =
          r['id'] as String;

      final first =
          firstItem[treatId];

      final recordedBy =
          r['recordedby'] as String;

      final loggedDate =
          DateTime.parse(
            r['recordeddate'] as String,
          ).toLocal();

      return TreatmentRecord(
        treatId: treatId,
        petId: r['petid'] as String,
        petName:
            pet?['name'] as String? ??
                'Unknown animal',
        petSpecies: petSpeciesFromString(
          pet?['species'] as String? ??
              'dog',
        ),
        petBreed:
            pet?['breed'] as String?,
        performedByName:
            first?['givenby']
                    as String? ??
                '',
        recordedByUserId:
            recordedBy,
        recordedByName:
            users[recordedBy] ??
                'Unknown user',
        treatName:
            (r['name'] as String?) ??
                '',
        notes:
            r['notes'] as String?,
        recDate:
            first?['consumeddate'] ==
                    null
                ? loggedDate
                : DateTime.parse(
                    first![
                            'consumeddate']
                        as String,
                  ).toLocal(),
        loggedDate:
            loggedDate,
      );
    }).toList();

    records.sort(
      (a, b) =>
          b.recDate.compareTo(
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
    final users =
        await _userNameMap();

    final units =
        await _unitAbbrMap();

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
      final item =
          r['item']
              as Map<String, dynamic>?;

      final dispenseUnit =
          r['dispense_unit']
              as String?;

      return TreatmentItemUsed(
        itemId:
            r['itemid'] as String,
        itemName:
            item?['name'] as String? ??
                'Unknown item',
        dispensedQty:
            _d(r['dispensed_qty']),
        dispenseUnitAbbr:
            dispenseUnit == null
                ? ''
                : (units[
                        dispenseUnit] ??
                    ''),
        consumedDate:
            DateTime.parse(
              r['consumeddate']
                  as String,
            ).toLocal(),
        givenBy:
            (r['givenby'] as String?) ??
                '',
        recordedByName:
            users[r['recordedby']] ??
                'Unknown user',
        recordedDate:
            DateTime.parse(
              r['recordeddate']
                  as String,
            ).toLocal(),
      );
    }).toList();
  }

  // ===========================================================================
  // TOTAL ITEMS USED
  // ===========================================================================

  @override
  Future<double> fetchTotalItemsUsed() async {
    final rows = await _client
        .from('treatment_item')
        .select(
          'dispensed_qty',
        );

    var total = 0.0;

    for (final r in rows) {
      total +=
          _d(r['dispensed_qty']);
    }

    return total;
  }

  // ===========================================================================
  // CREATE TREATMENT
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
    final consumedDate =
        (dateAdministered ??
                DateTime.now())
            .toUtc();

    // ========================================================================
    // PRE-VALIDATE ALL ITEMS
    // ========================================================================
    //
    // This happens BEFORE the treatment parent row is created.
    //
    // Previously:
    //
    // treatment row
    //   ↓
    // treatment_item
    //   ↓
    // FEFO deduction
    //
    // If stock was already unavailable, the treatment could exist even though
    // inventory deduction failed.
    //
    // Now:
    //
    // validate live usable stock
    //   ↓
    // create treatment
    //   ↓
    // treatment_item
    //   ↓
    // FEFO deduction
    //
    // ========================================================================

    final validatedItems =
        <(TreatmentItemInput, InventoryItem)>[];

    for (final row in items) {
      if (row.qty <= 0) {
        continue;
      }

      final inventoryItem =
          await _validateTreatmentStock(
        row,
      );

      validatedItems.add(
        (
          row,
          inventoryItem,
        ),
      );
    }

    if (validatedItems.isEmpty) {
      throw Exception(
        'Add at least one in-stock inventory item to the treatment.',
      );
    }

    // ========================================================================
    // CREATE TREATMENT PARENT
    // ========================================================================

    final treatment = await _client
        .from('treatment')
        .insert({
          'name':
              treatName,
          'petid':
              petId,
          'recordedby':
              performedByUserId,
          'notes':
              notes,
        })
        .select(
          'id',
        )
        .single();

    final treatId =
        treatment['id'] as String;

    // ========================================================================
    // CREATE TREATMENT ITEMS
    // ========================================================================

    for (final validated
        in validatedItems) {
      final row =
          validated.$1;

      final item =
          validated.$2;

      await _client
          .from('treatment_item')
          .insert({
        'treatid':
            treatId,
        'itemid':
            row.itemId,
        'dispensed_qty':
            row.qty,
        'dispense_unit':
            row.doseUnitId,
        'consumeddate':
            consumedDate
                .toIso8601String(),
        'givenby':
            administeredByName,
        'recordedby':
            performedByUserId,
      });

      await applyTreatmentDeduction(
        _inventoryService,
        item,
        row.qty,
      );
    }

    final records =
        await fetchTreatments();

    DataChangeBus.instance.ping();

    return records.firstWhere(
      (t) => t.treatId == treatId,
    );
  }

  // ===========================================================================
  // ADD ITEM TO EXISTING TREATMENT
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
    final invItem =
        await _validateTreatmentStock(
      item,
    );

    final consumedDate =
        (dateAdministered ??
                DateTime.now())
            .toUtc();

    await _client
        .from('treatment_item')
        .insert({
      'treatid':
          treatId,
      'itemid':
          item.itemId,
      'dispensed_qty':
          item.qty,
      'dispense_unit':
          item.doseUnitId,
      'consumeddate':
          consumedDate
              .toIso8601String(),
      'givenby':
          administeredByName,
      'recordedby':
          performedByUserId,
    });

    await applyTreatmentDeduction(
      _inventoryService,
      invItem,
      item.qty,
    );

    DataChangeBus.instance.ping();
  }

  // ===========================================================================
  // USAGE EVENT DATES
  // ===========================================================================

  @override
  Future<List<DateTime>>
      fetchUsageEventDates() async {
    final rows = await _client
        .from('treatment_item')
        .select(
          'consumeddate, recordeddate',
        );

    return [
      for (final row in rows)
        _parseUsageDate(
          row['consumeddate'] ??
              row['recordeddate'],
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