import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../services/inventory_service.dart';
import '../state/auth_state.dart';
import 'notification_bell.dart';

/// Path segment -> display label, shared with [setPageTitle] so the browser
/// tab title and the breadcrumb always agree.
///
/// IMPORTANT:
/// Dynamic database IDs are handled separately below so raw UUIDs are never
/// intentionally shown as breadcrumb labels.
const Map<String, String> kBreadcrumbLabels = {
  'dashboard': 'Dashboard',
  'donor': 'Dashboard',
  'inventory': 'Inventory',
  'donations': 'Donations',
  'impacts': 'Impacts',
  'donation-history': 'Donations',
  'reports': 'Reports',
  'medical-records': 'Medical',
  'animal-records': 'Animals',
  'suppliers': 'Suppliers',

  // Purchase + Replenishment are now one module.
  'purchase-orders': 'Purchases & Replenishment',
  'replenishment': 'Purchases & Replenishment',

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

  // ===========================================================================
  // BREADCRUMB LABEL RESOLUTION
  // ===========================================================================
  //
  // Static routes use [kBreadcrumbLabels].
  //
  // Dynamic routes use readable page/entity labels instead of exposing raw
  // database IDs.
  //
  // Examples:
  //
  // /inventory/<uuid>
  //   Inventory > Whiskas
  //
  // /purchase-orders/<uuid>
  //   Purchases & Replenishment > Purchase Details
  //
  // /donations/<uuid>
  //   Donations > Donation Details
  //
  // /medical-records/<uuid>
  //   Medical > Treatment Details
  //
  // /medical-records/pet/<uuid>
  //   Medical > Animal > Medical History
  // ===========================================================================

  String _staticBreadcrumbLabel(
    List<String> parts,
    int index,
  ) {
    final part = parts[index];

    final mapped = kBreadcrumbLabels[part];
    if (mapped != null) {
      return mapped;
    }

    // -------------------------------------------------------------------------
    // INVENTORY
    // -------------------------------------------------------------------------

    if (parts.isNotEmpty && parts.first == 'inventory') {
      if (index == 1 && part == 'add') {
        return 'Stock In';
      }

      if (index == 1) {
        // The actual item name is loaded by _InventoryItemBreadcrumbLabel.
        return 'Item Details';
      }
    }

    // -------------------------------------------------------------------------
    // PURCHASES & REPLENISHMENT
    // -------------------------------------------------------------------------

    if (parts.isNotEmpty && parts.first == 'purchase-orders') {
      if (index == 1) {
        return 'Purchase Details';
      }
    }

    // -------------------------------------------------------------------------
    // STAFF DONATIONS
    // -------------------------------------------------------------------------

    if (parts.isNotEmpty && parts.first == 'donations') {
      if (index == 1) {
        return 'Donation Details';
      }
    }

    // -------------------------------------------------------------------------
    // MEDICAL
    // -------------------------------------------------------------------------

    if (parts.isNotEmpty && parts.first == 'medical-records') {
      if (index == 1 && part == 'add') {
        return 'Add Treatment';
      }

      if (index == 1 && part == 'pet') {
        return 'Animal';
      }

      if (index == 2 && parts.length > 1 && parts[1] == 'pet') {
        return 'Medical History';
      }

      if (index == 1) {
        return 'Treatment Details';
      }
    }

    // -------------------------------------------------------------------------
    // NOTIFICATIONS
    // -------------------------------------------------------------------------

    if (parts.isNotEmpty && parts.first == 'notifications') {
      if (index == 1 && parts.length >= 3) {
        return 'Notification';
      }

      if (index == 2) {
        return 'Details';
      }
    }

    // -------------------------------------------------------------------------
    // SAFE FALLBACK
    // -------------------------------------------------------------------------
    //
    // If another detail route is added later and it contains a UUID, show a
    // readable generic label instead of leaking the UUID into the UI.
    // -------------------------------------------------------------------------

    if (_looksLikeUuid(part)) {
      return 'Details';
    }

    return _titleCaseSegment(part);
  }

  bool _isInventoryItemSegment(
    List<String> parts,
    int index,
  ) {
    return parts.isNotEmpty &&
        parts.first == 'inventory' &&
        index == 1 &&
        parts[index] != 'add';
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{4}-'
      r'[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }

  String _titleCaseSegment(String value) {
    if (value.trim().isEmpty) {
      return '';
    }

    final words = value
        .replaceAll('-', ' ')
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);

    return words
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().profile;

    final parts = currentPath
        .split('/')
        .where((part) => part.isNotEmpty)
        .toList();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.card,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(
              Icons.menu,
              color: AppColors.mutedForeground,
            ),
            onPressed: onToggleSidebar,
          ),

          const SizedBox(width: 4),

          // ===================================================================
          // BREADCRUMB / HISTORY TRAIL
          // ===================================================================

          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(
                    Icons.home_outlined,
                    size: 16,
                    color: AppColors.mutedForeground,
                  ),

                  for (var index = 0;
                      index < parts.length;
                      index++) ...[
                    const SizedBox(width: 6),

                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.mutedForeground,
                    ),

                    const SizedBox(width: 6),

                    _BreadcrumbLabel(
                      isLast: index == parts.length - 1,
                      child: _isInventoryItemSegment(
                        parts,
                        index,
                      )
                          ? _InventoryItemBreadcrumbLabel(
                              itemId: parts[index],
                            )
                          : Text(
                              _staticBreadcrumbLabel(
                                parts,
                                index,
                              ),
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
                hoverColor: AppColors.primary.withValues(
                  alpha: 0.08,
                ),
                highlightColor: AppColors.primary.withValues(
                  alpha: 0.14,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            user.firstName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${user.role.name[0].toUpperCase()}'
                            '${user.role.name.substring(1)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.mutedForeground,
                            ),
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

// =============================================================================
// BREADCRUMB TEXT STYLE
// =============================================================================
//
// This wrapper keeps the current breadcrumb styling in one place.
// It also avoids relying on "part == parts.last", which can be incorrect when
// the same path segment appears more than once. The caller passes the actual
// index-based [isLast] value instead.
// =============================================================================

class _BreadcrumbLabel extends StatelessWidget {
  final bool isLast;
  final Widget child;

  const _BreadcrumbLabel({
    required this.isLast,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(
        fontSize: 13.5,
        fontWeight:
            isLast ? FontWeight.w600 : FontWeight.w400,
        color: isLast
            ? AppColors.foreground
            : AppColors.mutedForeground,
      ),
      child: child,
    );
  }
}

// =============================================================================
// INVENTORY ITEM BREADCRUMB
// =============================================================================
//
// Inventory detail routes contain the item's UUID:
//
//   /inventory/<item-id>
//
// The route must keep that UUID because it is the correct database identifier.
// This widget only changes what the user SEES in the breadcrumb.
//
// It loads the same InventoryItem through the existing InventoryService and
// displays item.itemName.
//
// The Future is cached in State so ordinary TopNav rebuilds (for example an
// AuthController notification) do not repeatedly query the item.
// =============================================================================

class _InventoryItemBreadcrumbLabel extends StatefulWidget {
  final String itemId;

  const _InventoryItemBreadcrumbLabel({
    required this.itemId,
  });

  @override
  State<_InventoryItemBreadcrumbLabel> createState() =>
      _InventoryItemBreadcrumbLabelState();
}

class _InventoryItemBreadcrumbLabelState
    extends State<_InventoryItemBreadcrumbLabel> {
  late Future<String> _labelFuture;

  @override
  void initState() {
    super.initState();
    _labelFuture = _loadLabel();
  }

  @override
  void didUpdateWidget(
    covariant _InventoryItemBreadcrumbLabel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.itemId != widget.itemId) {
      _labelFuture = _loadLabel();
    }
  }

  Future<String> _loadLabel() async {
    try {
      final item = await InventoryService().fetchItem(
        widget.itemId,
      );

      final name = item?.itemName.trim() ?? '';

      if (name.isNotEmpty) {
        return name;
      }
    } catch (_) {
      // Breadcrumb failure must never break page navigation or item details.
    }

    return 'Item Details';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _labelFuture,
      builder: (
        context,
        snapshot,
      ) {
        return Text(
          snapshot.data ?? 'Item Details',
        );
      },
    );
  }
}
