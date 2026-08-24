import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../services/dashboard_service.dart';
import '../services/donor_notification_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import '../widgets/donor_notification_alerts.dart';
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

  final DonorNotificationService
      _donorNotificationService =
      DonorNotificationService();

  ManagerDashboardStats? _stats;

  List<DonorNotification>
      _donorNotifications = [];

  bool _loading = true;
  String? _error;

  AppRole? get _role => context
      .read<AuthController>()
      .profile
      ?.role;

  bool get _showsInventoryAlerts {
    final role = _role;

    return role == AppRole.manager ||
        role == AppRole.staff;
  }

  bool get _showsDonorUpdates =>
      _role == AppRole.donor;

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
    final profile = context
        .read<AuthController>()
        .profile;

    if (profile == null) {
      if (!mounted) return;

      setState(() {
        _stats = null;
        _donorNotifications = [];
        _loading = false;
      });

      return;
    }

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    // ========================================================================
    // DONOR
    // ========================================================================

    if (_showsDonorUpdates) {
      try {
        final notifications =
            await _donorNotificationService
                .fetchForDonor(
          profile.userId,
        );

        if (!mounted) return;

        setState(() {
          _donorNotifications =
              notifications;
          _stats = null;
          _loading = false;
          _error = null;
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

      return;
    }

    // ========================================================================
    // MANAGER / STAFF
    // ========================================================================

    if (_showsInventoryAlerts) {
      try {
        final stats =
            await _service.fetchManagerStats();

        if (!mounted) return;

        setState(() {
          _stats = stats;
          _donorNotifications = [];
          _loading = false;
          _error = null;
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

      return;
    }

    if (!mounted) return;

    setState(() {
      _stats = null;
      _donorNotifications = [];
      _loading = false;
      _error = null;
    });
  }

  void _openDetail(
    CompactNotif notif,
  ) {
    context.push(
      '/notifications/'
      '${notif.kind.routeSegment}/'
      '${notif.itemId}',
    );
  }

  void _openDonorUpdate(
    DonorNotification notification,
  ) {
    context.go(
      notification.route,
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifs =
        _stats == null
            ? const <CompactNotif>[]
            : buildCompactNotifs(
                _stats!,
              );

    final donorMode =
        _showsDonorUpdates;

    return ConstrainedBox(
      constraints:
          const BoxConstraints(
        maxWidth: 680,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Notifications',
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            donorMode
                ? 'Updates about your donation status and impact.'
                : 'Actionable inventory alerts for stock levels and batch expiry.',
            style: const TextStyle(
              color:
                  AppColors.mutedForeground,
            ),
          ),

          const SizedBox(height: 20),

          if (_loading)
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
          else if (donorMode) ...[
            Row(
              children: [
                Text(
                  '${_donorNotifications.length} donation '
                  'update${_donorNotifications.length == 1 ? '' : 's'}',
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

            DonorNotificationList(
              notifications:
                  _donorNotifications,
              onTapNotification:
                  _openDonorUpdate,
              emptyText:
                  'No donation updates right now.',
            ),
          ] else if (_showsInventoryAlerts) ...[
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
          ] else
            CompactNotificationList(
              notifs: const [],
              onTapNotif: (_) {},
              emptyText:
                  'No notifications right now.',
            ),
        ],
      ),
    );
  }
}
