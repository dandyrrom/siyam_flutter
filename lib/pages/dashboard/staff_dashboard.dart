import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../services/dashboard_service.dart';
import '../../state/data_bus.dart';
import '../../widgets/social_post_dialog.dart';
import '../../widgets/stat_card.dart';

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
      final stats = await _service.fetchStaffStats();
      final replenishment = await _service.fetchReplenishmentAlerts();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _replenishment = replenishment;
        _loading = false;
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

  String get _periodComparisonLabel =>
      _period == _Period.week ? 'vs. the previous 7 days' : 'vs. the previous 30 days';

  String get _periodWord => _period == _Period.week ? 'week' : 'month';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardHeader(
          title: 'Staff Dashboard',
          subtitle: 'Your day-to-day: inventory, treatments, and donations.',
        ),
        if (_error != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_error!, style: const TextStyle(color: AppColors.destructive)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else ...[
          _TopRow(loading: _loading, stats: _stats),
          const SizedBox(height: 26),
          _PeriodToggle(
            period: _period,
            comparisonLabel: _periodComparisonLabel,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 16),
          _MetricGrid(
            loading: _loading,
            stats: _stats,
            periodStats: _periodStats,
            periodWord: _periodWord,
            replenishment: _replenishment,
          ),
          const SizedBox(height: 24),
          const Text(
            'Cards with a ↑/↓ badge compare the selected period to the one before it, computed '
            'from dated records (purchases, treatments, donations). Cards without a badge are '
            'live counts of current state, not period totals.',
            style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground, height: 1.5),
          ),
        ],
      ],
    );
  }
}

class _TopRow extends StatelessWidget {
  final bool loading;
  final StaffDashboardStats? stats;

  const _TopRow({required this.loading, required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 760;
      final healthCard = _InventoryHealthCard(loading: loading, stats: stats);
      final mini1 = StatCard(
        label: 'Animals under treatment',
        value: loading ? '—' : '${stats!.animalsUnderTreatment}',
        icon: Icons.medical_services_outlined,
        accent: AppColors.roleStaff,
      );
      final mini2 = StatCard(
        label: 'Pending submissions',
        value: loading ? '—' : '${stats!.pendingSubmissions}',
        icon: Icons.schedule_outlined,
        accent: AppColors.warning,
      );

      if (isNarrow) {
        return Column(
          children: [
            healthCard,
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: mini1),
              const SizedBox(width: 16),
              Expanded(child: mini2),
            ]),
          ],
        );
      }

      // IntrinsicHeight lets the Row's stretch-aligned children (the health
      // card and the two StatCards, which have different natural heights)
      // equalize without needing a bounded-height ancestor -- without it,
      // CrossAxisAlignment.stretch on a Row inside a scrolling Column throws
      // "BoxConstraints forces an infinite height".
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 16, child: healthCard),
            const SizedBox(width: 16),
            Expanded(flex: 10, child: mini1),
            const SizedBox(width: 16),
            Expanded(flex: 10, child: mini2),
          ],
        ),
      );
    });
  }
}

class _InventoryHealthCard extends StatelessWidget {
  final bool loading;
  final StaffDashboardStats? stats;

  const _InventoryHealthCard({required this.loading, required this.stats});

