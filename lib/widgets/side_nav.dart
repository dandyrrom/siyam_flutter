import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../routing/nav_config.dart';
import '../state/auth_state.dart';

class SideNav extends StatelessWidget {
  final bool collapsed;
  final String currentPath;

  const SideNav(
      {super.key, required this.collapsed, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.profile;
    final items = kNavItems
        .where((i) => user != null && i.roles.contains(user.role))
        .toList();

    return Container(
      width: collapsed ? 72 : 248,
      decoration: const BoxDecoration(
        color: AppColors.sidebar,
        border: Border(right: BorderSide(color: AppColors.sidebarBorder)),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: AppColors.sidebarBorder)),
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/branding/pet-house-green.png',
                  width: 32,
                  height: 32,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('SIYAM',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.sidebarForeground),
                            overflow: TextOverflow.ellipsis),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text('Shelter Inventory and Audit Management',
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.sidebarAccentForeground)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: items.map((item) {
                final active = currentPath.startsWith(item.path);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color:
                        active ? AppColors.sidebarAccent : Colors.transparent,
                    elevation: active ? 1 : 0,
                    shadowColor:
                        AppColors.sidebarForeground.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.go(item.path),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        child: Row(
                          mainAxisAlignment: collapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            Icon(item.icon,
                                size: 18,
                                color: active
                                    ? AppColors.sidebarPrimary
                                    : AppColors.sidebarAccentForeground),
                            if (!collapsed) ...[
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
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // User + logout
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.sidebarBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!collapsed && user != null)
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => context.go('/profile'),
                      hoverColor: AppColors.sidebarPrimary.withValues(alpha: 0.08),
                      highlightColor: AppColors.sidebarPrimary.withValues(alpha: 0.14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: AppColors.sidebarPrimary,
                              child: Text(user.initials,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.sidebarPrimaryForeground)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(user.fullName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.sidebarForeground)),
                                  Text(user.email,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors
                                              .sidebarAccentForeground)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                collapsed
                    ? IconButton(
                        onPressed: () async {
                          await context.read<AuthController>().logout();
                          if (context.mounted) context.go('/login');
                        },
                        icon: const Icon(Icons.logout,
                            size: 16, color: AppColors.sidebarAccentForeground),
                      )
                    : TextButton.icon(
                        onPressed: () async {
                          await context.read<AuthController>().logout();
                          if (context.mounted) context.go('/login');
                        },
                        icon: const Icon(Icons.logout,
                            size: 16, color: AppColors.sidebarAccentForeground),
                        label: const Text('Logout',
                            style:
                                TextStyle(color: AppColors.sidebarForeground)),
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
    );
  }
}
