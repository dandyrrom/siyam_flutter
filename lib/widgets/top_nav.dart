import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../state/auth_state.dart';
import 'notification_bell.dart';

/// Path segment -> display label, shared with [setPageTitle] so the browser
/// tab title and the breadcrumb always agree.
const Map<String, String> kBreadcrumbLabels = {
  'dashboard': 'Dashboard',
  'inventory': 'Inventory',
  'donations': 'Donations',
  'impacts': 'Impacts',
  'donation-history': 'Donations',
  'reports': 'Reports & Analytics',
  'medical-records': 'Medical',
  'animal-records': 'Animals',
  'suppliers': 'Suppliers',
  'audit-trail': 'Audit Trail',
  'settings': 'Settings',
  'profile': 'Profile',
  'notifications': 'Notifications',
};

class TopNav extends StatelessWidget implements PreferredSizeWidget {
  final String currentPath;
  final VoidCallback onToggleSidebar;

  const TopNav({
    super.key,
    required this.currentPath,
    required this.onToggleSidebar,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().profile;
    final parts = currentPath.split('/').where((p) => p.isNotEmpty).toList();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.mutedForeground),
            onPressed: onToggleSidebar,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.home_outlined,
                      size: 16, color: AppColors.mutedForeground),
                  for (final part in parts) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right,
                        size: 14, color: AppColors.mutedForeground),
                    const SizedBox(width: 6),
                    Text(
                      kBreadcrumbLabels[part] ?? part,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: part == parts.last ? FontWeight.w600 : FontWeight.w400,
                        color: part == parts.last
                            ? AppColors.foreground
                            : AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const NotificationBell(),
          const SizedBox(width: 6),
          if (user != null)
            Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.go('/profile'),
              hoverColor: AppColors.primary.withValues(alpha: 0.08),
              highlightColor: AppColors.primary.withValues(alpha: 0.14),
              child: Padding(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(user.firstName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          user.role.name,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.mutedForeground),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ),
            ),
        ],
      ),
    );
  }
}
