import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/pet.dart';
import '../../models/treatment.dart';
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
    final rows = await _client.from('users').select('id, fname, lname');
    return {
      for (final r in rows)
        r['id'] as String:
            '${(r['fname'] as String?) ?? ''} ${(r['lname'] as String?) ?? ''}'
                .trim(),
    };
  }

  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select('id, abbr_name');
    return {
      for (final r in rows) r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  @override
  Future<List<TreatmentRecord>> fetchTreatments() async {
    final users = await _userNameMap();

    final rows = await _client
        .from('treatment')
        .select('id, name, petid, recordedby, recordeddate, notes, '
            'pet(name, species, breed)');

    // First treatment_item per treatment supplies performedBy/recDate.
    final itemRows = await _client
        .from('treatment_item')
        .select('treatid, givenby, consumeddate')
        .order('consumeddate', ascending: true);
    final firstItem = <String, Map<String, dynamic>>{};
    for (final r in itemRows) {
      firstItem.putIfAbsent(r['treatid'] as String, () => r);
    }

    final records = rows.map((r) {
      final pet = r['pet'] as Map<String, dynamic>?;
      final treatId = r['id'] as String;
      final first = firstItem[treatId];
      final recordedBy = r['recordedby'] as String;
      final loggedDate = DateTime.parse(r['recordeddate'] as String);
      return TreatmentRecord(
        treatId: treatId,
        petId: r['petid'] as String,
        petName: pet?['name'] as String? ?? 'Unknown animal',
        petSpecies: petSpeciesFromString(pet?['species'] as String? ?? 'dog'),
        petBreed: pet?['breed'] as String?,
        performedByName: first?['givenby'] as String? ?? '',
        recordedByUserId: recordedBy,
        recordedByName: users[recordedBy] ?? 'Unknown user',
        treatName: (r['name'] as String?) ?? '',
        notes: r['notes'] as String?,
        recDate: first?['consumeddate'] == null
            ? loggedDate
            : DateTime.parse(first!['consumeddate'] as String),
        loggedDate: loggedDate,
      );
    }).toList();

    records.sort((a, b) => b.recDate.compareTo(a.recDate));
    return records;
  }

  @override
  Future<List<TreatmentItemUsed>> fetchItemsUsed(String treatId) async {
    final users = await _userNameMap();
    final units = await _unitAbbrMap();
    final rows = await _client
        .from('treatment_item')
        .select('itemid, dispensed_qty, dispense_unit, consumeddate, givenby, '
            'recordeddate, recordedby, item(name)')
        .eq('treatid', treatId);
    return rows.map((r) {
      final item = r['item'] as Map<String, dynamic>?;
      final dispenseUnit = r['dispense_unit'] as String?;
      return TreatmentItemUsed(
        itemId: r['itemid'] as String,
        itemName: item?['name'] as String? ?? 'Unknown item',
        dispensedQty: _d(r['dispensed_qty']),
        dispenseUnitAbbr:
            dispenseUnit == null ? '' : (units[dispenseUnit] ?? ''),
        consumedDate: DateTime.parse(r['consumeddate'] as String),
        givenBy: (r['givenby'] as String?) ?? '',
        recordedByName: users[r['recordedby']] ?? 'Unknown user',
        recordedDate: DateTime.parse(r['recordeddate'] as String),
      );
    }).toList();
  }

  @override
  Future<double> fetchTotalItemsUsed() async {
    final rows = await _client.from('treatment_item').select('dispensed_qty');
    var total = 0.0;
    for (final r in rows) {
      total += _d(r['dispensed_qty']);
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
    final consumedDate = (dateAdministered ?? DateTime.now()).toUtc();

    final treatment = await _client
        .from('treatment')
        .insert({
          'name': treatName,
          'petid': petId,
          'recordedby': performedByUserId,
          'notes': notes,
        })
        .select('id')
        .single();
    final treatId = treatment['id'] as String;

    for (final row in items) {
      if (row.qty <= 0) continue;
      final item = await _inventoryService.fetchItem(row.itemId);
      if (item == null) continue;

      await _client.from('treatment_item').insert({
        'treatid': treatId,
        'itemid': row.itemId,
        'dispensed_qty': row.qty,
        'dispense_unit': row.doseUnitId,
        'consumeddate': consumedDate.toIso8601String(),
        'givenby': administeredByName,
        'recordedby': performedByUserId,
      });

      await applyTreatmentDeduction(_inventoryService, item, row.qty);
    }

    final records = await fetchTreatments();
    return records.firstWhere((t) => t.treatId == treatId);
  }
}
