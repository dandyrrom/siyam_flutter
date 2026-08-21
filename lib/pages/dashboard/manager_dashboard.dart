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
/// 4. Replenishment rows are traceable directly to Inventory Item Details.
/// 5. Staff Accounts opens a Manager-only modal with enable/disable controls.
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

  @override
  void initState() {
    super.initState();
    _load();
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
          content: SizedBox(
            width: 390,
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

    final dialogWidth =
        screen.width < 640
            ? screen.width - 72
            : 560.0;

    final dialogHeight =
        screen.height < 720
            ? screen.height * 0.58
            : 470.0;

    final compactRows =
        screen.width < 520;

    final activeCount =
        _staff.where((user) => user.isActive).length;

    final disabledCount =
        _staff.length - activeCount;

    return AlertDialog(
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
          Text('Staff Accounts'),
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
                            : ListView.separated(
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
                      constraints:
                          const BoxConstraints(
                        minWidth: 26,
                        minHeight: 24,
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 7,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${items.length}',
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
