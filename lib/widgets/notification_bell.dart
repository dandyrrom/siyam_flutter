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
  //
  // RESPONSIVE BEHAVIOR:
  //
  // Desktop/tablet:
  //   - keeps the existing 360px notification panel.
  //
  // Mobile:
  //   - panel width is limited to the available viewport width with a safe
  //     margin, so it cannot extend off the left/right side of the screen.
  //   - panel height is also capped relative to the viewport.
  //   - notification rows become scrollable when the available height is
  //     small, while the header and "View all notifications" action remain
  //     visible.
  //
  // This changes only the bell preview layout. Notification routes and data
  // loading remain unchanged.
  // ==========================================================================

  @override
  Widget buildFlyoutPanel(
    BuildContext context,
  ) {
    final preview =
        _notifs
            .take(_kBellPreviewCount)
            .toList();

    final screen =
        MediaQuery.sizeOf(context);

    // Keep a visible margin on narrow/mobile screens.
    final availableWidth =
        screen.width - 24.0;

    final panelWidth =
        availableWidth < 360.0
            ? availableWidth
            : 360.0;

    // Prevent the flyout from extending beyond a short mobile viewport.
    final availableHeight =
        screen.height - 96.0;

    final panelMaxHeight =
        availableHeight < 520.0
            ? availableHeight
            : 520.0;

    return Material(
      elevation: 6,
      borderRadius:
          BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      color: AppColors.card,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              panelMaxHeight > 0
                  ? panelMaxHeight
                  : screen.height,
        ),
        child: SizedBox(
          width:
              panelWidth > 0
                  ? panelWidth
                  : screen.width,
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              // ==============================================================
              // HEADER
              // ==============================================================

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

              // ==============================================================
              // PREVIEW CONTENT
              // ==============================================================

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
                Flexible(
                  child: ListView.separated(
                    padding:
                        EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount:
                        preview.length,
                    separatorBuilder:
                        (_, __) =>
                            const Divider(
                      height: 1,
                      color:
                          AppColors.border,
                    ),
                    itemBuilder:
                        (context, index) {
                      final notif =
                          preview[index];

                      return CompactNotificationTile(
                        notif: notif,
                        dense: true,
                        onTap: () =>
                            _openDetail(
                          notif,
                        ),
                      );
                    },
                  ),
                ),

              const Divider(
                height: 1,
                color: AppColors.border,
              ),

              // ==============================================================
              // FOOTER
              // ==============================================================

              SafeArea(
                top: false,
                minimum:
                    EdgeInsets.zero,
                child: TextButton(
                  onPressed: _viewAll,
                  child: const Text(
                    'View all notifications',
                  ),
                ),
              ),
            ],
          ),
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
