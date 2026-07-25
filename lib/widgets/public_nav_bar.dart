import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';

class _PublicTab {
  final String label;
  final String path;
  const _PublicTab(this.label, this.path);
}

const _kPublicTabs = [
  _PublicTab('Home', '/'),
  _PublicTab('About DAS', '/about'),
  _PublicTab('Donate', '/donate-info'),
  _PublicTab('FAQs', '/faqs'),
];

/// Shared top navigation for every public page (landing, about, donate-info,
/// FAQs, login, register) -- including the sign-in page itself, so it's the
/// exact same full-width bar everywhere rather than a page-specific one.
/// Collapses the tab strip into a menu below [_kNarrowBreakpoint] so it
/// never overflows on small windows.
class PublicNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String currentPath;
  const PublicNavBar({super.key, required this.currentPath});

  static const _kNarrowBreakpoint = 760.0;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            height: 76,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < _kNarrowBreakpoint;
                    if (narrow) {
                      return Row(
                        children: [
                          _Brand(onTap: () => context.go('/')),
                          const Spacer(),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.menu,
                                color: AppColors.deepBrown),
                            onSelected: (path) => context.go(path),
                            itemBuilder: (context) => [
                              for (final tab in _kPublicTabs)
                                PopupMenuItem(
                                    value: tab.path, child: Text(tab.label)),
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                  value: '/register', child: Text('Register')),
                              const PopupMenuItem(
                                  value: '/login', child: Text('Sign In')),
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _Brand(onTap: () => context.go('/')),
                          ),
                        ),
                        Row(
                          children: [
                            for (final tab in _kPublicTabs)
                              _NavTabButton(
                                label: tab.label,
                                active: _isActive(tab.path),
                                onTap: () => context.go(tab.path),
                              ),
                          ],
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => context.go('/register'),
                                  style: TextButton.styleFrom(
                                    backgroundColor: AppColors.cream,
                                    foregroundColor: AppColors.deepBrown,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      side: BorderSide(
                                          color: AppColors.catGray
                                              .withValues(alpha: 0.8)),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 22, vertical: 12),
                                  ),
                                  child: const Text('Register',
                                      style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 16),
                                _NavTabButton(
                                  label: 'Sign In',
                                  active: _isActive('/login'),
                                  onTap: () => context.go('/login'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isActive(String path) =>
      path == '/' ? currentPath == '/' : currentPath.startsWith(path);
}

class _Brand extends StatelessWidget {
  final VoidCallback onTap;
  const _Brand({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Image.asset(
                'assets/branding/pet-house-green.png',
                width: 36,
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text('SIYAM',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.deepBrown)),
          ],
        ),
      ),
    );
  }
}

class _NavTabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavTabButton(
      {required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.sageGreen : AppColors.deepBrown;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 14,
                    color: color),
              ),
              const SizedBox(height: 3),
              Container(width: 32, height: 2, color: active ? color : Colors.transparent),
            ],
          ),
        ),
      ),
    );
  }
}
