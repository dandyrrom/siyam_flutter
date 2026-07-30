import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../services/dashboard_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import '../widgets/notification_alerts.dart';

/// Zero-stock / low-stock / expiry-warning alerts, rendered as a compact
/// notification feed -- see updated_db.md's SYSTEM_SETTINGS and
/// `DashboardService.fetchManagerStats`, which already aggregates exactly
/// these three lists for the manager dashboard. Tapping a row opens
/// `NotificationDetailPage` for the full picture.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with DataBusRefreshMixin<NotificationsPage> {
  final DashboardService _service = DashboardService();

  ManagerDashboardStats? _stats;
  bool _loading = true;
  String? _error;

  bool get _showsInventoryAlerts {
    final role = context.read<AuthController>().profile?.role;
    return role == AppRole.manager || role == AppRole.staff;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!_showsInventoryAlerts) {
      setState(() => _loading = false);
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
      if (!silent) {
        setState(() {
          _error = 'Could not load notifications: $e';
          _loading = false;
        });
      }
    }
  }

  void _openDetail(CompactNotif notif) {
    context.push('/notifications/${notif.kind.routeSegment}/${notif.itemId}');
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Zero-stock, low-stock, and expiry alerts.',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          if (!_showsInventoryAlerts)
            CompactNotificationList(
              notifs: const [],
              onTapNotif: (_) {},
              emptyText: 'No notifications right now.',
            )
          else if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.destructive))
          else ...[
            CompactNotificationList(
              notifs: buildCompactNotifs(_stats!),
              onTapNotif: _openDetail,
              emptyText: 'No active alerts right now.',
            ),
            if (!_stats!.expiryTrackingAvailable) ...[
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Expiry warnings need batch expiry dates, which aren\'t '
                  'migrated onto the live backend yet.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
