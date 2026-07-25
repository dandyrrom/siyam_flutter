import '../mock/mock_database.dart';
import '../models/donation.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'inventory_service.dart';
import 'supabase/supabase_donation_service.dart';

/// Data-access interface for submissions and donations. The factory resolves
/// to the mock or Supabase implementation based on [kUseMock], chosen at build
/// time.
abstract interface class DonationService {
  factory DonationService() =>
      kUseMock ? MockDonationService() : SupabaseDonationService();

  Future<List<DonationSubmission>> fetchSubmissions({String? donorId});
  Future<DonationSubmission?> fetchSubmission(String subId);
  Future<DonationSubmission> createSubmission({
    required String donorId,
    DateTime? schedDate,
    String? proofImg,
    String? notes,
  });
  Future<void> updateSubmissionStatus({
    required String subId,
    required SubmissionStatus status,
    required String updatedByUserId,
  });
  Future<void> rejectSubmission({
    required String subId,
    required String updatedByUserId,
  });
  Future<void> approveSubmission({
    required String subId,
    required String donorId,
    required String updatedByUserId,
    required String receivedBy,
    required List<DonationItemInput> items,
    required DonationType type,
    DateTime? receivedDate,
  });
  /// Persists the moment staff confirm a submission's items physically
  /// arrived (the "Items Received" step, before Stock In).
  Future<void> markSubmissionReceived({required String subId});
  /// [type] is purely descriptive (walk_in/drop_off) and doesn't constrain
  /// [donorId]/[subId]/[donorName] -- all remain independently optional.
  /// [donorId] is only set when linking a submission (which always has a
  /// real donor account) or when staff manually link one; otherwise the
  /// donor may be unregistered, so [donorName] carries a free-text name for
  /// documentation only -- see KNOWN_LIMITATIONS.md.
  Future<void> recordDirectDonation({
    String? donorId,
    String? donorName,
    required String recordedByUserId,
    required String receivedBy,
    required List<DonationItemInput> items,
    required DonationType type,
    DateTime? receivedDate,
  });
  Future<List<DateTime>> fetchDonationDates();
  Future<List<DonationLineItem>> fetchReceivedItems(String subId);
  Future<List<DonationSubmission>> fetchLinkableSubmissions();
}

/// In-memory equivalent of the old public.submission / donation /
/// donation_item access layer.
///
/// Approving a submission also creates the donation + donation_item rows
/// and increments stock for each item received, via [InventoryService] --
/// the receiving-side mirror of how [TreatmentService] decrements stock on
/// consumption.
class MockDonationService implements DonationService {
  final MockDatabase _db = MockDatabase.instance;
  final InventoryService _inventoryService = MockInventoryService();

  String? _userName(String? userId) {
    if (userId == null) return null;
    final user = firstWhereOrNull(_db.users, (u) => u.userId == userId);
    return user?.fullName;
  }

  DonationSubmission _toDonationSubmission(SubmissionRow row) {
    return DonationSubmission(
      subId: row.id,
      donorId: row.donorId,
      donorName: _userName(row.donorId) ?? 'Unknown donor',
      updatedByUserId: row.updatedByUserId,
      updatedByName: _userName(row.updatedByUserId),
      status: submissionStatusFromString(row.status),
      schedDate: row.schedDate,
      dateSub: row.dateSub,
      dateReceived: row.dateReceived,
      proofImg: row.proofImg,
      notes: row.notes,
    );
  }

  @override
  Future<List<DonationSubmission>> fetchSubmissions({String? donorId}) async {
    final rows = donorId == null
        ? _db.submissions
        : _db.submissions.where((s) => s.donorId == donorId);
    final list = rows.map(_toDonationSubmission).toList();
    list.sort((a, b) => b.dateSub.compareTo(a.dateSub));
    return list;
  }

  @override
  Future<DonationSubmission?> fetchSubmission(String subId) async {
    final row = firstWhereOrNull(_db.submissions, (s) => s.id == subId);
    return row == null ? null : _toDonationSubmission(row);
  }

  @override
  Future<DonationSubmission> createSubmission({
    required String donorId,
    DateTime? schedDate,
    String? proofImg,
    String? notes,
  }) async {
    final row = SubmissionRow(
      id: newMockId('submission'),
      donorId: donorId,
      status: 'pending',
      schedDate: schedDate,
      dateSub: DateTime.now(),
      proofImg: proofImg,
      notes: notes,
    );
    _db.submissions.add(row);
    DataChangeBus.instance.ping();
    return _toDonationSubmission(row);
  }

