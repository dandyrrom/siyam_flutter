import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/donation.dart';
import 'inventory_service.dart';

/// Thin wrapper around public.submission / public.donation / public.donation_item.
///
/// Table reference (from your schema):
///   submission(subid PK, donorid FK->users, revby FK->users, status
///              sub_status, scheddate, datesub, proofimg)
///   donation(donid PK, subid FK->submission, donorid FK->users,
///            transdate, rcvdby FK->users)
///   donation_item(donid FK, itemid FK->item, qty int)
///
/// `submission` and `donation` both have two separate foreign keys into
/// `users` (donor + reviewer/receiver), so embedded-resource joins are
/// ambiguous without a DB-side FK constraint name we can't verify from
/// here. Instead this fetches user names in a single follow-up query
/// and stitches them in client-side, the same "best-effort lookup"
/// pattern InventoryService uses for supplier names.
///
/// Approving a submission also creates the `donation` + `donation_item`
/// rows and increments stock for each item received, via
/// InventoryService -- the receiving-side mirror of how TreatmentService
/// decrements stock on consumption.
class DonationService {
  final SupabaseClient _client = Supabase.instance.client;
  final InventoryService _inventoryService = InventoryService();

  Future<Map<String, String>> _userNames(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return {};
    final rows = await _client
        .from('users')
        .select('userid, userfname, userlname')
        .inFilter('userid', unique);
    return {
      for (final r in (rows as List))
        (r as Map<String, dynamic>)['userid'] as String:
            '${r['userfname'] ?? ''} ${r['userlname'] ?? ''}'.trim(),
    };
  }

  Future<List<DonationSubmission>> fetchSubmissions({String? donorId}) async {
    var query = _client.from('submission').select();
    final rows = await (donorId == null
            ? query
            : query.eq('donorid', donorId))
        .order('datesub', ascending: false);

    final ids = <String>{};
    for (final r in (rows as List)) {
      final map = r as Map<String, dynamic>;
      ids.add(map['donorid'] as String);
      final revby = map['revby'] as String?;
      if (revby != null) ids.add(revby);
    }
    final names = await _userNames(ids);

    return rows.map((r) => DonationSubmission.fromMap(r, names)).toList();
  }

  Future<DonationSubmission> createSubmission({
    required String donorId,
    DateTime? schedDate,
    String? proofImg,
  }) async {
    final row = await _client
        .from('submission')
        .insert({
          'donorid': donorId,
          'status': 'pending',
          'scheddate': schedDate?.toIso8601String(),
          'proofimg': proofImg,
        })
        .select()
        .single();
    final names = await _userNames([donorId]);
    return DonationSubmission.fromMap(row, names);
  }

  Future<void> rejectSubmission({
    required String subId,
    required String revById,
  }) async {
    await _client
        .from('submission')
        .update({'status': 'rejected', 'revby': revById}).eq('subid', subId);
  }

  /// Marks the submission approved and records what was actually
  /// received: creates the `donation` row, one `donation_item` row per
  /// item, and increments each item's stock.
  Future<void> approveSubmission({
    required String subId,
    required String donorId,
    required String revById,
    required List<DonationItemInput> items,
  }) async {
    await _client
        .from('submission')
        .update({'status': 'approved', 'revby': revById}).eq('subid', subId);

    final donationRow = await _client
        .from('donation')
        .insert({'subid': subId, 'donorid': donorId, 'rcvdby': revById})
        .select()
        .single();
    final donId = donationRow['donid'] as String;

    for (final item in items) {
      if (item.qty <= 0) continue;
      await _client.from('donation_item').insert({
        'donid': donId,
        'itemid': item.itemId,
        'qty': item.qty,
      });
      await _inventoryService.adjustStock(itemId: item.itemId, delta: item.qty);
    }
  }

  /// Transaction dates for every completed donation -- used to bucket
  /// donation counts by month on the Reports page.
  Future<List<DateTime>> fetchDonationDates() async {
    final rows = await _client.from('donation').select('transdate');
    return (rows as List)
        .map((r) =>
            DateTime.tryParse((r as Map<String, dynamic>)['transdate'] as String? ?? '') ??
            DateTime.now())
        .toList();
  }

  /// Items actually received for an already-approved submission, or an
  /// empty list if it hasn't been approved (no linked donation) yet.
  Future<List<DonationLineItem>> fetchReceivedItems(String subId) async {
    final donationRow = await _client
        .from('donation')
        .select('donid')
        .eq('subid', subId)
        .maybeSingle();
    if (donationRow == null) return [];

    final donId = donationRow['donid'] as String;
    final rows = await _client
        .from('donation_item')
        .select('qty, item(itemid, itemname, item_uom)')
        .eq('donid', donId);
    return (rows as List)
        .map((r) => DonationLineItem.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
