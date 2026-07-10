import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import 'search_select_field.dart';

/// Stock Out modal: quantity + reason (Waste, Expired, Adjustment,
/// Treatment).
///
/// For Waste/Expired/Adjustment, this directly decrements
/// `item.currentstock` and returns null -- there's no stock-history table
/// in the schema, so this doesn't leave a separate audit trail beyond
/// the updated quantity.
///
/// For Treatment, this does NOT touch inventory itself -- it returns the
/// entered quantity so the caller can redirect to the Add Treatment
/// page, which records the usage (and the actual stock deduction) via
/// treatment_item.
///
/// If [item] is null (opened from the Inventory page's "New" menu rather
/// than a specific row), a TSS item picker is shown first -- the returned
/// record includes which item was picked so the caller can build the
/// Add Treatment redirect without already knowing it.
Future<(InventoryItem, double)?> showStockOutDialog(
  BuildContext context, {
  required InventoryService service,
  InventoryItem? item,
  List<InventoryItem> items = const [],
}) {
  final qtyCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String reason = 'Waste';
  InventoryItem? selectedItem = item;

  return showDialog<(InventoryItem, double)?>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.arrow_downward, size: 18, color: AppColors.destructive),
            SizedBox(width: 8),
            Text('Stock Out'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item == null) ...[
                SearchSelectField<InventoryItem>(
                  labelText: 'Item',
                  options: items,
                  displayStringForOption: (i) => i.itemName,
                  validator: (v) => selectedItem == null ? 'Required' : null,
                  onSelected: (picked) => setDialogState(() => selectedItem = picked),
                ),
                const SizedBox(height: 16),
              ],
              if (selectedItem != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(selectedItem!.itemName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Current: ${formatQty(selectedItem!.stockQty)} ${selectedItem!.itemUom}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: item != null,
                decoration: InputDecoration(
                    labelText: 'Quantity${selectedItem == null ? '' : ' (${selectedItem!.itemUom})'}'),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a quantity greater than 0';
                  if (selectedItem != null && n > selectedItem!.stockQty) {
                    return 'Only ${formatQty(selectedItem!.stockQty)} ${selectedItem!.itemUom} available';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reason,
                decoration: const InputDecoration(labelText: 'Reason'),
                items: const [
                  DropdownMenuItem(value: 'Waste', child: Text('Waste')),
                  DropdownMenuItem(value: 'Expired', child: Text('Expired')),
                  DropdownMenuItem(value: 'Adjustment', child: Text('Adjustment')),
                  DropdownMenuItem(value: 'Treatment', child: Text('Treatment')),
                ],
                onChanged: (v) => setDialogState(() => reason = v ?? 'Waste'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final target = selectedItem;
              if (target == null) return;
              final qty = double.parse(qtyCtrl.text);

              if (reason == 'Treatment') {
                Navigator.of(context).pop((target, qty));
                return;
              }

              try {
                await service.adjustStock(itemId: target.itemId, delta: -qty);
                if (!context.mounted) return;
                Navigator.of(context).pop();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: Text(reason == 'Treatment' ? 'Proceed' : 'Save'),
          ),
        ],
      ),
    ),
  );
}
