import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/inventory_item.dart';
import '../../models/pet.dart';
import '../../models/treatment.dart';
import '../../state/data_bus.dart';
import '../inventory_service.dart';
import '../treatment_service.dart';
import '../unit_conversion.dart';

// =============================================================================
// TREATMENT BATCH ALLOCATION
// =============================================================================
//
// This is a read-only plan of the exact FEFO batches that the existing
// InventoryService deduction is about to consume.
//
// The actual stock deduction still stays inside InventoryService. We only use
// this plan to write the missing TREATMENT rows into batch_transaction_log so
// donor impact can attribute treatment usage to the exact donated batch.
// =============================================================================

class _TreatmentBatchAllocation {
  final String inventoryBatchId;
  final double batchQty;
  final String qtyUnit;

  const _TreatmentBatchAllocation({
    required this.inventoryBatchId,
    required this.batchQty,
    required this.qtyUnit,
  });
}

/// Supabase-backed access for public.treatment / treatment_item.
///
/// Logging a treatment always writes a treatment_item row per item, and
/// additionally applies the stock effect via [applyTreatmentDeduction].
///
/// IMPORTANT DONOR IMPACT LINK:
///
/// treatment_item
///   → FEFO inventory_batch deduction
///   → batch_transaction_log (txntype = TREATMENT)
///
/// The batch transaction is required because donor impact is attributed from
/// the exact physical donated batch that was consumed.
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
  // DATE HELPERS
  // ===========================================================================

  DateTime _todayOnly() {
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  DateTime? _parseDateOnly(dynamic value) {
    if (value == null) return null;

    final parsed =
        DateTime.tryParse(value.toString());

    if (parsed == null) return null;

    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
    );
  }

  String _batchQtyUnit(
    Map<String, dynamic> batch,
  ) {
    final value =
        (batch['qtyunit'] as String?) ??
            'purchase_unit';

    return value.trim().toLowerCase();
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
  // ===========================================================================

  Future<InventoryItem> _validateTreatmentStock(
    TreatmentItemInput input,
  ) async {
    if (input.qty <= 0) {
      throw Exception(
        'Treatment quantity must be greater than 0.',
      );
    }

    final item =
        await _inventoryService.fetchItem(
      input.itemId,
    );

    if (item == null) {
      throw Exception(
        '${input.itemName} is no longer available in inventory.',
      );
    }

    final available =
        item.currentUsableStockQty;

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
  // DOES THIS TREATMENT ACTUALLY DEDUCT INVENTORY?
  // ===========================================================================
  //
  // Keep this in exact sync with applyTreatmentDeduction().
  //
  // 1. dispense unit == package unit + package quantity
  //    → measurable package-unit deduction
  //
  // 2. no dispense unit
  //    → direct count deduction
  //
  // 3. otherwise
  //    → treatment is logged, but no reliable stock conversion exists
  // ===========================================================================

  bool _treatmentDeductsInventory(
    InventoryItem item,
  ) {
    if (item.dispenseUnitId != null &&
        item.dispenseUnitId ==
            item.packageUnitId &&
        item.packageQuantity != null) {
      return true;
    }

    if (item.dispenseUnitId == null) {
      return true;
    }

    return false;
  }

  // ===========================================================================
  // BATCH QUANTITY CONVERSION
  // ===========================================================================

  double _batchCanonicalAvailable(
    Map<String, dynamic> batch,
    InventoryItem item,
  ) {
    final available =
        _d(batch['qtyavailable']);

    final packageQuantity =
        item.packageQuantity;

    if (packageQuantity == null) {
      return available;
    }

    if (packageQuantity <= 0) {
      throw Exception(
        'Invalid package quantity configured for ${item.itemName}.',
      );
    }

    if (_batchQtyUnit(batch) ==
        'purchase_unit') {
      return available *
          packageQuantity;
    }

    return available;
  }

  double _canonicalToBatchQty(
    double canonicalQty,
    Map<String, dynamic> batch,
    InventoryItem item,
  ) {
    final packageQuantity =
        item.packageQuantity;

    if (packageQuantity == null) {
      return canonicalQty;
    }

    if (packageQuantity <= 0) {
      throw Exception(
        'Invalid package quantity configured for ${item.itemName}.',
      );
    }

    if (_batchQtyUnit(batch) ==
        'purchase_unit') {
      return canonicalQty /
          packageQuantity;
    }

    return canonicalQty;
  }

  // ===========================================================================
  // PLAN EXACT TREATMENT FEFO BATCHES
  // ===========================================================================
  //
  // IMPORTANT:
  //
  // This mirrors the already-working FEFO eligibility/sort rules in
  // SupabaseInventoryService.deductFefo().
  //
  // It does NOT change stock.
  //
  // We take the snapshot immediately before applyTreatmentDeduction() so that,
  // after the stable deduction succeeds, the exact same allocations can be
  // written to batch_transaction_log.
  // ===========================================================================

  Future<List<_TreatmentBatchAllocation>>
      _planTreatmentBatchAllocations({
    required InventoryItem item,
    required double canonicalQty,
  }) async {
    if (!_treatmentDeductsInventory(item)) {
      return const [];
    }

    final rows = await _client
        .from('inventory_batch')
        .select(
          'inventorybatchid, expirydate, receiveddate, '
          'qtyavailable, qtyunit, status',
        )
        .eq('itemid', item.itemId)
        .gt('qtyavailable', 0);

    final today = _todayOnly();

    final batches = rows
        .where((r) {
          final status =
              ((r['status'] as String?) ??
                      'ACTIVE')
                  .toUpperCase();

          if (status == 'DEPLETED' ||
              status == 'QUARANTINED') {
            return false;
          }

          final expiryDate =
              _parseDateOnly(
            r['expirydate'],
          );

          if (expiryDate == null) {
            return true;
          }

          return !expiryDate.isBefore(
            today,
          );
        })
        .map(
          (r) =>
              Map<String, dynamic>.from(r),
        )
        .toList();

    // FEFO:
    // earliest expiry first, then oldest received.
    batches.sort((a, b) {
      final aExpiry =
          _parseDateOnly(
        a['expirydate'],
      );

      final bExpiry =
          _parseDateOnly(
        b['expirydate'],
      );

      if (aExpiry == null &&
          bExpiry != null) {
        return 1;
      }

      if (aExpiry != null &&
          bExpiry == null) {
        return -1;
      }

      if (aExpiry != null &&
          bExpiry != null) {
        final compare =
            aExpiry.compareTo(
          bExpiry,
        );

        if (compare != 0) {
          return compare;
        }
      }

      final aReceived =
          DateTime.parse(
        a['receiveddate'] as String,
      );

      final bReceived =
          DateTime.parse(
        b['receiveddate'] as String,
      );

      return aReceived.compareTo(
        bReceived,
      );
    });

    final totalAvailable =
        batches.fold<double>(
      0,
      (sum, batch) =>
          sum +
          _batchCanonicalAvailable(
            batch,
            item,
          ),
    );

    if (totalAvailable <
        canonicalQty) {
      throw Exception(
        'Not enough usable batch stock for ${item.itemName}. '
        'Only ${formatQty(totalAvailable)} '
        '${item.hasPackageBreakdown ? item.packageUnitAbbr : item.purchaseUnitAbbr} '
        'available.',
      );
    }

    var remaining =
        canonicalQty;

    final allocations =
        <_TreatmentBatchAllocation>[];

    for (final batch in batches) {
      if (remaining <= 0) {
        break;
      }

      final canonicalAvailable =
          _batchCanonicalAvailable(
        batch,
        item,
      );

      if (canonicalAvailable <= 0) {
        continue;
      }

      final canonicalDraw =
          remaining <
                  canonicalAvailable
              ? remaining
              : canonicalAvailable;

      final batchDraw =
          _canonicalToBatchQty(
        canonicalDraw,
        batch,
        item,
      );

      allocations.add(
        _TreatmentBatchAllocation(
          inventoryBatchId:
              batch['inventorybatchid']
                  as String,
          batchQty:
              batchDraw,
          qtyUnit:
              (batch['qtyunit']
                      as String?) ??
                  'purchase_unit',
        ),
      );

      remaining -=
          canonicalDraw;
    }

    return allocations;
  }

  // ===========================================================================
  // WRITE TREATMENT BATCH TRANSACTIONS
  // ===========================================================================
  //
  // This is the missing link that caused donated medical items used during a
  // treatment to fail to appear in the donor's Impact page.
  //
  // SupabaseImpactService reads TREATMENT movements by inventorybatchid and
  // treatmentitemid. Without these rows, the donor page cannot know that the
  // exact donated batch helped an animal.
  // ===========================================================================

  Future<void> _recordTreatmentBatchTransactions({
    required List<_TreatmentBatchAllocation>
        allocations,
    required String treatmentItemId,
    required String performedByUserId,
    required DateTime transactionDate,
  }) async {
    if (allocations.isEmpty) {
      return;
    }

    await _client
        .from('batch_transaction_log')
        .insert([
      for (final allocation
          in allocations)
        {
          'inventorybatchid':
              allocation
                  .inventoryBatchId,
          'treatmentitemid':
              treatmentItemId,
          'stockoutid': null,
          'txntype': 'TREATMENT',
          'qtychange':
              -allocation.batchQty,
          'qtyunit':
              allocation.qtyUnit,
          'txndate':
              transactionDate
                  .toUtc()
                  .toIso8601String(),
          'performedby':
              performedByUserId,
          'notes':
              'Treatment usage',
        },
    ]);
  }

  // ===========================================================================
  // APPLY TREATMENT DEDUCTION + IMPACT LINK
  // ===========================================================================
  //
  // The actual stock deduction remains in the existing shared helper.
  // We only add the exact batch transaction after that stable deduction
  // succeeds.
  // ===========================================================================

  Future<void> _applyTreatmentDeductionWithImpact({
    required InventoryItem item,
    required double qty,
    required String treatmentItemId,
    required String performedByUserId,
    required DateTime consumedDate,
  }) async {
    if (!_treatmentDeductsInventory(item)) {
      // Same behavior as the original applyTreatmentDeduction():
      // usage is recorded on treatment_item, but inventory is not changed
      // because SIYAM does not know a safe unit conversion.
      return;
    }

    final allocations =
        await _planTreatmentBatchAllocations(
      item: item,
      canonicalQty: qty,
    );

    // Preserve the existing stable stock deduction implementation.
    await applyTreatmentDeduction(
      _inventoryService,
      item,
      qty,
    );

    // Add the missing exact donor-impact provenance.
    await _recordTreatmentBatchTransactions(
      allocations: allocations,
      treatmentItemId:
          treatmentItemId,
      performedByUserId:
          performedByUserId,
      transactionDate:
          consumedDate,
    );
  }

  // ===========================================================================
  // FETCH TREATMENTS
  // ===========================================================================

  @override
  Future<List<TreatmentRecord>>
      fetchTreatments() async {
    final users =
        await _userNameMap();

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
          r['pet']
              as Map<String, dynamic>?;

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
        petId:
            r['petid'] as String,
        petName:
            pet?['name'] as String? ??
                'Unknown animal',
        petSpecies:
            petSpeciesFromString(
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
  Future<List<TreatmentItemUsed>>
      fetchItemsUsed(
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
            _d(
          r['dispensed_qty'],
        ),
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
            (r['givenby']
                    as String?) ??
                '',
        recordedByName:
            users[
                    r['recordedby']] ??
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
  Future<double>
      fetchTotalItemsUsed() async {
    final rows = await _client
        .from('treatment_item')
        .select(
          'dispensed_qty',
        );

    var total = 0.0;

    for (final r in rows) {
      total +=
          _d(
        r['dispensed_qty'],
      );
    }

    return total;
  }

  // ===========================================================================
  // CREATE TREATMENT
  // ===========================================================================

  @override
  Future<TreatmentRecord>
      createTreatment({
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
    // validate live usable stock
    //   ↓
    // create treatment
    //   ↓
    // treatment_item
    //   ↓
    // FEFO deduction
    //   ↓
    // TREATMENT batch transaction
    //
    // ========================================================================

    final validatedItems =
        <(TreatmentItemInput,
            InventoryItem)>[];

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

    final treatment =
        await _client
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

      // IMPORTANT:
      // Return treatmentitemid so the exact consumed inventory batch can be
      // linked to this treatment item in batch_transaction_log.
      final treatmentItemRow =
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
              })
              .select(
                'treatmentitemid',
              )
              .single();

      final treatmentItemId =
          treatmentItemRow[
                  'treatmentitemid']
              as String;

      await _applyTreatmentDeductionWithImpact(
        item: item,
        qty: row.qty,
        treatmentItemId:
            treatmentItemId,
        performedByUserId:
            performedByUserId,
        consumedDate:
            consumedDate,
      );
    }

    final records =
        await fetchTreatments();

    DataChangeBus.instance.ping();

    return records.firstWhere(
      (t) =>
          t.treatId == treatId,
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

    // Return treatmentitemid so this exact treatment usage can be attached to
    // the exact FEFO batch/batches that supplied it.
    final treatmentItemRow =
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
            })
            .select(
              'treatmentitemid',
            )
            .single();

    final treatmentItemId =
        treatmentItemRow[
                'treatmentitemid']
            as String;

    await _applyTreatmentDeductionWithImpact(
      item: invItem,
      qty: item.qty,
      treatmentItemId:
          treatmentItemId,
      performedByUserId:
          performedByUserId,
      consumedDate:
          consumedDate,
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
