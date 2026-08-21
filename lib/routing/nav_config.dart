import 'package:flutter/material.dart';

import '../models/app_user.dart';

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

/// Single source of truth for which roles can see/access which routes.
/// Used by SideNav (what to show) and the router (what to allow).
///
/// Current per-role tabs:
///
/// Manager:
///   Dashboard, Animals, Suppliers, Reports, Audit, Settings, Donations,
///   Profile, Notifications
///
/// Staff:
///   Dashboard, Inventory, Medical, Purchases & Replenishment, Reports,
///   My Activity, Profile, Notifications
///
/// Donor:
///   Dashboard, Donate, Impacts, Donations, Profile, Notifications
///
/// PANEL REVISION:
/// Purchase and Replenishment are one Staff navigation item.
/// Donations approval/stock-in is handled by Manager.
/// Staff receives limited read-only access to their own operational audit
/// activity through My Activity.
const List<NavItem> kNavItems = [
  NavItem(
    label: 'Dashboard',
    path: '/dashboard',
    icon: Icons.dashboard_outlined,
    roles: [
      AppRole.manager,
      AppRole.staff,
      AppRole.donor,
    ],
  ),
  NavItem(
    label: 'Animals',
    path: '/animal-records',
    icon: Icons.pets_outlined,
    roles: [AppRole.manager],
  ),
  NavItem(
    label: 'Suppliers',
    path: '/suppliers',
    icon: Icons.local_shipping_outlined,
    roles: [AppRole.manager],
  ),
  NavItem(
    label: 'Reports',
    path: '/reports',
    icon: Icons.bar_chart_outlined,
    roles: [AppRole.manager],
  ),
  NavItem(
    label: 'Audit',
    path: '/audit-trail',
    icon: Icons.fact_check_outlined,
    roles: [AppRole.manager],
  ),
  NavItem(
    label: 'Settings',
    path: '/settings',
    icon: Icons.settings_outlined,
    roles: [AppRole.manager],
  ),
  NavItem(
    label: 'Donations',
    path: '/donations',
    icon: Icons.volunteer_activism_outlined,
    roles: [AppRole.manager],
  ),
  NavItem(
    label: 'Inventory',
    path: '/inventory',
    icon: Icons.inventory_2_outlined,
    roles: [AppRole.staff],
  ),
  NavItem(
    label: 'Medical',
    path: '/medical-records',
    icon: Icons.medical_services_outlined,
    roles: [AppRole.staff],
  ),
  NavItem(
    label: 'Purchases & Replenishment',
    path: '/purchase-orders',
    icon: Icons.shopping_cart_outlined,
    roles: [AppRole.staff],
  ),
  NavItem(
    label: 'Reports',
    path: '/reports',
    icon: Icons.bar_chart_outlined,
    roles: [AppRole.staff],
  ),
  NavItem(
    label: 'My Activity',
    path: '/audit-trail',
    icon: Icons.fact_check_outlined,
    roles: [AppRole.staff],
  ),
  NavItem(
    label: 'Donate',
    path: '/donate',
    icon: Icons.favorite_outline,
    roles: [AppRole.donor],
  ),
  NavItem(
    label: 'Impacts',
    path: '/impacts',
    icon: Icons.insights_outlined,
    roles: [AppRole.donor],
  ),
  NavItem(
    label: 'Donations',
    path: '/donation-history',
    icon: Icons.receipt_long_outlined,
    roles: [AppRole.donor],
  ),
  NavItem(
    label: 'Profile',
    path: '/profile',
    icon: Icons.person_outline,
    roles: [
      AppRole.manager,
      AppRole.staff,
      AppRole.donor,
    ],
  ),
  NavItem(
    label: 'Notifications',
    path: '/notifications',
    icon: Icons.notifications_outlined,
    roles: [
      AppRole.manager,
      AppRole.staff,
      AppRole.donor,
    ],
  ),
];

/// Returns the roles allowed to view [path], or null if [path] is not a
/// role-gated route.
///
/// Because Manager "Audit" and Staff "My Activity" intentionally share
/// /audit-trail, this function unions both role lists for that route.
List<AppRole>? rolesAllowedFor(
  String path,
) {
  List<AppRole>? roles;

  for (final item in kNavItems) {
    if (path == item.path ||
        path.startsWith(
          '${item.path}/',
        )) {
      roles = {
        ...?roles,
        ...item.roles,
      }.toList();
    }
  }

  return roles;
}
