import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import '../widgets/stat_card.dart'; // for ComingSoonNotice
import '../widgets/stock_out_dialog.dart';

class InventoryItemPage extends StatefulWidget {
  final String itemId;
  const InventoryItemPage({super.key, required this.itemId});

  @override
  State<InventoryItemPage> createState() => _InventoryItemPageState();
}

class _InventoryItemPageState extends State<InventoryItemPage> {
  final InventoryService _service = InventoryService();

  InventoryItem? _item;
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
      final item = await _service.fetchItem(widget.itemId);
      if (!mounted) return;
      setState(() {
        _item = item;
        _notFound = item == null;
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

  Future<void> _editField({
    required String label,
    required String currentValue,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit $label'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop();
              try {
                await onSave(controller.text.trim());
                _load();
              } catch (e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text('Could not update: $e')));
}
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _openStockOutDialog() async {
    final item = _item;
    if (item == null) return;
    final result = await showStockOutDialog(context, service: _service, item: item);
    if (!mounted) return;
    if (result != null) {
      final (usedItem, qty) = result;
      context.push('/medical-records/add?itemId=${usedItem.itemId}&qty=$qty');
      return;
    }
    _load();
  }

  Future<void> _confirmDelete() async {
    final item = _item;
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete item?'),
        content: Text('This will permanently remove "${item.itemName}" from inventory.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
  try {
    await _service.deleteItem(item.itemId);
    if (!mounted) return;
    context.go('/inventory');
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Could not delete item: $e')));
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
            const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            const Text('Item not found', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextButton(onPressed: () => context.go('/inventory'), child: const Text('Back to Inventory')),
          ],
        ),
      );
    }

    final item = _item!;
    final outOfStock = item.stockQty <= 0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/inventory'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Inventory'),
            style: TextButton.styleFrom(foregroundColor: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: (outOfStock ? AppColors.destructive : AppColors.roleManager)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        outOfStock ? 'Out of Stock' : 'In Stock',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: outOfStock ? AppColors.destructive : AppColors.roleManager,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(item.itemName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'delete') _confirmDelete();
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'delete', child: Text('Delete item')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/inventory/add?itemId=${item.itemId}'),
                  icon: const Icon(Icons.arrow_upward, size: 16, color: AppColors.roleManager),
                  label: const Text('Stock In'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
                  onPressed: _openStockOutDialog,
                  icon: const Icon(Icons.arrow_downward, size: 16),
                  label: const Text('Stock Out'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _FieldRow(
            label: 'Name',
            value: item.itemName,
            onEdit: () => _editField(
              label: 'Name',
              currentValue: item.itemName,
              onSave: (v) => _service.updateDetails(itemId: item.itemId, itemName: v),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _FieldRow(
                  label: 'Category',
                  value: item.itemCategory,
                  onEdit: () => _editField(
                    label: 'Category',
                    currentValue: item.itemCategory,
                    onSave: (v) => _service.updateDetails(itemId: item.itemId, itemCategory: v),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FieldRow(
                  label: 'Unit of Measure',
                  value: item.itemUom,
                  onEdit: () => _editField(
                    label: 'Unit of Measure',
                    currentValue: item.itemUom,
                    onSave: (v) => _service.updateDetails(itemId: item.itemId, itemUom: v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const _FieldLabel('Quantity'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Row(
              children: [
                Text(formatQty(item.stockQty), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text(item.itemUom, style: const TextStyle(color: AppColors.mutedForeground)),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const ComingSoonNotice(
            text:
                'Stock history (who stocked in/out and when) will appear here once transaction logging is added to the database.',
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onEdit;

  const _FieldRow({required this.label, required this.value, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 15, color: AppColors.mutedForeground),
                onPressed: onEdit,
                splashRadius: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}