  @override
  Widget build(BuildContext context) {
    final pct = loading ? 0.0 : stats!.inventoryHealthPct;
    final pctLabel = loading ? '—' : '${pct.round()}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              const Text('Inventory Health',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.foreground),
                  children: [
                    TextSpan(text: pctLabel),
                    const TextSpan(
                        text: '%',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.mutedForeground)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: loading ? 0 : (pct / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.stockNeedsRestock),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                loading
                    ? ' '
                    : '${stats!.healthyItemCount} of ${stats!.totalItems} items above the low-stock line',
                style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
              ),
              Text(
                loading
                    ? ' '
                    : '${stats!.lowStockCount} low · ${stats!.outOfStockCount} out of stock',
                style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  final _Period period;
  final String comparisonLabel;
  final ValueChanged<_Period> onChanged;

  const _PeriodToggle({
    required this.period,
    required this.comparisonLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, _Period value) {
      final active = period == value;
      return InkWell(
        onTap: () => onChanged(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.roleStaff : Colors.transparent,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : AppColors.foreground,
            ),
          ),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            segment('This week', _Period.week),
            segment('This month', _Period.month),
          ]),
        ),
        Text(comparisonLabel,
            style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
      ],
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final bool loading;
  final StaffDashboardStats? stats;
  final DashboardPeriodStats? periodStats;
  final String periodWord;
  final List<ReplenishmentAlert> replenishment;

  const _MetricGrid({
    required this.loading,
    required this.stats,
    required this.periodStats,
    required this.periodWord,
    required this.replenishment,
  });

  @override
  Widget build(BuildContext context) {
    if (loading || stats == null || periodStats == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final s = stats!;
    final p = periodStats!;
    final critical =
        replenishment.where((a) => a.priority == ReplenishmentPriority.critical).length;
    final high = replenishment.where((a) => a.priority == ReplenishmentPriority.high).length;
    final medium =
        replenishment.where((a) => a.priority == ReplenishmentPriority.medium).length;

    final purchasesChange = percentChange(p.purchaseCount, p.purchaseCountPrior);
    final itemsReceivedChange = percentChange(p.itemsReceived, p.itemsReceivedPrior);
    final suppliersChange = percentChange(p.distinctSuppliers, p.distinctSuppliersPrior);

    final treatmentsChange = percentChange(p.treatmentCount, p.treatmentCountPrior);
    final animalsTreatedChange = percentChange(p.animalsTreated, p.animalsTreatedPrior);
    final itemsDispensedChange = percentChange(p.itemsDispensed, p.itemsDispensedPrior);

    final donationsChange = percentChange(p.donationCount, p.donationCountPrior);
    final itemsDonatedChange = percentChange(p.itemsDonated, p.itemsDonatedPrior);
    final donorsChange = percentChange(p.distinctDonors, p.distinctDonorsPrior);

    final cards = [
      _MetricCard(
        title: 'Stock Alerts',
        headline: '${s.outOfStockCount}',
        note: 'Items with zero stock right now.',
        rows: [
          _BreakdownRow('Out of stock', '${s.outOfStockCount} items', AppColors.stockOut),
          _BreakdownRow('Low stock', '${s.lowStockCount} items', AppColors.stockLow),
          _BreakdownRow(
              'Needs restock soon', '${s.needsRestockCount} items', AppColors.stockNeedsRestock),
        ],
      ),
      _MetricCard(
        title: 'Purchases',
        headline: '${p.purchaseCount}',
        change: purchasesChange,
        note: 'Deliveries received this $periodWord, $_comparisonSuffix',
        rows: [
          _BreakdownRow('Total items received', '${p.itemsReceived}', AppColors.roleStaff,
              change: itemsReceivedChange),
          _BreakdownRow('Distinct suppliers', '${p.distinctSuppliers}', AppColors.roleStaff,
              change: suppliersChange),
          _BreakdownRow(
              'Most recent delivery', _relativeDate(s.mostRecentDeliveryDate), AppColors.roleStaff),
        ],
      ),
      _MetricCard(
        title: 'Treatments',
        headline: '${p.treatmentCount}',
        change: treatmentsChange,
        note: 'Treatments logged this $periodWord, $_comparisonSuffix',
        rows: [
          _BreakdownRow('Animals treated', '${p.animalsTreated}', AppColors.primary,
              change: animalsTreatedChange),
          _BreakdownRow('Items dispensed', '${p.itemsDispensed}', AppColors.primary,
              change: itemsDispensedChange),
          _BreakdownRow('Recorded by staff', '${p.staffWhoRecorded}', AppColors.primary),
        ],
      ),
      _MetricCard(
        title: 'Donations',
        headline: '${p.donationCount}',
        change: donationsChange,
        note: 'Donations received this $periodWord, $_comparisonSuffix',
        rows: [
          _BreakdownRow('Total items donated', '${p.itemsDonated}', AppColors.sageGreen,
              change: itemsDonatedChange),
          _BreakdownRow('Distinct donors', '${p.distinctDonors}', AppColors.sageGreen,
              change: donorsChange),
          _BreakdownRow('Largest single drop-off', '${p.largestDropoff} items', AppColors.sageGreen),
        ],
      ),
      _MetricCard(
        title: 'Pending Submissions',
        headline: '${s.pendingSubmissions}',
        note: 'Donor submissions waiting on staff right now.',
        rows: [
          _BreakdownRow('Scheduled, not yet received', '${s.pendingScheduled}', AppColors.warning),
          _BreakdownRow('Past scheduled date', '${s.pendingOverdue}', AppColors.stockOut),
          _BreakdownRow('Not yet scheduled', '${s.pendingUnscheduled}', AppColors.mutedForeground),
        ],
      ),
      _MetricCard(
        title: 'Replenishment',
        headline: '${critical + high + medium}',
        note: 'Items at or below their stock threshold right now.',
        rows: [
          _BreakdownRow('Critical priority', '$critical items', AppColors.stockOut),
          _BreakdownRow('High priority', '$high items', AppColors.stockLow),
          _BreakdownRow('Medium priority', '$medium items', AppColors.stockNeedsRestock),
        ],
        trailing: Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.roleStaff),
              onPressed: replenishment.isEmpty
                  ? null
                  : () => showSocialPostDialog(context, alerts: replenishment),
              icon: const Icon(Icons.campaign_outlined, size: 16),
              label: const Text('Generate social media post'),
            ),
          ],
        ),
      ),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width > 900 ? 3 : (width > 600 ? 2 : 1);

