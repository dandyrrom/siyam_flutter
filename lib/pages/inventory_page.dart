import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import '../widgets/stat_card.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  final InventoryService _service = InventoryService();

  List<InventoryItem> _items = [];
  bool _loading = true;
  String? _error;

  String _search = '';
  String _category = 'All';

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
      final items = await _service.fetchItems();
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Could not load inventory. Please try again.';
        _loading = false;
      });
    }
  }

  List<String> get _categories {
    final set = <String>{};
    for (final i in _items) {
      if (i.itemCategory.isNotEmpty) set.add(i.itemCategory);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<InventoryItem> get _filtered {
    return _items.where((i) {
      final matchesSearch = _search.isEmpty ||
          i.itemName.toLowerCase().contains(_search.toLowerCase());
      final matchesCategory = _category == 'All' || i.itemCategory == _category;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  Future<void> _openStockDialog(InventoryItem item, {required bool isStockIn}) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isStockIn ? Icons.arrow_upward : Icons.arrow_downward,
              size: 18,
              color: isStockIn ? AppColors.roleManager : AppColors.destructive,
            ),
            const SizedBox(width: 8),
            Text(isStockIn ? 'Stock In' : 'Stock Out'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Current: ${item.stockQty} ${item.itemUom}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(labelText: 'Quantity (${item.itemUom})'),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a quantity greater than 0';
                  if (!isStockIn && n > item.stockQty) {
                    return 'Only ${item.stockQty} ${item.itemUom} available';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isStockIn ? AppColors.primary : AppColors.destructive,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final qty = int.parse(controller.text);
              Navigator.of(context).pop();
              try {
                await _service.adjustStock(itemId: item.itemId, delta: isStockIn ? qty : -qty);
                _load();
              } catch (e) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
}
            },
            child: Text('Confirm ${isStockIn ? 'Stock In' : 'Stock Out'}'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddItemDialog() async {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController();
    final uomCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '0');
    final formKey = GlobalKey<FormState>();

    await showDialog(
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
                  decoration: const InputDecoration(labelText: 'Initial quantity'),
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
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop();
              try {
                await _service.createItem(
                  itemName: nameCtrl.text.trim(),
                  itemCategory: categoryCtrl.text.trim(),
                  itemUom: uomCtrl.text.trim(),
                  initialQty: int.parse(qtyCtrl.text),
                );
                _load();
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

    final outOfStockCount = _items.where((i) => i.stockQty <= 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Inventory', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('${_items.length} items tracked',
                    style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _openAddItemDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Item'),
            ),
          ],
        ),
        const SizedBox(height: 20),

        StatCardRow(cards: [
          StatCard(
            label: 'Total Items',
            value: '${_items.length}',
            icon: Icons.inventory_2_outlined,
            accent: AppColors.roleManager,
          ),
          StatCard(
            label: 'Categories',
            value: '${_categories.length - 1}',
            icon: Icons.category_outlined,
            accent: AppColors.roleStaff,
          ),
          StatCard(
            label: 'Out of Stock',
            value: '$outOfStockCount',
            icon: Icons.report_problem_outlined,
            accent: AppColors.destructive,
          ),
        ]),
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search, size: 18),
                          hintText: 'Search items…',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _category,
                      underline: const SizedBox.shrink(),
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setState(() => _category = v ?? 'All'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              _filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 32, color: AppColors.mutedForeground),
                          SizedBox(height: 8),
                          Text('No items match your filters.',
                              style: TextStyle(color: AppColors.mutedForeground)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Quantity')),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: _filtered.map((item) {
                          final outOfStock = item.stockQty <= 0;
                          return DataRow(cells: [
                            DataCell(
                              InkWell(
                                onTap: () => context.push('/inventory/${item.itemId}'),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (outOfStock)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 6),
                                        child: Icon(Icons.warning_amber_rounded,
                                            size: 14, color: AppColors.destructive),
                                      ),
                                    Text(item.itemName,
                                        style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(item.itemCategory, style: const TextStyle(fontSize: 12)),
                            )),
                            DataCell(Text(
                              '${item.stockQty} ${item.itemUom}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: outOfStock ? AppColors.destructive : AppColors.foreground,
                              ),
                            )),
                            DataCell(Row(
                              children: [
                                IconButton(
                                  tooltip: 'Stock In',
                                  icon: const Icon(Icons.arrow_upward,
                                      size: 16, color: AppColors.roleManager),
                                  onPressed: () => _openStockDialog(item, isStockIn: true),
                                ),
                                IconButton(
                                  tooltip: 'Stock Out',
                                  icon: const Icon(Icons.arrow_downward,
                                      size: 16, color: AppColors.destructive),
                                  onPressed: () => _openStockDialog(item, isStockIn: false),
                                ),
                              ],
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}