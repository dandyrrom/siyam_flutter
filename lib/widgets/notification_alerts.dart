import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../services/dashboard_service.dart';

/// Which of the three alert types (see `SYSTEM_SETTINGS` in updated_db.md)
/// a [CompactNotif] represents. The string form is the route segment used by
/// `/notifications/:kind/:itemId` (see `app_router.dart`).
enum NotifKind { zeroStock, lowStock, expiry }

extension NotifKindRoute on NotifKind {
  String get routeSegment => switch (this) {
        NotifKind.zeroStock => 'zero',
        NotifKind.lowStock => 'low',
        NotifKind.expiry => 'expiry',
      };

  static NotifKind? fromRouteSegment(String segment) => switch (segment) {
        'zero' => NotifKind.zeroStock,
        'low' => NotifKind.lowStock,
        'expiry' => NotifKind.expiry,
        _ => null,
      };

  IconData get icon => switch (this) {
        NotifKind.zeroStock => Icons.remove_shopping_cart_outlined,
        NotifKind.lowStock => Icons.warning_amber_outlined,
        NotifKind.expiry => Icons.event_busy_outlined,
      };

  String get label => switch (this) {
        NotifKind.zeroStock => 'Zero Stock',
        NotifKind.lowStock => 'Low Stock',
        NotifKind.expiry => 'Expiry Warning',
      };
}

/// One row's worth of data for the compact notification UI shared by
/// `NotificationsPage`, `NotificationBell`, and `NotificationDetailPage`.
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

String formatExpirySubtitle(int daysUntilExpiry) {
  if (daysUntilExpiry < 0) {
    final daysAgo = -daysUntilExpiry;
    return 'Expired $daysAgo day${daysAgo == 1 ? '' : 's'} ago';
  }
  if (daysUntilExpiry == 0) return 'Expires today';
  return 'Expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}';
}

/// Flattens [stats]'s three alert lists into one severity-ordered list for
/// display as standard notification rows: Zero Stock, then already-expired
/// batches, then Low Stock, then still-upcoming expiry warnings.
List<CompactNotif> buildCompactNotifs(ManagerDashboardStats stats) {
  final expired = stats.expiringSoonItems.where((e) => e.daysUntilExpiry < 0);
  final upcoming = stats.expiringSoonItems.where((e) => e.daysUntilExpiry >= 0);

  return [
    for (final item in stats.zeroStockItems)
      CompactNotif(
        kind: NotifKind.zeroStock,
        itemId: item.itemId,
        itemName: item.itemName,
        subtitle: 'Out of stock',
        accent: AppColors.destructive,
      ),
    for (final item in expired)
      CompactNotif(
        kind: NotifKind.expiry,
        itemId: item.itemId,
        itemName: item.itemName,
        subtitle: formatExpirySubtitle(item.daysUntilExpiry),
        accent: AppColors.destructive,
      ),
    for (final item in stats.lowStockItems)
      CompactNotif(
        kind: NotifKind.lowStock,
        itemId: item.itemId,
        itemName: item.itemName,
        subtitle:
            '${formatQty(item.stockQty)} ${item.unitAbbr} left (≤ '
            '${formatQty(lowStockPurchaseUnitThreshold)} threshold)',
        accent: AppColors.warning,
      ),
    for (final item in upcoming)
      CompactNotif(
        kind: NotifKind.expiry,
        itemId: item.itemId,
        itemName: item.itemName,
        subtitle: formatExpirySubtitle(item.daysUntilExpiry),
        accent: AppColors.warning,
      ),
  ];
}

/// A single standard-notification-style row: leading colored icon, item
/// name, one-line reason, trailing chevron. Tap navigates to
/// `NotificationDetailPage` for the full picture.
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
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16, vertical: dense ? 8 : 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: notif.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(notif.kind.icon, size: 16, color: notif.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif.itemName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notif.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.mutedForeground),
          ],
        ),
      ),
    );
  }
}

/// A bordered card containing [notifs] as [CompactNotificationTile] rows
/// with dividers, or [emptyText] when there are none.
class CompactNotificationList extends StatelessWidget {
  final List<CompactNotif> notifs;
  final void Function(CompactNotif notif) onTapNotif;
  final String emptyText;
  final bool dense;

  const CompactNotificationList({
    super.key,
    required this.notifs,
    required this.onTapNotif,
    this.emptyText = 'No notifications right now.',
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(dense ? 12 : 16),
        border: Border.all(color: AppColors.border),
      ),
      child: notifs.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Text(emptyText,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < notifs.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppColors.border),
                  CompactNotificationTile(
                    notif: notifs[i],
                    dense: dense,
                    onTap: () => onTapNotif(notifs[i]),
                  ),
                ],
              ],
            ),
    );
  }
}
