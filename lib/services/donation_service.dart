import '../mock/mock_database.dart';
import '../models/donation.dart';
import '../models/qty_unit.dart';
import '../state/data_bus.dart';
import 'backend.dart';
import 'inventory_service.dart';
import 'supabase/supabase_donation_service.dart';

// =============================================================================
// MONTHLY DONOR SUMMARY
// =============================================================================

class MonthlyDonorSummary {
  final DateTime month;

  /// Unique donor names for donations stocked during this month.
  final List<String> donorNames;

  /// Number of completed donation records during this month.
  final int donationCount;

  /// Total donated quantity recorded in donation_item during this month.
  final int itemsDonated;

  const MonthlyDonorSummary({
    required this.month,
    required this.donorNames,
    required this.donationCount,
    required this.itemsDonated,
  });

  int get donorCount => donorNames.length;
}

/// Data-access interface for submissions and donations. The factory resolves
/// to the mock or Supabase implementation based on [kUseMock], chosen at build
/// time.
abstract interface class DonationService {
  factory DonationService() =>
      kUseMock ? MockDonationService() : SupabaseDonationService();

  Future<List<DonationSubmission>> fetchSubmissions({
    String? donorId,
  });

  Future<DonationSubmission?> fetchSubmission(
    String subId,
  );

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
  Future<void> markSubmissionReceived({
    required String subId,
  });

  /// [type] is purely descriptive (walk_in/drop_off) and doesn't constrain
  /// [donorId]/[subId]/[donorName] -- all remain independently optional.
  ///
  /// [donorId] is only set when linking a submission or when staff manually
  /// link one. Otherwise [donorName] carries a free-text name.
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

  Future<List<DonationLineItem>> fetchReceivedItems(
    String subId,
  );

  Future<List<DonationSubmission>> fetchLinkableSubmissions();

  /// Returns the donors and donation totals for donations that were stocked
  /// into inventory during the selected calendar month.
  Future<MonthlyDonorSummary> fetchMonthlyDonorSummary(
    DateTime month,
  );
}

// =============================================================================
// MOCK DONATION SERVICE
// =============================================================================

class MockDonationService implements DonationService {
  final MockDatabase _db = MockDatabase.instance;

  final InventoryService _inventoryService =
      MockInventoryService();

  String? _userName(
    String? userId,
  ) {
    if (userId == null) {
      return null;
    }

    final user = firstWhereOrNull(
      _db.users,
      (u) => u.userId == userId,
    );

    return user?.fullName;
  }

  DonationSubmission _toDonationSubmission(
    SubmissionRow row,
  ) {
    return DonationSubmission(
      subId: row.id,
      donorId: row.donorId,
      donorName:
          _userName(row.donorId) ??
          'Unknown donor',
      updatedByUserId:
          row.updatedByUserId,
      updatedByName:
          _userName(
            row.updatedByUserId,
          ),
      status:
          submissionStatusFromString(
        row.status,
      ),
      schedDate:
          row.schedDate,
      dateSub:
          row.dateSub,
      dateReceived:
          row.dateReceived,
      proofImg:
          row.proofImg,
      notes:
          row.notes,
    );
  }

  @override
  Future<List<DonationSubmission>> fetchSubmissions({
    String? donorId,
  }) async {
    final rows = donorId == null
        ? _db.submissions
        : _db.submissions.where(
            (s) =>
                s.donorId == donorId,
          );

    final list =
        rows.map(_toDonationSubmission).toList();

    list.sort(
      (a, b) =>
          b.dateSub.compareTo(
        a.dateSub,
      ),
    );

    return list;
  }

  @override
  Future<DonationSubmission?> fetchSubmission(
    String subId,
  ) async {
    final row = firstWhereOrNull(
      _db.submissions,
      (s) => s.id == subId,
    );

    return row == null
        ? null
        : _toDonationSubmission(
            row,
          );
  }

  @override
  Future<DonationSubmission> createSubmission({
    required String donorId,
    DateTime? schedDate,
    String? proofImg,
    String? notes,
  }) async {
    final row = SubmissionRow(
      id:
          newMockId(
        'submission',
      ),
      donorId:
          donorId,
      status:
          'pending',
      schedDate:
          schedDate,
      dateSub:
          DateTime.now(),
      proofImg:
          proofImg,
      notes:
          notes,
    );

    _db.submissions.add(
      row,
    );

    DataChangeBus.instance.ping();

    return _toDonationSubmission(
      row,
    );
  }

  @override
  Future<void> updateSubmissionStatus({
    required String subId,
    required SubmissionStatus status,
    required String updatedByUserId,
  }) async {
    final row = firstWhereOrNull(
      _db.submissions,
      (s) => s.id == subId,
    );

    if (row == null) {
      throw Exception(
        'Submission not found',
      );
    }

    row.status =
        submissionStatusToString(
      status,
    );

    row.updatedByUserId =
        updatedByUserId;

    DataChangeBus.instance.ping();
  }

  @override
  Future<void> rejectSubmission({
    required String subId,
    required String updatedByUserId,
  }) {
    return updateSubmissionStatus(
      subId:
          subId,
      status:
          SubmissionStatus.rejected,
      updatedByUserId:
          updatedByUserId,
    );
  }

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
    final donationRow =
        DonationRow(
      id:
          newMockId(
        'donation',
      ),
      type:
          donationTypeToString(
        type,
      ),
      donorId:
          donorId,
      donorName:
          donorName,
      subId:
          subId,
      receivedBy:
          receivedBy,
      receivedDate:
          receivedDate ??
          DateTime.now(),
      recordedByUserId:
          recordedByUserId,
      recordedDate:
          DateTime.now(),
    );

