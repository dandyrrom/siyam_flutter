import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/donation.dart';
import '../donation_service.dart';
import '../inventory_service.dart';

/// Supabase-backed access for public.submission / donation / donation_item.
///
/// Approving a submission creates the donation + donation_item rows and
/// increments stock for each item received, via [InventoryService].
class SupabaseDonationService implements DonationService {
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

  static const String _subColumns =
      'id, donorid, updatedby, status, drop_off_sched, datesubmitted, '
      'proof_img, notes';

  DonationSubmission _mapSubmission(
      Map<String, dynamic> r, Map<String, String> users) {
    final updatedBy = r['updatedby'] as String?;
    final sched = r['drop_off_sched'] as String?;
    return DonationSubmission(
      subId: r['id'] as String,
      donorId: r['donorid'] as String,
      donorName: users[r['donorid']] ?? 'Unknown donor',
      updatedByUserId: updatedBy,
      updatedByName: updatedBy == null ? null : users[updatedBy],
      status: submissionStatusFromString((r['status'] as String?) ?? 'pending'),
      schedDate: sched == null ? null : DateTime.parse(sched),
      dateSub: DateTime.parse(r['datesubmitted'] as String),
      proofImg: r['proof_img'] as String?,
      notes: r['notes'] as String?,
    );
  }

  @override
  Future<List<DonationSubmission>> fetchSubmissions({String? donorId}) async {
    final users = await _userNameMap();
    var query = _client.from('submission').select(_subColumns);
    if (donorId != null) query = query.eq('donorid', donorId);
    final rows = await query.order('datesubmitted', ascending: false);
    return rows.map((r) => _mapSubmission(r, users)).toList();
  }

  @override
  Future<DonationSubmission> createSubmission({
    required String donorId,
    DateTime? schedDate,
    String? proofImg,
    String? notes,
  }) async {
    final insert = <String, dynamic>{
      'donorid': donorId,
      'status': 'pending',
      'proof_img': proofImg,
      'notes': notes,
    };
    if (schedDate != null) {
      insert['drop_off_sched'] = schedDate.toUtc().toIso8601String();
    }
    final row = await _client
        .from('submission')
        .insert(insert)
        .select(_subColumns)
        .single();
    final users = await _userNameMap();
    return _mapSubmission(row, users);
  }

  @override
  Future<void> updateSubmissionStatus({
    required String subId,
    required SubmissionStatus status,
    required String updatedByUserId,
  }) async {
    await _client.from('submission').update({
      'status': submissionStatusToString(status),
      'updatedby': updatedByUserId,
    }).eq('id', subId);
  }

  @override
  Future<void> rejectSubmission({
    required String subId,
    required String updatedByUserId,
  }) {
    return updateSubmissionStatus(
      subId: subId,
      status: SubmissionStatus.rejected,
      updatedByUserId: updatedByUserId,
    );
  }

  Future<void> _createDonationAndItems({
    String? subId,
    required String donorId,
    required String recordedByUserId,
    required String receivedBy,
    required List<DonationItemInput> items,
    DateTime? receivedDate,
  }) async {
    final insert = <String, dynamic>{
      'donorid': donorId,
      'subid': subId,
      'receivedby': receivedBy,
      'recordedby': recordedByUserId,
    };
    if (receivedDate != null) {
      insert['receiveddate'] = receivedDate.toUtc().toIso8601String();
    }
    final donation =
        await _client.from('donation').insert(insert).select('id').single();
    final donationId = donation['id'] as String;

    for (final item in items) {
      if (item.qty <= 0) continue;
      await _client.from('donation_item').insert({
        'dntid': donationId,
        'itemid': item.itemId,
        'qty': item.qty,
      });
      await _inventoryService.adjustStock(itemId: item.itemId, delta: item.qty);
    }
  }

  @override
  Future<void> approveSubmission({
    required String subId,
    required String donorId,
    required String updatedByUserId,
    required String receivedBy,
    required List<DonationItemInput> items,
  }) async {
    await _client.from('submission').update({
      'status': 'approved',
      'updatedby': updatedByUserId,
    }).eq('id', subId);
    await _createDonationAndItems(
      subId: subId,
      donorId: donorId,
      recordedByUserId: updatedByUserId,
      receivedBy: receivedBy,
      items: items,
    );
  }

  @override
  Future<void> recordDirectDonation({
    required String donorId,
    required String recordedByUserId,
    required String receivedBy,
    required List<DonationItemInput> items,
    DateTime? receivedDate,
  }) {
    return _createDonationAndItems(
      donorId: donorId,
      recordedByUserId: recordedByUserId,
      receivedBy: receivedBy,
      items: items,
      receivedDate: receivedDate,
    );
  }

  @override
  Future<List<DateTime>> fetchDonationDates() async {
    final rows = await _client.from('donation').select('receiveddate');
    return rows
        .map((r) => DateTime.parse(r['receiveddate'] as String))
        .toList();
  }

  @override
  Future<List<DonationLineItem>> fetchReceivedItems(String subId) async {
    final donation = await _client
        .from('donation')
        .select('id')
        .eq('subid', subId)
        .maybeSingle();
    if (donation == null) return [];

    final units = await _unitAbbrMap();
    final rows = await _client
        .from('donation_item')
        .select('itemid, qty, item(name, purchase_unit)')
        .eq('dntid', donation['id'] as String);
    return rows.map((r) {
      final item = r['item'] as Map<String, dynamic>?;
      final purchaseUnit = item?['purchase_unit'] as String?;
      return DonationLineItem(
        itemId: r['itemid'] as String,
        itemName: item?['name'] as String? ?? 'Unknown item',
        itemUom: purchaseUnit == null ? '' : (units[purchaseUnit] ?? ''),
        qty: _d(r['qty']),
      );
    }).toList();
  }

  @override
  Future<List<DonationSubmission>> fetchLinkableSubmissions() async {
    final subs = await fetchSubmissions();
    final donationRows = await _client.from('donation').select('subid');
    final linkedIds = donationRows
        .map((r) => r['subid'] as String?)
        .whereType<String>()
        .toSet();
    return subs
        .where((s) =>
            !linkedIds.contains(s.subId) &&
            s.status != SubmissionStatus.rejected)
        .toList();
  }
}
