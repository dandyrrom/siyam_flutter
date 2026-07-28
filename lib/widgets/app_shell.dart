import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../core/page_title.dart';
import 'side_nav.dart';
import 'top_nav.dart';
import 'mobile_drawer.dart';

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

  // GlobalKey for Scaffold (to control drawer)
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  void _toggle() => setState(() => _collapsed = !_collapsed);

  /// Keeps the browser tab title in sync with the current tab, e.g.
  /// "Dashboard - Siyam" -- same label the breadcrumb in [TopNav] shows.
  void _updatePageTitle() {
    final firstSegment = widget.currentPath.split('/').firstWhere(
          (p) => p.isNotEmpty,
          orElse: () => '',
        );
    final label = kBreadcrumbLabels[firstSegment];
    setPageTitle(label == null ? 'Siyam' : '$label - Siyam');
  }

  @override
  void initState() {
    super.initState();
    _updatePageTitle();
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPath != widget.currentPath) _updatePageTitle();
  }

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // MOBILE DETECTION: Check if screen width is less than 600px
    // ============================================================
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    // ============================================================
    // MOBILE: Scaffold with AppBar and Drawer
    // ============================================================
    if (isMobile) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('SIYAM'),
          leading: IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              if (_scaffoldKey.currentState != null) {
                _scaffoldKey.currentState!.openDrawer();
              }
            },
          ),
          elevation: 0,
          backgroundColor: AppColors.card,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () {
                context.go('/notifications');
              },
            ),
          ],
        ),
        // ============================================================
        // FIX: Pass the actual currentPath, not hardcoded '/dashboard'
        // ============================================================
        drawer: MobileDrawer(
          currentPath: widget.currentPath,  // ← CHANGED: Now uses actual path
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: widget.child,
          ),
        ),
      );
    }

    // ============================================================
    // WEB: Original layout (UNCHANGED)
    // ============================================================
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