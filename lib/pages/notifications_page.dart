import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../services/dashboard_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import '../widgets/notification_alerts.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() =>
      _NotificationsPageState();
}

class _NotificationsPageState
    extends State<NotificationsPage>
    with DataBusRefreshMixin<NotificationsPage> {
  final DashboardService _service =
      DashboardService();

  ManagerDashboardStats? _stats;

  bool _loading = true;
  String? _error;

  bool get _showsInventoryAlerts {
    final role = context
        .read<AuthController>()
        .profile
        ?.role;

    return role == AppRole.manager ||
        role == AppRole.staff;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) => _load(),
    );
  }

  @override
  void onExternalDataChanged() {
    _load(silent: true);
  }

  Future<void> _load({
    bool silent = false,
  }) async {
    if (!_showsInventoryAlerts) {
      if (mounted) {
        setState(() {
          _stats = null;
          _loading = false;
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
      final stats =
          await _service.fetchManagerStats();

      if (!mounted) return;

      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error =
              'Could not load notifications: $e';
          _loading = false;
        });
      }
    }
  }

  void _openDetail(CompactNotif notif) {
    context.push(
      '/notifications/'
      '${notif.kind.routeSegment}/'
      '${notif.itemId}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifs = _stats == null
        ? const <CompactNotif>[]
        : buildCompactNotifs(_stats!);

    return ConstrainedBox(
      constraints:
          const BoxConstraints(maxWidth: 680),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'Actionable inventory alerts for stock levels and batch expiry.',
            style: TextStyle(
              color:
                  AppColors.mutedForeground,
            ),
          ),

          const SizedBox(height: 20),

          if (!_showsInventoryAlerts)
            CompactNotificationList(
              notifs: const [],
              onTapNotif: (_) {},
              emptyText:
                  'No notifications right now.',
            )
          else if (_loading)
            const Center(
              child:
                  CircularProgressIndicator(),
            )
          else if (_error != null)
            Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _error!,
                  style: const TextStyle(
                    color:
                        AppColors.destructive,
                  ),
                ),

                const SizedBox(height: 8),

                OutlinedButton(
                  onPressed: _load,
                  child:
                      const Text('Retry'),
                ),
              ],
            )
          else ...[
            Row(
              children: [
                Text(
                  '${notifs.length} active '
                  'alert${notifs.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),

                const Spacer(),

                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _load,
                  icon: const Icon(
                    Icons.refresh,
                    size: 18,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            CompactNotificationList(
              notifs: notifs,
              onTapNotif: _openDetail,
              emptyText:
                  'No active inventory alerts right now.',
            ),
          ],
        ],
      ),
    );
  }
}