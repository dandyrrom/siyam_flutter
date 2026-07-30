import 'qty_unit.dart';

/// Mirrors the Postgres `donation_type` enum: 'walk_in', 'drop_off'. Purely
/// descriptive -- independent of whether a submission/donor is actually
/// linked (both fields are optional regardless of type).
enum DonationType { walkIn, dropOff }

DonationType donationTypeFromString(String value) {
  switch (value) {
    case 'drop_off':
      return DonationType.dropOff;
    case 'walk_in':
    default:
      return DonationType.walkIn;
  }
}

String donationTypeToString(DonationType type) {
  switch (type) {
    case DonationType.walkIn:
      return 'walk_in';
    case DonationType.dropOff:
      return 'drop_off';
  }
}

/// Mirrors the Postgres `submission_status` enum: 'pending', 'approved',
/// 'rejected', 'received', 'stocked'. Flow: pending -> approved (staff
/// review) -> received (staff confirms items physically arrived) ->
/// stocked (Stock In creates the donation/donation_item rows); rejected is
/// a terminal state reachable only from pending.
enum SubmissionStatus { pending, approved, rejected, received, stocked }

SubmissionStatus submissionStatusFromString(String value) {
  switch (value) {
    case 'approved':
      return SubmissionStatus.approved;
    case 'rejected':
      return SubmissionStatus.rejected;
    case 'received':
      return SubmissionStatus.received;
    case 'stocked':
      return SubmissionStatus.stocked;
    case 'pending':
    default:
      return SubmissionStatus.pending;
  }
}

String submissionStatusToString(SubmissionStatus status) => status.name;

/// Mirrors a row in public.submission -- a donor's request to donate,
/// before staff records what was actually received.
class DonationSubmission {
  final String subId;
  final String donorId;
  final String donorName;
  final String? updatedByUserId;
  final String? updatedByName;
  final SubmissionStatus status;
  final DateTime? schedDate;
  final DateTime dateSub;
  final DateTime? dateReceived;
  final String? proofImg;
  final String? notes;

  const DonationSubmission({
    required this.subId,
    required this.donorId,
    required this.donorName,
    this.updatedByUserId,
    this.updatedByName,
    required this.status,
    this.schedDate,
    required this.dateSub,
    this.dateReceived,
    this.proofImg,
    this.notes,
  });
}

/// A single item received as part of a donation (joined public.donation_item
/// with public.item for its name/unit).
class DonationLineItem {
  final String itemId;
  final String itemName;
  final String itemUom;
  final double qty;

  const DonationLineItem({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    required this.qty,
  });
}

/// Form-side input for one row in the "items received" list while
/// approving a submission, before it's written to donation_item. [qty] is
/// in [qtyUnit] terms -- see [OrderItemInput] (the purchase-side
/// equivalent) for why donations can also arrive by package_unit.
class DonationItemInput {
  final String itemId;
  final String itemName;
  final String itemUom;
  double qty;
  QtyUnit qtyUnit;
  DateTime? expiryDate;

  DonationItemInput({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    this.qty = 1,
    this.qtyUnit = QtyUnit.purchaseUnit,
    this.expiryDate,
  });
}
