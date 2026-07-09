import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';

/// Shared "add a catalog item" form (name/category/unit + optional
/// starting quantity). Used standalone from the Inventory page, and
/// inline from flows that need to reference an item that doesn't exist
/// yet (Create Purchase Order, Approve Donation) -- so staff can catalog
/// a brand-new item without leaving that screen.
///
/// This only ever creates the catalog entry -- it never creates a
/// purchase_trans or donation record. Recording how stock actually
/// arrived (purchase vs. donation vs. manual opening balance) stays the
/// job of the flow that called this, not this dialog.
///
/// Returns the created item, or null if the user cancelled.
Future<InventoryItem?> showCreateItemDialog(
  BuildContext context, {
  required InventoryService service,
}) {
  final nameCtrl = TextEditingController();
  final categoryCtrl = TextEditingController();
  final uomCtrl = TextEditingController();
  final qtyCtrl = TextEditingController(text: '0');
  final formKey = GlobalKey<FormState>();

  return showDialog<InventoryItem?>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Add Item'),
      content: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Item name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: categoryCtrl,
                decoration: const InputDecoration(labelText: 'Category'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: uomCtrl,
                decoration:
                    const InputDecoration(labelText: 'Unit of measure (e.g. kg, pcs, boxes)'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Starting quantity'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n < 0) return 'Enter a valid quantity';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!formKey.currentState!.validate()) return;
            try {
              final item = await service.createItem(
                itemName: nameCtrl.text.trim(),
                itemCategory: categoryCtrl.text.trim(),
                itemUom: uomCtrl.text.trim(),
                initialQty: int.parse(qtyCtrl.text),
              );
              if (!context.mounted) return;
              Navigator.of(context).pop(item);
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Could not add item: $e')));
            }
          },
          child: const Text('Add Item'),
        ),
      ],
    ),
  );
}
