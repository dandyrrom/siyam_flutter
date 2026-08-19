import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../services/dashboard_service.dart';
import '../services/expiry_alerts.dart';
import 'hoverable_row.dart';

// ============================================================================
// NOTIFICATION TYPES
// ============================================================================
//
// Keep "expiry" as the existing route value for upcoming expiry warnings.
// Add "expired" as a separate route for physical expired stock.
// ============================================================================

enum NotifKind {
  zeroStock,
  lowStock,
  expiry,
  expiredStock,
}

extension NotifKindRoute on NotifKind {
  String get routeSegment => switch (this) {
        NotifKind.zeroStock => 'zero',
        NotifKind.lowStock => 'low',
        NotifKind.expiry => 'expiry',
        NotifKind.expiredStock => 'expired',
      };

  static NotifKind? fromRouteSegment(String segment) => switch (segment) {
        'zero' => NotifKind.zeroStock,
        'low' => NotifKind.lowStock,
        'expiry' => NotifKind.expiry,
        'expired' => NotifKind.expiredStock,
        _ => null,
      };

  IconData get icon => switch (this) {
        NotifKind.zeroStock =>
          Icons.remove_shopping_cart_outlined,
        NotifKind.lowStock =>
          Icons.warning_amber_outlined,
        NotifKind.expiry =>
          Icons.schedule_outlined,
        NotifKind.expiredStock =>
          Icons.event_busy_outlined,
      };

  String get label => switch (this) {
        NotifKind.zeroStock => 'Zero Stock',
        NotifKind.lowStock => 'Low Stock',
        NotifKind.expiry => 'Expiring Soon',
        NotifKind.expiredStock => 'Expired Stock',
      };
}

// ============================================================================
// COMPACT NOTIFICATION
// ============================================================================

class CompactNotif {
  final NotifKind kind;
  final String itemId;
  final String itemName;
  final String subtitle;
  final Color accent;

  const CompactNotif({
    required this.kind,
    required this.itemId,
    required this.itemName,
    required this.subtitle,
    required this.accent,
  });
}

// ============================================================================
// EXPIRY TEXT
// ============================================================================

String formatExpirySubtitle(int daysUntilExpiry) {
  if (daysUntilExpiry < 0) {
    final daysAgo = -daysUntilExpiry;

    return 'Expired $daysAgo '
        'day${daysAgo == 1 ? '' : 's'} ago';
  }

  if (daysUntilExpiry == 0) {
    return 'Expires today';
  }

  return 'Expires in $daysUntilExpiry '
      'day${daysUntilExpiry == 1 ? '' : 's'}';
}

String _expiryQuantity(ExpiryAlert alert) {
  if (alert.qty == null ||
      alert.unitAbbr == null ||
      alert.unitAbbr!.trim().isEmpty) {
    return '';
  }

  return '${formatQty(alert.qty!)} ${alert.unitAbbr}';
}

// ============================================================================
// BUILD NOTIFICATIONS
// ============================================================================
//
// Severity:
//
// 1. Zero Stock
// 2. Expired Stock requiring removal
// 3. Low Stock
// 4. Expiring Soon
//
// The same item may legitimately appear more than once when separate actions
// are required.
// ============================================================================

List<CompactNotif> buildCompactNotifs(
  ManagerDashboardStats stats,
) {
  final expired = stats.expiringSoonItems.where(
    (alert) =>
        alert.kind ==
        ExpiryAlertKind.expiredStock,
  );

  final upcoming = stats.expiringSoonItems.where(
    (alert) =>
        alert.kind ==
        ExpiryAlertKind.expiringSoon,
  );

  return [
    for (final item in stats.zeroStockItems)
      CompactNotif(
        kind: NotifKind.zeroStock,
        itemId: item.itemId,
        itemName: item.itemName,
        subtitle: 'No usable stock remaining',
        accent: AppColors.destructive,
      ),

    for (final alert in expired)
      CompactNotif(
        kind: NotifKind.expiredStock,
        itemId: alert.itemId,
        itemName: alert.itemName,
        subtitle: _expiryQuantity(alert).isNotEmpty
            ? '${_expiryQuantity(alert)} expired · removal required'
            : '${formatExpirySubtitle(alert.daysUntilExpiry)} · removal required',
        accent: AppColors.destructive,
      ),

    for (final item in stats.lowStockItems)
      CompactNotif(
        kind: NotifKind.lowStock,
        itemId: item.itemId,
        itemName: item.itemName,
        subtitle:
            '${formatQty(item.stockQty)} '
            '${item.unitAbbr} equivalent left '
            '(≤ ${formatQty(lowStockPurchaseUnitThreshold)})',
        accent: AppColors.warning,
      ),

    for (final alert in upcoming)
      CompactNotif(
        kind: NotifKind.expiry,
        itemId: alert.itemId,
        itemName: alert.itemName,
        subtitle: _expiryQuantity(alert).isNotEmpty
            ? '${_expiryQuantity(alert)} · '
                '${formatExpirySubtitle(alert.daysUntilExpiry)}'
            : formatExpirySubtitle(
                alert.daysUntilExpiry,
              ),
        accent: AppColors.warning,
      ),
  ];
}

// ============================================================================
// COMPACT TILE
// ============================================================================

class CompactNotificationTile extends StatelessWidget {
  final CompactNotif notif;
  final VoidCallback onTap;
  final bool dense;

  const CompactNotificationTile({
    super.key,
    required this.notif,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return HoverableRow(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 12 : 16,
          vertical: dense ? 8 : 12,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: notif.accent.withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                notif.kind.icon,
                size: 16,
                color: notif.accent,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notif.itemName,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      Text(
                        notif.kind.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight:
                              FontWeight.w600,
                          color: notif.accent,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 2),

                  Text(
                    notif.subtitle,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color:
                          AppColors.mutedForeground,
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
    );
  }
}

// ============================================================================
// COMPACT LIST
// ============================================================================

class CompactNotificationList extends StatelessWidget {
  final List<CompactNotif> notifs;
  final void Function(CompactNotif notif)
      onTapNotif;
  final String emptyText;
  final bool dense;

  const CompactNotificationList({
    super.key,
    required this.notifs,
    required this.onTapNotif,
    this.emptyText =
        'No notifications right now.',
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(
          dense ? 12 : 16,
        ),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: notifs.isEmpty
          ? Padding(
              padding:
                  const EdgeInsets.all(20),
              child: Text(
                emptyText,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            )
          : Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                for (var i = 0;
                    i < notifs.length;
                    i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      color: AppColors.border,
                    ),

                  CompactNotificationTile(
                    notif: notifs[i],
                    dense: dense,
                    onTap: () =>
                        onTapNotif(
                      notifs[i],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}