    _db.donations.add(
      donationRow,
    );

    for (final item in items) {
      if (item.qty <= 0) {
        continue;
      }

      final invItem =
          await _inventoryService.fetchItem(
        item.itemId,
      );

      final packageQuantity =
          invItem?.packageQuantity;

      final qtyRemaining =
          packageQuantity == null
              ? item.qty
              : item.qtyUnit ==
                      QtyUnit.packageUnit
                  ? item.qty
                  : item.qty *
                      packageQuantity;

      _db.donationItems.add(
        DonationItemRow(
          donId:
              donationRow.id,
          itemId:
              item.itemId,
          qty:
              item.qty,
          qtyUnit:
              item.qtyUnit,
          expiryDate:
              item.expiryDate,
          qtyRemaining:
              qtyRemaining,
        ),
      );

      await _inventoryService.stockIn(
        itemId:
            item.itemId,
        qty:
            item.qty,
        qtyUnit:
            item.qtyUnit,
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
    final row = firstWhereOrNull(
      _db.submissions,
      (s) => s.id == subId,
    );

    if (row == null) {
      throw Exception(
        'Submission not found',
      );
    }

    row.status =
        'stocked';

    row.updatedByUserId =
        updatedByUserId;

    DataChangeBus.instance.ping();

    await _createDonationAndItems(
      subId:
          subId,
      donorId:
          donorId,
      recordedByUserId:
          updatedByUserId,
      receivedBy:
          receivedBy,
      items:
          items,
      type:
          type,
      receivedDate:
          receivedDate,
    );
  }

  @override
  Future<void> markSubmissionReceived({
    required String subId,
  }) async {
    final row = firstWhereOrNull(
      _db.submissions,
      (s) => s.id == subId,
    );

    if (row == null) {
      throw Exception(
        'Submission not found',
      );
    }

    row.dateReceived =
        DateTime.now();

    row.status =
        'received';

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
      donorId:
          donorId,
      donorName:
          donorName,
      recordedByUserId:
          recordedByUserId,
      receivedBy:
          receivedBy,
      items:
          items,
      type:
          type,
      receivedDate:
          receivedDate,
    );
  }

  @override
  Future<List<DateTime>> fetchDonationDates() async {
    return _db.donations
        .map(
          (d) =>
              d.receivedDate,
        )
        .toList();
  }

  @override
  Future<List<DonationLineItem>> fetchReceivedItems(
    String subId,
  ) async {
    final donation =
        firstWhereOrNull(
      _db.donations,
      (d) => d.subId == subId,
    );

    if (donation == null) {
      return [];
    }

    final rows =
        _db.donationItems.where(
      (di) =>
          di.donId == donation.id,
    );

    final result =
        <DonationLineItem>[];

    for (final row in rows) {
      final item =
          await _inventoryService.fetchItem(
        row.itemId,
      );

      result.add(
        DonationLineItem(
          itemId:
              row.itemId,
          itemName:
              item?.itemName ??
              'Unknown item',
          itemUom:
              item?.itemUom ??
              '',
          qty:
              row.qty,
        ),
      );
    }

    return result;
  }

  @override
  Future<List<DonationSubmission>>
      fetchLinkableSubmissions() async {
    final subs =
        await fetchSubmissions();

    final linkedIds =
        _db.donations
            .map(
              (d) => d.subId,
            )
            .whereType<String>()
            .toSet();

    return subs
        .where(
          (s) =>
              !linkedIds.contains(
                s.subId,
              ) &&
              s.status ==
                  SubmissionStatus.received,
        )
        .toList();
  }

  // ==========================================================================
  // MONTHLY DONOR SUMMARY
  // ==========================================================================

  @override
  Future<MonthlyDonorSummary> fetchMonthlyDonorSummary(
    DateTime month,
  ) async {
    final start =
        DateTime(
      month.year,
      month.month,
      1,
    );

    final end =
        DateTime(
      month.year,
      month.month + 1,
      1,
    );

    final donations =
        _db.donations
            .where(
              (donation) =>
                  !donation.receivedDate
                      .isBefore(start) &&
                  donation.receivedDate
                      .isBefore(end),
            )
            .toList();

    final donorNames =
        <String>{};

    var itemsDonated =
        0.0;

    for (final donation in donations) {
      final name =
          donation.donorId != null
              ? _userName(
                  donation.donorId,
                )
              : donation.donorName;

      final cleaned =
          name?.trim() ?? '';

      if (cleaned.isNotEmpty &&
          cleaned != 'Unknown donor') {
        donorNames.add(
          cleaned,
        );
      }

      for (final item
          in _db.donationItems) {
        if (item.donId ==
            donation.id) {
          itemsDonated +=
              item.qty;
        }
      }
    }

    final sortedNames =
        donorNames.toList()
          ..sort(
            (a, b) =>
                a.toLowerCase().compareTo(
              b.toLowerCase(),
            ),
          );

    return MonthlyDonorSummary(
      month:
          start,
      donorNames:
          sortedNames,
      donationCount:
          donations.length,
      itemsDonated:
          itemsDonated.round(),
    );
  }
}