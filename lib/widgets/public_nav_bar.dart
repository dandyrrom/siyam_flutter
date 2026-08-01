import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';

/// Shared top navigation for the public login/register pages.
/// Registration is disabled for now, so the Register action is shown
/// greyed-out and non-interactive.
/// Collapses to a menu below [_kNarrowBreakpoint] so it never overflows on
/// small windows.
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
                          _Brand(onTap: () => context.go('/login')),
                          const Spacer(),
                          const _DisabledRegisterButton(),
                          const SizedBox(width: 12),
                          _NavTabButton(
                            label: 'Sign In',
                            active: _isActive('/login'),
                            onTap: () => context.go('/login'),
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _Brand(onTap: () => context.go('/login')),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _DisabledRegisterButton(),
                            const SizedBox(width: 16),
                            _NavTabButton(
                              label: 'Sign In',
                              active: _isActive('/login'),
                              onTap: () => context.go('/login'),
                            ),
                          ],
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

/// Registration is disabled system-wide for now; shown greyed-out and
/// non-interactive rather than removed outright.
class _DisabledRegisterButton extends StatelessWidget {
  const _DisabledRegisterButton();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cream.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppColors.catGray.withValues(alpha: 0.4)),
        ),
        child: Text('Register',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.deepBrown.withValues(alpha: 0.4))),
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
