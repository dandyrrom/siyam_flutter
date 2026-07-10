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
///
/// Note: there's no monetary `value` or itemized "items summary" column
/// on this table (donors don't pick items up front) -- items are only
/// recorded once staff approves and logs what came in via
/// public.donation / public.donation_item.
class DonationSubmission {
  final String subId;
  final String donorId;
  final String donorName;
  final String? revById;
  final String? reviewerName;
  final SubmissionStatus status;
  final DateTime? schedDate;
  final DateTime dateSub;
  final String? proofImg;

  const DonationSubmission({
    required this.subId,
    required this.donorId,
    required this.donorName,
    this.revById,
    this.reviewerName,
    required this.status,
    this.schedDate,
    required this.dateSub,
    this.proofImg,
  });

  factory DonationSubmission.fromMap(
    Map<String, dynamic> map,
    Map<String, String> userNames,
  ) {
    final donorId = map['donorid'] as String;
    final revById = map['revby'] as String?;
    return DonationSubmission(
      subId: map['subid'] as String,
      donorId: donorId,
      donorName: userNames[donorId] ?? 'Unknown donor',
      revById: revById,
      reviewerName: revById == null ? null : userNames[revById],
      status: submissionStatusFromString(map['status'] as String? ?? 'pending'),
      schedDate: map['scheddate'] == null
          ? null
          : DateTime.tryParse(map['scheddate'] as String),
      dateSub: DateTime.tryParse(map['datesub'] as String? ?? '') ?? DateTime.now(),
      proofImg: map['proofimg'] as String?,
    );
  }
}

/// A single item received as part of a donation (joined
/// public.donation_item with public.item for its name/unit).
class DonationLineItem {
  final String itemId;
  final String itemName;
  final String itemUom;
  final int qty;

  const DonationLineItem({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    required this.qty,
  });

  factory DonationLineItem.fromMap(Map<String, dynamic> map) {
    final item = map['item'] as Map<String, dynamic>? ?? const {};
    return DonationLineItem(
      itemId: item['itemid'] as String? ?? '',
      itemName: item['name'] as String? ?? 'Unknown item',
      itemUom: item['uom'] as String? ?? '',
      qty: (map['qty'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Form-side input for one row in the "items received" list while
/// approving a submission, before it's written to donation_item.
class DonationItemInput {
  final String itemId;
  final String itemName;
  final String itemUom;
  int qty;

  DonationItemInput({
    required this.itemId,
    required this.itemName,
    required this.itemUom,
    this.qty = 1,
  });
}
