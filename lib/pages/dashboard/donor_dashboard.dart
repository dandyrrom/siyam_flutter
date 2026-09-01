import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../models/donation.dart';
import '../../models/donation_impact.dart';
import '../../models/stock_out.dart';
import '../../services/dashboard_service.dart';
import '../../services/donation_service.dart';
import '../../services/impact_service.dart';
import '../../state/auth_state.dart';
import '../../state/data_bus.dart';

// ============================================================================
// DASHBOARD IMAGE
// ============================================================================
//
// Replace this with your actual shelter/animal image.
//
// Make sure the image is declared inside pubspec.yaml.
//
const String _dashboardAnimalImage =
    'assets/donor_dashboard_animals.jpg';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() =>
      _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard>
    with DataBusRefreshMixin<DonorDashboard> {
  // Existing donor dashboard statistics.
  final DashboardService _dashboardService =
      DashboardService();

  // Existing donation service used for recent donation activity.
  final DonationService _donationService =
      DonationService();

  // Existing impact service used for recent donor impact.
  final ImpactService _impactService =
      ImpactService();

  DonorDashboardStats? _stats;

  List<DonationSubmission> _submissions = [];
  List<DonationImpactLine> _impactLines = [];
  List<ReplenishmentAlert> _currentNeeds = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Loads all dashboard information when the donor opens the page.
    _load();
  }

  @override
  void onExternalDataChanged() {
    // Refreshes the dashboard whenever donation/inventory data changes.
    _load(silent: true);
  }

  Future<void> _load({
    bool silent = false,
  }) async {
    final donorId =
        context.read<AuthController>().profile?.userId;

    if (donorId == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Loads the existing dashboard stats, donation history,
      // and donor impact data at the same time.
      final results = await Future.wait<Object?>([
        _dashboardService.fetchDonorStats(
          donorId,
        ),
        _donationService.fetchSubmissions(
          donorId: donorId,
        ),
        _impactService.fetchDonorImpact(
          donorId,
        ),
        _dashboardService
            .fetchReplenishmentAlerts(),
      ]);

      if (!mounted) return;

      setState(() {
        _stats =
            results[0] as DonorDashboardStats;

        _submissions =
            results[1] as List<DonationSubmission>;

        _impactLines =
            results[2] as List<DonationImpactLine>;

        _currentNeeds =
            results[3] as List<ReplenishmentAlert>;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error =
              'Could not load your dashboard: $e';
          _loading = false;
        });
      }
    }
  }

  // Returns donor-friendly status labels.
  (String, Color) _statusMeta(
    SubmissionStatus status,
  ) {
    switch (status) {
      case SubmissionStatus.pending:
        return (
          'Under Review',
          AppColors.warning,
        );

      case SubmissionStatus.approved:
        return (
          'Accepted',
          AppColors.primary,
        );

      case SubmissionStatus.received:
        return (
          'Received by Shelter',
          AppColors.primary,
        );

      case SubmissionStatus.stocked:
        return (
          'Completed',
          AppColors.primary,
        );

      case SubmissionStatus.rejected:
        return (
          'Declined',
          AppColors.destructive,
        );
    }
  }

  // Gets the most recent donation submissions.
  List<DonationSubmission> get _recentSubmissions {
    final list =
        List<DonationSubmission>.from(
      _submissions,
    );

    list.sort(
      (a, b) =>
          b.dateSub.compareTo(a.dateSub),
    );

    return list.take(3).toList();
  }

  // Gets meaningful donor-facing impact events.
  List<_RecentImpactEntry> get _recentImpact {
    final entries =
        <_RecentImpactEntry>[];

    for (final line in _impactLines) {
      for (final contribution
          in line.contributions) {
        final meaningful =
            contribution.kind ==
                    ImpactEventKind.treatment ||
                (contribution.kind ==
                        ImpactEventKind.stockOut &&
                    contribution.stockOutReason ==
                        StockOutReason.adjustment);

        if (!meaningful) continue;

        entries.add(
          _RecentImpactEntry(
            itemName: line.itemName,
            date: contribution.date,
          ),
        );
      }
    }

    entries.sort(
      (a, b) =>
          b.date.compareTo(a.date),
    );

    return entries.take(2).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _DashboardError(
        message: _error!,
        onRetry: _load,
      );
    }

    final lastDonation =
        _stats?.lastDonation;

    final lastDonationLabel =
        lastDonation == null
            ? 'None yet'
            : _formatDate(
                lastDonation,
              );

    final totalDonations =
        _loading
            ? '—'
            : '${_stats?.totalDonations ?? 0}';

    final itemsDonated =
        _loading
            ? '—'
            : '${_stats?.itemsDonated ?? 0}';

    final pendingSubmissions =
        _loading
            ? '—'
            : '${_stats?.pendingSubmissions ?? 0}';

    final recentSubmissions =
        _recentSubmissions;

    final recentImpact =
        _recentImpact;

    final currentNeeds =
        _currentNeeds.take(3).toList();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // ============================================================
        // PAGE HEADER
        // ============================================================
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          'Here\'s what\'s happening with your support.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),

        const SizedBox(height: 22),

        // ============================================================
        // MAIN HERO / SUPPORT CARD
        // ============================================================
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final compact =
                constraints.maxWidth < 760;

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: compact
                  ? _HeroMobileLayout(
                      loading: _loading,
                      totalDonations:
                          totalDonations,
                      itemsDonated:
                          itemsDonated,
                      pendingSubmissions:
                          pendingSubmissions,
                      lastDonation:
                          lastDonationLabel,
                    )
                  : _HeroDesktopLayout(
                      loading: _loading,
                      totalDonations:
                          totalDonations,
                      itemsDonated:
                          itemsDonated,
                      pendingSubmissions:
                          pendingSubmissions,
                      lastDonation:
                          lastDonationLabel,
                    ),
            );
          },
        ),

        const SizedBox(height: 22),

        // ============================================================
        // CURRENT NEEDS + RECENT IMPACT
        // ============================================================
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final compact =
                constraints.maxWidth < 760;

            if (compact) {
              return Column(
                children: [
                  _CurrentNeedsCard(
                    loading: _loading,
                    alerts:
                        currentNeeds,
                  ),

                  const SizedBox(
                    height: 16,
                  ),

                  _RecentImpactCard(
                    loading: _loading,
                    impacts:
                        recentImpact,
                  ),
                ],
              );
            }
