import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../models/supplier.dart';
import '../services/supplier_service.dart';

/// Read-only detail/receipt view for a single public.purchase_trans row:
/// who it was placed with and by whom, when it was received, and every
/// order_item line logged against it. There's no edit/delete here -- this
/// is a record of what happened, not a form.
class PurchaseTransPage extends StatefulWidget {
  final String purId;
  const PurchaseTransPage({super.key, required this.purId});

  @override
  State<PurchaseTransPage> createState() => _PurchaseTransPageState();
}

class _PurchaseTransPageState extends State<PurchaseTransPage> {
  final SupplierService _service = SupplierService();

  PurchaseOrder? _order;
  List<OrderLineItem> _items = [];
  bool _loading = true;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _notFound = false;
    });
    try {
      final results = await Future.wait([
        _service.fetchPurchaseOrder(widget.purId),
        _service.fetchOrderItems(widget.purId),
      ]);
      if (!mounted) return;
      final order = results[0] as PurchaseOrder?;
      setState(() {
        _order = order;
        _items = results[1] as List<OrderLineItem>;
        _notFound = order == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _notFound = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notFound || _order == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            const Text('Purchase order not found', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => context.go('/purchase-orders'),
                child: const Text('Back to Purchase Orders')),
          ],
        ),
      );
    }

    final order = _order!;
    final total = _items.fold<double>(0, (sum, i) => sum + i.qty * i.unitCost);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/purchase-orders'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Purchase Orders'),
            style: TextButton.styleFrom(foregroundColor: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          Text(order.suppName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _FieldBlock(label: 'Date received', value: _formatDate(order.purDate)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FieldBlock(label: 'Received by', value: order.buyerName),
              ),
            ],
          ),
          const SizedBox(height: 24),

          const _SectionLabel('Items'),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: _HeaderCell('Item')),
                      Expanded(flex: 2, child: _HeaderCell('Qty')),
                      Expanded(flex: 2, child: _HeaderCell('Unit cost')),
                      Expanded(flex: 2, child: _HeaderCell('Subtotal')),
                    ],
                  ),
                ),
                const Divider(height: 1),
                if (_items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No items logged for this purchase.',
                          style: TextStyle(color: AppColors.mutedForeground)),
                    ),
                  )
                else
                  for (final item in _items)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(item.itemName, overflow: TextOverflow.ellipsis),
                          ),
                          Expanded(flex: 2, child: Text('${item.qty} ${item.itemUom}')),
                          Expanded(flex: 2, child: Text('₱${item.unitCost.toStringAsFixed(2)}')),
                          Expanded(
                            flex: 2,
                            child: Text(
                              '₱${(item.qty * item.unitCost).toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('₱${total.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ],
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  final String label;
  final String value;
  const _FieldBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.mutedForeground,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.mutedForeground,
      ),
    );
  }
}

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
