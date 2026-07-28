import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../routing/nav_config.dart';
import '../state/auth_state.dart';
import '../models/app_user.dart';  // ← ADDED: For appRoleToString

class MobileDrawer extends StatelessWidget {
  final String currentPath;

  const MobileDrawer({
    super.key,
    required this.currentPath,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.profile;
    final items = kNavItems
        .where((i) => user != null && i.roles.contains(user.role))
        .toList();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // ============================================================
            // DRAWER HEADER
            // ============================================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              color: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SIYAM',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.fullName ?? 'Guest',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (user != null)
                    Text(
                      appRoleToString(user.role).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            // ============================================================
            // DRAWER ITEMS (Using same pattern as SideNav)
            // ============================================================
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                children: items.map((item) {
                  final active = currentPath.startsWith(item.path);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: active
                          ? AppColors.sidebarAccent
                          : Colors.transparent,
                      elevation: active ? 1 : 0,
                      shadowColor: AppColors.sidebarForeground
                          .withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        // ============================================================
                        // EXACT SAME NAVIGATION AS SIDEBAR
                        // ============================================================
                        onTap: () {
                          // Close drawer first
                          Navigator.of(context).pop();
                          // Navigate using the same method as sidebar
                          context.go(item.path);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 11),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: active
                                    ? AppColors.sidebarPrimary
                                    : AppColors.sidebarAccentForeground,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: active
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: AppColors.sidebarForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            // ============================================================
            // LOGOUT (Same as sidebar)
            // ============================================================
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: AppColors.sidebarBorder),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (user != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: AppColors.sidebarPrimary,
                            child: Text(
                              user.initials,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.sidebarPrimaryForeground,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user.fullName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.sidebarForeground,
                                  ),
                                ),
                                Text(
                                  user.email,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.sidebarAccentForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  // ============================================================
                  // LOGOUT BUTTON (Same as sidebar)
                  // ============================================================
                  TextButton.icon(
                    onPressed: () async {
                      // Close drawer
                      Navigator.of(context).pop();
                      // Logout (same as sidebar)
                      await context.read<AuthController>().logout();
                      if (context.mounted) context.go('/login');
                    },
                    icon: const Icon(
                      Icons.logout,
                      size: 16,
                      color: AppColors.sidebarAccentForeground,
                    ),
                    label: const Text(
                      'Logout',
                      style: TextStyle(color: AppColors.sidebarForeground),
                    ),
                    style: TextButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
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