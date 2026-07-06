import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import 'side_nav.dart';
import 'top_nav.dart';

/// Wraps every authenticated/protected page with the sidebar + top nav,
/// mirroring ProtectedLayout from the original Layout.tsx.
class AppShell extends StatefulWidget {
  final Widget child;
  final String currentPath;

  const AppShell({super.key, required this.child, required this.currentPath});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _collapsed = false;

  void _toggle() => setState(() => _collapsed = !_collapsed);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          SideNav(collapsed: _collapsed, currentPath: widget.currentPath),
          Expanded(
            child: Column(
              children: [
                TopNav(currentPath: widget.currentPath, onToggleSidebar: _toggle),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1400),
                      child: widget.child,
                    ),
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
