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
    // ============================================================
    // MOBILE DETECTION: Check if screen width is less than 600px
    // ============================================================
    final bool isMobile = MediaQuery.of(context).size.width < 600;

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
        // ============================================================
        // HEADER: Responsive title
        // ============================================================
        Text(
          'Reports & Analytics',
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Derived from live inventory, donation, treatment, and purchase data.',
          style: TextStyle(
            fontSize: isMobile ? 12.5 : 14,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 20),

        // ============================================================
        // STAT CARDS: 2 per row on mobile, 4 per row on web
        // ============================================================
        isMobile
            ? _buildMobileStatCards(
                itemsCount: _items.length,
                totalStock: totalStock,
                donationCount: _donationDates.length,
                totalSpend: totalSpend,
              )
            : StatCardRow(cards: [
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

        SizedBox(height: isMobile ? 16 : 24),

        _ReportCard(
          title: 'Inventory by Category',
          isMobile: isMobile,
          child: _categoryStock.isEmpty
              ? const _EmptyNote(text: 'No inventory items yet.')
              : _CategoryBreakdown(data: _categoryStock),
        ),
        SizedBox(height: isMobile ? 12 : 20),
        _ReportCard(
          title: 'Donations (Last 6 Months)',
          isMobile: isMobile,
          child: _donationDates.isEmpty
              ? const _EmptyNote(text: 'No completed donations yet.')
              : _MonthlyBarChart(labels: monthLabels, values: _monthlyCounts(_donationDates)),
        ),
        SizedBox(height: isMobile ? 12 : 20),
        _ReportCard(
          title: 'Treatments (Last 6 Months)',
          isMobile: isMobile,
          child: _treatments.isEmpty
              ? const _EmptyNote(text: 'No treatments logged yet.')
              : _MonthlyBarChart(
                  labels: monthLabels,
                  values: _monthlyCounts(_treatments.map((t) => t.recDate).toList()),
                ),
        ),
        SizedBox(height: isMobile ? 12 : 20),
        _ReportCard(
          title: 'Purchase Spend (Last 6 Months)',
          isMobile: isMobile,
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

  // ============================================================
  // MOBILE: Stat cards in 2-column grid
  // ============================================================
  Widget _buildMobileStatCards({
    required int itemsCount,
    required double totalStock,
    required int donationCount,
    required double totalSpend,
  }) {
    final cards = [
      _MobileStatCard(
        label: 'Items Tracked',
        value: '$itemsCount',
        icon: Icons.inventory_2_outlined,
        accent: AppColors.roleManager,
      ),
      _MobileStatCard(
        label: 'Total Stock',
        value: formatQty(totalStock),
        icon: Icons.widgets_outlined,
        accent: AppColors.roleManager,
      ),
      _MobileStatCard(
        label: 'Total Donations',
        value: '$donationCount',
        icon: Icons.volunteer_activism_outlined,
        accent: AppColors.roleDonor,
      ),
      _MobileStatCard(
        label: 'Total Purchase Spend',
        value: '₱${totalSpend.toStringAsFixed(0)}',
        icon: Icons.receipt_long_outlined,
        accent: AppColors.roleStaff,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.4,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) => cards[index],
    );
  }
}

// ============================================================
// MOBILE STAT CARD
// ============================================================
class _MobileStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _MobileStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: accent),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MODIFIED: _ReportCard with responsive padding
// ============================================================
class _ReportCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool isMobile;

  const _ReportCard({
    required this.title,
    required this.child,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: isMobile ? 14 : 15,
            ),
          ),
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
    // ============================================================
    // MOBILE DETECTION: Smaller chart on mobile to prevent overflow
    // ============================================================
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final maxValue = values.fold<double>(0, (m, v) => v > m ? v : m);
    final chartHeight = isMobile ? 100.0 : 140.0;
    final labelFontSize = isMobile ? 11.0 : 12.0;
    final valueFontSize = isMobile ? 10.0 : 11.0;
    final barWidth = isMobile ? 28.0 : 30.0;
    final horizontalPadding = isMobile ? 4.0 : 6.0;

    // ============================================================
    // FIX: Calculate total height to prevent overflow
    // ============================================================
    // chartHeight (bars) + 20 for value text + 20 for month labels + 20 padding
    final totalHeight = chartHeight + 60;

    return SizedBox(
      height: totalHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      values[i] == 0
                          ? ''
                          : '$valuePrefix${values[i] % 1 == 0 ? values[i].toInt() : values[i].toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: valueFontSize,
                        color: AppColors.mutedForeground,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: barWidth,
                      height: maxValue == 0 ? 2 : (values[i] / maxValue) * chartHeight,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: labelFontSize,
                        color: AppColors.mutedForeground,
                      ),
                      overflow: TextOverflow.ellipsis,
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

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];