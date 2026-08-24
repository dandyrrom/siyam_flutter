import '../models/donation.dart';
import '../models/donation_impact.dart';
import 'donation_service.dart';
import 'impact_service.dart';

// =============================================================================
// DONOR NOTIFICATIONS
// =============================================================================
//
// Donor notifications are derived from data SIYAM already stores.
//
// No notification table is required for this revision:
//
// - Donation Approved:
//   derived from submission status. A submission that is already received or
//   stocked must also have passed through Approved, so the update remains
//   visible after the workflow moves forward.
//
// - Donation Received:
//   derived from submission status Received / Stocked. `dateReceived` is the
//   exact date Staff confirmed that the physical items arrived.
//
// - Donation Impact:
//   derived from actual treatment transactions attributed to this donor's
//   donated inventory batches by ImpactService.
//
// This keeps donor notifications separate from Manager/Staff inventory alerts.
// =============================================================================

enum DonorNotificationKind {
  approved,
  received,
  impact,
}

extension DonorNotificationKindMeta on DonorNotificationKind {
  String get title => switch (this) {
        DonorNotificationKind.approved => 'Donation Approved',
        DonorNotificationKind.received => 'Donation Received',
        DonorNotificationKind.impact => 'Donation Impact',
      };

  String get message => switch (this) {
        DonorNotificationKind.approved =>
          'Your submitted donation was approved.',
        DonorNotificationKind.received =>
          'DAS has recorded the supplies you donated.',
        DonorNotificationKind.impact =>
          'Some of your donated supplies were used for animal care.',
      };

  String get route => switch (this) {
        DonorNotificationKind.approved => '/donation-history',
        DonorNotificationKind.received => '/donation-history',
        DonorNotificationKind.impact => '/impacts',
      };

  int get sortPriority => switch (this) {
        DonorNotificationKind.impact => 3,
        DonorNotificationKind.received => 2,
        DonorNotificationKind.approved => 1,
      };
}

class DonorNotification {
  final String id;
  final DonorNotificationKind kind;

  /// Used only for ordering notifications.
  ///
  /// Approval currently has no dedicated timestamp in public.submission, so
  /// its sort date uses the best stable date already available. The UI does
  /// not display a fabricated approval date.
  final DateTime sortDate;

  /// Exact date that may safely be shown to the donor.
  ///
  /// Approval intentionally leaves this null because SIYAM does not currently
  /// persist the exact approval timestamp.
  final DateTime? displayDate;

  const DonorNotification({
    required this.id,
    required this.kind,
    required this.sortDate,
    this.displayDate,
  });

  String get title => kind.title;
  String get message => kind.message;
  String get route => kind.route;
}

class DonorNotificationService {
  final DonationService _donationService =
      DonationService();

  final ImpactService _impactService =
      ImpactService();

  Future<List<DonorNotification>> fetchForDonor(
    String donorId,
  ) async {
    // Start both reads together.
    final submissionsFuture =
        _donationService.fetchSubmissions(
      donorId: donorId,
    );

    final impactFuture =
        _impactService.fetchDonorImpact(
      donorId,
    );

    final submissions =
        await submissionsFuture;

    final impactLines =
        await impactFuture;

    final notifications =
        <DonorNotification>[];

    // =========================================================================
    // DONATION STATUS UPDATES
    // =========================================================================

    for (final submission in submissions) {
      final status =
          submission.status;

      final hasBeenApproved =
          status == SubmissionStatus.approved ||
              status == SubmissionStatus.received ||
              status == SubmissionStatus.stocked;

      if (hasBeenApproved) {
        // public.submission currently has no approval timestamp.
        //
        // If the donation has already been physically received, dateReceived
        // provides a stable upper-bound sort position. Otherwise dateSub is
        // used. The donor UI intentionally does not display this as an approval
        // date.
        notifications.add(
          DonorNotification(
            id: 'approved:${submission.subId}',
            kind:
                DonorNotificationKind.approved,
            sortDate:
                submission.dateReceived ??
                    submission.dateSub,
          ),
        );
      }

      final hasBeenReceived =
          status == SubmissionStatus.received ||
              status == SubmissionStatus.stocked;

      if (hasBeenReceived) {
        final receivedDate =
            submission.dateReceived ??
                submission.dateSub;

        notifications.add(
          DonorNotification(
            id: 'received:${submission.subId}',
            kind:
                DonorNotificationKind.received,
            sortDate:
                receivedDate,
            displayDate:
                submission.dateReceived,
          ),
        );
      }
    }

    // =========================================================================
    // DONATION IMPACT UPDATES
    // =========================================================================
    //
    // One treatment can consume more than one donated item from the same donor.
    // The donor should receive one impact update for that treatment, not several
    // duplicate notifications.
    // =========================================================================

    final seenTreatmentKeys =
        <String>{};

    for (final line in impactLines) {
      for (final contribution
          in line.contributions) {
        if (contribution.kind !=
            ImpactEventKind.treatment) {
          continue;
        }

        final key =
            contribution.treatmentId ??
                '${contribution.date.toUtc().toIso8601String()}:${contribution.petId ?? line.itemId}';

        if (!seenTreatmentKeys.add(key)) {
          continue;
        }

        notifications.add(
          DonorNotification(
            id: 'impact:$key',
            kind:
                DonorNotificationKind.impact,
            sortDate:
                contribution.date,
            displayDate:
                contribution.date,
          ),
        );
      }
    }

    notifications.sort((a, b) {
      final dateCompare =
          b.sortDate.compareTo(
        a.sortDate,
      );

      if (dateCompare != 0) {
        return dateCompare;
      }

      return b.kind.sortPriority.compareTo(
        a.kind.sortPriority,
      );
    });

    return notifications;
  }
}
