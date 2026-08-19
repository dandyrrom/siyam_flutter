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

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() =>
      _NotificationBellState();
}

class _NotificationBellState
    extends State<NotificationBell>
    with
        DropdownOverlayMixin<
            NotificationBell>,
        DataBusRefreshMixin<
            NotificationBell> {
  final DashboardService _service =
      DashboardService();

  List<CompactNotif> _notifs = [];

  @override
  Alignment get targetAnchor =>
      Alignment.topRight;

  @override
  Alignment get followerAnchor =>
      Alignment.topRight;

  bool get _tracksAlerts {
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
    _load();
  }

  Future<void> _load() async {
    if (!_tracksAlerts) {
      if (mounted && _notifs.isNotEmpty) {
        setState(() {
          _notifs = [];
        });

        rebuildDropdown();
      }

      return;
    }

    try {
      final stats =
          await _service.fetchManagerStats();

      if (!mounted) return;

      setState(() {
        _notifs =
            buildCompactNotifs(stats);
      });

      rebuildDropdown();
    } catch (_) {
      // Bell intentionally degrades silently.
    }
  }

  void _openDetail(CompactNotif notif) {
    closeDropdown();

    context.push(
      '/notifications/'
      '${notif.kind.routeSegment}/'
      '${notif.itemId}',
    );
  }

  void _viewAll() {
    closeDropdown();
    context.go('/notifications');
  }

  // ==========================================================================
  // POPOVER
  // ==========================================================================

  @override
  Widget buildFlyoutPanel(
    BuildContext context,
  ) {
    final preview =
        _notifs
            .take(_kBellPreviewCount)
            .toList();

    return Material(
      elevation: 6,
      borderRadius:
          BorderRadius.circular(16),
      color: AppColors.card,
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                14,
                16,
                10,
              ),
              child: Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),

                  const Spacer(),

                  if (_notifs.isNotEmpty)
                    Text(
                      '${_notifs.length} active',
                      style:
                          const TextStyle(
                        fontSize: 11.5,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                ],
              ),
            ),

            if (preview.isEmpty)
              const Padding(
                padding:
                    EdgeInsets.fromLTRB(
                  16,
                  2,
                  16,
                  16,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons
                          .check_circle_outline,
                      size: 17,
                      color: AppColors
                          .roleManager,
                    ),

                    SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        'No active inventory alerts right now.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors
                              .mutedForeground,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              for (var i = 0;
                  i < preview.length;
                  i++) ...[
                if (i > 0)
                  const Divider(
                    height: 1,
                    color: AppColors.border,
                  ),

                CompactNotificationTile(
                  notif: preview[i],
                  dense: true,
                  onTap: () =>
                      _openDetail(
                    preview[i],
                  ),
                ),
              ],

            const Divider(
              height: 1,
              color: AppColors.border,
            ),

            TextButton(
              onPressed: _viewAll,
              child: const Text(
                'View all notifications',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // BELL
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final hasAlerts =
        _notifs.isNotEmpty;

    final badgeText =
        _notifs.length > 99
            ? '99+'
            : '${_notifs.length}';

    return CompositedTransformTarget(
      link: dropdownLink,
      child: Material(
        color: Colors.transparent,
        borderRadius:
            BorderRadius.circular(20),
        child: InkWell(
          borderRadius:
              BorderRadius.circular(20),
          onTap: toggleDropdown,
          hoverColor:
              AppColors.primary.withValues(
            alpha: 0.08,
          ),
          highlightColor:
              AppColors.primary.withValues(
            alpha: 0.14,
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons
                      .notifications_outlined,
                  color: AppColors
                      .mutedForeground,
                  size: 20,
                ),

                if (hasAlerts)
                  Positioned(
                    top: -8,
                    right: -10,
                    child: Container(
                      constraints:
                          const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 4,
                      ),
                      decoration:
                          BoxDecoration(
                        color: AppColors
                            .destructive,
                        borderRadius:
                            BorderRadius.circular(
                          999,
                        ),
                        border: Border.all(
                          color:
                              AppColors.card,
                          width: 1.5,
                        ),
                      ),
                      alignment:
                          Alignment.center,
                      child: Text(
                        badgeText,
                        style:
                            const TextStyle(
                          fontSize: 9,
                          fontWeight:
                              FontWeight.w700,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
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