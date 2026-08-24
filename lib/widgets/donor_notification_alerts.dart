import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/donor_notification_service.dart';
import 'hoverable_row.dart';

// =============================================================================
// DONOR NOTIFICATION UI
// =============================================================================
//
// This is intentionally separate from notification_alerts.dart.
//
// notification_alerts.dart remains the Manager/Staff inventory-alert system.
// These widgets are only for donor donation-status and impact updates.
// =============================================================================

class DonorNotificationTile
    extends StatelessWidget {
  final DonorNotification notification;
  final VoidCallback onTap;
  final bool dense;

  const DonorNotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.dense = false,
  });

  Color get _accent =>
      switch (notification.kind) {
        DonorNotificationKind.approved =>
          AppColors.roleDonor,
        DonorNotificationKind.received =>
          AppColors.primary,
        DonorNotificationKind.impact =>
          AppColors.primary,
      };

  IconData get _icon =>
      switch (notification.kind) {
        DonorNotificationKind.approved =>
          Icons.check_circle_outline,
        DonorNotificationKind.received =>
          Icons.inventory_2_outlined,
        DonorNotificationKind.impact =>
          Icons.favorite_outline,
      };

  @override
  Widget build(BuildContext context) {
    final date =
        notification.displayDate;

    return HoverableRow(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 12 : 16,
          vertical: dense ? 9 : 12,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _accent.withValues(
                  alpha: 0.12,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _icon,
                size: 16,
                color: _accent,
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
                          notification.title,
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

                      if (date != null) ...[
                        const SizedBox(width: 8),

                        Text(
                          _formatDate(date),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors
                                .mutedForeground,
                          ),
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 2),

                  Text(
                    notification.message,
                    maxLines:
                        dense ? 2 : 3,
                    overflow:
                        TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            const Padding(
              padding:
                  EdgeInsets.only(top: 7),
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DonorNotificationList
    extends StatelessWidget {
  final List<DonorNotification>
      notifications;

  final void Function(
    DonorNotification notification,
  ) onTapNotification;

  final String emptyText;
  final bool dense;

  const DonorNotificationList({
    super.key,
    required this.notifications,
    required this.onTapNotification,
    this.emptyText =
        'No donation updates right now.',
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
      child: notifications.isEmpty
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
                    i <
                        notifications
                            .length;
                    i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      color:
                          AppColors.border,
                    ),

                  DonorNotificationTile(
                    notification:
                        notifications[i],
                    dense: dense,
                    onTap: () =>
                        onTapNotification(
                      notifications[i],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

const _monthAbbrev = [
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

String _formatDate(
  DateTime date,
) {
  final local =
      date.toLocal();

  return '${_monthAbbrev[local.month - 1]} '
      '${local.day}, ${local.year}';
}
