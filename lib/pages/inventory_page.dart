import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';

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
  String _supplier = 'All';
  StockLevel? _stockLevelFilter; // null = All

  int _pageSize = 12;
  int _page = 0;

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
    } catch (e) {
      setState(() {
        _error = 'Could not load inventory: $e';
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

  List<String> get _suppliers {
    final set = <String>{};
    for (final i in _items) {
      if ((i.supplierName ?? '').isNotEmpty) set.add(i.supplierName!);
    }
    final list = set.toList()..sort();
    return ['All', ...list];
  }

  List<InventoryItem> get _filtered {
    return _items.where((i) {
      final matchesSearch = _search.isEmpty ||
          i.itemName.toLowerCase().contains(_search.toLowerCase());
      final matchesCategory = _category == 'All' || i.itemCategory == _category;
      final matchesSupplier = _supplier == 'All' || i.supplierName == _supplier;
      final matchesStockLevel =
          _stockLevelFilter == null || i.stockLevel == _stockLevelFilter;
      return matchesSearch && matchesCategory && matchesSupplier && matchesStockLevel;
    }).toList();
  }

  int get _pageCount => (_filtered.length / _pageSize).ceil().clamp(1, 999);

  List<InventoryItem> get _pageItems {
    final start = _page * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
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

  (String, Color) _stockLevelMeta(StockLevel level) {
    switch (level) {
      case StockLevel.inStock:
        return ('In Stock', AppColors.stockInStock);
      case StockLevel.needsRestock:
        return ('Needs Restock', AppColors.stockNeedsRestock);
      case StockLevel.low:
        return ('Low Stock', AppColors.stockLow);
      case StockLevel.outOfStock:
        return ('Out of Stock', AppColors.stockOut);
    }
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Inventory',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz, color: AppColors.mutedForeground),
                  onSelected: (v) {
                    if (v == 'add') _openAddItemDialog();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'add', child: Text('Add Item')),
                  ],
                ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.roleDonor,
                foregroundColor: Colors.white,
              ),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reorder workflow coming soon'))),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Reorder'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('${_items.length} items',
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
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
                    SizedBox(
                      width: 280,
                      child: TextField(
                        onChanged: (v) => setState(() {
                          _search = v;
                          _page = 0;
                        }),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search, size: 18),
                          hintText: 'Search items…',
                          isDense: true,
                        ),
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: _category,
                      underline: const SizedBox.shrink(),
                      selectedItemBuilder: (context) =>
                          _categories.map((_) => const Text('Category')).toList(),
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() { _category = v ?? 'All'; _page = 0; }),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _supplier,
                      underline: const SizedBox.shrink(),
                      selectedItemBuilder: (context) =>
                          _suppliers.map((_) => const Text('Supplier')).toList(),
                      items: _suppliers
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() { _supplier = v ?? 'All'; _page = 0; }),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<StockLevel?>(
                      value: _stockLevelFilter,
                      hint: const Text('Stock Level'),
                      underline: const SizedBox.shrink(),
                      selectedItemBuilder: (context) => [
                        const Text('Stock Level'),
                        ...StockLevel.values.map((_) => const Text('Stock Level')),
                      ],
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All levels')),
                        ...StockLevel.values.map((lvl) => DropdownMenuItem(
                              value: lvl,
                              child: Text(_stockLevelMeta(lvl).$1),
                            )),
                      ],
                      onChanged: (v) => setState(() { _stockLevelFilter = v; _page = 0; }),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 56),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          size: 36, color: AppColors.mutedForeground),
                      SizedBox(height: 10),
                      Text('No items in inventory yet',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Items you add will show up here.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                    ],
                  ),
                )
              else if (_filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(Icons.search_off, size: 32, color: AppColors.mutedForeground),
                      SizedBox(height: 8),
                      Text('No items match your filters.',
                          style: TextStyle(color: AppColors.mutedForeground)),
                    ],
                  ),
                )
              else ...[
                // Column proportions -- tune these to match the design's
                // widths. Using Expanded/flex instead of DataTable's
                // intrinsic sizing means this also stretches to fill
                // the full card width instead of hugging its content.
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: const [
                      Expanded(flex: 2, child: _HeaderCell('ID')),
                      Expanded(flex: 4, child: _HeaderCell('Item name')),
                      Expanded(flex: 2, child: _HeaderCell('Category')),
                      Expanded(flex: 3, child: _HeaderCell('Supplier')),
                      Expanded(flex: 2, child: _HeaderCell('Stock')),
                      Expanded(flex: 2, child: _HeaderCell('Stock Level')),
                      SizedBox(width: 56, child: _HeaderCell('Action', alignEnd: true)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pageItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = _pageItems[index];
                    final (levelLabel, levelColor) = _stockLevelMeta(item.stockLevel);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(item.displayId,
                                style: const TextStyle(color: AppColors.mutedForeground)),
                          ),
                          Expanded(
                            flex: 4,
                            child: InkWell(
                              onTap: () => context.push('/inventory/${item.itemId}'),
                              child: Text(item.itemName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.secondary,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(item.itemCategory,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12)),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(item.supplierName ?? '—',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: AppColors.mutedForeground)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('${item.stockQty} ${item.itemUom}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: levelColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(levelLabel,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: levelColor)),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: PopupMenuButton<String>(
                                icon: const Icon(Icons.more_horiz, size: 18),
                                onSelected: (v) {
                                  if (v == 'in') _openStockDialog(item, isStockIn: true);
                                  if (v == 'out') _openStockDialog(item, isStockIn: false);
                                  if (v == 'view') context.push('/inventory/${item.itemId}');
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'view', child: Text('View details')),
                                  PopupMenuItem(value: 'in', child: Text('Stock In')),
                                  PopupMenuItem(value: 'out', child: Text('Stock Out')),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text('Show', style: TextStyle(fontSize: 12.5)),
                          const SizedBox(width: 8),
                          DropdownButton<int>(
                            value: _pageSize,
                            underline: const SizedBox.shrink(),
                            items: const [12, 25, 50]
                                .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                                .toList(),
                            onChanged: (v) =>
                                setState(() { _pageSize = v ?? 12; _page = 0; }),
                          ),
                          const SizedBox(width: 8),
                          const Text('Per Page', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _page > 0 ? () => setState(() => _page--) : null,
                            icon: const Icon(Icons.chevron_left, size: 16),
                            label: const Text('Previous'),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('${_page + 1} / $_pageCount',
                                style: const TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed:
                                _page < _pageCount - 1 ? () => setState(() => _page++) : null,
                            icon: const Icon(Icons.chevron_right, size: 16),
                            label: const Text('Next'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool alignEnd;
  const _HeaderCell(this.label, {this.alignEnd = false});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.mutedForeground,
        ),
      ),
    );
  }
}