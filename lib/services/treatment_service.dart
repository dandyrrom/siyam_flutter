import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/treatment.dart';
import 'inventory_service.dart';

/// Thin wrapper around public.treatment / public.treatment_item.
///
/// Table reference (from your schema):
///   treatment(treatid uuid PK, petid FK->pet, userid FK->users,
///             treatname, notes, recdate timestamptz)
///   treatment_item(treatid FK, itemid FK->item, qtyused int,
///                  consumeddate timestamptz, givenby FK->users)
///
/// Note: there's no follow-up date or a distinct ongoing/completed/
/// scheduled status column in the schema -- this only logs treatments
/// that have already happened (recdate defaults to now()), it doesn't
/// model scheduling.
///
/// Logging a treatment with items used also decrements each item's
/// `item.stockqty` via InventoryService, since treatment_item models
/// inventory consumption the same way donation_item models inventory
/// receipt.
class TreatmentService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  static const _selectWithJoins = '*, pet(petname, species, breed), users(userfname, userlname)';

  Future<List<TreatmentRecord>> fetchTreatments() async {
    final rows = await _client
        .from('treatment')
        .select(_selectWithJoins)
        .order('recdate', ascending: false);
    return (rows as List)
        .map((r) => TreatmentRecord.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<List<TreatmentItemUsed>> fetchItemsUsed(String treatId) async {
    final rows = await _client
        .from('treatment_item')
        .select('qtyused, item(itemid, itemname, item_uom)')
        .eq('treatid', treatId);
    return (rows as List)
        .map((r) => TreatmentItemUsed.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<int> fetchTotalItemsUsed() async {
    final rows = await _client.from('treatment_item').select('qtyused');
    var total = 0;
    for (final r in (rows as List)) {
      total += (r as Map<String, dynamic>)['qtyused'] as int? ?? 0;
    }
    return total;
  }

  /// Creates the treatment record, logs each consumed item into
  /// treatment_item, and decrements stock for each item consumed.
  Future<TreatmentRecord> createTreatment({
    required String petId,
    required String userId,
    required String treatName,
    String? notes,
    required List<TreatmentItemInput> items,
  }) async {
    final row = await _client
        .from('treatment')
        .insert({
          'petid': petId,
          'userid': userId,
          'treatname': treatName,
          'notes': notes,
        })
        .select(_selectWithJoins)
        .single();

    final treatId = row['treatid'] as String;

    for (final item in items) {
      if (item.qty <= 0) continue;
      await _client.from('treatment_item').insert({
        'treatid': treatId,
        'itemid': item.itemId,
        'qtyused': item.qty,
        'givenby': userId,
      });
      await _inventoryService.adjustStock(itemId: item.itemId, delta: -item.qty);
    }

    return TreatmentRecord.fromMap(row);
  }
}
