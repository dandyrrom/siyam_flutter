import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../state/auth_state.dart';

const Map<String, String> _breadcrumbLabels = {
  'dashboard': 'Dashboard',
  'inventory': 'Inventory',
  'donations': 'Donations',
  'donate': 'Donate Now',
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
          const Icon(Icons.home_outlined, size: 16, color: AppColors.mutedForeground),
          for (final part in parts) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 14, color: AppColors.mutedForeground),
            const SizedBox(width: 6),
            Text(
              _breadcrumbLabels[part] ?? part,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: part == parts.last ? FontWeight.w600 : FontWeight.w400,
                color: part == parts.last
                    ? AppColors.foreground
                    : AppColors.mutedForeground,
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.mutedForeground, size: 20),
            onPressed: () {},
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined,
                    color: AppColors.mutedForeground, size: 20),
                onPressed: () => context.go('/notifications'),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: AppColors.destructive, shape: BoxShape.circle),
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
          if (user != null)
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.go('/profile'),
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
        ],
      ),
    );
  }
}
