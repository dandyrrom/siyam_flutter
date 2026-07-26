import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../models/inventory_item.dart';
import '../../services/dashboard_service.dart';
import '../../services/inventory_service.dart';
import '../../services/treatment_service.dart';
import '../../state/auth_state.dart';
import '../../state/data_bus.dart';
import '../../widgets/stat_card.dart';

/// Manager Dashboard - Provides a comprehensive overview of the sanctuary's
/// inventory health, stock alerts, usage trends, and key metrics.
/// This dashboard is specifically designed for managers with role-based access.
class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard>
    with DataBusRefreshMixin<ManagerDashboard> {
  // Service that fetches dashboard data from Supabase
  final DashboardService _service = DashboardService();
  // Chart data — loaded here only; full breakdown lives on Reports & Analytics.
  final TreatmentService _treatmentService = TreatmentService();
  final InventoryService _inventoryService = InventoryService();

  // GlobalKey used to scroll to the replenishment section when the button is pressed
  final GlobalKey _replenishmentKey = GlobalKey();

  // Dashboard statistics fetched from the database
  ManagerDashboardStats? _stats;

  // Consumption event dates for the dashboard-only usage overview chart.
  List<DateTime> _usageEventDates = [];

  // Loading state indicator
  bool _loading = true;

  // Error message if data fetching fails
  String? _error;

  @override
  void initState() {
    super.initState();
    // Load data after a short delay to ensure auth is restored
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  /// Called when external data changes (via DataBus refresh events)
  /// Silently refreshes data without showing loading indicators
  @override
  void onExternalDataChanged() => _load(silent: true);

  /// Loads dashboard data from the Supabase database
  /// [silent] - If true, doesn't show loading indicators or error messages
  Future<void> _load({bool silent = false}) async {
    // Check if user is authenticated before loading
    final authController = Provider.of<AuthController>(context, listen: false);

    // If not authenticated, don't try to load data
    if (!authController.isAuthenticated) {
      if (!silent) {
        setState(() {
          _loading = false;
          _error = 'Please log in to view the dashboard.';
        });
      }
      return;
    }

    // Show loading state only if not silent refresh
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Stats for cards/alerts; chart dates fetched separately (dashboard overview only).
      final results = await Future.wait([
        _service.fetchManagerStats(),
        _treatmentService.fetchUsageEventDates(),
        _inventoryService.fetchStockOutDates(),
      ]);

      if (!mounted) return;

      final stats = results[0] as ManagerDashboardStats;
      final treatmentDates = results[1] as List<DateTime>;
      final stockOutDates = results[2] as List<DateTime>;

      setState(() {
        _stats = stats;
        _usageEventDates = [...treatmentDates, ...stockOutDates];
        _loading = false;
      });
    } catch (e) {
      // Handle errors gracefully
      if (!mounted) return;

      // Check if error is authentication-related
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('jwt') ||
          errorStr.contains('token') ||
          errorStr.contains('auth') ||
          errorStr.contains('permission denied') ||
          errorStr.contains('unauthorized')) {
        // Token expired or invalid, but don't redirect - let auth_state handle it
        if (!silent) {
          setState(() {
            _error = 'Your session may have expired. Please refresh the page.';
            _loading = false;
          });
        }
      } else {
        // Other errors
        if (!silent) {
          setState(() {
            _error = 'Could not load dashboard: $e';
            _loading = false;
          });
        }
      }
    }
  }

  /// Refresh dashboard data with visible loading
  Future<void> _refreshData() async {
    await _load(silent: false);
  }

  /// Last 6 calendar months (oldest first).
  List<(String, String)> get _last6Months {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final d = DateTime(now.year, now.month - (5 - i));
      return (_monthAbbrev[d.month - 1], '${d.year}-${d.month}');
    });
  }

  String _bucketKey(DateTime d) => '${d.year}-${d.month}';

  List<double> _monthlyUsageCounts(List<DateTime> dates) {
    final months = _last6Months;
    return [
      for (final (_, key) in months)
        dates.where((d) => _bucketKey(d) == key).length.toDouble(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Listen to auth state changes
    final authController = Provider.of<AuthController>(context);

    // If not authenticated, show message and redirect to login
    if (!authController.isAuthenticated) {
      // Redirect to login after a short delay
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.mounted) {
          context.go('/login');
        }
      });
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Redirecting to login...'),
            ],
          ),
        ),
      );
    }

    // Wrap with RefreshIndicator for pull-to-refresh functionality
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== SECTION 1: DASHBOARD HEADER =====
            // Displays the title and subtitle with description
            const DashboardHeader(
              title: 'Manager Dashboard',
              subtitle:
                  'Inventory health, stock alerts, usage trends, and sanctuary-wide overview.',
            ),

            // ===== SECTION 2: ERROR STATE =====
            // Shows error message and retry button if data loading fails
            if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_error!,
                      style: const TextStyle(color: AppColors.destructive)),
                  const SizedBox(height: 8),
                  OutlinedButton(
                      onPressed: _refreshData, child: const Text('Retry')),
                ],
              )
            else ...[
              // ===== SECTION 3: STAT CARDS ROW 1 =====
              // Displays key metrics: Animals, Suppliers, Submissions, Staff
              // Data comes from: pet table, supplier table, submission table (pending), users table (staff role)
              StatCardRow(cards: [
                StatCard(
                  label: 'Total Animals',
                  value: _loading ? '—' : '${_stats!.totalAnimals}',
                  icon: Icons.pets_outlined,
                  accent: AppColors.roleManager,
                ),
                StatCard(
                  label: 'Suppliers',
                  value: _loading ? '—' : '${_stats!.totalSuppliers}',
                  icon: Icons.local_shipping_outlined,
                  accent: AppColors.roleManager,
                ),
                StatCard(
                  label: 'Pending Submissions',
                  value: _loading ? '—' : '${_stats!.pendingSubmissions}',
                  icon: Icons.fact_check_outlined,
                  accent: AppColors.roleManager,
                ),
                StatCard(
                  label: 'Staff Accounts',
                  value: _loading ? '—' : '${_stats!.staffAccounts}',
                  icon: Icons.badge_outlined,
                  accent: AppColors.roleManager,
                ),
              ]),
              const SizedBox(height: 16),

              // ===== SECTION 4: STAT CARDS ROW 2 =====
              // Displays inventory metrics: Total Items, Zero Stock, Low Stock, Expiring Soon
              // Data comes from: item table with stock calculations
              StatCardRow(cards: [
                StatCard(
                  label: 'Total Inventory Items',
                  value: _loading ? '—' : '${_stats!.totalItems}',
                  icon: Icons.inventory_2_outlined,
                  accent: AppColors.roleManager,
                ),
                StatCard(
                  label: 'Zero Stock',
                  value: _loading ? '—' : '${_stats!.zeroStockCount}',
                  icon: Icons.remove_shopping_cart_outlined,
                  accent: AppColors.destructive,
                ),
                StatCard(
                  label: 'Low Stock',
                  value: _loading ? '—' : '${_stats!.lowStockCount}',
                  icon: Icons.warning_amber_outlined,
                  accent: AppColors.warning,
                ),
                StatCard(
                  label: 'Expiring Soon',
                  value: _loading
                      ? '—'
                      : (_stats!.expiryTrackingAvailable
                          ? '${_stats!.expiringSoonCount}'
                          : 'N/A'),
                  icon: Icons.event_busy_outlined,
                  accent: AppColors.warning,
                ),
              ]),

              // ===== SECTION 5: EXPIRY TRACKING NOTICE =====
              // Shows informational message when expiry tracking is not yet available
              // This feature requires an expiration_date field in the item table
              if (!_loading && !_stats!.expiryTrackingAvailable) ...[
                const SizedBox(height: 12),
                const ComingSoonNotice(
                  text:
                      'Expiry warnings need an expiration date on stock batches — '
                      'that field is not in the schema yet, so this alert stays empty.',
                ),
              ],

              // ===== SECTION 6: PENDING SUBMISSIONS BANNER =====
              // Shows info banner when there are pending submissions but no stock alerts
              // Helps staff know about pending donor submissions that need review
              if (!_loading &&
                  _stats!.pendingSubmissions > 0 &&
                  _stats!.zeroStockCount + _stats!.lowStockCount == 0) ...[
                const SizedBox(height: 12),
                _InfoBanner(
                  icon: Icons.inbox_outlined,
                  text:
                      '${_stats!.pendingSubmissions} donor submission(s) awaiting staff review on the Donations page.',
                ),
              ],

              const SizedBox(height: 24),

              // ===== SECTION 7: REPLENISHMENT LIST =====
              // Shows items that need restocking (zero stock and low stock)
              // Uses a GlobalKey to enable scrolling to this section
              Text(
                'Replenishment List',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              KeyedSubtree(
                key: _replenishmentKey, // Allows scrolling to this section
                child: _loading
                    ? const SizedBox(
                        height: 120,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : _ReplenishmentAlerts(
                        zeroStockItems: _stats!.zeroStockItems,
                        lowStockItems: _stats!.lowStockItems,
                      ),
              ),

              const SizedBox(height: 24),

              // Dashboard-only usage overview — Reports page has the full analytics.
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monthly Stock Usage',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Quick snapshot of consumption (last 6 months). '
                          'See Reports & Analytics for donations, treatments, and spend.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.mutedForeground,
                              ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/reports'),
                    child: const Text('View reports'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _loading
                  ? const SizedBox(
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _UsageChartCard(
                      usageDates: _usageEventDates,
                      monthLabels: _last6Months.map((m) => m.$1).toList(),
                      values: _monthlyUsageCounts(_usageEventDates),
                    ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card wrapper + empty state for the dashboard usage overview chart.
class _UsageChartCard extends StatelessWidget {
  final List<DateTime> usageDates;
  final List<String> monthLabels;
  final List<double> values;

  const _UsageChartCard({
    required this.usageDates,
    required this.monthLabels,
    required this.values,
  });

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
      child: usageDates.isEmpty || values.every((v) => v == 0)
          ? const Text(
              'No stock usage recorded in the last 6 months.',
              style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
            )
          : _MonthlyBarChart(labels: monthLabels, values: values),
    );
  }
}

/// Simple monthly column chart — dashboard overview only.
class _MonthlyBarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;

  const _MonthlyBarChart({required this.labels, required this.values});

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
                          : (values[i] % 1 == 0
                              ? values[i].toInt().toString()
                              : values[i].toStringAsFixed(0)),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.mutedForeground,
                      ),
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
                    Text(
                      labels[i],
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
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

/// Widget that displays zero and low stock alerts in a responsive layout
/// Shows items that need to be reordered based on current stock levels
/// Data comes from Supabase: item table with total_purchase_stocks and total_package_stocks
class _ReplenishmentAlerts extends StatelessWidget {
  final List<DashboardStockAlert>
      zeroStockItems; // Items with no stock available
  final List<DashboardStockAlert> lowStockItems; // Items below threshold

  const _ReplenishmentAlerts({
    required this.zeroStockItems,
    required this.lowStockItems,
  });

  @override
  Widget build(BuildContext context) {
    // ===== EMPTY STATE =====
    // Show a friendly message when there are no stock alerts
    if (zeroStockItems.isEmpty && lowStockItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Text(
          'No zero- or low-stock items right now.',
          style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
        ),
      );
    }

    // ===== CREATE ALERT PANELS =====
    // Build separate panels for zero stock and low stock items
    final zeroPanel = zeroStockItems.isNotEmpty
        ? _StockAlertPanel(
            title: 'Zero Stock', // Items with no stock available
            accent: AppColors.destructive, // Red color for urgency
            items: zeroStockItems,
            emptyLabel: 'No zero-stock items.',
          )
        : null;

    final lowPanel = lowStockItems.isNotEmpty
        ? _StockAlertPanel(
            title: 'Low Stock', // Items below reorder threshold
            subtitle:
                'At or below $kLowStockPurchaseUnitThreshold whole containers '
                '(placeholder threshold until system settings exist).',
            accent: AppColors.warning, // Yellow/amber color for caution
            items: lowStockItems,
            emptyLabel: 'No low-stock items.',
          )
        : null;

    // ===== RESPONSIVE LAYOUT =====
    // Show panels side by side on wide screens, stacked on narrow screens
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide =
            constraints.maxWidth > 720; // Breakpoint for responsive layout

        // Side by side layout for wide screens
        if (sideBySide && zeroPanel != null && lowPanel != null) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: zeroPanel),
              const SizedBox(width: 16),
              Expanded(child: lowPanel),
            ],
          );
        }

        // Stacked layout for narrow screens
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (zeroPanel != null) zeroPanel,
            if (zeroPanel != null && lowPanel != null)
              const SizedBox(height: 16),
            if (lowPanel != null) lowPanel,
          ],
        );
      },
    );
  }
}

