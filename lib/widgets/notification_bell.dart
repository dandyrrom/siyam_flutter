import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../services/dashboard_service.dart';
import '../services/donor_notification_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import 'app_dropdown.dart';
import 'donor_notification_alerts.dart';
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

  final DonorNotificationService
      _donorNotificationService =
      DonorNotificationService();

  List<CompactNotif> _notifs = [];

  List<DonorNotification>
      _donorNotifs = [];

  @override
  Alignment get targetAnchor =>
      Alignment.topRight;

  @override
  Alignment get followerAnchor =>
      Alignment.topRight;

  AppRole? get _role => context
      .read<AuthController>()
      .profile
      ?.role;

  bool get _tracksInventoryAlerts {
    final role = _role;

    return role == AppRole.manager ||
        role == AppRole.staff;
  }

  bool get _tracksDonorUpdates =>
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
    _load();
  }

  Future<void> _load() async {
    final profile = context
        .read<AuthController>()
        .profile;

    if (profile == null) {
      return;
    }

    // ========================================================================
    // DONOR
    // ========================================================================

    if (_tracksDonorUpdates) {
      try {
        final updates =
            await _donorNotificationService
                .fetchForDonor(
          profile.userId,
        );

        if (!mounted) return;

        setState(() {
          _donorNotifs = updates;
          _notifs = [];
        });

        rebuildDropdown();
      } catch (_) {
        // Bell intentionally degrades silently.
      }

      return;
    }

    // ========================================================================
    // MANAGER / STAFF
    // ========================================================================

    if (_tracksInventoryAlerts) {
      try {
        final stats =
            await _service.fetchManagerStats();

        if (!mounted) return;

        setState(() {
          _notifs =
              buildCompactNotifs(stats);
          _donorNotifs = [];
        });

        rebuildDropdown();
      } catch (_) {
        // Bell intentionally degrades silently.
      }

      return;
    }

    // Unknown / unsupported role state.
    if (!mounted) return;

    if (_notifs.isNotEmpty ||
        _donorNotifs.isNotEmpty) {
      setState(() {
        _notifs = [];
        _donorNotifs = [];
      });

      rebuildDropdown();
    }
  }

  void _openDetail(
    CompactNotif notif,
  ) {
    closeDropdown();

    context.push(
      '/notifications/'
      '${notif.kind.routeSegment}/'
      '${notif.itemId}',
    );
  }

  void _openDonorUpdate(
    DonorNotification notification,
  ) {
    closeDropdown();

    context.go(
      notification.route,
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
    final donorMode =
        _tracksDonorUpdates;

    final inventoryPreview =
        _notifs
            .take(_kBellPreviewCount)
            .toList();

    final donorPreview =
        _donorNotifs
            .take(_kBellPreviewCount)
            .toList();

    final totalCount =
        donorMode
            ? _donorNotifs.length
            : _notifs.length;

    final screen =
        MediaQuery.sizeOf(context);

    final availableWidth =
        screen.width - 24.0;

    final panelWidth =
        availableWidth < 360.0
            ? availableWidth
            : 360.0;

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

                    if (totalCount > 0)
                      Text(
                        donorMode
                            ? '$totalCount update${totalCount == 1 ? '' : 's'}'
                            : '$totalCount active',
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

              if (donorMode)
                if (donorPreview.isEmpty)
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
                              .notifications_none_outlined,
                          size: 17,
                          color: AppColors
                              .roleDonor,
                        ),

                        SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            'No donation updates right now.',
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
                    child:
                        ListView.separated(
                      padding:
                          EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount:
                          donorPreview.length,
                      separatorBuilder:
                          (_, __) =>
                              const Divider(
                        height: 1,
                        color:
                            AppColors.border,
                      ),
                      itemBuilder:
                          (context, index) {
                        final notification =
                            donorPreview[index];

                        return DonorNotificationTile(
                          notification:
                              notification,
                          dense: true,
                          onTap: () =>
                              _openDonorUpdate(
                            notification,
                          ),
                        );
                      },
                    ),
                  )
              else if (inventoryPreview.isEmpty)
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
                        inventoryPreview
                            .length,
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
                          inventoryPreview[
                              index];

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
    final donorMode =
        _tracksDonorUpdates;

    final count =
        donorMode
            ? _donorNotifs.length
            : _notifs.length;

    final hasAlerts =
        count > 0;

    final badgeText =
        count > 99
            ? '99+'
            : '$count';

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
