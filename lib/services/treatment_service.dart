import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/treatment.dart';
import 'inventory_service.dart';

/// Thin wrapper around public.treatment / public.treatment_item.
///
/// Table reference (from your schema):
///   treatment(treatid uuid PK, petid FK->pet, name, notes)
///   treatment_item(treatid FK, itemid FK->item, qtyused float4,
///                  givenon timestamptz, givenby text, userid FK->users,
///                  recdate timestamptz, uom text)
///
/// `treatment` itself carries no user or date -- the "who administered /
/// when" the form collects is written onto every treatment_item row
/// instead (givenby is free text, no FK; userid is the signed-in staff
/// member's id, captured separately). `uom` records the unit a dose was
/// actually given in, which may differ from the item's own stocked unit
/// (see [TreatmentItemInput.deduct]).
///
/// Note: there's no follow-up date or a distinct ongoing/completed/
/// scheduled status column in the schema -- this only logs treatments
/// that have already happened, it doesn't model scheduling.
///
/// Logging a treatment with items used also decrements each item's
/// `item.currentstock` via InventoryService, since treatment_item models
/// inventory consumption the same way donation_item models inventory
/// receipt.
class TreatmentService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  static const _selectWithJoins = '*, pet(petname, species, breed), treatment_item(givenby, givenon)';

  Future<List<TreatmentRecord>> fetchTreatments() async {
    final rows = await _client.from('treatment').select(_selectWithJoins);
    final records = (rows as List)
        .map((r) => TreatmentRecord.fromMap(r as Map<String, dynamic>))
        .toList();
    // Can't order() on an embedded (treatment_item) column via PostgREST,
    // so sort client-side by the derived display date instead.
    records.sort((a, b) => b.recDate.compareTo(a.recDate));
    return records;
  }

  Future<List<TreatmentItemUsed>> fetchItemsUsed(String treatId) async {
    final rows = await _client
        .from('treatment_item')
        .select('qtyused, uom, item(itemid, name, uom)')
        .eq('treatid', treatId);
    return (rows as List)
        .map((r) => TreatmentItemUsed.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<double> fetchTotalItemsUsed() async {
    final rows = await _client.from('treatment_item').select('qtyused');
    var total = 0.0;
    for (final r in (rows as List)) {
      total += (r as Map<String, dynamic>)['qtyused'] as num? ?? 0;
    }
    return total;
  }

  /// Creates the treatment record, logs each consumed item into
  /// treatment_item, and decrements stock for each item consumed --
  /// unless that item's [TreatmentItemInput.deduct] is false (set when
  /// the staff member changed the unit away from the item's own UOM,
  /// since there's no safe way to convert between units).
  ///
  /// [administeredByName] (free text, e.g. a vet or staff member's name --
  /// not necessarily a system user) and [dateAdministered] are written to
  /// every treatment_item row for this submission, since the form only
  /// collects one "who / when" pair for the whole treatment.
  /// [performedByUserId] is the signed-in staff member's id, captured
  /// separately for treatment_item.userid.
  Future<TreatmentRecord> createTreatment({
    required String petId,
    required String administeredByName,
    required String performedByUserId,
    required String treatName,
    String? notes,
    DateTime? dateAdministered,
    required List<TreatmentItemInput> items,
  }) async {
    final row = await _client
        .from('treatment')
        .insert({
          'petid': petId,
          'name': treatName,
          'notes': notes,
        })
        .select('*, pet(petname, species, breed)')
        .single();

    final treatId = row['treatid'] as String;
    final givenOn = dateAdministered ?? DateTime.now();

    for (final item in items) {
      if (item.qty <= 0) continue;
      await _client.from('treatment_item').insert({
        'treatid': treatId,
        'itemid': item.itemId,
        'qtyused': item.qty,
        'givenon': givenOn.toIso8601String(),
        'givenby': administeredByName,
        'userid': performedByUserId,
        'recdate': DateTime.now().toIso8601String(),
        'uom': item.unit,
      });
      if (item.deduct) {
        await _inventoryService.adjustStock(itemId: item.itemId, delta: -item.qty);
      }
    }

    return TreatmentRecord.fromMap({
      ...row,
      'treatment_item': [
        {'givenby': administeredByName, 'givenon': givenOn.toIso8601String()},
      ],
    });
  }
}