      // Cards vary in content length (note line count, whether a CTA is
      // present), so a plain Wrap lets each one size to its own content --
      // IntrinsicHeight + stretch per row forces every card in that row to
      // match the tallest one instead.
      final rowsOfCards = <List<Widget>>[];
      for (var i = 0; i < cards.length; i += columns) {
        rowsOfCards.add(cards.sublist(i, (i + columns).clamp(0, cards.length)));
      }

      return Column(
        children: [
          for (var i = 0; i < rowsOfCards.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < rowsOfCards[i].length; j++) ...[
                    if (j > 0) const SizedBox(width: 16),
                    Expanded(child: rowsOfCards[i][j]),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  String get _comparisonSuffix =>
      periodWord == 'week' ? 'vs. the previous 7 days' : 'vs. the previous 30 days';

  String _relativeDate(DateTime? date) {
    if (date == null) return 'No deliveries yet';
    final days = DateTime.now().difference(date).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return '1 day ago';
    return '$days days ago';
  }
}

class _BreakdownRow {
  final String label;
  final String value;
  final Color dotColor;
  final ({String label, bool isUp, bool isFlat})? change;

  const _BreakdownRow(this.label, this.value, this.dotColor, {this.change});
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String headline;
  final ({String label, bool isUp, bool isFlat})? change;
  final String note;
  final List<_BreakdownRow> rows;
  final Widget? trailing;

  const _MetricCard({
    required this.title,
    required this.headline,
    this.change,
    required this.note,
    required this.rows,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.border)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(headline, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              if (change != null) ...[
                const SizedBox(width: 10),
                _ChangeChip(change: change!),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(note,
              style: const TextStyle(fontSize: 11.5, color: AppColors.mutedForeground, height: 1.4)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                for (final row in rows) _BreakdownTile(row: row),
              ],
            ),
          ),
          // Pushes the optional CTA to the bottom edge so every card in the
          // row (equal-height via IntrinsicHeight + stretch, see
          // _MetricGrid) lines up instead of leaving ragged trailing space.
          const Spacer(),
          if (trailing != null) ...[
            const SizedBox(height: 16),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _ChangeChip extends StatelessWidget {
  final ({String label, bool isUp, bool isFlat}) change;
  const _ChangeChip({required this.change});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    if (change.isFlat) {
      bg = AppColors.border;
      fg = AppColors.mutedForeground;
    } else if (change.isUp) {
      bg = AppColors.sageGreenTint;
      fg = AppColors.sageGreen;
    } else {
      bg = AppColors.destructive.withValues(alpha: 0.12);
      fg = AppColors.destructive;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(change.label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _BreakdownTile extends StatelessWidget {
  final _BreakdownRow row;
  const _BreakdownTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: row.dotColor, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(row.label, style: const TextStyle(fontSize: 12.5)),
          ),
          Text(row.value,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          if (row.change != null) ...[
            const SizedBox(width: 8),
            Text(
              row.change!.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: row.change!.isFlat
                    ? AppColors.mutedForeground
                    : (row.change!.isUp ? AppColors.sageGreen : AppColors.destructive),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
