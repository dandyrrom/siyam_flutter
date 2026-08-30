import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../services/dashboard_service.dart';
import '../../services/follow_up_service.dart';
import '../../state/data_bus.dart';
import '../../widgets/social_post_dialog.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/page_loading.dart';

enum _Period { week, month }

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard>
    with DataBusRefreshMixin<StaffDashboard> {
  final DashboardService _service = DashboardService();
  final FollowUpService _followUpService = FollowUpService();

  StaffDashboardStats? _stats;
  List<ReplenishmentAlert> _replenishment = [];
  List<MedicalFollowUpReminder> _followUps = [];

  bool _loading = true;
  bool _loadInProgress = false;
  bool _refreshPending = false;

  String? _error;
  _Period _period = _Period.week;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() {
    _load(silent: true);
  }

  // Loads follow-up reminders without allowing a reminder-only failure
  // to block the rest of the Staff dashboard.
  Future<
      ({
        List<MedicalFollowUpReminder> reminders,
        String? warning,
      })> _fetchFollowUpsSafely() async {
    try {
      final reminders =
          await _followUpService.fetchActionableReminders();

      return (
        reminders: reminders,
        warning: null,
      );
    } catch (_) {
      return (
        reminders: _followUps,
        warning:
            'Medical follow-up reminders could not refresh. Showing the last loaded reminder data.',
      );
    }
  }

  // Collapses a burst of DataBus refreshes into the current load plus,
  // at most, one silent catch-up load. Loads never overlap.
  Future<void> _load({
    bool silent = false,
  }) async {
    if (_loadInProgress) {
      _refreshPending = true;
      return;
    }

    _loadInProgress = true;

    try {
      await _performLoad(silent: silent);

      if (_refreshPending && mounted) {
        _refreshPending = false;
        await _performLoad(silent: true);
      }
    } finally {
      _refreshPending = false;
      _loadInProgress = false;
    }
  }

  // Performs one dashboard snapshot load. The three reads start together.
  Future<void> _performLoad({
    required bool silent,
  }) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait<Object?>([
        _service.fetchStaffStats(),
        _service.fetchReplenishmentAlerts(),
        _fetchFollowUpsSafely(),
      ]);

      if (!mounted) return;

      final followUpResult = results[2]
          as ({
            List<MedicalFollowUpReminder> reminders,
            String? warning,
          });

      setState(() {
        _stats = results[0] as StaffDashboardStats;
        _replenishment = results[1] as List<ReplenishmentAlert>;
        _followUps = followUpResult.reminders;

        _loading = false;
        _error = followUpResult.warning;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load dashboard: $e';
        _loading = false;
      });
    }
  }

  DashboardPeriodStats? get _periodStats {
    final stats = _stats;
    if (stats == null) return null;
    return _period == _Period.week ? stats.week : stats.month;
  }

  String get _periodWord => _period == _Period.week ? 'week' : 'month';

  String get _comparisonLabel => _period == _Period.week
      ? 'vs. previous 7 days'
      : 'vs. previous 30 days';

  int get _criticalCount => _replenishment
      .where((item) => item.priority == ReplenishmentPriority.critical)
      .length;

  int get _highCount => _replenishment
      .where((item) => item.priority == ReplenishmentPriority.high)
      .length;

  int get _mediumCount => _replenishment
      .where((item) => item.priority == ReplenishmentPriority.medium)
      .length;

  List<MedicalFollowUpReminder> get _followUpPreview =>
      _followUps.take(2).toList();

  void _go(String path) => context.go(path);

  // Opens the animal's medical history. All treatment actions remain there.
  void _openFollowUpReminder(
    MedicalFollowUpReminder reminder,
  ) {
    _go(
      '/medical-records/pet/${Uri.encodeComponent(reminder.petId)}',
    );
  }

  // Uses the already-loaded reminder snapshot; opening this dialog makes
  // no additional Supabase request.
  Future<void> _openAllFollowUps() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _MedicalFollowUpDialog(
        reminders: _followUps,
        onOpenReminder: (reminder) {
          Navigator.of(dialogContext).pop();

          if (mounted) {
            _openFollowUpReminder(reminder);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    final period = _periodStats;

    if (_loading && stats == null) {
      return const PageLoading(
        message: 'Loading dashboard',
      );
    }

    if (_error != null && stats == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (stats == null || period == null) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final compact = width < 760;
        final medium = width < 1180;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        const DashboardHeader(
          title: 'Staff Dashboard',
          subtitle:
              'Quick view of inventory, treatments, and replenishment needs.',
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          _InlineNotice(
            icon: Icons.warning_amber_outlined,
            text:
                'Some dashboard data could not refresh. Showing the last loaded values.',
            actionLabel: 'Retry',
            onAction: _load,
          ),
        ],
        const SizedBox(height: 18),
        _DashboardKpiGrid(
          cards: [
            _DashboardKpiCard(
              icon: Icons.autorenew_outlined,
              value: '${_replenishment.length}',
              label: 'Stock Attention',
              helper: 'Items currently needing closer attention',
              accent: AppColors.primary,
              onTap: () => _go('/purchase-orders'),
            ),
            _DashboardKpiCard(
              icon: Icons.pets_outlined,
              value: '${stats.animalsUnderTreatment}',
              label: 'Animals Under Treatment',
              helper: 'Animals currently with active medical records',
              accent: AppColors.roleStaff,
              onTap: () => _go('/medical-records'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Expanded(
              child: _SectionHeading(
                title: 'Operational Overview',
                subtitle:
                    'Activity recorded from purchases and treatments.',
              ),
            ),
            if (!compact)
              _PeriodToggle(
                period: _period,
                onChanged: (value) => setState(() => _period = value),
              ),
          ],
        ),
        if (compact) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _PeriodToggle(
              period: _period,
              onChanged: (value) => setState(() => _period = value),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (medium)
          Column(
            children: [
              _OperationalActivityCard(
                periodStats: period,
                periodWord: _periodWord,
                comparisonLabel: _comparisonLabel,
                onPurchases: () => _go('/purchase-orders'),
                onTreatments: () => _go('/medical-records'),
              ),
              const SizedBox(height: 14),
              _PriorityOverviewCard(
                critical: _criticalCount,
                high: _highCount,
                medium: _mediumCount,
                onViewAll: () => _go('/purchase-orders'),
              ),
            ],
          )
        else
          SizedBox(
            height: 270,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: _OperationalActivityCard(
                    periodStats: period,
                    periodWord: _periodWord,
                    comparisonLabel: _comparisonLabel,
                    onPurchases: () => _go('/purchase-orders'),
                    onTreatments: () => _go('/medical-records'),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: _PriorityOverviewCard(
                    critical: _criticalCount,
                    high: _highCount,
                    medium: _mediumCount,
                    onViewAll: () => _go('/purchase-orders'),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        if (medium)
          Column(
            children: [
              _MedicalFollowUpCard(
                reminders: _followUpPreview,
                totalCount: _followUps.length,
                onViewAll: _followUps.isEmpty ? null : _openAllFollowUps,
                onOpenReminder: _openFollowUpReminder,
              ),
              const SizedBox(height: 14),
              _SocialTemplateCard(alerts: _replenishment),
            ],
          )
        else
          SizedBox(
            height: 270,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: _MedicalFollowUpCard(
                    reminders: _followUpPreview,
                    totalCount: _followUps.length,
                    onViewAll: _followUps.isEmpty ? null : _openAllFollowUps,
                    onOpenReminder: _openFollowUpReminder,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  flex: 4,
                  child: _SocialTemplateCard(
                    alerts: _replenishment,
                    pinButtonToBottom: true,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        const Text(
          'Period comparisons use recorded purchases and treatments. '
          'Stock-attention and medical follow-up counts are current live values.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: AppColors.mutedForeground,
          ),
        ),
          ],
        );
      },
    );
  }
}

class _DashboardKpiGrid extends StatelessWidget {
  final List<Widget> cards;

  const _DashboardKpiGrid({
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Use the dashboard's REAL available width after the sidebar/app shell,
        // not the whole screen width. This prevents three narrow cards from
        // being forced beside each other at intermediate web/tablet sizes.
        final preferredColumns = width >= 840
            ? 3
            : width >= 540
                ? 2
                : 1;

        final columns =
            preferredColumns > cards.length
                ? cards.length
                : preferredColumns;

        const spacing = 12.0;

        final cardWidth =
            (width - (columns - 1) * spacing) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(
                width: cardWidth,
                child: card,
              ),
          ],
        );
      },
    );
  }
}

class _DashboardKpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String helper;
  final Color accent;
  final VoidCallback onTap;

  const _DashboardKpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.helper,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: accent.withValues(alpha: 0.035),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 148,
          ),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      helper,
                      style: const TextStyle(
                        fontSize: 11.2,
                        height: 1.35,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View details',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: accent,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeading({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.8,
            color: AppColors.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  final _Period period;
  final ValueChanged<_Period> onChanged;

  const _PeriodToggle({
    required this.period,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(String label, _Period value) {
      final selected = period == value;

      return InkWell(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.roleStaff : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.foreground,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          option('Week', _Period.week),
          option('Month', _Period.month),
        ],
      ),
    );
  }
}

class _OperationalActivityCard extends StatelessWidget {
  final DashboardPeriodStats periodStats;
  final String periodWord;
  final String comparisonLabel;
  final VoidCallback onPurchases;
  final VoidCallback onTreatments;

  const _OperationalActivityCard({
    required this.periodStats,
    required this.periodWord,
    required this.comparisonLabel,
    required this.onPurchases,
    required this.onTreatments,
  });

  @override
  Widget build(BuildContext context) {
    final p = periodStats;

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeading(
                  title: 'Operational Activity',
                  subtitle: 'What was recorded during the selected period.',
                ),
              ),
              Text(
                comparisonLabel,
                style: const TextStyle(
                  fontSize: 10.8,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ActivityRow(
            icon: Icons.receipt_long_outlined,
            title: 'Purchases',
            value: '${p.purchaseCount}',
            valueLabel: 'received this $periodWord',
            change: percentChange(
              p.purchaseCount,
              p.purchaseCountPrior,
            ),
            detail1: '${p.itemsReceived} items received',
            detail2: '${p.distinctSuppliers} suppliers',
            accent: AppColors.roleStaff,
            onTap: onPurchases,
          ),
          const Divider(height: 1),
          _ActivityRow(
            icon: Icons.medical_services_outlined,
            title: 'Treatments',
            value: '${p.treatmentCount}',
            valueLabel: 'logged this $periodWord',
            change: percentChange(
              p.treatmentCount,
              p.treatmentCountPrior,
            ),
            detail1: '${p.animalsTreated} animals treated',
            detail2: '${p.itemsDispensed} items dispensed',
            accent: AppColors.primary,
            onTap: onTreatments,
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String valueLabel;
  final ({
    String label,
    bool isUp,
    bool isFlat,
  })? change;
  final String detail1;
  final String detail2;
  final Color accent;
  final VoidCallback onTap;

  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.valueLabel,
    required this.change,
    required this.detail1,
    required this.detail2,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow =
            constraints.maxWidth < 520;

        final iconBox = Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: accent,
          ),
        );

        final description = Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$detail1 · $detail2',
              style: const TextStyle(
                fontSize: 11.2,
                height: 1.35,
                color:
                    AppColors.mutedForeground,
              ),
            ),
          ],
        );

        final valueBlock = Column(
          crossAxisAlignment:
              narrow
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
          children: [
            Wrap(
              spacing: 7,
              runSpacing: 5,
              crossAxisAlignment:
                  WrapCrossAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (change != null)
                  _ChangeBadge(
                    change: change!,
                  ),
              ],
            ),
            Text(
              valueLabel,
              style: const TextStyle(
                fontSize: 10.5,
                color:
                    AppColors.mutedForeground,
              ),
            ),
          ],
        );

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            hoverColor:
                accent.withValues(alpha: 0.025),
            borderRadius:
                BorderRadius.circular(10),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 14,
              ),
              child: narrow
                  ? Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        iconBox,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              description,
                              const SizedBox(
                                height: 10,
                              ),
                              valueBlock,
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Padding(
                          padding:
                              EdgeInsets.only(
                            top: 10,
                          ),
                          child: Icon(
                            Icons.chevron_right,
                            size: 18,
                            color: AppColors
                                .mutedForeground,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.center,
                      children: [
                        iconBox,
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: description,
                        ),
                        const SizedBox(width: 10),
                        valueBlock,
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors
                              .mutedForeground,
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ChangeBadge extends StatelessWidget {
  final ({
    String label,
    bool isUp,
    bool isFlat,
  }) change;

  const _ChangeBadge({
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    final color = change.isFlat
        ? AppColors.mutedForeground
        : change.isUp
            ? AppColors.primary
            : AppColors.stockOut;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        change.label,
        style: TextStyle(
          fontSize: 10.2,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _PriorityOverviewCard extends StatelessWidget {
  final int critical;
  final int high;
  final int medium;
  final VoidCallback onViewAll;

  const _PriorityOverviewCard({
    required this.critical,
    required this.high,
    required this.medium,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final total = critical + high + medium;

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: _SectionHeading(
                  title: 'Stock Priority',
                  subtitle: 'Current items needing attention.',
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow =
                  constraints.maxWidth < 300;

              final donut = SizedBox(
                width: 148,
                height: 148,
                child: CustomPaint(
                  painter: _PriorityDonutPainter(
                    critical: critical,
                    high: high,
                    medium: medium,
                    criticalColor:
                        AppColors.stockOut,
                    highColor:
                        AppColors.stockLow,
                    mediumColor: AppColors
                        .stockNeedsRestock,
                    trackColor:
                        AppColors.border,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style:
                              const TextStyle(
                            fontSize: 25,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        const Text(
                          'items',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors
                                .mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );

              final legend = Column(
                children: [
                  _PriorityLegendRow(
                    label: 'Critical',
                    value: critical,
                    helper: 'No usable stock',
                    color:
                        AppColors.stockOut,
                  ),
                  const SizedBox(height: 12),
                  _PriorityLegendRow(
                    label: 'High',
                    value: high,
                    helper: 'Well below ROP',
                    color:
                        AppColors.stockLow,
                  ),
                  const SizedBox(height: 12),
                  _PriorityLegendRow(
                    label: 'Medium',
                    value: medium,
                    helper:
                        'At or below ROP',
                    color: AppColors
                        .stockNeedsRestock,
                  ),
                ],
              );

              if (narrow) {
                return Column(
                  children: [
                    Center(child: donut),
                    const SizedBox(height: 16),
                    legend,
                  ],
                );
              }

              return Row(
                children: [
                  donut,
                  const SizedBox(width: 18),
                  Expanded(child: legend),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PriorityLegendRow extends StatelessWidget {
  final String label;
  final int value;
  final String helper;
  final Color color;

  const _PriorityLegendRow({
    required this.label,
    required this.value,
    required this.helper,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                helper,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _PriorityDonutPainter extends CustomPainter {
  final int critical;
  final int high;
  final int medium;
  final Color criticalColor;
  final Color highColor;
  final Color mediumColor;
  final Color trackColor;

  const _PriorityDonutPainter({
    required this.critical,
    required this.high,
    required this.medium,
    required this.criticalColor,
    required this.highColor,
    required this.mediumColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius = math.min(
          size.width,
          size.height,
        ) /
        2 -
        10;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius,
    );

    const strokeWidth = 15.0;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt
      ..color = trackColor;

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      trackPaint,
    );

    final total = critical + high + medium;
    if (total <= 0) return;

    var start = -math.pi / 2;

    void drawSegment(int value, Color color) {
      if (value <= 0) return;

      final sweep = math.pi * 2 * (value / total);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = color;

      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        paint,
      );

      start += sweep;
    }

    drawSegment(critical, criticalColor);
    drawSegment(high, highColor);
    drawSegment(medium, mediumColor);
  }

  @override
  bool shouldRepaint(
    covariant _PriorityDonutPainter oldDelegate,
  ) {
    return critical != oldDelegate.critical ||
        high != oldDelegate.high ||
        medium != oldDelegate.medium ||
        criticalColor != oldDelegate.criticalColor ||
        highColor != oldDelegate.highColor ||
        mediumColor != oldDelegate.mediumColor ||
        trackColor != oldDelegate.trackColor;
  }
}

class _MedicalFollowUpCard extends StatelessWidget {
  final List<MedicalFollowUpReminder> reminders;
  final int totalCount;
  final VoidCallback? onViewAll;
  final ValueChanged<MedicalFollowUpReminder> onOpenReminder;

  const _MedicalFollowUpCard({
    required this.reminders,
    required this.totalCount,
    required this.onViewAll,
    required this.onOpenReminder,
  });

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              16,
              12,
              14,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: _SectionHeading(
                    title: 'Medical Follow-up Reminders',
                    subtitle: 'Follow-ups needing attention within 7 days.',
                  ),
                ),
                if (totalCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$totalCount',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (reminders.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 38,
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 32,
                      color: AppColors.primary,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No follow-ups need attention',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Nothing is due within the next 7 days.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            for (var i = 0; i < reminders.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _MedicalFollowUpRow(
                reminder: reminders[i],
                onTap: () => onOpenReminder(reminders[i]),
              ),
            ],
            if (totalCount > reminders.length) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
                child: Text(
                  'Showing the 2 most urgent of $totalCount follow-ups.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _MedicalFollowUpRow extends StatelessWidget {
  final MedicalFollowUpReminder reminder;
  final VoidCallback onTap;

  const _MedicalFollowUpRow({
    required this.reminder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _followUpMeta(reminder);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: meta.color.withValues(alpha: 0.025),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: meta.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.medical_services_outlined,
                  size: 17,
                  color: meta.color,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.petName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reminder.treatmentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Due ${_formatDashboardDate(reminder.dueDate)}',
                      style: TextStyle(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w600,
                        color: meta.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _FollowUpStatusBadge(
                label: meta.label,
                color: meta.color,
              ),
              const SizedBox(width: 3),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowUpStatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _FollowUpStatusBadge({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minWidth: 72,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9.8,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

enum _FollowUpFilter {
  all,
  overdue,
  dueSoon,
}

class _MedicalFollowUpDialog extends StatefulWidget {
  final List<MedicalFollowUpReminder> reminders;
  final ValueChanged<MedicalFollowUpReminder> onOpenReminder;

  const _MedicalFollowUpDialog({
    required this.reminders,
    required this.onOpenReminder,
  });

  @override
  State<_MedicalFollowUpDialog> createState() =>
      _MedicalFollowUpDialogState();
}

class _MedicalFollowUpDialogState
    extends State<_MedicalFollowUpDialog> {
  final TextEditingController _searchController =
      TextEditingController();

  String _search = '';
  _FollowUpFilter _filter = _FollowUpFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MedicalFollowUpReminder> get _filtered {
    final query = _search.trim().toLowerCase();

    return widget.reminders.where((reminder) {
      if (query.isNotEmpty) {
        final matches =
            reminder.petName.toLowerCase().contains(query) ||
            reminder.treatmentName.toLowerCase().contains(query);

        if (!matches) {
          return false;
        }
      }

      final status = reminder.statusAt(DateTime.now());

      switch (_filter) {
        case _FollowUpFilter.all:
          return true;
        case _FollowUpFilter.overdue:
          return status == FollowUpReminderStatus.overdue;
        case _FollowUpFilter.dueSoon:
          return status != FollowUpReminderStatus.overdue;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);
    final width =
        screen.width < 700 ? screen.width - 24 : 640.0;
    final height =
        screen.height < 760 ? screen.height - 24 : 690.0;

    final reminders = _filtered;

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(
          color: AppColors.border,
        ),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                17,
                10,
                12,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medical Follow-up Reminders',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Overdue, today, and the next 7 days.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                10,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _search = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search animal or treatment',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 19,
                      ),
                      filled: true,
                      fillColor: AppColors.muted.withValues(
                        alpha: 0.35,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: AppColors.primary.withValues(
                            alpha: 0.55,
                          ),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _FilterChipButton(
                          label: 'All',
                          selected: _filter == _FollowUpFilter.all,
                          onTap: () {
                            setState(() {
                              _filter = _FollowUpFilter.all;
                            });
                          },
                        ),
                        _FilterChipButton(
                          label: 'Overdue',
                          selected:
                              _filter == _FollowUpFilter.overdue,
                          onTap: () {
                            setState(() {
                              _filter = _FollowUpFilter.overdue;
                            });
                          },
                        ),
                        _FilterChipButton(
                          label: 'Due Soon',
                          selected:
                              _filter == _FollowUpFilter.dueSoon,
                          onTap: () {
                            setState(() {
                              _filter = _FollowUpFilter.dueSoon;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: reminders.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_available_outlined,
                              size: 34,
                              color: AppColors.mutedForeground,
                            ),
                            SizedBox(height: 9),
                            Text(
                              'No matching follow-ups',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Try another search or filter.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                      ),
                      itemCount: reminders.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final reminder = reminders[index];

                        return _MedicalFollowUpRow(
                          reminder: reminder,
                          onTap: () =>
                              widget.onOpenReminder(reminder),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.09)
          : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
              color:
                  selected ? AppColors.primary : AppColors.foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _SocialTemplateCard extends StatelessWidget {
  final List<ReplenishmentAlert> alerts;
  final bool pinButtonToBottom;

  const _SocialTemplateCard({
    required this.alerts,
    this.pinButtonToBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    final preview = alerts.take(3).toList();

    return _PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.roleStaff.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.campaign_outlined,
                  size: 19,
                  color: AppColors.roleStaff,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: _SectionHeading(
                  title: 'Social Media Template',
                  subtitle: 'Prepare a post from current stock needs.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (alerts.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'There are no current stock needs to include in a social-media post.',
                style: TextStyle(
                  fontSize: 11.7,
                  height: 1.4,
                  color: AppColors.mutedForeground,
                ),
              ),
            )
          else ...[
            const Text(
              'Current priority items',
              style: TextStyle(
                fontSize: 11.8,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final item in preview)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _priorityMeta(item.priority).$2,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        item.itemName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (alerts.length > preview.length)
              Text(
                '+ ${alerts.length - preview.length} more item'
                '${alerts.length - preview.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.mutedForeground,
                ),
              ),
          ],
          if (pinButtonToBottom)
            const Spacer()
          else
            const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.roleStaff,
              ),
              onPressed: alerts.isEmpty
                  ? null
                  : () => showSocialPostDialog(
                        context,
                        alerts: alerts,
                      ),
              icon: const Icon(
                Icons.auto_awesome_outlined,
                size: 16,
              ),
              label: const Text(
                'Generate Social Media Post',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _PanelCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _InlineNotice({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}

({String label, Color color}) _followUpMeta(
  MedicalFollowUpReminder reminder,
) {
  switch (reminder.statusAt(DateTime.now())) {
    case FollowUpReminderStatus.overdue:
      return (
        label: 'OVERDUE',
        color: AppColors.stockOut,
      );
    case FollowUpReminderStatus.dueToday:
      return (
        label: 'DUE TODAY',
        color: AppColors.warning,
      );
    case FollowUpReminderStatus.dueSoonUrgent:
      final days = reminder.daysUntil(DateTime.now());
      return (
        label: days == 1 ? '1 DAY' : '$days DAYS',
        color: AppColors.stockLow,
      );
    case FollowUpReminderStatus.dueSoon:
      return (
        label: 'DUE SOON',
        color: AppColors.primary,
      );
  }
}

const _dashboardMonths = [
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

String _formatDashboardDate(
  DateTime date,
) {
  return '${_dashboardMonths[date.month - 1]} '
      '${date.day}, ${date.year}';
}

(String, Color) _priorityMeta(
  ReplenishmentPriority priority,
) {
  switch (priority) {
    case ReplenishmentPriority.critical:
      return ('Critical', AppColors.stockOut);
    case ReplenishmentPriority.high:
      return ('High', AppColors.stockLow);
    case ReplenishmentPriority.medium:
      return ('Medium', AppColors.stockNeedsRestock);
  }
}

String _formatQty(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
