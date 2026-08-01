import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../services/dashboard_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import 'app_dropdown.dart';
import 'notification_alerts.dart';

const int _kBellPreviewCount = 6;

/// Top-nav bell: opens the same compact notification rows shown on
/// `NotificationsPage`, capped to a short preview with a "View all" link.
/// Manager/Staff only -- Donor has no inventory alerts, so the bell shows no
/// badge and an empty panel for that role, matching `NotificationsPage`.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell>
    with DropdownOverlayMixin<NotificationBell>, DataBusRefreshMixin<NotificationBell> {
  final DashboardService _service = DashboardService();
  List<CompactNotif> _notifs = [];

  // The bell sits near the right edge of the top nav -- anchor the panel's
  // right edge to the trigger's right edge instead of the default left
  // alignment, so its 340px width doesn't overflow off-screen.
  @override
  Alignment get targetAnchor => Alignment.topRight;
  @override
  Alignment get followerAnchor => Alignment.topRight;

  bool get _tracksAlerts {
    final role = context.read<AuthController>().profile?.role;
    return role == AppRole.manager || role == AppRole.staff;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void onExternalDataChanged() => _load();

  Future<void> _load() async {
    if (!_tracksAlerts) return;
    try {
      final stats = await _service.fetchManagerStats();
      if (!mounted) return;
      setState(() => _notifs = buildCompactNotifs(stats));
      rebuildDropdown();
    } catch (_) {
      // Silent -- the bell degrades to "no alerts" rather than surfacing
      // a load error in a small popover.
    }
  }

  void _openDetail(CompactNotif notif) {
    closeDropdown();
    context.push('/notifications/${notif.kind.routeSegment}/${notif.itemId}');
  }

  void _viewAll() {
    closeDropdown();
    context.push('/notifications');
  }

  @override
  Widget buildFlyoutPanel(BuildContext context) {
    final preview = _notifs.take(_kBellPreviewCount).toList();
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: AppColors.card,
      child: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Text('Notifications',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
            ),
            if (preview.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text('No active alerts right now.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
              )
            else
              for (var i = 0; i < preview.length; i++) ...[
                if (i > 0) const Divider(height: 1, color: AppColors.border),
                CompactNotificationTile(
                  notif: preview[i],
                  dense: true,
                  onTap: () => _openDetail(preview[i]),
                ),
              ],
            const Divider(height: 1, color: AppColors.border),
            TextButton(
              onPressed: _viewAll,
              child: const Text('View all notifications'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAlerts = _notifs.isNotEmpty;
    return CompositedTransformTarget(
      link: dropdownLink,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(toggleDropdown),
        hoverColor: AppColors.primary.withValues(alpha: 0.08),
        highlightColor: AppColors.primary.withValues(alpha: 0.14),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_outlined,
                  color: AppColors.mutedForeground, size: 20),
              if (hasAlerts)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                        color: AppColors.destructive, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
