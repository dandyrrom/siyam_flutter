import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../models/inventory_item.dart';
import '../../models/supplier.dart';
import '../../models/treatment.dart';
import '../../services/donation_service.dart';
import '../../services/inventory_service.dart';
import '../../services/supplier_service.dart';
import '../../services/treatment_service.dart';
import '../../state/data_bus.dart';
import '../../widgets/stat_card.dart';

/// Reports derived strictly from what the schema actually stores.
///
/// The React design's "Reorder Analytics" tab needs a reorder-point
/// column that doesn't exist on `item`, and "Generated Reports" needs a
/// downloadable-report table that doesn't exist at all -- both are
/// dropped rather than faked. What's shown here (category breakdown,
/// donations/treatments/purchase spend over time) is all derivable from
/// item, donation, treatment, and order_item/purchase_trans.
class ManagerReportsPage extends StatefulWidget {
  const ManagerReportsPage({super.key});

  @override
  State<ManagerReportsPage> createState() => _ManagerReportsPageState();
}

class _ManagerReportsPageState extends State<ManagerReportsPage>
    with DataBusRefreshMixin<ManagerReportsPage> {
  final InventoryService _inventoryService = InventoryService();
  final DonationService _donationService = DonationService();
  final TreatmentService _treatmentService = TreatmentService();
  final SupplierService _supplierService = SupplierService();

  List<InventoryItem> _items = [];
  List<DateTime> _donationDates = [];
  List<TreatmentRecord> _treatments = [];
  List<OrderSpendEntry> _spendEntries = [];

  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        _inventoryService.fetchItems(),
        _donationService.fetchDonationDates(),
        _treatmentService.fetchTreatments(),
        _supplierService.fetchOrderSpendEntries(),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<InventoryItem>;
        _donationDates = results[1] as List<DateTime>;
        _treatments = results[2] as List<TreatmentRecord>;
        _spendEntries = results[3] as List<OrderSpendEntry>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'Could not load reports: $e';
          _loading = false;
        });
      }
    }
  }

  /// Last 6 months (oldest first) as (label, bucket-key) pairs.
  List<(String, String)> get _last6Months {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i));
      return (_monthAbbrev[d.month - 1], '${d.year}-${d.month}');
    });
  }

  String _bucketKey(DateTime d) => '${d.year}-${d.month}';

  Map<String, double> get _categoryStock {
    final map = <String, double>{};
    for (final item in _items) {
      map[item.itemCategory] = (map[item.itemCategory] ?? 0) + item.stockQty;
    }
    return map;
  }

  List<double> _monthlyCounts(List<DateTime> dates) {
    final months = _last6Months;
    return [
      for (final (_, key) in months)
        dates.where((d) => _bucketKey(d) == key).length.toDouble(),
    ];
  }

  List<double> _monthlySpend() {
    final months = _last6Months;
    return [
      for (final (_, key) in months)
        _spendEntries
            .where((e) => _bucketKey(e.purDate) == key)
            .fold(0.0, (sum, e) => sum + e.amount),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final totalStock = _items.fold<double>(0, (sum, i) => sum + i.stockQty);
    final totalSpend = _spendEntries.fold<double>(0, (sum, e) => sum + e.amount);
    final monthLabels = _last6Months.map((m) => m.$1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reports & Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Derived from live inventory, donation, treatment, and purchase data.',
            style: TextStyle(color: AppColors.mutedForeground)),
        const SizedBox(height: 20),
        StatCardRow(cards: [
          StatCard(
            label: 'Items Tracked',
            value: '${_items.length}',
            icon: Icons.inventory_2_outlined,
            accent: AppColors.roleManager,
          ),
          StatCard(
            label: 'Total Stock',
            value: formatQty(totalStock),
            icon: Icons.widgets_outlined,
            accent: AppColors.roleManager,
          ),
          StatCard(
            label: 'Total Donations',
            value: '${_donationDates.length}',
            icon: Icons.volunteer_activism_outlined,
            accent: AppColors.roleDonor,
          ),
          StatCard(
            label: 'Total Purchase Spend',
            value: '₱${totalSpend.toStringAsFixed(0)}',
            icon: Icons.receipt_long_outlined,
            accent: AppColors.roleStaff,
          ),
        ]),
        const SizedBox(height: 24),
        _ReportCard(
          title: 'Inventory by Category',
          child: _categoryStock.isEmpty
              ? const _EmptyNote(text: 'No inventory items yet.')
              : _CategoryBreakdown(data: _categoryStock),
        ),
        const SizedBox(height: 20),
        _ReportCard(
          title: 'Donations (Last 6 Months)',
          child: _donationDates.isEmpty
              ? const _EmptyNote(text: 'No completed donations yet.')
              : _MonthlyBarChart(labels: monthLabels, values: _monthlyCounts(_donationDates)),
        ),
        const SizedBox(height: 20),
        _ReportCard(
          title: 'Treatments (Last 6 Months)',
          child: _treatments.isEmpty
              ? const _EmptyNote(text: 'No treatments logged yet.')
              : _MonthlyBarChart(
                  labels: monthLabels,
                  values: _monthlyCounts(_treatments.map((t) => t.recDate).toList()),
                ),
        ),
        const SizedBox(height: 20),
        _ReportCard(
          title: 'Purchase Spend (Last 6 Months)',
          child: _spendEntries.isEmpty
              ? const _EmptyNote(text: 'No purchase orders yet.')
              : _MonthlyBarChart(
                  labels: monthLabels,
                  values: _monthlySpend(),
                  valuePrefix: '₱',
                ),
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ReportCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;
  const _EmptyNote({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground));
  }
}

/// Simple horizontal breakdown -- a labeled row + proportional bar per
/// category, sorted largest first. No charting package required.
class _CategoryBreakdown extends StatelessWidget {
  final Map<String, double> data;
  const _CategoryBreakdown({required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.first.value;

    return Column(
      children: [
        for (final entry in entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${entry.value.toInt()}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: maxValue == 0 ? 0 : entry.value / maxValue,
                    minHeight: 8,
                    backgroundColor: AppColors.muted,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Simple monthly column chart built from plain widgets -- no charting
/// package required for a handful of bars.
class _MonthlyBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final String valuePrefix;

  const _MonthlyBarChart({
    required this.labels,
    required this.values,
    this.valuePrefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    const chartHeight = 140.0;

    return SizedBox(
      height: chartHeight + 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      values[i] == 0
                          ? ''
                          : '$valuePrefix${values[i] % 1 == 0 ? values[i].toInt() : values[i].toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 11, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: maxValue == 0 ? 2 : (values[i] / maxValue) * chartHeight,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(labels[i],
                        style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
