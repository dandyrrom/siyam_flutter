import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';
import '../../services/dashboard_service.dart';
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

  StaffDashboardStats? _stats;
  List<ReplenishmentAlert> _replenishment = [];

  bool _loading = true;
  String? _error;
  _Period _period = _Period.week;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait<Object?>([
        _service.fetchStaffStats(),
        _service.fetchReplenishmentAlerts(),
      ]);

      if (!mounted) return;

      setState(() {
        _stats = results[0] as StaffDashboardStats;
        _replenishment = results[1] as List<ReplenishmentAlert>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error = 'Could not load dashboard: $e';
          _loading = false;
        });
      }
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

  List<ReplenishmentAlert> get _attentionPreview =>
      _replenishment.take(3).toList();

  void _go(String path) => context.go(path);

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
              _AttentionListCard(
                alerts: _attentionPreview,
                totalCount: _replenishment.length,
                onViewAll: () => _go('/purchase-orders'),
                onOpenItem: (item) => _go(
                  '/inventory/${item.itemId}?from=purchase-orders',
                ),
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
                  child: _AttentionListCard(
                    alerts: _attentionPreview,
                    totalCount: _replenishment.length,
                    onViewAll: () => _go('/purchase-orders'),
                    onOpenItem: (item) => _go(
                      '/inventory/${item.itemId}?from=purchase-orders',
                    ),
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
          'Current stock-attention counts are live values, not period totals.',
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
                    helper: 'Low stock',
                    color:
                        AppColors.stockLow,
                  ),
                  const SizedBox(height: 12),
                  _PriorityLegendRow(
                    label: 'Medium',
                    value: medium,
                    helper:
                        'Needs restock soon',
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

class _AttentionListCard extends StatelessWidget {
  final List<ReplenishmentAlert> alerts;
  final int totalCount;
  final VoidCallback onViewAll;
  final ValueChanged<ReplenishmentAlert> onOpenItem;

  const _AttentionListCard({
    required this.alerts,
    required this.totalCount,
    required this.onViewAll,
    required this.onOpenItem,
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
                    title: 'Items Needing Attention',
                    subtitle: 'Highest-priority stock items right now.',
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
          if (alerts.isEmpty)
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
                      'No stock items need attention',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Current stock alerts are clear.',
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
            for (var i = 0; i < alerts.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              _AttentionRow(
                item: alerts[i],
                onTap: () => onOpenItem(alerts[i]),
              ),
            ],
            if (totalCount > alerts.length) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                child: Text(
                  'Showing ${alerts.length} of $totalCount items. '
                  'Open Purchases & Replenishment for the complete list.',
                  style: const TextStyle(
                    fontSize: 11.2,
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

class _AttentionRow extends StatelessWidget {
  final ReplenishmentAlert item;
  final VoidCallback onTap;

  const _AttentionRow({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = _priorityMeta(item.priority);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: color.withValues(alpha: 0.025),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow =
                constraints.maxWidth < 520;

            final statusBadge = Container(
              constraints:
                  const BoxConstraints(
                minWidth: 72,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color:
                    color.withValues(alpha: 0.10),
                borderRadius:
                    BorderRadius.circular(999),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.4,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            );

            return Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              child: narrow
                  ? Row(
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
                          decoration:
                              BoxDecoration(
                            color: color,
                            shape:
                                BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style:
                                    const TextStyle(
                                  fontSize: 12.8,
                                  height: 1.3,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                              const SizedBox(
                                height: 7,
                              ),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment:
                                    WrapCrossAlignment
                                        .center,
                                children: [
                                  Text(
                                    '${_formatQty(item.stockQty)} ${item.unitAbbr}',
                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                      fontWeight:
                                          FontWeight.w600,
                                    ),
                                  ),
                                  statusBadge,
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Padding(
                          padding:
                              EdgeInsets.only(
                            top: 2,
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
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration:
                              BoxDecoration(
                            color: color,
                            shape:
                                BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.itemName,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize: 12.8,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_formatQty(item.stockQty)} ${item.unitAbbr}',
                          style:
                              const TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        statusBadge,
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AppColors
                              .mutedForeground,
                        ),
                      ],
                    ),
            );
          },
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
          const Text(
            'The generated caption should follow DAS’s real posting tone and format.',
            style: TextStyle(
              fontSize: 10.8,
              height: 1.35,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 10),
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
