/// Mirrors the Postgres `sub_status` enum: 'pending', 'approved', 'rejected'.
enum SubmissionStatus { pending, approved, rejected }

SubmissionStatus submissionStatusFromString(String value) {
  switch (value) {
    case 'approved':
      return SubmissionStatus.approved;
    case 'rejected':
      return SubmissionStatus.rejected;
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
/// approving a submission, before it's written to donation_item.
class DonationItemInput {
  final String itemId;
  final String itemName;
  final String itemUom;
  double qty;

  DonationItemInput({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    this.qty = 1,
  });
}