return IntrinsicHeight(
  child: Row(
    crossAxisAlignment:
        CrossAxisAlignment.stretch,
    children: [
      Expanded(
        child:
            _CurrentNeedsCard(
          loading: _loading,
          alerts:
              currentNeeds,
        ),
      ),

      const SizedBox(width: 16),

      Expanded(
        child:
            _RecentImpactCard(
          loading: _loading,
          impacts:
              recentImpact,
        ),
      ),
    ],
  ),
);
          },
        ),

        const SizedBox(height: 22),

        // ============================================================
        // RECENT DONATION ACTIVITY
        // ============================================================
        _RecentActivityCard(
          loading: _loading,
          submissions:
              recentSubmissions,
          statusMeta: _statusMeta,
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

// ============================================================================
// HERO DESKTOP
// ============================================================================

class _HeroDesktopLayout
    extends StatelessWidget {
  final bool loading;

  final String totalDonations;
  final String itemsDonated;
  final String pendingSubmissions;
  final String lastDonation;

  const _HeroDesktopLayout({
    required this.loading,
    required this.totalDonations,
    required this.itemsDonated,
    required this.pendingSubmissions,
    required this.lastDonation,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          // ==========================================================
          // LEFT
          // ==========================================================
          Expanded(
            flex: 11,
            child: Padding(
              padding:
                  const EdgeInsets.all(
                26,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Support',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'A quick snapshot of your contributions.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child:
                            _MetricCard(
                          label:
                              'Donations',
                          value:
                              totalDonations,
                          icon: Icons
                              .favorite_outline,
                          accent: AppColors
                              .roleDonor,
                          loading: loading,
                        ),
                      ),

                      const SizedBox(
                          width: 12),

                      Expanded(
                        child:
                            _MetricCard(
                          label:
                              'Items Donated',
                          value:
                              itemsDonated,
                          icon: Icons
                              .inventory_2_outlined,
                          accent:
                              AppColors.primary,
                          loading: loading,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child:
                            _MetricCard(
                          label:
                              'Under Review',
                          value:
                              pendingSubmissions,
                          icon: Icons
                              .schedule_outlined,
                          accent:
                              AppColors.warning,
                          loading: loading,
                        ),
                      ),

                      const SizedBox(
                          width: 12),

                      Expanded(
                        child:
                            _MetricCard(
                          label:
                              'Last Donation',
                          value:
                              lastDonation,
                          icon: Icons
                              .event_outlined,
                          accent: AppColors
                              .roleDonor,
                          loading: loading,
                          compactValue: true,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ==========================================================
          // RIGHT
          // ==========================================================
          const Expanded(
            flex: 9,
            child:
                _AnimalImagePanel(
              height: 390,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HERO MOBILE
// ============================================================================

class _HeroMobileLayout
    extends StatelessWidget {
  final bool loading;

  final String totalDonations;
  final String itemsDonated;
  final String pendingSubmissions;
  final String lastDonation;

  const _HeroMobileLayout({
    required this.loading,
    required this.totalDonations,
    required this.itemsDonated,
    required this.pendingSubmissions,
    required this.lastDonation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _AnimalImagePanel(
          height: 190,
        ),

        Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Your Support',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              const Text(
                'A quick snapshot of your contributions.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors
                      .mutedForeground,
                ),
              ),

              const SizedBox(height: 16),

              LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {
                  final veryNarrow =
                      constraints.maxWidth <
                          340;

                  if (veryNarrow) {
                    return Column(
                      children: [
                        _MetricCard(
                          label:
                              'Donations',
                          value:
                              totalDonations,
                          icon: Icons
                              .favorite_outline,
                          accent: AppColors
                              .roleDonor,
                          loading: loading,
                        ),

                        const SizedBox(
                            height: 10),

                        _MetricCard(
                          label:
                              'Items Donated',
                          value:
                              itemsDonated,
                          icon: Icons
                              .inventory_2_outlined,
                          accent:
                              AppColors.primary,
                          loading: loading,
                        ),

                        const SizedBox(
                            height: 10),

                        _MetricCard(
                          label:
                              'Under Review',
                          value:
                              pendingSubmissions,
                          icon: Icons
                              .schedule_outlined,
                          accent:
                              AppColors.warning,
                          loading: loading,
                        ),

                        const SizedBox(
                            height: 10),

                        _MetricCard(
                          label:
                              'Last Donation',
                          value:
                              lastDonation,
                          icon: Icons
                              .event_outlined,
                          accent: AppColors
                              .roleDonor,
                          loading: loading,
                          compactValue: true,
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child:
                                _MetricCard(
                              label:
                                  'Donations',
                              value:
                                  totalDonations,
                              icon: Icons
                                  .favorite_outline,
                              accent:
                                  AppColors
                                      .roleDonor,
                              loading:
                                  loading,
                              mobile: true,
                            ),
                          ),

                          const SizedBox(
                              width: 10),

                          Expanded(
                            child:
                                _MetricCard(
                              label:
                                  'Items Donated',
                              value:
                                  itemsDonated,
                              icon: Icons
                                  .inventory_2_outlined,
                              accent:
                                  AppColors
                                      .primary,
                              loading:
                                  loading,
                              mobile: true,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                          height: 10),

                      Row(
                        children: [
                          Expanded(
                            child:
                                _MetricCard(
                              label:
                                  'Under Review',
                              value:
                                  pendingSubmissions,
                              icon: Icons
                                  .schedule_outlined,
                              accent:
                                  AppColors
                                      .warning,
                              loading:
                                  loading,
                              mobile: true,
                            ),
                          ),

                          const SizedBox(
                              width: 10),

                          Expanded(
                            child:
                                _MetricCard(
                              label:
                                  'Last Donation',
                              value:
                                  lastDonation,
                              icon: Icons
                                  .event_outlined,
                              accent:
                                  AppColors
                                      .roleDonor,
                              loading:
                                  loading,
                              compactValue:
                                  true,
                              mobile: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// METRIC CARD
// ============================================================================

class _MetricCard
    extends StatefulWidget {
  final String label;
  final String value;

  final IconData icon;
  final Color accent;

  final bool loading;
  final bool compactValue;
  final bool mobile;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.loading,
    this.compactValue = false,
    this.mobile = false,
  });

  @override
  State<_MetricCard> createState() =>
      _MetricCardState();
}

class _MetricCardState
    extends State<_MetricCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovering = false;
        });
      },
      child: AnimatedContainer(
        duration:
            const Duration(
          milliseconds: 140,
        ),
        width: double.infinity,
        padding: EdgeInsets.all(
          widget.mobile ? 13 : 15,
        ),
        decoration: BoxDecoration(
          color: _hovering
              ? widget.accent.withValues(
                  alpha: 0.04,
                )
              : AppColors.card,
          borderRadius:
              BorderRadius.circular(14),
          border: Border.all(
            color: _hovering
                ? widget.accent.withValues(
                    alpha: 0.42,
                  )
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width:
                  widget.mobile ? 36 : 40,
              height:
                  widget.mobile ? 36 : 40,
              decoration: BoxDecoration(
                color: widget.accent
                    .withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(
                  10,
                ),
              ),
              child: Icon(
                widget.icon,
                size:
                    widget.mobile ? 18 : 20,
                color: widget.accent,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  if (widget.loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  else
                    Text(
                      widget.value,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: TextStyle(
                        fontSize:
                            widget.compactValue
                                ? widget.mobile
                                    ? 12.5
                                    : 14
                                : widget.mobile
                                    ? 19
                                    : 22,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            widget.accent,
                      ),
                    ),

                  const SizedBox(height: 2),

                  Text(
                    widget.label,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style: TextStyle(
                      fontSize:
                          widget.mobile
                              ? 11
                              : 12,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CURRENT NEEDS
// ============================================================================
//
// Uses the same live replenishment list as the Staff Dashboard/Ordering flow.
// Only the top three items are shown here, with donor-friendly wording.
// Technical ROP details stay on the Staff/Manager side.
// ============================================================================

class _CurrentNeedsCard
    extends StatelessWidget {
  final bool loading;
  final List<ReplenishmentAlert>
      alerts;

  const _CurrentNeedsCard({
    required this.loading,
    required this.alerts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(16),
        border:
            Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _SectionIcon(
                icon: Icons
                    .priority_high_rounded,
                color:
                    AppColors.warning,
              ),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Currently Needed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if (loading)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 24,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            )
          else if (alerts.isEmpty)
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(
                16,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary
                    .withValues(
                  alpha: 0.045,
                ),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons
                        .check_circle_outline,
                    size: 26,
                    color:
                        AppColors.primary,
                  ),

                  SizedBox(height: 8),

                  Text(
                    'Supply needs are currently covered',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),

                  SizedBox(height: 3),

                  Text(
                    'New priority items will appear here when the shelter needs support.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.8,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                for (var i = 0;
                    i < alerts.length;
                    i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 18,
                    ),

                  _CurrentNeedRow(
                    alert:
                        alerts[i],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _CurrentNeedRow
    extends StatelessWidget {
  final ReplenishmentAlert alert;

  const _CurrentNeedRow({
    required this.alert,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) =
        _needMeta(alert.priority);

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 9,
          height: 9,
          margin:
              const EdgeInsets.only(
            top: 5,
          ),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                alert.itemName,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.8,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                alert.stockQty <= 0
                    ? 'Currently out of stock'
                    : '${_formatQty(alert.stockQty)} ${alert.unitAbbr} remaining',
                style: const TextStyle(
                  fontSize: 11.2,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 10),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: 0.10,
            ),
            borderRadius:
                BorderRadius.circular(
              999,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight:
                  FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

(String, Color) _needMeta(
  ReplenishmentPriority priority,
) {
  switch (priority) {
    case ReplenishmentPriority.critical:
      return (
        'Urgent',
        AppColors.stockOut,
      );

    case ReplenishmentPriority.high:
      return (
        'Running Low',
        AppColors.stockLow,
      );

    case ReplenishmentPriority.medium:
      return (
        'Needed Soon',
        AppColors.stockNeedsRestock,
      );
  }
}

String _formatQty(double value) {
  if (value ==
      value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value
      .toStringAsFixed(2)
      .replaceFirst(
        RegExp(r'0+$'),
        '',
      )
      .replaceFirst(
        RegExp(r'\.$'),
        '',
      );
}

// ============================================================================
// RECENT IMPACT
// ============================================================================

class _RecentImpactCard
    extends StatelessWidget {
  final bool loading;
  final List<_RecentImpactEntry>
      impacts;

  const _RecentImpactCard({
    required this.loading,
    required this.impacts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(16),
        border:
            Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _SectionIcon(
                icon:
                    Icons.favorite_outline,
                color:
                    AppColors.primary,
              ),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Recent Impact',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          if (loading)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 24,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            )
          else if (impacts.isEmpty)
            const _SimpleEmptyState(
              icon:
                  Icons.favorite_border,
              title:
                  'No impact updates yet',
              message:
                  'Updates will appear here when your donated items are put to use.',
            )
          else
            Column(
              children: [
                for (var i = 0;
                    i < impacts.length;
                    i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 22,
                    ),

                  _ImpactPreview(
                    impact:
                        impacts[i],
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ImpactPreview
    extends StatelessWidget {
  final _RecentImpactEntry impact;

  const _ImpactPreview({
    required this.impact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.primary
                .withValues(
              alpha: 0.10,
            ),
            borderRadius:
                BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.favorite,
            size: 17,
            color: AppColors.primary,
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                '${impact.itemName} made an impact',
                style: const TextStyle(
                  fontSize: 12.8,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                'Your donated item was put to use in the shelter.',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors
                      .mutedForeground,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                _formatDate(
                  impact.date,
                ),
                style: const TextStyle(
                  fontSize: 10.8,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// RECENT ACTIVITY
// ============================================================================

class _RecentActivityCard
    extends StatelessWidget {
  final bool loading;

  final List<DonationSubmission>
      submissions;

  final (
    String,
    Color
  ) Function(SubmissionStatus)
      statusMeta;

  const _RecentActivityCard({
    required this.loading,
    required this.submissions,
    required this.statusMeta,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(16),
        border:
            Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Padding(
            padding:
                EdgeInsets.fromLTRB(
              18,
              17,
              18,
              14,
            ),
            child: Row(
              children: [
                _SectionIcon(
                  icon: Icons
                      .history_outlined,
                  color: AppColors
                      .roleDonor,
                ),

                SizedBox(width: 10),

                Text(
                  'Recent Donation Activity',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          if (loading)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 30,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            )
          else if (submissions.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.all(20),
              child: _SimpleEmptyState(
                icon: Icons
                    .volunteer_activism_outlined,
                title:
                    'No donation activity yet',
                message:
                    'Your recent donation updates will appear here.',
              ),
            )
          else
            Column(
              children: [
                for (var i = 0;
                    i <
                        submissions.length;
                    i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                    ),

                  _ActivityRow(
                    submission:
                        submissions[i],
                    statusMeta:
                        statusMeta(
                      submissions[i]
                          .status,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ActivityRow
    extends StatelessWidget {
  final DonationSubmission submission;

  final (String, Color)
      statusMeta;

  const _ActivityRow({
    required this.submission,
    required this.statusMeta,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) =
        statusMeta;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 14,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.09,
              ),
              borderRadius:
                  BorderRadius.circular(
                9,
              ),
            ),
            child: Icon(
              _activityIcon(
                submission.status,
              ),
              size: 18,
              color: color,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Donation submitted ${_formatDate(submission.dateSub)}',
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style: const TextStyle(
                    fontSize: 12.8,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                if (submission.schedDate !=
                    null) ...[
                  const SizedBox(
                    height: 2,
                  ),

                  Text(
                    'Drop-off ${_formatDate(submission.schedDate!)}',
                    style:
                        const TextStyle(
                      fontSize: 11.3,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 9,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.11,
              ),
              borderRadius:
                  BorderRadius.circular(
                20,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10.8,
                fontWeight:
                    FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// IMAGE PANEL
// ============================================================================

class _AnimalImagePanel
    extends StatelessWidget {
  final double height;

  const _AnimalImagePanel({
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _dashboardAnimalImage,
            fit: BoxFit.cover,
            errorBuilder: (
              context,
              error,
              stackTrace,
            ) {
              return const
                  _AnimalImageFallback();
            },
          ),

          Align(
            alignment:
                Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                45,
                18,
                18,
              ),
              decoration:
                  const BoxDecoration(
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topCenter,
                  end:
                      Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(
                      0x99000000,
                    ),
                  ],
                ),
              ),
              child: const Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Every donation counts.',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Colors.white,
                    ),
                  ),

                  SizedBox(height: 3),

                  Text(
                    'Thank you for helping us care for animals in need.',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimalImageFallback
    extends StatelessWidget {
  const _AnimalImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.roleDonor
          .withValues(
        alpha: 0.08,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.roleDonor
                  .withValues(
                alpha: 0.12,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.pets_outlined,
              size: 30,
              color:
                  AppColors.roleDonor,
            ),
          ),

          const SizedBox(height: 10),

          const Text(
            'Dumaguete Animal Sanctuary',
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  FontWeight.w600,
              color:
                  AppColors.roleDonor,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMMON HELPERS
// ============================================================================

class _SectionIcon
    extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _SectionIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.09,
        ),
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: Icon(
        icon,
        size: 17,
        color: color,
      ),
    );
  }
}

class _SimpleEmptyState
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _SimpleEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color:
                AppColors.mutedForeground,
          ),

          const SizedBox(height: 8),

          Text(
            title,
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              fontSize: 12.8,
              fontWeight:
                  FontWeight.w600,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            message,
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors
                  .mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardError
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DashboardError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(16),
        border:
            Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline,
            size: 30,
            color:
                AppColors.mutedForeground,
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color:
                  AppColors.mutedForeground,
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton(
            onPressed: onRetry,
            child:
                const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INTERNAL RECENT IMPACT MODEL
// ============================================================================

class _RecentImpactEntry {
  final String itemName;
  final DateTime date;

  const _RecentImpactEntry({
    required this.itemName,
    required this.date,
  });
}

// ============================================================================
// STATUS ICON
// ============================================================================

IconData _activityIcon(
  SubmissionStatus status,
) {
  switch (status) {
    case SubmissionStatus.pending:
      return Icons.schedule_outlined;

    case SubmissionStatus.approved:
      return Icons
          .check_circle_outline;

    case SubmissionStatus.received:
      return Icons
          .local_shipping_outlined;

    case SubmissionStatus.stocked:
      return Icons.done_all_outlined;

    case SubmissionStatus.rejected:
      return Icons.cancel_outlined;
  }
}

// ============================================================================
// DATE FORMAT
// ============================================================================

const _monthAbbrev = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';