import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../models/supplier.dart';
import '../services/supplier_service.dart';

/// Staff-only list of every purchase transaction (public.purchase), most
/// recent first. Each row opens the read-only detail/receipt view at
/// [PurchaseTransPage].
class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage> {
  final SupplierService _service = SupplierService();

  List<PurchaseOrder> _orders = [];
  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await _service.fetchAllPurchaseOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load purchase orders: $e';
        _loading = false;
      });
    }
  }

  List<PurchaseOrder> get _filtered {
    if (_search.isEmpty) return _orders;
    final q = _search.toLowerCase();
    return _orders.where((o) {
      return o.suppName.toLowerCase().contains(q) ||
          o.receivedBy.toLowerCase().contains(q) ||
          o.buyerName.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Purchase Orders',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(
          _orders.length == 1
              ? '1 purchase transaction'
              : '${_orders.length} purchase transactions',
          style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: 320,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Search supplier, received by…',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_orders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 36, color: AppColors.mutedForeground),
                  SizedBox(height: 10),
                  Text('No purchase orders yet',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text(
                    'Record a purchase from Inventory → Stock In.',
                    style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
          )
        else if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 32, color: AppColors.mutedForeground),
                  SizedBox(height: 8),
                  Text('No purchase orders match your search.',
                      style: TextStyle(color: AppColors.mutedForeground)),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            // Plain Column (not ListView) — AppShell already scrolls, and a
            // nested ListView+InkWell triggers layout asserts on Flutter Web.
            child: Column(
              children: [
                for (var i = 0; i < _filtered.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _OrderRow(order: _filtered[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _OrderRow extends StatelessWidget {
  final PurchaseOrder order;

  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/purchase-orders/${order.purId}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: Text(
                        order.suppName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text(
                        _formatDate(order.receivedDate),
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.mutedForeground),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: _MetaLine(
                        label: 'Received by',
                        value: order.receivedBy.isEmpty ? '—' : order.receivedBy,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: _MetaLine(
                        label: 'Recorded by',
                        value: order.buyerName,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  size: 20, color: AppColors.mutedForeground),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final String label;
  final String value;

  const _MetaLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
