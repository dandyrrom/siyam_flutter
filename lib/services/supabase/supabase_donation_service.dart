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
  final SupabaseClient _client =
      Supabase.instance.client;

  final InventoryService _inventoryService =
      InventoryService();

  double _d(
    dynamic value,
  ) =>
      value == null
          ? 0
          : (value as num).toDouble();

  Future<Map<String, String>> _userNameMap() async {
    final rows =
        await _client
            .from('users')
            .select(
              'id, fname, lname',
            );

    return {
      for (final row in rows)
        row['id'] as String:
            '${(row['fname'] as String?) ?? ''} '
                    '${(row['lname'] as String?) ?? ''}'
                .trim(),
    };
  }

  Future<Map<String, String>> _unitAbbrMap() async {
    final rows =
        await _client
            .from('units')
            .select(
              'id, abbr_name',
            );

    return {
      for (final row in rows)
        row['id'] as String:
            (row['abbr_name'] as String?) ??
                '',
    };
  }

  static const String _subColumns =
      'id, donorid, updatedby, status, drop_off_sched, datesubmitted, '
      'date_received, proof_img, notes';

  DonationSubmission _mapSubmission(
    Map<String, dynamic> row,
    Map<String, String> users,
  ) {
    final updatedBy =
        row['updatedby'] as String?;

    final sched =
        row['drop_off_sched'] as String?;

    final received =
        row['date_received'] as String?;

    return DonationSubmission(
      subId:
          row['id'] as String,
      donorId:
          row['donorid'] as String,
      donorName:
          users[row['donorid']] ??
          'Unknown donor',
      updatedByUserId:
          updatedBy,
      updatedByName:
          updatedBy == null
              ? null
              : users[updatedBy],
      status:
          submissionStatusFromString(
        (row['status'] as String?) ??
            'pending',
      ),
      schedDate:
          sched == null
              ? null
              : DateTime.parse(
                  sched,
                ),
      dateSub:
          DateTime.parse(
        row['datesubmitted'] as String,
      ),
      dateReceived:
          received == null
              ? null
              : DateTime.parse(
                  received,
                ),
      proofImg:
          row['proof_img'] as String?,
      notes:
          row['notes'] as String?,
    );
  }

  @override
  Future<List<DonationSubmission>> fetchSubmissions({
    String? donorId,
  }) async {
    final users =
        await _userNameMap();

    var query =
        _client
            .from('submission')
            .select(
              _subColumns,
            );

    if (donorId != null) {
      query =
          query.eq(
        'donorid',
        donorId,
      );
    }

    final rows =
        await query.order(
      'datesubmitted',
      ascending:
          false,
    );

    return rows
        .map(
          (row) =>
              _mapSubmission(
            row,
            users,
          ),
        )
        .toList();
  }

  @override
  Future<DonationSubmission?> fetchSubmission(
    String subId,
  ) async {
    final row =
        await _client
            .from(
              'submission',
            )
            .select(
              _subColumns,
            )
            .eq(
              'id',
              subId,
            )
            .maybeSingle();

    if (row == null) {
      return null;
    }

    final users =
        await _userNameMap();

    return _mapSubmission(
      row,
      users,
    );
  }

  @override
  Future<DonationSubmission> createSubmission({
    required String donorId,
    DateTime? schedDate,
    String? proofImg,
    String? notes,
  }) async {
    final insert =
        <String, dynamic>{
      'donorid':
          donorId,
      'status':
          'pending',
      'proof_img':
          proofImg,
      'notes':
          notes,
    };

    if (schedDate != null) {
      insert['drop_off_sched'] =
          schedDate
              .toUtc()
              .toIso8601String();
    }

    final row =
        await _client
            .from(
              'submission',
            )
            .insert(
              insert,
            )
            .select(
              _subColumns,
            )
            .single();

    final users =
        await _userNameMap();

    DataChangeBus.instance.ping();

    return _mapSubmission(
      row,
      users,
    );
  }

  @override
  Future<void> updateSubmissionStatus({
    required String subId,
    required SubmissionStatus status,
    required String updatedByUserId,
  }) async {
    await _client
        .from(
          'submission',
        )
        .update({
          'status':
              submissionStatusToString(
            status,
          ),
          'updatedby':
              updatedByUserId,
        })
        .eq(
          'id',
          subId,
        );

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

  /// Creates the donation and its donation_item rows.
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
    final actualReceivedDate =
        receivedDate ??
        DateTime.now();

    final insert =
        <String, dynamic>{
      'type':
          donationTypeToString(
        type,
      ),
      'donorid':
          donorId,
      'donor_name':
          donorName,
      'subid':
          subId,
      'receivedby':
          receivedBy,
      'recordedby':
          recordedByUserId,
      'receiveddate':
          actualReceivedDate
              .toUtc()
              .toIso8601String(),
    };

    final donation =
        await _client
            .from(
              'donation',
            )
            .insert(
              insert,
            )
            .select(
              'id',
            )
            .single();

    final donationId =
        donation['id'] as String;

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

      final batchQty =
          packageQuantity == null
              ? item.qty
              : item.qtyUnit ==
                      QtyUnit.packageUnit
                  ? item.qty
                  : item.qty *
                      packageQuantity;

      final donationItem =
          await _client
              .from(
                'donation_item',
              )
              .insert({
                'dntid':
                    donationId,
                'itemid':
                    item.itemId,
                'qty':
                    item.qty,
                'qty_unit':
                    qtyUnitToString(
                  item.qtyUnit,
                ),
              })
              .select(
                'donationitemid',
              )
              .single();

      final donationItemId =
          donationItem['donationitemid']
              as String;

      final batch =
          await _client
              .from(
                'inventory_batch',
              )
              .insert({
                'itemid':
                    item.itemId,
                'purchaseitemid':
                    null,
                'donationitemid':
                    donationItemId,
                'batchcode':
                    'DON-${donationItemId.substring(0, 8).toUpperCase()}',
                'receiveddate':
                    actualReceivedDate
                        .toUtc()
                        .toIso8601String(),
                'expirydate':
                    item.expiryDate
                        ?.toIso8601String()
                        .split('T')
                        .first,
                'qtyreceived':
                    batchQty,
                'qtyavailable':
                    batchQty,
                'qtyunit':
                    qtyUnitToString(
                  packageQuantity == null
                      ? QtyUnit.purchaseUnit
                      : QtyUnit.packageUnit,
                ),
                'unitcost':
                    null,
                'status':
                    'ACTIVE',
                'createdby':
                    recordedByUserId,
              })
              .select(
                'inventorybatchid',
              )
              .single();

      final inventoryBatchId =
          batch['inventorybatchid']
              as String;

      await _client
          .from(
            'batch_transaction_log',
          )
          .insert({
            'inventorybatchid':
                inventoryBatchId,
            'treatmentitemid':
                null,
            'stockoutid':
                null,
            'txntype':
                'RECEIVE',
            'qtychange':
                batchQty,
            'qtyunit':
                qtyUnitToString(
              packageQuantity == null
                  ? QtyUnit.purchaseUnit
                  : QtyUnit.packageUnit,
            ),
            'txndate':
                actualReceivedDate
                    .toUtc()
                    .toIso8601String(),
            'performedby':
                recordedByUserId,
            'notes':
                'Stock received from donation $donationId',
          });

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
    await _client
        .from(
          'submission',
        )
        .update({
          'status':
              'stocked',
          'updatedby':
              updatedByUserId,
        })
        .eq(
          'id',
          subId,
        );

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
    await _client
        .from(
          'submission',
        )
        .update({
          'date_received':
              DateTime.now()
                  .toUtc()
                  .toIso8601String(),
          'status':
              'received',
        })
        .eq(
          'id',
          subId,
        );

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
    final rows =
        await _client
            .from(
              'donation',
            )
            .select(
              'receiveddate',
            );

    return rows
        .map(
          (row) =>
              DateTime.parse(
            row['receiveddate']
                as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<DonationLineItem>> fetchReceivedItems(
    String subId,
  ) async {
    final donation =
        await _client
            .from(
              'donation',
            )
            .select(
              'id',
            )
            .eq(
              'subid',
              subId,
            )
            .maybeSingle();

    if (donation == null) {
      return [];
    }

    final units =
        await _unitAbbrMap();

    final rows =
        await _client
            .from(
              'donation_item',
            )
            .select(
              'itemid, qty, item(name, purchase_unit)',
            )
            .eq(
              'dntid',
              donation['id']
                  as String,
            );

    return rows.map(
      (row) {
        final item =
            row['item']
                as Map<String, dynamic>?;

        final purchaseUnit =
            item?['purchase_unit']
                as String?;

        return DonationLineItem(
          itemId:
              row['itemid'] as String,
          itemName:
              item?['name'] as String? ??
              'Unknown item',
          itemUom:
              purchaseUnit == null
                  ? ''
                  : units[purchaseUnit] ??
                      '',
          qty:
              _d(
            row['qty'],
          ),
        );
      },
    ).toList();
  }

  @override
  Future<List<DonationSubmission>>
      fetchLinkableSubmissions() async {
    final subs =
        await fetchSubmissions();

    final donationRows =
        await _client
            .from(
              'donation',
            )
            .select(
              'subid',
            );

    final linkedIds =
        donationRows
            .map(
              (row) =>
                  row['subid']
                      as String?,
            )
            .whereType<String>()
            .toSet();

    return subs
        .where(
          (submission) =>
              !linkedIds.contains(
                submission.subId,
              ) &&
              submission.status ==
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
        DateTime.utc(
      month.year,
      month.month,
      1,
    );

    final end =
        DateTime.utc(
      month.year,
      month.month + 1,
      1,
    );

    // donation.receiveddate is the stock-in date used when the donation row,
    // inventory batches, and RECEIVE transactions are created.
    final donationRows =
        await _client
            .from(
              'donation',
            )
            .select(
              'id, donorid, donor_name, receiveddate',
            )
            .gte(
              'receiveddate',
              start.toIso8601String(),
            )
            .lt(
              'receiveddate',
              end.toIso8601String(),
            )
            .order(
              'receiveddate',
            );

    if (donationRows.isEmpty) {
      return MonthlyDonorSummary(
        month:
            DateTime(
          month.year,
          month.month,
          1,
        ),
        donorNames:
            const [],
        donationCount:
            0,
        itemsDonated:
            0,
      );
    }

    final users =
        await _userNameMap();

    final donorNames =
        <String>{};

    final donationIds =
        <String>[];

    for (final row
        in donationRows) {
      final donationId =
          row['id'] as String;

      donationIds.add(
        donationId,
      );

      final donorId =
          row['donorid'] as String?;

      final directName =
          row['donor_name'] as String?;

      final name =
          donorId != null
              ? users[donorId]
              : directName;

      final cleaned =
          name?.trim() ?? '';

      if (cleaned.isNotEmpty &&
          cleaned != 'Unknown donor') {
        donorNames.add(
          cleaned,
        );
      }
    }

    var donatedQty =
        0.0;

    // Keeping this simple and compatible with the current schema.
    // Only donation_item rows belonging to donations received this month
    // contribute to the monthly donated quantity.
    for (final donationId
        in donationIds) {
      final itemRows =
          await _client
              .from(
                'donation_item',
              )
              .select(
                'qty',
              )
              .eq(
                'dntid',
                donationId,
              );

      for (final itemRow
          in itemRows) {
        donatedQty +=
            _d(
          itemRow['qty'],
        );
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
          DateTime(
        month.year,
        month.month,
        1,
      ),
      donorNames:
          sortedNames,
      donationCount:
          donationRows.length,
      itemsDonated:
          donatedQty.round(),
    );
  }
}