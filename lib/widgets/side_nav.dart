import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../routing/nav_config.dart';
import '../state/auth_state.dart';

class SideNav extends StatefulWidget {
  final bool collapsed;
  final String currentPath;

  const SideNav({
    super.key,
    required this.collapsed,
    required this.currentPath,
  });

  @override
  State<SideNav> createState() =>
      _SideNavState();
}

class _SideNavState
    extends State<SideNav> {
  bool _confirmingLogout = false;
  bool _loggingOut = false;

  // =========================================================================
  // LOGOUT
  // =========================================================================
  //
  // IMPORTANT:
  //
  // There is intentionally NO AlertDialog here.
  //
  // Confirmation happens directly inside the sidebar.
  // This avoids adding/removing a Navigator overlay at the same time the
  // authenticated AppShell is removed.
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
      // ---------------------------------------------------------------
      // SINGLE LOGOUT NAVIGATION
      // ---------------------------------------------------------------
      //
      // AuthController does NOT refresh GoRouter during successful logout.
      // This is the one place that sends the user to /login.
      // ---------------------------------------------------------------

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

  // =========================================================================
  // LOGOUT AREA
  // =========================================================================

  Widget _buildLogoutArea(
    AuthController auth,
  ) {
    final disabled =
        auth.isBusy ||
        _loggingOut;

    // -----------------------------------------------------------------------
    // COLLAPSED SIDEBAR
    // -----------------------------------------------------------------------

    if (widget.collapsed) {
      if (!_confirmingLogout) {
        return IconButton(
          onPressed:
              disabled
                  ? null
                  : _showLogoutConfirmation,
          icon: const Icon(
            Icons.logout,
            size: 16,
            color:
                AppColors
                    .sidebarAccentForeground,
          ),
          tooltip: 'Logout',
        );
      }

      return Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 4,
        ),
        child: Column(
          children: [
            const Text(
              'Log out?',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                color:
                    AppColors
                        .sidebarAccentForeground,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed:
                      disabled
                          ? null
                          : _cancelLogout,
                  tooltip:
                      'Cancel',
                  padding:
                      EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(
                    minWidth: 28,
                    minHeight: 30,
                  ),
                  icon: const Icon(
                    Icons.close,
                    size: 15,
                    color:
                        AppColors
                            .sidebarAccentForeground,
                  ),
                ),

                IconButton(
                  onPressed:
                      disabled
                          ? null
                          : _performLogout,
                  tooltip:
                      'Confirm Logout',
                  padding:
                      EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(
                    minWidth: 28,
                    minHeight: 30,
                  ),
                  icon: _loggingOut
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.check,
                          size: 15,
                          color:
                              AppColors
                                  .destructive,
                        ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // -----------------------------------------------------------------------
    // NORMAL SIDEBAR
    // -----------------------------------------------------------------------

    if (!_confirmingLogout) {
      return TextButton.icon(
        onPressed:
            disabled
                ? null
                : _showLogoutConfirmation,
        icon: const Icon(
          Icons.logout,
          size: 16,
          color:
              AppColors
                  .sidebarAccentForeground,
        ),
        label: const Text(
          'Logout',
          style: TextStyle(
            color:
                AppColors
                    .sidebarForeground,
          ),
        ),
        style:
            TextButton.styleFrom(
          alignment:
              Alignment.centerLeft,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.all(
        10,
      ),
      decoration: BoxDecoration(
        color: AppColors
            .destructive
            .withValues(
          alpha: 0.06,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: AppColors
              .destructive
              .withValues(
            alpha: 0.20,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Are you sure you want to log out?',
            style: TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
              color:
                  AppColors
                      .sidebarForeground,
            ),
          ),

          const SizedBox(
            height: 8,
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
                  style:
                      OutlinedButton
                          .styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 8,
                    ),
                  ),
                  child:
                      const Text(
                    'Cancel',
                    style:
                        TextStyle(
                      fontSize: 11.5,
                    ),
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
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 8,
                    ),
                  ),
                  child: _loggingOut
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color:
                                Colors.white,
                          ),
                        )
                      : const Text(
                          'Confirm',
                          style:
                              TextStyle(
                            fontSize: 11.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BUILD
  // =========================================================================

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

    return Container(
      width:
          widget.collapsed
              ? 72
              : 248,
      decoration:
          const BoxDecoration(
        color:
            AppColors.sidebar,
        border: Border(
          right: BorderSide(
            color:
                AppColors
                    .sidebarBorder,
          ),
        ),
      ),
      child: Column(
        children: [
          // =================================================================
          // LOGO
          // =================================================================

          Container(
            height: 64,
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 16,
            ),
            decoration:
                const BoxDecoration(
              border: Border(
                bottom:
                    BorderSide(
                  color:
                      AppColors
                          .sidebarBorder,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  widget.collapsed
                      ? MainAxisAlignment
                          .center
                      : MainAxisAlignment
                          .start,
              children: [
                Image.asset(
                  'assets/branding/pet-house-green.png',
                  width: 32,
                  height: 32,
                ),

                if (!widget
                    .collapsed) ...[
                  const SizedBox(
                    width: 10,
                  ),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      mainAxisSize:
                          MainAxisSize
                              .min,
                      children: [
                        Text(
                          'SIYAM',
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .w700,
                            fontSize: 13,
                            color:
                                AppColors
                                    .sidebarForeground,
                          ),
                        ),

                        SingleChildScrollView(
                          scrollDirection:
                              Axis.horizontal,
                          child: Text(
                            'Shelter Inventory and Audit Management',
                            maxLines: 1,
                            softWrap:
                                false,
                            style:
                                TextStyle(
                              fontSize: 10,
                              color:
                                  AppColors
                                      .sidebarAccentForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                          context.go(
                            item.path,
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
                            mainAxisAlignment:
                                widget
                                        .collapsed
                                    ? MainAxisAlignment
                                        .center
                                    : MainAxisAlignment
                                        .start,
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

                              if (!widget
                                  .collapsed) ...[
                                const SizedBox(
                                  width:
                                      12,
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
              border: Border(
                top: BorderSide(
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
                // =============================================================
                // USER PROFILE
                // =============================================================

                if (!widget
                        .collapsed &&
                    user != null)
                  Material(
                    color:
                        Colors.transparent,
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                    child:
                        InkWell(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                      onTap: () {
                        context.go(
                          '/profile',
                        );
                      },
                      hoverColor:
                          AppColors
                              .sidebarPrimary
                              .withValues(
                        alpha:
                            0.08,
                      ),
                      highlightColor:
                          AppColors
                              .sidebarPrimary
                              .withValues(
                        alpha:
                            0.14,
                      ),
                      child:
                          Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              8,
                          vertical:
                              6,
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
                                      fontSize:
                                          12.5,
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
                                      fontSize:
                                          11,
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
                    ),
                  ),

                _buildLogoutArea(
                  auth,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}