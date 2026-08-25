import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../routing/nav_config.dart';
import '../state/auth_state.dart';
import '../state/app_operation_controller.dart';

class MobileDrawer
    extends StatefulWidget {
  final String currentPath;

  const MobileDrawer({
    super.key,
    required this.currentPath,
  });

  @override
  State<MobileDrawer> createState() =>
      _MobileDrawerState();
}

class _MobileDrawerState
    extends State<MobileDrawer> {
  bool _confirmingLogout = false;
  bool _loggingOut = false;
Future<void> _openRoute(
  String path,
  String label,
) async {
  if (AppOperationController.instance.isBusy) {
    return;
  }

  await AppOperationController.instance.run<void>(
    message: 'Opening $label...',
    action: () async {
      if (!mounted) return;

      // Close the drawer first.
      Navigator.of(context).pop();

      // Then perform one navigation.
      context.go(path);

      await WidgetsBinding.instance.endOfFrame;
    },
  );
}
  // =========================================================================
  // MOBILE LOGOUT
  // =========================================================================

  Future<void> _performLogout() async {
    if (_loggingOut) {
      return;
    }

    setState(() {
      _loggingOut = true;
    });

    final auth =
        context.read<AuthController>();

    final success =
        await auth.logout();

    if (!mounted) {
      return;
    }

    if (success) {
      // One navigation removes the entire authenticated AppShell,
      // including this Drawer.
      context.go('/login');
      return;
    }

    setState(() {
      _loggingOut = false;
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          auth.errorMessage ??
              'Could not log out. Please try again.',
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    if (_loggingOut) {
      return;
    }

    setState(() {
      _confirmingLogout = true;
    });
  }

  void _cancelLogout() {
    if (_loggingOut) {
      return;
    }

    setState(() {
      _confirmingLogout = false;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final auth =
        context.watch<AuthController>();

    final user =
        auth.profile;

    final items = kNavItems
        .where(
          (item) =>
              user != null &&
              item.roles.contains(
                user.role,
              ),
        )
        .toList();

    final disabled =
        auth.isBusy ||
        _loggingOut;

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // =================================================================
            // DRAWER HEADER
            // =================================================================

            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                20,
              ),
              color:
                  AppColors.primary,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    'SIYAM',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize: 22,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  Text(
                    user?.fullName ??
                        'Guest',
                    style:
                        const TextStyle(
                      color:
                          Colors.white70,
                      fontSize: 14,
                      fontWeight:
                          FontWeight
                              .w500,
                    ),
                  ),

                  if (user != null)
                    Text(
                      appRoleToString(
                        user.role,
                      ).toUpperCase(),
                      style:
                          const TextStyle(
                        color:
                            Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            // =================================================================
            // NAVIGATION
            // =================================================================

            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                children:
                    items.map(
                  (item) {
                    final active =
                        widget
                            .currentPath
                            .startsWith(
                      item.path,
                    );

                    return Padding(
                      padding:
                          const EdgeInsets
                              .only(
                        bottom: 2,
                      ),
                      child:
                          Material(
                        color: active
                            ? AppColors
                                .sidebarAccent
                            : Colors
                                .transparent,
                        elevation:
                            active
                                ? 1
                                : 0,
                        shadowColor:
                            AppColors
                                .sidebarForeground
                                .withValues(
                          alpha:
                              0.25,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                        child:
                            InkWell(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            16,
                          ),
                    onTap: () {
  if (active) {
    Navigator.of(context).pop();
    return;
  }

  _openRoute(
    item.path,
    item.label,
  );
},
                          child:
                              Padding(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  12,
                              vertical:
                                  11,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 18,
                                  color: active
                                      ? AppColors
                                          .sidebarPrimary
                                      : AppColors
                                          .sidebarAccentForeground,
                                ),

                                const SizedBox(
                                  width: 12,
                                ),

                                Expanded(
                                  child:
                                      Text(
                                    item.label,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        TextStyle(
                                      fontSize:
                                          13.5,
                                      fontWeight:
                                          active
                                              ? FontWeight
                                                  .w600
                                              : FontWeight
                                                  .w400,
                                      color:
                                          AppColors
                                              .sidebarForeground,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ).toList(),
              ),
            ),

            // =================================================================
            // USER + LOGOUT
            // =================================================================

            Container(
              padding:
                  const EdgeInsets.all(
                8,
              ),
              decoration:
                  const BoxDecoration(
                border:
                    Border(
                  top:
                      BorderSide(
                    color:
                        AppColors
                            .sidebarBorder,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .stretch,
                children: [
                  // ===========================================================
                  // USER
                  // ===========================================================

                  if (user != null)
                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor:
                                AppColors
                                    .sidebarPrimary,
                            child: Text(
                              user.initials,
                              style:
                                  const TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    FontWeight
                                        .w700,
                                color:
                                    AppColors
                                        .sidebarPrimaryForeground,
                              ),
                            ),
                          ),

                          const SizedBox(
                            width: 8,
                          ),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              mainAxisSize:
                                  MainAxisSize
                                      .min,
                              children: [
                                Text(
                                  user.fullName,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight:
                                        FontWeight
                                            .w600,
                                    color:
                                        AppColors
                                            .sidebarForeground,
                                  ),
                                ),

                                Text(
                                  user.email,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    fontSize: 11,
                                    color:
                                        AppColors
                                            .sidebarAccentForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ===========================================================
                  // LOGOUT CONFIRMATION
                  // ===========================================================

                  if (!_confirmingLogout)
                    TextButton.icon(
                      onPressed:
                          disabled
                              ? null
                              : _showLogoutConfirmation,
                      icon:
                          const Icon(
                        Icons.logout,
                        size: 16,
                        color:
                            AppColors
                                .sidebarAccentForeground,
                      ),
                      label:
                          const Text(
                        'Logout',
                        style:
                            TextStyle(
                          color:
                              AppColors
                                  .sidebarForeground,
                        ),
                      ),
                      style:
                          TextButton
                              .styleFrom(
                        alignment:
                            Alignment
                                .centerLeft,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              12,
                          vertical:
                              10,
                        ),
                      ),
                    )
                  else
                    Container(
                      margin:
                          const EdgeInsets.only(
                        top: 4,
                      ),
                      padding:
                          const EdgeInsets.all(
                        12,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            AppColors
                                .destructive
                                .withValues(
                          alpha:
                              0.06,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                        border:
                            Border.all(
                          color:
                              AppColors
                                  .destructive
                                  .withValues(
                            alpha:
                                0.20,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          const Text(
                            'Are you sure you want to log out?',
                            style:
                                TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  FontWeight
                                      .w600,
                              color:
                                  AppColors
                                      .sidebarForeground,
                            ),
                          ),

                          const SizedBox(
                            height: 10,
                          ),

                          Row(
                            children: [
                              Expanded(
                                child:
                                    OutlinedButton(
                                  onPressed:
                                      disabled
                                          ? null
                                          : _cancelLogout,
                                  child:
                                      const Text(
                                    'Cancel',
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Expanded(
                                child:
                                    ElevatedButton(
                                  onPressed:
                                      disabled
                                          ? null
                                          : _performLogout,
                                  style:
                                      ElevatedButton
                                          .styleFrom(
                                    backgroundColor:
                                        AppColors
                                            .destructive,
                                    foregroundColor:
                                        Colors.white,
                                  ),
                                  child: _loggingOut
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                            color:
                                                Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Confirm Logout',
                                          textAlign:
                                              TextAlign.center,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}