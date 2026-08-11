import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/donation.dart';
import '../../models/qty_unit.dart';
import '../../state/data_bus.dart';
import '../donation_service.dart';
import '../inventory_service.dart';

/// Supabase-backed access for public.submission / donation / donation_item.
///
/// Approving a submission creates the donation + donation_item rows, then
/// creates an inventory_batch for each item received and records its initial
/// RECEIVE movement in batch_transaction_log.
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
      for (final r in rows)
        r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  static const String _subColumns =
      'id, donorid, updatedby, status, drop_off_sched, datesubmitted, '
      'date_received, proof_img, notes';

  DonationSubmission _mapSubmission(
    Map<String, dynamic> r,
    Map<String, String> users,
  ) {
    final updatedBy = r['updatedby'] as String?;
    final sched = r['drop_off_sched'] as String?;
    final received = r['date_received'] as String?;

    return DonationSubmission(
      subId: r['id'] as String,
      donorId: r['donorid'] as String,
      donorName: users[r['donorid']] ?? 'Unknown donor',
      updatedByUserId: updatedBy,
      updatedByName: updatedBy == null ? null : users[updatedBy],
      status: submissionStatusFromString((r['status'] as String?) ?? 'pending'),
      schedDate: sched == null ? null : DateTime.parse(sched),
      dateSub: DateTime.parse(r['datesubmitted'] as String),
      dateReceived: received == null ? null : DateTime.parse(received),
      proofImg: r['proof_img'] as String?,
      notes: r['notes'] as String?,
    );
  }

  @override
  Future<List<DonationSubmission>> fetchSubmissions({String? donorId}) async {
    final users = await _userNameMap();

    var query = _client.from('submission').select(_subColumns);

    if (donorId != null) {
      query = query.eq('donorid', donorId);
    }

    final rows = await query.order('datesubmitted', ascending: false);

    return rows.map((r) => _mapSubmission(r, users)).toList();
  }

  @override
  Future<DonationSubmission?> fetchSubmission(String subId) async {
    final row = await _client
        .from('submission')
        .select(_subColumns)
        .eq('id', subId)
        .maybeSingle();

    if (row == null) return null;

    final users = await _userNameMap();

    return _mapSubmission(row, users);
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

    DataChangeBus.instance.ping();

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

    DataChangeBus.instance.ping();
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

  /// Creates the donation and its donation_item rows.
  ///
  /// Each donation_item now becomes the source of one physical
  /// inventory_batch. Expiry and remaining stock are stored on
  /// inventory_batch rather than donation_item.
  ///
  /// A RECEIVE row is then created in batch_transaction_log so the exact
  /// batch that entered inventory is preserved for later FEFO deductions
  /// and donor-impact tracing.
  Future<void> _createDonationAndItems({
    String? subId,
    String? donorId,
    String? donorName,
    required String recordedByUserId,
    required String receivedBy,
    required List<DonationItemInput> items,
    required DonationType type,
    DateTime? receivedDate,
  }) async {
    final actualReceivedDate = receivedDate ?? DateTime.now();

    final insert = <String, dynamic>{
      'type': donationTypeToString(type),
      'donorid': donorId,
      'donor_name': donorName,
      'subid': subId,
      'receivedby': receivedBy,
      'recordedby': recordedByUserId,
      'receiveddate': actualReceivedDate.toUtc().toIso8601String(),
    };

    final donation =
        await _client.from('donation').insert(insert).select('id').single();

    final donationId = donation['id'] as String;

    for (final item in items) {
      if (item.qty <= 0) continue;

      final invItem = await _inventoryService.fetchItem(item.itemId);

      // Canonical batch qty for FEFO: package_unit terms when the item
      // has a breakdown (converting from purchase_unit if that's how this
      // donation was received), else purchase_unit terms directly.
      final packageQuantity = invItem?.packageQuantity;

      final batchQty = packageQuantity == null
          ? item.qty
          : (item.qtyUnit == QtyUnit.packageUnit
              ? item.qty
              : item.qty * packageQuantity);

      // donation_item now stores only the donation line itself. Expiry and
      // remaining quantity belong to the inventory_batch created below.
      final donationItem = await _client
          .from('donation_item')
          .insert({
            'dntid': donationId,
            'itemid': item.itemId,
            'qty': item.qty,
            'qty_unit': qtyUnitToString(item.qtyUnit),
          })
          .select('donationitemid')
          .single();

      final donationItemId = donationItem['donationitemid'] as String;

      // Every received donation_item creates its own physical batch.
      //
      // Donor identity is NOT copied into inventory_batch. Donor provenance
      // remains traceable through:
      // inventory_batch → donation_item → donation → donorid.
      final batch = await _client
          .from('inventory_batch')
          .insert({
            'itemid': item.itemId,
            'purchaseitemid': null,
            'donationitemid': donationItemId,
            'batchcode':
                'DON-${donationItemId.substring(0, 8).toUpperCase()}',
            'receiveddate': actualReceivedDate.toUtc().toIso8601String(),
            'expirydate': item.expiryDate?.toIso8601String().split('T').first,
            'qtyreceived': batchQty,
            'qtyavailable': batchQty,
            'qtyunit': qtyUnitToString(
              packageQuantity == null
                  ? QtyUnit.purchaseUnit
                  : QtyUnit.packageUnit,
            ),
            'unitcost': null,
            'status': 'ACTIVE',
            'createdby': recordedByUserId,
          })
          .select('inventorybatchid')
          .single();

      final inventoryBatchId = batch['inventorybatchid'] as String;

      // RECEIVE records the initial stock movement for this exact donated
      // batch. Later treatment/stock-out transactions can point back to this
      // same inventorybatchid.
      await _client.from('batch_transaction_log').insert({
        'inventorybatchid': inventoryBatchId,
        'treatmentitemid': null,
        'stockoutid': null,
        'txntype': 'RECEIVE',
        'qtychange': batchQty,
        'qtyunit': qtyUnitToString(
          packageQuantity == null
              ? QtyUnit.purchaseUnit
              : QtyUnit.packageUnit,
        ),
        'txndate': actualReceivedDate.toUtc().toIso8601String(),
        'performedby': recordedByUserId,
        'notes': 'Stock received from donation $donationId',
      });

      // TEMPORARY:
      // Existing inventory pages still use item-level aggregate stock.
      // Keep that value synchronized while inventory displays are being
      // migrated to SUM(inventory_batch.qtyavailable).
      await _inventoryService.stockIn(
        itemId: item.itemId,
        qty: item.qty,
        qtyUnit: item.qtyUnit,
      );
    }

    DataChangeBus.instance.ping();
  }

  @override
  Future<void> approveSubmission({
    required String subId,
    required String donorId,
    required String updatedByUserId,
    required String receivedBy,
    required List<DonationItemInput> items,
    required DonationType type,
    DateTime? receivedDate,
  }) async {
    await _client.from('submission').update({
      'status': 'stocked',
      'updatedby': updatedByUserId,
    }).eq('id', subId);

    DataChangeBus.instance.ping();

    await _createDonationAndItems(
      subId: subId,
      donorId: donorId,
      recordedByUserId: updatedByUserId,
      receivedBy: receivedBy,
      items: items,
      type: type,
      receivedDate: receivedDate,
    );
  }

  /// Persists the "Items Received" confirmation for a submission, before
  /// Stock In actually creates the donation/donation_item rows.
  @override
  Future<void> markSubmissionReceived({
    required String subId,
  }) async {
    await _client.from('submission').update({
      'date_received': DateTime.now().toUtc().toIso8601String(),
      'status': 'received',
    }).eq('id', subId);

    DataChangeBus.instance.ping();
  }

  @override
  Future<void> recordDirectDonation({
    String? donorId,
    String? donorName,
    required String recordedByUserId,
    required String receivedBy,
    required List<DonationItemInput> items,
    required DonationType type,
    DateTime? receivedDate,
  }) {
    return _createDonationAndItems(
      donorId: donorId,
      donorName: donorName,
      recordedByUserId: recordedByUserId,
      receivedBy: receivedBy,
      items: items,
      type: type,
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
        .where(
          (s) =>
              !linkedIds.contains(s.subId) &&
              s.status == SubmissionStatus.received,
        )
        .toList();
  }
}