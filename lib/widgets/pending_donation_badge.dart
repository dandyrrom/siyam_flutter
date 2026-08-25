import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/donation.dart';
import '../services/donation_service.dart';
import '../state/data_bus.dart';

// =============================================================================
// PENDING DONATION BADGE
// =============================================================================
//
// Small, isolated badge used by both desktop and mobile navigation.
//
// The badge counts ONLY SubmissionStatus.pending because those are the donor
// submissions still waiting for Manager review. Opening the Donations page does
// not clear the badge. The count disappears only when the submissions leave the
// pending state (for example, after approval or rejection).
//
// This widget owns its own refresh state so the entire sidebar/drawer does not
// need to rebuild when only the pending count changes.
// =============================================================================

class PendingDonationBadge extends StatefulWidget {
  final bool compact;

  const PendingDonationBadge({
    super.key,
    this.compact = false,
  });

  @override
  State<PendingDonationBadge> createState() =>
      _PendingDonationBadgeState();
}

class _PendingDonationBadgeState
    extends State<PendingDonationBadge>
    with DataBusRefreshMixin<PendingDonationBadge> {
  final DonationService _donationService =
      DonationService();

  int _count = 0;
  int _requestId = 0;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        _refresh();

        // DataChangeBus handles same-session changes immediately. The timer is
        // only a lightweight fallback for submissions created from a different
        // donor browser/device while the Manager remains signed in.
        _refreshTimer = Timer.periodic(
          const Duration(seconds: 30),
          (_) => _refresh(),
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void onExternalDataChanged() {
    _refresh();
  }

  Future<void> _refresh() async {
    final requestId = ++_requestId;

    try {
      final submissions =
          await _donationService.fetchSubmissions();

      if (!mounted || requestId != _requestId) {
        return;
      }

      final nextCount = submissions
          .where(
            (submission) =>
                submission.status ==
                SubmissionStatus.pending,
          )
          .length;

      if (nextCount == _count) {
        return;
      }

      setState(() {
        _count = nextCount;
      });
    } catch (_) {
      // Navigation must remain usable even if the badge cannot refresh.
      // Keep the last successfully loaded count.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_count <= 0) {
      return const SizedBox.shrink();
    }

    final label = _count > 99
        ? '99+'
        : '$_count';

    if (widget.compact) {
      return Container(
        constraints: const BoxConstraints(
          minWidth: 15,
          minHeight: 15,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 3,
        ),
        decoration: BoxDecoration(
          color: AppColors.destructive,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.sidebar,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        minWidth: 20,
        minHeight: 20,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.destructive,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}
