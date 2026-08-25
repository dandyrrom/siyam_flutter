import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../models/app_user.dart';
import '../../models/inventory_item.dart';
import '../../services/auth_service.dart';
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
/// 4. Manager Replenishment is read-only and does not route into Inventory.
/// 5. Staff Accounts opens a Manager-only modal with enable/disable controls.
/// 6. Total Inventory Items opens a read-only Manager overview modal instead
///    of routing the Manager into the Staff Inventory module.
class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard>
    with DataBusRefreshMixin<ManagerDashboard> {
  final DashboardService _service = DashboardService();
  final AuthService _authService = AuthService();

  // ===========================================================================
  // REPLENISHMENT SECTION KEY
  // ===========================================================================

  final GlobalKey _replenishmentKey = GlobalKey();

  ManagerDashboardStats? _stats;
  bool _loading = true;
  String? _error;

  // Prevent repeated taps from opening duplicate Staff Account dialogs.
  bool _staffAccountsDialogOpen = false;

  // Prevent repeated taps from opening duplicate Inventory Overview dialogs.
  bool _inventoryOverviewDialogOpen = false;

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

  // ===========================================================================
  // STAFF ACCOUNTS
  // ===========================================================================

  Future<void> _openStaffAccountsDialog() async {
    if (_staffAccountsDialogOpen) {
      return;
    }

    _staffAccountsDialogOpen = true;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return _StaffAccountsDialog(
            service: _authService,
            onAccountsChanged: () {
              _load(silent: true);
            },
          );
        },
      );
    } finally {
      _staffAccountsDialogOpen = false;
    }
  }

  // ===========================================================================
  // INVENTORY OVERVIEW
  // ===========================================================================
  //
  // REVISION REQUIREMENT:
  //
  // The Manager may view an inventory summary from the Dashboard, but must
  // not be routed into the operational Staff Inventory module.
  //
  // This modal therefore uses the Manager Dashboard statistics already loaded
  // on this page. It is read-only and has no Stock In, Dispense, Edit, or
  // Inventory navigation actions.
  // ===========================================================================

  Future<void> _openInventoryOverviewDialog() async {
    if (_inventoryOverviewDialogOpen ||
        _stats == null) {
      return;
    }

    _inventoryOverviewDialogOpen = true;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return _InventoryOverviewDialog(
            stats: _stats!,
          );
        },
      );
    } finally {
      _inventoryOverviewDialogOpen = false;
    }
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
              // MANAGEMENT OVERVIEW
              // ===============================================================

              Text(
                'Management Overview',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
              ),

              const SizedBox(height: 10),

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
                    tooltip: 'View Staff accounts',
                    onTap: _loading
                        ? null
                        : _openStaffAccountsDialog,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ===============================================================
              // INVENTORY STATUS
              // ===============================================================

              Text(
                'Inventory Status',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.foreground,
                    ),
              ),

              const SizedBox(height: 10),

              StatCardRow(
                cards: [
                  StatCard(
                    label: 'Total Inventory Items',
                    value: _loading
                        ? '—'
                        : '${_stats!.totalItems}',
                    icon: Icons.inventory_2_outlined,
                    accent: AppColors.roleManager,
                    tooltip: 'View inventory overview',
                    onTap: _loading
                        ? null
                        : _openInventoryOverviewDialog,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      'Items requiring stock attention. This overview is read-only for Managers.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            AppColors.mutedForeground,
                      ),
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
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// INVENTORY OVERVIEW DIALOG
// =============================================================================

class _InventoryOverviewDialog extends StatelessWidget {
  final ManagerDashboardStats stats;

  const _InventoryOverviewDialog({
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    final dialogWidth =
        screen.width < 560
            ? screen.width - 72
            : 470.0;

    final itemsWithStock =
        (stats.totalItems - stats.zeroStockCount)
            .clamp(0, stats.totalItems);

    final stockAttention =
        stats.zeroStockCount +
            stats.lowStockCount;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 21,
            color: AppColors.roleManager,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Inventory Overview',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.visibility_outlined,
                      size: 17,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Read-only overview. Inventory operations are handled by Staff.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color:
                              AppColors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              _InventoryOverviewRow(
                label: 'Total Inventory Items',
                value: '${stats.totalItems}',
                icon:
                    Icons.inventory_2_outlined,
                accent:
                    AppColors.roleManager,
              ),

              const SizedBox(height: 8),

              _InventoryOverviewRow(
                label: 'Items With Stock',
                value: '$itemsWithStock',
                icon:
                    Icons.check_circle_outline,
                accent: AppColors.sageGreen,
              ),

              const SizedBox(height: 8),

              _InventoryOverviewRow(
                label: 'Low Stock',
                value: '${stats.lowStockCount}',
                icon:
                    Icons.warning_amber_outlined,
                accent: AppColors.warning,
              ),

              const SizedBox(height: 8),

              _InventoryOverviewRow(
                label: 'Zero Stock',
                value:
                    '${stats.zeroStockCount}',
                icon: Icons
                    .remove_shopping_cart_outlined,
                accent:
                    AppColors.destructive,
              ),

              const SizedBox(height: 8),

              _InventoryOverviewRow(
                label:
                    'Items Requiring Stock Attention',
                value: '$stockAttention',
                icon:
                    Icons.priority_high_rounded,
                accent: AppColors.warning,
              ),

              const SizedBox(height: 8),

              _InventoryOverviewRow(
                label: 'Expiry Alerts',
                value:
                    '${stats.expiringSoonCount}',
                icon:
                    Icons.event_busy_outlined,
                accent: AppColors.warning,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// =============================================================================
// INVENTORY OVERVIEW ROW
// =============================================================================

class _InventoryOverviewRow
    extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  const _InventoryOverviewRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  accent.withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              size: 17,
              color: accent,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// STAFF ACCOUNTS DIALOG
// =============================================================================

class _StaffAccountsDialog extends StatefulWidget {
  final AuthService service;
  final VoidCallback onAccountsChanged;

  const _StaffAccountsDialog({
    required this.service,
    required this.onAccountsChanged,
  });

  @override
  State<_StaffAccountsDialog> createState() =>
      _StaffAccountsDialogState();
}

class _StaffAccountsDialogState
    extends State<_StaffAccountsDialog> {
  List<AppUser> _staff = [];

  bool _loading = true;
  String? _error;
  String? _changingUserId;

  final ScrollController _staffScrollController =
      ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _staffScrollController.dispose();
    super.dispose();
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final staff =
          await widget.service.fetchStaffAccounts();

      if (!mounted) return;

      setState(() {
        _staff = staff;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = _cleanError(e);
        _loading = false;
      });
    }
  }

  Future<void> _changeAccountStatus(
    AppUser staff,
  ) async {
    if (_changingUserId != null) {
      return;
    }

    final willEnable = !staff.isActive;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (confirmContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            willEnable
                ? 'Enable Staff account?'
                : 'Disable Staff account?',
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 390,
            ),
            child: Text(
              willEnable
                  ? '${staff.fullName} will be able to sign in to SIYAM again.'
                  : '${staff.fullName} will no longer be able to sign in to SIYAM. '
                      'Their existing records and activity history will remain unchanged.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(confirmContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(confirmContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: willEnable
                    ? AppColors.sageGreen
                    : AppColors.destructive,
              ),
              child: Text(
                willEnable ? 'Enable' : 'Disable',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _changingUserId = staff.userId;
    });

    try {
      await widget.service.setStaffAccountActive(
        userId: staff.userId,
        isActive: willEnable,
      );

      if (!mounted) return;

      await _load();

      widget.onAccountsChanged();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              willEnable
                  ? '${staff.fullName} has been enabled.'
                  : '${staff.fullName} has been disabled.',
            ),
            backgroundColor: AppColors.sageGreen,
          ),
        );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'Could not update Staff account: ${_cleanError(e)}',
            ),
            backgroundColor: AppColors.destructive,
          ),
        );
    } finally {
      if (mounted) {
        setState(() {
          _changingUserId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context);

    final compactRows =
        screen.width < 520;

    final dialogWidth =
        compactRows
            ? screen.width - 32
            : 600.0;

    final availableContentHeight =
        screen.height - (compactRows ? 190 : 180);

    final dialogHeight =
        availableContentHeight
            .clamp(
              compactRows ? 280.0 : 360.0,
              compactRows ? 520.0 : 540.0,
            )
            .toDouble();

    final activeCount =
        _staff.where((user) => user.isActive).length;

    final disabledCount =
        _staff.length - activeCount;

    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compactRows ? 16 : 40,
        vertical: 24,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Row(
        children: [
          Icon(
            Icons.badge_outlined,
            size: 21,
            color: AppColors.roleManager,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text('Staff Accounts'),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 14),
                    Text(
                      'Loading Staff accounts...',
                      style: TextStyle(
                        fontSize: 12.5,
                        color:
                            AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 34,
                          color:
                              AppColors.destructive,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color:
                                AppColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _load,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _AccountCountBadge(
                            label: 'Active',
                            value: activeCount,
                            color:
                                AppColors.sageGreen,
                          ),
                          _AccountCountBadge(
                            label: 'Disabled',
                            value: disabledCount,
                            color:
                                AppColors.destructive,
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      const Text(
                        'Disable unused Staff accounts without removing their existing records.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color:
                              AppColors.mutedForeground,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Expanded(
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(
                            8,
                            8,
                            4,
                            8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),
                          child: _staff.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No Staff accounts found.',
                                    style: TextStyle(
                                      color: AppColors
                                          .mutedForeground,
                                    ),
                                  ),
                                )
                              : Scrollbar(
                                  controller:
                                      _staffScrollController,
                                  thumbVisibility:
                                      !compactRows,
                                  radius:
                                      const Radius.circular(
                                    999,
                                  ),
                                  child:
                                      ListView.separated(
                                    controller:
                                        _staffScrollController,
                                    padding:
                                        EdgeInsets.only(
                                      right: compactRows
                                          ? 4
                                          : 12,
                                    ),
                                    itemCount:
                                        _staff.length,
                                    separatorBuilder:
                                        (_, __) =>
                                            const SizedBox(
                                      height: 8,
                                    ),
                                    itemBuilder:
                                        (context, index) {
                                      final staff =
                                          _staff[index];

                                      return _StaffAccountRow(
                                        staff: staff,
                                        compact:
                                            compactRows,
                                        busy:
                                            _changingUserId ==
                                                staff.userId,
                                        disabled:
                                            _changingUserId !=
                                                    null &&
                                                _changingUserId !=
                                                    staff.userId,
                                        onToggle: () =>
                                            _changeAccountStatus(
                                          staff,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _changingUserId == null
              ? () {
                  Navigator.of(context).pop();
                }
              : null,
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// =============================================================================
// STAFF ACCOUNT ROW
// =============================================================================

class _StaffAccountRow extends StatelessWidget {
  final AppUser staff;
  final bool compact;
  final bool busy;
  final bool disabled;
  final VoidCallback onToggle;

  const _StaffAccountRow({
    required this.staff,
    required this.compact,
    required this.busy,
    required this.disabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = staff.isActive
        ? AppColors.sageGreen
        : AppColors.destructive;

    final name = staff.fullName.trim().isEmpty
        ? 'Unnamed Staff'
        : staff.fullName.trim();

    final details = Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                overflow:
                    TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 7,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(
                  alpha: 0.10,
                ),
                borderRadius:
                    BorderRadius.circular(999),
              ),
              child: Text(
                staff.isActive
                    ? 'Active'
                    : 'Disabled',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight:
                      FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 3),

        Text(
          staff.email,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            color:
                AppColors.mutedForeground,
          ),
        ),

        if ((staff.contactNum ?? '')
            .trim()
            .isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            staff.contactNum!,
            style: const TextStyle(
              fontSize: 11.5,
              color:
                  AppColors.mutedForeground,
            ),
          ),
        ],
      ],
    );

    final action = OutlinedButton.icon(
      onPressed:
          disabled || busy
              ? null
              : onToggle,
      icon: busy
          ? SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: statusColor,
              ),
            )
          : Icon(
              staff.isActive
                  ? Icons.block_outlined
                  : Icons.check_circle_outline,
              size: 15,
            ),
      label: Text(
        busy
            ? 'Saving...'
            : staff.isActive
                ? 'Disable'
                : 'Enable',
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: staff.isActive
            ? AppColors.destructive
            : AppColors.sageGreen,
      ),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: compact
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 10),
                action,
              ],
            )
          : Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor:
                      AppColors.secondary,
                  foregroundColor:
                      AppColors.foreground,
                  child: Text(
                    staff.initials.isEmpty
                        ? 'S'
                        : staff.initials,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(child: details),

                const SizedBox(width: 12),

                action,
              ],
            ),
    );
  }
}

// =============================================================================
// ACCOUNT COUNT BADGE
// =============================================================================

class _AccountCountBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _AccountCountBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
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

  const _ReplenishmentAlerts({
    required this.zeroStockItems,
    required this.lowStockItems,
  });

  @override
  Widget build(BuildContext context) {
    final zeroPanel = _StockAlertPanel(
      title: 'Zero Stock',
      subtitle: 'Items with no usable inventory remaining.',
      emptyText: 'No zero stock items as of the moment.',
      accent: AppColors.destructive,
      icon: Icons.remove_shopping_cart_outlined,
      items: zeroStockItems,
      isZeroStock: true,
    );

    final lowPanel = _StockAlertPanel(
      title: 'Low Stock',
      subtitle:
          'Usable stock has reached or fallen below its calculated reorder point (ROP).',
      emptyText: 'No low stock items as of the moment.',
      accent: AppColors.warning,
      icon: Icons.warning_amber_outlined,
      items: lowStockItems,
      isZeroStock: false,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 720) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: zeroPanel),
              const SizedBox(width: 16),
              Expanded(child: lowPanel),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            zeroPanel,
            const SizedBox(height: 16),
            lowPanel,
          ],
        );
      },
    );
  }
}

class _StockAlertPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emptyText;
  final Color accent;
  final IconData icon;
  final List<DashboardStockAlert> items;
  final bool isZeroStock;

  const _StockAlertPanel({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.accent,
    required this.icon,
    required this.items,
    required this.isZeroStock,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 16, color: accent),
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
                      padding: const EdgeInsets.symmetric(horizontal: 7),
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
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 22,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.sageGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      emptyText,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
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
                isZeroStock: isZeroStock,
              ),
            ],
        ],
      ),
    );
  }
}

class _ReplenishmentItemRow extends StatelessWidget {
  final DashboardStockAlert item;
  final Color accent;
  final bool isZeroStock;

  const _ReplenishmentItemRow({
    required this.item,
    required this.accent,
    required this.isZeroStock,
  });

  @override
  Widget build(BuildContext context) {
    final qty =
        '${formatQty(item.stockQty)} ${item.unitAbbr}'.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                item.itemName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  qty,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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
                : 'Stock is at or below the calculated reorder point (ROP)',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedForeground,
            ),
          ),
        ],
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
