import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../state/auth_state.dart';

class NavItem {
  final String label;
  final String path;
  final IconData icon;
  final List<AppRole> roles;

  const NavItem({
    required this.label,
    required this.path,
    required this.icon,
    required this.roles,
  });
}

// Mirrors NAV_ITEMS in the original Sidebar.tsx
const List<NavItem> _navItems = [
  NavItem(
      label: 'Dashboard',
      path: '/dashboard',
      icon: Icons.dashboard_outlined,
      roles: [AppRole.manager, AppRole.staff, AppRole.donor]),
  NavItem(
      label: 'Animals',
      path: '/animal-records',
      icon: Icons.pets_outlined,
      roles: [AppRole.manager]),
  NavItem(
      label: 'Suppliers',
      path: '/suppliers',
      icon: Icons.local_shipping_outlined,
      roles: [AppRole.manager]),
  NavItem(
      label: 'Reports',
      path: '/reports',
      icon: Icons.bar_chart_outlined,
      roles: [AppRole.manager, AppRole.staff]),
  NavItem(
      label: 'Audit Trail',
      path: '/audit-trail',
      icon: Icons.fact_check_outlined,
      roles: [AppRole.manager]),
  NavItem(
      label: 'Settings',
      path: '/settings',
      icon: Icons.settings_outlined,
      roles: [AppRole.manager]),
  NavItem(
      label: 'Inventory',
      path: '/inventory',
      icon: Icons.inventory_2_outlined,
      roles: [AppRole.staff]),
  NavItem(
      label: 'Medical',
      path: '/medical-records',
      icon: Icons.medical_services_outlined,
      roles: [AppRole.staff]),
  NavItem(
      label: 'Donations',
      path: '/donations',
      icon: Icons.volunteer_activism_outlined,
      roles: [AppRole.staff]),
  NavItem(
      label: 'Donate Now',
      path: '/donate',
      icon: Icons.favorite_outline,
      roles: [AppRole.donor]),
  NavItem(
      label: 'Donations',
      path: '/donation-history',
      icon: Icons.receipt_long_outlined,
      roles: [AppRole.donor]),
  NavItem(
      label: 'Profile',
      path: '/profile',
      icon: Icons.person_outline,
      roles: [AppRole.manager, AppRole.staff, AppRole.donor]),
  NavItem(
      label: 'Notifications',
      path: '/notifications',
      icon: Icons.notifications_outlined,
      roles: [AppRole.manager, AppRole.staff, AppRole.donor]),
];

class SideNav extends StatelessWidget {
  final bool collapsed;
  final String currentPath;

  const SideNav({super.key, required this.collapsed, required this.currentPath});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.profile;
    final items =
        _navItems.where((i) => user != null && i.roles.contains(user.role)).toList();

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
              border: Border(bottom: BorderSide(color: AppColors.sidebarBorder)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.pets, size: 16, color: Colors.white),
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
                                fontWeight: FontWeight.w700, fontSize: 13),
                            overflow: TextOverflow.ellipsis),
                        Text('Dumaguete Sanctuary',
                            style: TextStyle(
                                fontSize: 10, color: AppColors.mutedForeground),
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Role badge
          if (!collapsed && user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.apartment, size: 13, color: AppColors.mutedForeground),
                    const SizedBox(width: 6),
                    Text(
                      appRoleToString(user.role).toUpperCase(),
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: AppColors.mutedForeground),
                    ),
                  ],
                ),
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
                    color: active ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => context.go(item.path),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 11),
                        child: Row(
                          children: [
                            Icon(item.icon,
                                size: 18,
                                color: active
                                    ? Colors.white
                                    : AppColors.mutedForeground),
                            if (!collapsed) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight:
                                        active ? FontWeight.w600 : FontWeight.w400,
                                    color: active
                                        ? Colors.white
                                        : AppColors.foreground,
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: AppColors.primary,
                          child: Text(user.initials,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
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
                                      fontSize: 12.5, fontWeight: FontWeight.w600)),
                              Text(user.email,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.mutedForeground)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                TextButton.icon(
                  onPressed: () async {
                    await context.read<AuthController>().logout();
                    if (context.mounted) context.go('/login');
                  },
                  icon: const Icon(Icons.logout, size: 16, color: AppColors.mutedForeground),
                  label: collapsed
                      ? const SizedBox.shrink()
                      : const Text('Logout', style: TextStyle(color: AppColors.foreground)),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
