import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../models/inventory_item.dart';
import '../services/dashboard_service.dart';
import '../services/expiry_alerts.dart';
import '../services/inventory_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import '../widgets/notification_alerts.dart';

/// Full-information view for a single alert -- opened from a compact
/// notification row on `NotificationsPage` or the top-nav bell. [kind] and
/// [itemId] come from the route (`/notifications/:kind/:id`); everything
/// shown here is re-derived from the same services that produce the compact
/// list (`DashboardService`, `InventoryService`), not passed through
/// navigation state, so a refresh or a deep link works the same way.
class NotificationDetailPage extends StatefulWidget {
  final NotifKind kind;
  final String itemId;

  const NotificationDetailPage({
    super.key,
    required this.kind,
    required this.itemId,
  });

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage>
    with DataBusRefreshMixin<NotificationDetailPage> {
  final InventoryService _inventoryService = InventoryService();
  final DashboardService _dashboardService = DashboardService();

  InventoryItem? _item;
  ExpiryAlert? _expiryAlert;
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _inventoryService.fetchItem(widget.itemId),
        _dashboardService.fetchManagerStats(),
      ]);
      if (!mounted) return;
      final item = results[0] as InventoryItem?;
      final stats = results[1] as ManagerDashboardStats;
      ExpiryAlert? expiryAlert;
      for (final alert in stats.expiringSoonItems) {
        if (alert.itemId == widget.itemId) {
          expiryAlert = alert;
          break;
        }
      }
      setState(() {
        _item = item;
        _expiryAlert = expiryAlert;
        _notFound = item == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notFound || _item == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_off_outlined,
                size: 40, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            const Text('Notification not found', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'This item may have been removed or restocked.',
              style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go('/notifications'),
              child: const Text('Back to Notifications'),
            ),
          ],
        ),
      );
    }

    final item = _item!;
    final isManager = context.watch<AuthController>().profile?.role == AppRole.manager;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/notifications'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Notifications'),
            style: TextButton.styleFrom(foregroundColor: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          _StatusBanner(kind: widget.kind, item: item, expiryAlert: _expiryAlert),
          const SizedBox(height: 20),
          Text(item.itemName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(item.itemCategory, style: const TextStyle(color: AppColors.mutedForeground)),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _detailRows(item),
            ),
          ),
          if (!isManager) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/inventory/${item.itemId}'),
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('View Full Item Details'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _detailRows(InventoryItem item) {
    final rows = <Widget>[
      _DetailRow(label: 'Purchase stock', value: '${formatQty(item.stockQty)} ${item.purchaseUnitAbbr}'),
    ];
    if (item.packageStockQty != null) {
      rows.add(_DetailRow(
        label: 'Package stock',
        value: '${formatQty(item.packageStockQty!)} ${item.packageUnitAbbr ?? ''}'.trim(),
      ));
    }
    if (widget.kind == NotifKind.lowStock) {
      rows.add(_DetailRow(
        label: 'Low-stock threshold',
        value: '${formatQty(lowStockPurchaseUnitThreshold)} ${item.purchaseUnitAbbr}',
      ));
    }
    if (widget.kind == NotifKind.expiry && _expiryAlert != null) {
      final alert = _expiryAlert!;
      rows.add(_DetailRow(label: 'Nearest batch expiry', value: _formatDate(alert.expiryDate)));
      rows.add(_DetailRow(label: 'Status', value: formatExpirySubtitle(alert.daysUntilExpiry)));
    }
    return [
      for (var i = 0; i < rows.length; i++) ...[
        if (i > 0) const Divider(height: 20, color: AppColors.border),
        rows[i],
      ],
    ];
  }
}

const _monthAbbr = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime d) => '${_monthAbbr[d.month - 1]} ${d.day}, ${d.year}';

class _StatusBanner extends StatelessWidget {
  final NotifKind kind;
  final InventoryItem item;
  final ExpiryAlert? expiryAlert;

  const _StatusBanner({required this.kind, required this.item, required this.expiryAlert});

  @override
  Widget build(BuildContext context) {
    final (label, accent) = switch (kind) {
      NotifKind.zeroStock => ('Out of Stock', AppColors.destructive),
      NotifKind.lowStock => ('Low Stock', AppColors.warning),
      NotifKind.expiry => (expiryAlert != null && expiryAlert!.daysUntilExpiry < 0)
          ? ('Expired', AppColors.destructive)
          : ('Expiring Soon', AppColors.warning),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(kind.icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent)),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
