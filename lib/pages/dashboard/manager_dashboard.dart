import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../models/inventory_item.dart';
import '../../services/dashboard_service.dart';
import '../../state/auth_state.dart';
import '../../state/data_bus.dart';
import '../../widgets/stat_card.dart';

/// Manager Dashboard
///
/// PANEL REQUIREMENTS ADDRESSED HERE:
///
/// 1. Dashboard metric cards are clickable.
/// 2. Cards lead to their relevant full module/detail view.
/// 3. Replenishment item description and quantity are kept visually together.
/// 4. Replenishment rows are traceable directly to Inventory Item Details.
class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard>
    with DataBusRefreshMixin<ManagerDashboard> {
  final DashboardService _service = DashboardService();

  // ===========================================================================
  // REPLENISHMENT SECTION KEY
  // ===========================================================================

  final GlobalKey _replenishmentKey = GlobalKey();

  ManagerDashboardStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _load(),
    );
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  // ===========================================================================
  // LOAD DASHBOARD
  // ===========================================================================

  Future<void> _load({bool silent = false}) async {
    final authController =
        Provider.of<AuthController>(context, listen: false);

    if (!authController.isAuthenticated) {
      if (!silent && mounted) {
        setState(() {
          _loading = false;
          _error = 'Please log in to view the dashboard.';
        });
      }
      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final stats = await _service.fetchManagerStats();

      if (!mounted) return;

      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final errorStr = e.toString().toLowerCase();

      if (!silent) {
        setState(() {
          if (errorStr.contains('jwt') ||
              errorStr.contains('token') ||
              errorStr.contains('auth') ||
              errorStr.contains('permission denied') ||
              errorStr.contains('unauthorized')) {
            _error =
                'Your session may have expired. Please refresh the page.';
          } else {
            _error = 'Could not load dashboard: $e';
          }

          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await _load(silent: false);
  }

  // ===========================================================================
  // MANAGER NAME
  // ===========================================================================

  String _getUserDisplayName(AuthController authController) {
    final profile = authController.profile;

    if (profile == null) return 'User';

    final firstName = profile.firstName.trim();
    final lastName = profile.lastName.trim();

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '$firstName $lastName';
    }

    if (firstName.isNotEmpty) return firstName;
    if (lastName.isNotEmpty) return lastName;

    if (profile.email.isNotEmpty) {
      return profile.email.split('@')[0];
    }

    return 'User';
  }

  // ===========================================================================
  // CARD NAVIGATION
  // ===========================================================================

  void _goTo(String route) {
    context.go(route);
  }

  Future<void> _scrollToReplenishment() async {
    final targetContext = _replenishmentKey.currentContext;

    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  void _openInventoryItem(DashboardStockAlert item) {
    context.push('/inventory/${item.itemId}');
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final authController =
        Provider.of<AuthController>(context);

    if (!authController.isAuthenticated) {
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
              Text('Redirecting to login'),
            ],
          ),
        ),
      );
    }

    final displayName =
        _getUserDisplayName(authController);

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================================
            // HEADER
            // =================================================================

            Text(
              'Welcome, $displayName!',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
            ),

            const SizedBox(height: 8),

            Text(
              'Monitor sanctuary operations, inventory alerts, and records requiring attention.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
                    color: AppColors.mutedForeground,
                  ),
            ),

            const SizedBox(height: 24),

            // =================================================================
            // ERROR STATE
            // =================================================================

            if (_error != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: AppColors.destructive,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _refreshData,
                    child: const Text('Retry'),
                  ),
                ],
              )
            else ...[
              // ===============================================================
              // ORGANIZATION CARDS
              // ===============================================================
              //
              // Each card now opens the relevant full module.
              // ===============================================================

              StatCardRow(
                cards: [
                  StatCard(
                    label: 'Total Animals',
                    value: _loading
                        ? '—'
                        : '${_stats!.totalAnimals}',
                    icon: Icons.pets_outlined,
                    accent: AppColors.roleManager,
                    tooltip: 'Open animal records',
                    onTap: _loading
                        ? null
                        : () => _goTo('/animal-records'),
                  ),
                  StatCard(
                    label: 'Suppliers',
                    value: _loading
                        ? '—'
                        : '${_stats!.totalSuppliers}',
                    icon: Icons.local_shipping_outlined,
                    accent: AppColors.roleManager,
                    tooltip: 'Open suppliers',
                    onTap: _loading
                        ? null
                        : () => _goTo('/suppliers'),
                  ),
                  StatCard(
                    label: 'Pending Submissions',
                    value: _loading
                        ? '—'
                        : '${_stats!.pendingSubmissions}',
                    icon: Icons.fact_check_outlined,
                    accent: AppColors.roleManager,
                    tooltip: 'Open donation submissions',
                    onTap: _loading
                        ? null
                        : () => _goTo('/donations'),
                  ),
                  StatCard(
                    label: 'Staff Accounts',
                    value: _loading
                        ? '—'
                        : '${_stats!.staffAccounts}',
                    icon: Icons.badge_outlined,
                    accent: AppColors.roleManager,
                    tooltip: 'Open account settings',
                    onTap: _loading
                        ? null
                        : () => _goTo('/settings'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // ===============================================================
              // INVENTORY CARDS
              // ===============================================================

              StatCardRow(
                cards: [
                  StatCard(
                    label: 'Total Inventory Items',
                    value: _loading
                        ? '—'
                        : '${_stats!.totalItems}',
                    icon: Icons.inventory_2_outlined,
                    accent: AppColors.roleManager,
                    tooltip: 'Open inventory',
                    onTap: _loading
                        ? null
                        : () => _goTo('/inventory'),
                  ),
                  StatCard(
                    label: 'Zero Stock',
                    value: _loading
                        ? '—'
                        : '${_stats!.zeroStockCount}',
                    icon: Icons.remove_shopping_cart_outlined,
                    accent: AppColors.destructive,
                    tooltip: 'View zero-stock items',
                    onTap: _loading
                        ? null
                        : _scrollToReplenishment,
                  ),
                  StatCard(
                    label: 'Low Stock',
                    value: _loading
                        ? '—'
                        : '${_stats!.lowStockCount}',
                    icon: Icons.warning_amber_outlined,
                    accent: AppColors.warning,
                    tooltip: 'View low-stock items',
                    onTap: _loading
                        ? null
                        : _scrollToReplenishment,
                  ),

                  // ===========================================================
                  // EXPIRY ALERT CARD
                  // ===========================================================
                  //
                  // The notification system now includes both:
                  // - expired physical stock
                  // - upcoming expiry warnings
                  //
                  // "Expiry Alerts" is therefore more accurate than the old
                  // "Expiring Soon" label.
                  // ===========================================================

                  StatCard(
                    label: 'Expiry Alerts',
                    value: _loading
                        ? '—'
                        : '${_stats!.expiringSoonCount}',
                    icon: Icons.event_busy_outlined,
                    accent: AppColors.warning,
                    tooltip: 'Open expiry notifications',
                    onTap: _loading
                        ? null
                        : () => _goTo('/notifications'),
                  ),
                ],
              ),

              // ===============================================================
              // PENDING SUBMISSION NOTICE
              // ===============================================================

              if (!_loading &&
                  _stats!.pendingSubmissions > 0 &&
                  _stats!.zeroStockCount +
                          _stats!.lowStockCount ==
                      0) ...[
                const SizedBox(height: 12),
                _InfoBanner(
                  icon: Icons.inbox_outlined,
                  text:
                      '${_stats!.pendingSubmissions} donor submission(s) are awaiting review on the Donations page.',
                ),
              ],

              const SizedBox(height: 28),

              // ===============================================================
              // REPLENISHMENT SECTION HEADER
              // ===============================================================

              KeyedSubtree(
                key: _replenishmentKey,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replenishment List',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Items requiring stock attention. Select an item to view its full inventory details.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color:
                                  AppColors.mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      onPressed: () => _goTo('/inventory'),
                      icon: const Icon(
                        Icons.inventory_2_outlined,
                        size: 16,
                      ),
                      label: const Text('Open Inventory'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ===============================================================
              // REPLENISHMENT LIST
              // ===============================================================

              if (_loading)
                const SizedBox(
                  height: 120,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _ReplenishmentAlerts(
                  zeroStockItems:
                      _stats!.zeroStockItems,
                  lowStockItems:
                      _stats!.lowStockItems,
                  onOpenItem: _openInventoryItem,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// REPLENISHMENT ALERTS
// =============================================================================

class _ReplenishmentAlerts extends StatelessWidget {
  final List<DashboardStockAlert> zeroStockItems;
  final List<DashboardStockAlert> lowStockItems;
  final void Function(DashboardStockAlert item)
      onOpenItem;

  const _ReplenishmentAlerts({
    required this.zeroStockItems,
    required this.lowStockItems,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    if (zeroStockItems.isEmpty &&
        lowStockItems.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 18,
              color: AppColors.roleManager,
            ),
            SizedBox(width: 8),
            Text(
              'No zero-stock or low-stock items right now.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    final zeroPanel = zeroStockItems.isEmpty
        ? null
        : _StockAlertPanel(
            title: 'Zero Stock',
            subtitle:
                'Items with no usable inventory remaining.',
            accent: AppColors.destructive,
            icon:
                Icons.remove_shopping_cart_outlined,
            items: zeroStockItems,
            onOpenItem: onOpenItem,
          );

    final lowPanel = lowStockItems.isEmpty
        ? null
        : _StockAlertPanel(
            title: 'Low Stock',
            subtitle:
                'At or below ${formatQty(lowStockPurchaseUnitThreshold)} purchase-unit equivalent.',
            accent: AppColors.warning,
            icon: Icons.warning_amber_outlined,
            items: lowStockItems,
            onOpenItem: onOpenItem,
          );

    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide =
            constraints.maxWidth > 720;

        if (sideBySide &&
            zeroPanel != null &&
            lowPanel != null) {
          return Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(child: zeroPanel),
              const SizedBox(width: 16),
              Expanded(child: lowPanel),
            ],
          );
        }

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            if (zeroPanel != null) zeroPanel,
            if (zeroPanel != null &&
                lowPanel != null)
              const SizedBox(height: 16),
            if (lowPanel != null) lowPanel,
          ],
        );
      },
    );
  }
}

// =============================================================================
// STOCK ALERT PANEL
// =============================================================================

class _StockAlertPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final List<DashboardStockAlert> items;
  final void Function(DashboardStockAlert item)
      onOpenItem;

  const _StockAlertPanel({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.items,
    required this.onOpenItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===================================================================
          // PANEL HEADER
          // ===================================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              16,
              18,
              12,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                  Container(
  constraints: const BoxConstraints(
    minWidth: 26,
    minHeight: 24,
  ),
  padding: const EdgeInsets.symmetric(
    horizontal: 7,
  ),
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: accent.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Text(
    '${items.length}',
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      color: accent,
    ),
  ),
),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color:
                        AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: AppColors.border,
          ),

          // ===================================================================
          // TRACEABLE ITEM ROWS
          // ===================================================================
          //
          // PANEL FEEDBACK:
          //
          // Description + quantity should not be visually far apart.
          //
          // The quantity is therefore placed directly beside the item name,
          // rather than pushed to the far-right edge of the card.
          //
          // The whole row opens /inventory/:itemId for traceability.
          // ===================================================================

          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: AppColors.border,
              ),
            _ReplenishmentItemRow(
              item: items[i],
              accent: accent,
              isZeroStock:
                  title == 'Zero Stock',
              onTap: () =>
                  onOpenItem(items[i]),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// REPLENISHMENT ITEM ROW
// =============================================================================

class _ReplenishmentItemRow
    extends StatelessWidget {
  final DashboardStockAlert item;
  final Color accent;
  final bool isZeroStock;
  final VoidCallback onTap;

  const _ReplenishmentItemRow({
    required this.item,
    required this.accent,
    required this.isZeroStock,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final qty =
        '${formatQty(item.stockQty)} ${item.unitAbbr}'
            .trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        mouseCursor:
            SystemMouseCursors.click,
        hoverColor:
            accent.withValues(alpha: 0.04),
        highlightColor:
            accent.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // =========================================================
                    // ITEM + QUANTITY KEPT TOGETHER
                    // =========================================================

                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      crossAxisAlignment:
                          WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.itemName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(
                              alpha: 0.10,
                            ),
                            borderRadius:
                                BorderRadius.circular(8),
                          ),
                          child: Text(
                            qty,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight:
                                  FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      isZeroStock
                          ? 'Requires replenishment'
                          : 'Stock is at or below the low-stock threshold',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.chevron_right,
                size: 18,
                color:
                    AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// INFO BANNER
// =============================================================================

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBanner({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}