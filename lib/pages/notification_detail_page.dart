import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../models/inventory_item.dart';
import '../models/replenishment_item.dart';
import '../services/dashboard_service.dart';
import '../services/expiry_alerts.dart';
import '../services/inventory_service.dart';
import '../services/replenishment_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import '../widgets/notification_alerts.dart';

class NotificationDetailPage
    extends StatefulWidget {
  final NotifKind kind;
  final String itemId;

  const NotificationDetailPage({
    super.key,
    required this.kind,
    required this.itemId,
  });

  @override
  State<NotificationDetailPage>
      createState() =>
          _NotificationDetailPageState();
}

class _NotificationDetailPageState
    extends State<NotificationDetailPage>
    with
        DataBusRefreshMixin<
            NotificationDetailPage> {
  final InventoryService _inventoryService =
      InventoryService();

  final DashboardService _dashboardService =
      DashboardService();

  final ReplenishmentService _replenishmentService =
      ReplenishmentService();

  InventoryItem? _item;
  ExpiryAlert? _expiryAlert;
  ReplenishmentItem? _replenishment;

  bool _loading = true;
  bool _notFound = false;
  bool _activeAlert = true;

  bool get _isManager =>
      context
          .read<AuthController>()
          .profile
          ?.role ==
      AppRole.manager;

  bool get _canOpenInventory =>
      context
          .read<AuthController>()
          .profile
          ?.role ==
      AppRole.staff;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() {
    _load(silent: true);
  }

  Future<void> _load({
    bool silent = false,
  }) async {
    if (!silent) {
      setState(() {
        _loading = true;
      });
    }

    try {
      final results = await Future.wait<Object?>([
        _inventoryService.fetchItem(
          widget.itemId,
        ),
        _dashboardService
            .fetchManagerStats(),
        _replenishmentService
            .fetchReplenishmentItems(),
      ]);

      if (!mounted) return;

      final item =
          results[0] as InventoryItem?;

      final stats =
          results[1] as ManagerDashboardStats;

      final replenishmentRows =
          results[2] as List<ReplenishmentItem>;

      ReplenishmentItem? replenishment;

      for (final row in replenishmentRows) {
        if (row.item.itemId == widget.itemId) {
          replenishment = row;
          break;
        }
      }

      ExpiryAlert? expiryAlert;
      bool activeAlert = false;

      switch (widget.kind) {
        case NotifKind.zeroStock:
          activeAlert =
              stats.zeroStockItems.any(
            (alert) =>
                alert.itemId ==
                widget.itemId,
          );
          break;

        case NotifKind.lowStock:
          activeAlert =
              stats.lowStockItems.any(
            (alert) =>
                alert.itemId ==
                widget.itemId,
          );
          break;

        case NotifKind.expiredStock:
          for (final alert
              in stats.expiringSoonItems) {
            if (alert.itemId ==
                    widget.itemId &&
                alert.kind ==
                    ExpiryAlertKind
                        .expiredStock) {
              expiryAlert = alert;
              activeAlert = true;
              break;
            }
          }
          break;

        case NotifKind.expiry:
          for (final alert
              in stats.expiringSoonItems) {
            if (alert.itemId ==
                    widget.itemId &&
                alert.kind ==
                    ExpiryAlertKind
                        .expiringSoon) {
              expiryAlert = alert;
              activeAlert = true;
              break;
            }
          }
          break;
      }

      setState(() {
        _item = item;
        _expiryAlert = expiryAlert;
        _replenishment = replenishment;
        _notFound = item == null;
        _activeAlert = activeAlert;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_notFound || _item == null) {
      return Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .notifications_off_outlined,
              size: 40,
              color:
                  AppColors.mutedForeground,
            ),

            const SizedBox(height: 12),

            const Text(
              'Notification not found',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'The inventory item may have been removed.',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors
                    .mutedForeground,
              ),
            ),

            const SizedBox(height: 12),

            TextButton(
              onPressed: () =>
                  context.go(
                '/notifications',
              ),
              child: const Text(
                'Back to Notifications',
              ),
            ),
          ],
        ),
      );
    }

    final item = _item!;

    // =========================================================================
    // RESOLVED ALERT
    // =========================================================================

    if (!_activeAlert) {
      return ConstrainedBox(
        constraints:
            const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            TextButton.icon(
              onPressed: () =>
                  context.go(
                '/notifications',
              ),
              icon: const Icon(
                Icons.arrow_back,
                size: 16,
              ),
              label: const Text(
                'Back to Notifications',
              ),
            ),

            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius:
                    BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.border,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons
                        .check_circle_outline,
                    size: 34,
                    color:
                        AppColors.roleManager,
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'This alert is no longer active',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    'The inventory condition has already changed or been resolved.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),

                  if (_canOpenInventory) ...[
                    const SizedBox(height: 14),

                    OutlinedButton.icon(
                      onPressed: () =>
                          context.push(
                        '/inventory/${item.itemId}',
                      ),
                      icon: const Icon(
                        Icons
                            .inventory_2_outlined,
                        size: 16,
                      ),
                      label: const Text(
                        'View Inventory Item',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints:
          const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () =>
                context.go(
              '/notifications',
            ),
            icon: const Icon(
              Icons.arrow_back,
              size: 16,
            ),
            label: const Text(
              'Back to Notifications',
            ),
            style: TextButton.styleFrom(
              foregroundColor:
                  AppColors.mutedForeground,
            ),
          ),

          const SizedBox(height: 8),

          _StatusBanner(
            kind: widget.kind,
          ),

          const SizedBox(height: 20),

          Text(
            item.itemName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            item.itemCategory,
            style: const TextStyle(
              color:
                  AppColors.mutedForeground,
            ),
          ),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children:
                  _detailRows(item),
            ),
          ),

          // ===================================================================
          // GUIDANCE
          // ===================================================================

          if (_guidanceText != null) ...[
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _guidanceColor
                    .withValues(alpha: 0.08),
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                  color: _guidanceColor
                      .withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Icon(
                    _guidanceIcon,
                    size: 17,
                    color: _guidanceColor,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      _guidanceText!,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color:
                            _guidanceColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_canOpenInventory) ...[
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    context.push(
                  '/inventory/${item.itemId}',
                ),
                icon: const Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                ),
                label: Text(
                  widget.kind ==
                          NotifKind
                              .expiredStock
                      ? 'View Item & Remove Expired Stock'
                      : 'View Inventory Item',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // DETAIL ROWS
  // ===========================================================================

  List<Widget> _detailRows(
    InventoryItem item,
  ) {
    final rows = <Widget>[
      _DetailRow(
        label: 'Available stock',
        value:
            '${formatQty(item.currentUsableStockQty)} '
            '${item.currentUsableStockUnit}',
      ),
    ];

    if (item.hasPackageBreakdown) {
      rows.add(
        _DetailRow(
          label: 'Equivalent',
          value:
              '${formatQty(item.currentPurchaseUnitEquivalent)} '
              '${item.purchaseUnitAbbr}',
        ),
      );
    }

    if (widget.kind == NotifKind.lowStock &&
        _replenishment != null) {
      final rop = _replenishment!;

      rows.add(
        _DetailRow(
          label: 'Reorder point (ROP)',
          value:
              '${formatQty(rop.reorderPoint)} '
              '${item.purchaseUnitAbbr}',
        ),
      );

      rows.add(
        _DetailRow(
          label: '30-day usage',
          value:
              '${formatQty(rop.usage30PurchaseUnits)} '
              '${item.purchaseUnitAbbr}',
        ),
      );

      rows.add(
        _DetailRow(
          label: 'Average daily usage',
          value:
              '${formatQty(rop.averageDailyUsage)} '
              '${item.purchaseUnitAbbr}/day',
        ),
      );

      rows.add(
        _DetailRow(
          label: 'Lead time',
          value:
              '${rop.leadTimeDays} '
              'day${rop.leadTimeDays == 1 ? '' : 's'}',
        ),
      );

      rows.add(
        _DetailRow(
          label: 'Safety stock',
          value:
              '${formatQty(rop.safetyStockQty)} '
              '${item.purchaseUnitAbbr}',
        ),
      );
    }

    if (widget.kind ==
        NotifKind.expiredStock) {
      rows.add(
        _DetailRow(
          label: 'Expired stock',
          value:
              '${formatQty(item.expiredBatchStockQty)} '
              '${item.currentUsableStockUnit}',
        ),
      );

      if (_expiryAlert != null) {
        rows.add(
          _DetailRow(
            label: 'Oldest expired batch',
            value: _formatDate(
              _expiryAlert!.expiryDate,
            ),
          ),
        );

        rows.add(
          _DetailRow(
            label: 'Status',
            value:
                formatExpirySubtitle(
              _expiryAlert!
                  .daysUntilExpiry,
            ),
          ),
        );
      }
    }

    if (widget.kind ==
            NotifKind.expiry &&
        _expiryAlert != null) {
      final alert = _expiryAlert!;

      rows.add(
        _DetailRow(
          label: 'Nearest batch expiry',
          value:
              _formatDate(alert.expiryDate),
        ),
      );

      if (alert.qty != null &&
          alert.unitAbbr != null) {
        rows.add(
          _DetailRow(
            label: 'Batch stock',
            value:
                '${formatQty(alert.qty!)} '
                '${alert.unitAbbr}',
          ),
        );
      }

      rows.add(
        _DetailRow(
          label: 'Status',
          value:
              formatExpirySubtitle(
            alert.daysUntilExpiry,
          ),
        ),
      );
    }

    return [
      for (var i = 0;
          i < rows.length;
          i++) ...[
        if (i > 0)
          const Divider(
            height: 20,
            color: AppColors.border,
          ),

        rows[i],
      ],
    ];
  }

  String? get _guidanceText {
    if (_isManager) {
      return switch (widget.kind) {
        NotifKind.expiredStock =>
          'This stock is excluded from usable inventory and should be recorded for removal by Staff.',
        NotifKind.expiry =>
          'This is the nearest valid batch expiry. The system will automatically prioritize the earliest-expiring usable batch during dispensing.',
        NotifKind.zeroStock =>
          'No usable stock remains for this item. Replenishment may be required.',
        NotifKind.lowStock =>
          'Usable stock has reached or fallen below the calculated reorder point (ROP).',
      };
    }

    return switch (widget.kind) {
      NotifKind.expiredStock =>
        'This stock is excluded from usable inventory. Open the item, choose Dispense, then select Expired to record its removal.',
      NotifKind.expiry =>
        'This is the nearest valid batch expiry. The system will automatically prioritize the earliest-expiring usable batch during normal dispensing.',
      NotifKind.zeroStock =>
        'No usable stock remains for this item. Consider adding it to Goods Received or replenishment.',
      NotifKind.lowStock =>
        'Usable stock has reached or fallen below the calculated reorder point (ROP).',
    };
  }

  Color get _guidanceColor {
    return switch (widget.kind) {
      NotifKind.expiredStock ||
      NotifKind.zeroStock =>
        AppColors.destructive,
      NotifKind.expiry ||
      NotifKind.lowStock =>
        AppColors.warning,
    };
  }

  IconData get _guidanceIcon {
    return switch (widget.kind) {
      NotifKind.expiredStock =>
        Icons.event_busy_outlined,
      NotifKind.expiry =>
        Icons.schedule_outlined,
      NotifKind.zeroStock =>
        Icons
            .remove_shopping_cart_outlined,
      NotifKind.lowStock =>
        Icons.warning_amber_outlined,
    };
  }
}

// =============================================================================
// DATE
// =============================================================================

const _monthAbbr = [
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

String _formatDate(DateTime date) {
  return '${_monthAbbr[date.month - 1]} '
      '${date.day}, ${date.year}';
}

// =============================================================================
// STATUS BANNER
// =============================================================================

class _StatusBanner extends StatelessWidget {
  final NotifKind kind;

  const _StatusBanner({
    required this.kind,
  });

  @override
  Widget build(BuildContext context) {
    final (label, accent) = switch (kind) {
      NotifKind.zeroStock => (
          'Out of Stock',
          AppColors.destructive,
        ),
      NotifKind.lowStock => (
          'Low Stock',
          AppColors.warning,
        ),
      NotifKind.expiry => (
          'Expiring Soon',
          AppColors.warning,
        ),
      NotifKind.expiredStock => (
          'Expired Stock',
          AppColors.destructive,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            kind.icon,
            size: 16,
            color: accent,
          ),

          const SizedBox(width: 6),

          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// DETAIL ROW
// =============================================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color:
                  AppColors.mutedForeground,
            ),
          ),
        ),

        const SizedBox(width: 16),

        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