  /// Lightweight status change only -- no donation/donation_item rows are
  /// created. Used for Reject, and for Approve when staff isn't recording
  /// received items in the same step (they can stock in later via the Stock
  /// In form's "Link to submission" picker, or immediately via
  /// [approveSubmission]).
  @override
  Future<void> updateSubmissionStatus({
    required String subId,
    required SubmissionStatus status,
    required String updatedByUserId,
  }) async {
    final row = firstWhereOrNull(_db.submissions, (s) => s.id == subId);
    if (row == null) throw Exception('Submission not found');
    row.status = submissionStatusToString(status);
    row.updatedByUserId = updatedByUserId;
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

  /// Creates the donation row (optionally linked to a submission) plus one
  /// donation_item row per item, and increments each item's stock. Shared
  /// by [approveSubmission] (submission-linked, always a real donorId) and
  /// [recordDirectDonation] (donorId only when a submission was linked;
  /// otherwise donorName documents an unregistered donor -- see
  /// KNOWN_LIMITATIONS.md).
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
    final donationRow = DonationRow(
      id: newMockId('donation'),
      type: donationTypeToString(type),
      donorId: donorId,
      donorName: donorName,
      subId: subId,
      receivedBy: receivedBy,
      receivedDate: receivedDate ?? DateTime.now(),
      recordedByUserId: recordedByUserId,
      recordedDate: DateTime.now(),
    );
    _db.donations.add(donationRow);

    for (final item in items) {
      if (item.qty <= 0) continue;
      _db.donationItems.add(DonationItemRow(
        donId: donationRow.id,
        itemId: item.itemId,
        qty: item.qty,
      ));
      await _inventoryService.adjustStock(itemId: item.itemId, delta: item.qty);
    }
    DataChangeBus.instance.ping();
  }

  /// Marks the submission approved and records what was actually received:
  /// creates the donation row linked to it, one donation_item row per item,
  /// and increments each item's stock.
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
    final row = firstWhereOrNull(_db.submissions, (s) => s.id == subId);
    if (row == null) throw Exception('Submission not found');
    row.status = 'stocked';
    row.updatedByUserId = updatedByUserId;
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
  Future<void> markSubmissionReceived({required String subId}) async {
    final row = firstWhereOrNull(_db.submissions, (s) => s.id == subId);
    if (row == null) throw Exception('Submission not found');
    row.dateReceived = DateTime.now();
    row.status = 'received';
    DataChangeBus.instance.ping();
  }

  /// Records a donation directly from the Stock In Item form, not linked to
  /// a prior submission -- donorId/donorName as documented on the interface.
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

  /// Transaction dates for every completed donation -- used to bucket
  /// donation counts by month on the Reports page.
  @override
  Future<List<DateTime>> fetchDonationDates() async {
    return _db.donations.map((d) => d.receivedDate).toList();
  }

  /// Items actually received for an already-approved submission, or an
  /// empty list if it hasn't been approved (no linked donation) yet.
  @override
  Future<List<DonationLineItem>> fetchReceivedItems(String subId) async {
    final donation = firstWhereOrNull(_db.donations, (d) => d.subId == subId);
    if (donation == null) return [];

    final rows = _db.donationItems.where((di) => di.donId == donation.id);
    final result = <DonationLineItem>[];
    for (final row in rows) {
      final item = await _inventoryService.fetchItem(row.itemId);
      result.add(DonationLineItem(
        itemId: row.itemId,
        itemName: item?.itemName ?? 'Unknown item',
        itemUom: item?.itemUom ?? '',
        qty: row.qty,
      ));
    }
    return result;
  }

  /// Submissions that don't yet have a linked donation row -- i.e. a donor
  /// pledge that staff can reconcile against an incoming Stock In entry.
  @override
  Future<List<DonationSubmission>> fetchLinkableSubmissions() async {
    final subs = await fetchSubmissions();
    final linkedIds = _db.donations.map((d) => d.subId).whereType<String>().toSet();
    return subs
        .where((s) =>
            !linkedIds.contains(s.subId) && s.status == SubmissionStatus.received)
        .toList();
  }
}