/// Individual stock alert panel displaying a list of items that need attention
/// Shows items with their current stock quantity and unit abbreviation
class _StockAlertPanel extends StatelessWidget {
  final String title; // Panel title (e.g., "Zero Stock" or "Low Stock")
  final String? subtitle; // Optional explanatory text
  final Color accent; // Color theme for the panel
  final List<DashboardStockAlert> items; // List of stock alerts to display
  final String emptyLabel; // Message when no items are in this category

  const _StockAlertPanel({
    required this.title,
    required this.accent,
    required this.items,
    required this.emptyLabel,
    this.subtitle,
  });

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
          // ===== PANEL HEADER =====
          // Shows title with color indicator and count badge
          Row(
            children: [
              // Color indicator dot
              Icon(Icons.circle, size: 10, color: accent),
              const SizedBox(width: 8),
              // Panel title
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              // Count badge showing number of items
              Text(
                '${items.length}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),

          // ===== SUBTITLE =====
          // Display optional explanation if provided
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.mutedForeground),
            ),
          ],

          const SizedBox(height: 12),

          // ===== ITEMS LIST =====
          // Show each item with its name and current stock quantity
          if (items.isEmpty)
            // Empty state within panel
            Text(emptyLabel,
                style: const TextStyle(color: AppColors.mutedForeground))
          else
            // List of items requiring attention
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    // Item name (expanded to take available space)
                    Expanded(
                      child: Text(
                        item.itemName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    // Current stock quantity with unit abbreviation
                    Text(
                      '${formatQty(item.stockQty)} ${item.unitAbbr}'.trim(),
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.mutedForeground),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Simple information banner widget for displaying non-critical notifications
/// Used for pending submissions notice when no stock alerts exist
class _InfoBanner extends StatelessWidget {
  final IconData icon; // Icon to display
  final String text; // Message text

  const _InfoBanner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent
            .withValues(alpha: 0.12), // Semi-transparent accent color
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with accent color
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          // Message text
          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
