import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/inventory_item.dart';
import '../services/inventory_service.dart';
import '../state/auth_state.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/stock_out_dialog.dart';

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
  String? _selectedPCategoryId;
  String? _selectedSCategoryId;
  String _categoryLabel = 'Category';
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
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load inventory: $e';
        _loading = false;
      });
    }
  }

  /// Primary categories present in the current items, each carrying its
  /// distinct subcategories, both sorted alphabetically.
  List<_PrimaryCategoryOption> get _primaryCategories {
    final byId = <String, _PrimaryCategoryOption>{};
    for (final i in _items) {
      final opt = byId.putIfAbsent(
        i.pCategoryId,
        () => _PrimaryCategoryOption(id: i.pCategoryId, name: i.pCategoryName),
      );
      if (i.sCategoryId != null && i.sCategoryName != null) {
        opt.subcategories[i.sCategoryId!] = i.sCategoryName!;
      }
    }
    final list = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void _selectCategory({String? pCategoryId, String? sCategoryId, required String label}) {
    setState(() {
      _selectedPCategoryId = pCategoryId;
      _selectedSCategoryId = sCategoryId;
      _categoryLabel = label;
      _page = 0;
    });
  }

  List<InventoryItem> get _filtered {
    return _items.where((i) {
      final matchesSearch = _search.isEmpty ||
          i.itemName.toLowerCase().contains(_search.toLowerCase());
      final matchesCategory = _selectedSCategoryId != null
          ? i.sCategoryId == _selectedSCategoryId
          : _selectedPCategoryId != null
              ? i.pCategoryId == _selectedPCategoryId
              : true;
      final matchesStockLevel =
          _stockLevelFilter == null || i.stockLevel == _stockLevelFilter;
      return matchesSearch && matchesCategory && matchesStockLevel;
    }).toList();
  }

  int get _pageCount => (_filtered.length / _pageSize).ceil().clamp(1, 999);

  List<InventoryItem> get _pageItems {
    final start = _page * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  Future<void> _openStockOutDialog({InventoryItem? item}) async {
    final result = await showStockOutDialog(
      context,
      service: _service,
      recordedByUserId: context.read<AuthController>().profile!.userId,
      item: item,
      items: _items,
    );
    if (!mounted) return;
    if (result != null) {
      final (usedItem, qty) = result;
      context.push('/medical-records/add?itemId=${usedItem.itemId}&qty=$qty');
      return;
    }
    _load();
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
            const Expanded(
              child: Text(
                'Inventory',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppMenuButton<String>(
                  options: const [
                    AppDropdownOption('purchase', 'Purchase'),
                    AppDropdownOption('donation', 'Donation'),
                    AppDropdownOption('stockout', 'Stock out'),
                  ],
                  onSelected: (v) {
                    if (v == 'purchase') context.push('/inventory/add?type=purchased');
                    if (v == 'donation') context.push('/inventory/add?type=donated');
                    if (v == 'stockout') _openStockOutDialog();
                  },
                  triggerBuilder: (context, isOpen) =>
                      const AppDropdownButton(label: 'New', leadingIcon: Icons.add),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.roleDonor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => context.push('/inventory/add'),
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  label: const Text('Stock In'),
                ),
              ],
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 360,
                      child: TextField(
                        style: const TextStyle(fontSize: 14),
                        onChanged: (v) => setState(() {
                          _search = v;
                          _page = 0;
                        }),
                        decoration: const InputDecoration(
                          hintStyle: TextStyle(fontSize: 14),
                          prefixIcon: Icon(Icons.search, size: 18),
                          hintText: 'Search items…',
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    _CategoryFilterMenu(
                      label: _categoryLabel,
                      primaryCategories: _primaryCategories,
                      onSelectAll: () => _selectCategory(label: 'Category'),
                      onSelectPrimary: (p) => _selectCategory(
                        pCategoryId: p.id,
                        label: p.name,
                      ),
                      onSelectSub: (p, subId, subName) => _selectCategory(
                        pCategoryId: p.id,
                        sCategoryId: subId,
                        label: subName,
                      ),
                    ),
                    AppDropdown<StockLevel?>(
                      label: _stockLevelFilter == null
                          ? 'Stock Level'
                          : _stockLevelMeta(_stockLevelFilter!).$1,
                      options: [
                        const AppDropdownOption(null, 'All levels'),
                        for (final lvl in StockLevel.values)
                          AppDropdownOption(lvl, _stockLevelMeta(lvl).$1),
                      ],
                      onSelect: (v) => setState(() { _stockLevelFilter = v; _page = 0; }),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (_items.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 56),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
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
                  ),
                )
              else if (_filtered.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off, size: 32, color: AppColors.mutedForeground),
                        SizedBox(height: 8),
                        Text('No items match your filters.',
                            style: TextStyle(color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
                )
              else ...[
                // Column proportions -- tune these to match the design's
                // widths. Using Expanded/flex instead of DataTable's
                // intrinsic sizing means this also stretches to fill
                // the full card width instead of hugging its content.
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: _HeaderCell('ID')),
                      Expanded(flex: 4, child: _HeaderCell('Item name')),
                      SizedBox(width: 16),
                      Expanded(flex: 2, child: _HeaderCell('Category')),
                      SizedBox(width: 16),
                      Expanded(flex: 2, child: _HeaderCell('Stock')),
                      SizedBox(width: 16),
                      Expanded(flex: 2, child: _HeaderCell('Stock Level')),
                      SizedBox(width: 56, child: _HeaderCell('Action', alignEnd: true)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Column(
                  children: [
                    for (var index = 0; index < _pageItems.length; index++) ...[
                      if (index > 0) const Divider(height: 1),
                      Builder(builder: (context) {
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
                          const SizedBox(width: 16),
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
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('${formatQty(item.stockQty)} ${item.itemUom}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 16),
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
                              child: AppMenuButton<String>(
                                options: const [
                                  AppDropdownOption('view', 'View details'),
                                  AppDropdownOption('in', 'Stock In'),
                                  AppDropdownOption('out', 'Stock Out'),
                                ],
                                onSelected: (v) {
                                  if (v == 'in') context.push('/inventory/add?itemId=${item.itemId}');
                                  if (v == 'out') _openStockOutDialog(item: item);
                                  if (v == 'view') context.push('/inventory/${item.itemId}');
                                },
                                triggerBuilder: (context, isOpen) => const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.more_horiz, size: 18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                      }),
                    ],
                  ],
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Show', style: TextStyle(fontSize: 12.5)),
                          const SizedBox(width: 8),
                          AppDropdown<int>(
                            label: '$_pageSize',
                            options: const [12, 25, 50]
                                .map((n) => AppDropdownOption(n, '$n'))
                                .toList(),
                            onSelect: (v) => setState(() { _pageSize = v; _page = 0; }),
                          ),
                          const SizedBox(width: 8),
                          const Text('Per Page', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
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

/// A primary category and the distinct subcategories seen among the current
/// items, keyed by subcategory id -> subcategory name.
class _PrimaryCategoryOption {
  final String id;
  final String name;
  final Map<String, String> subcategories = {};

  _PrimaryCategoryOption({required this.id, required this.name});
}

/// Category filter control: top level lists primary categories; hovering one
/// reveals a side panel of its subcategories. Picking the primary category
/// itself (the "All <primary>" row) filters to all items under all of its
/// subcategories; picking a subcategory narrows to just that subcategory.
///
/// Built on a manual [OverlayEntry] rather than [MenuAnchor]/[SubmenuButton]
/// -- those throw a RenderBox layout assertion on web when their anchor sits
/// inside a [Wrap] (https://github.com/flutter/flutter/issues/131843).
class _CategoryFilterMenu extends StatefulWidget {
  final String label;
  final List<_PrimaryCategoryOption> primaryCategories;
  final VoidCallback onSelectAll;
  final ValueChanged<_PrimaryCategoryOption> onSelectPrimary;
  final void Function(_PrimaryCategoryOption p, String subId, String subName) onSelectSub;

  const _CategoryFilterMenu({
    required this.label,
    required this.primaryCategories,
    required this.onSelectAll,
    required this.onSelectPrimary,
    required this.onSelectSub,
  });

  @override
  State<_CategoryFilterMenu> createState() => _CategoryFilterMenuState();
}

class _CategoryFilterMenuState extends State<_CategoryFilterMenu>
    with DropdownOverlayMixin<_CategoryFilterMenu> {
  String? _hoveredPrimaryId;

  void _select(VoidCallback action) {
    action();
    closeDropdown();
  }

  @override
  void openDropdown() {
    _hoveredPrimaryId = null;
    super.openDropdown();
  }

  @override
  Widget buildFlyoutPanel(BuildContext context) {
    _PrimaryCategoryOption? hovered;
    for (final p in widget.primaryCategories) {
      if (p.id == _hoveredPrimaryId) hovered = p;
    }
    final subs = hovered == null
        ? const <MapEntry<String, String>>[]
        : (hovered.subcategories.entries.toList()
          ..sort((a, b) => a.value.compareTo(b.value)));

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: AppColors.card,
      child: IntrinsicHeight(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 200,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppDropdownMenuRow(
                    label: 'All Categories',
                    onTap: () => _select(widget.onSelectAll),
                  ),
                  for (final p in widget.primaryCategories)
                    MouseRegion(
                      onEnter: (_) {
                        _hoveredPrimaryId = p.id;
                        rebuildDropdown();
                      },
                      child: AppDropdownMenuRow(
                        label: p.name,
                        hasChildren: p.subcategories.isNotEmpty,
                        onTap: () => _select(() => widget.onSelectPrimary(p)),
                      ),
                    ),
                ],
              ),
            ),
            if (hovered != null && subs.isNotEmpty) ...[
              const VerticalDivider(width: 1),
              SizedBox(
                width: 200,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppDropdownMenuRow(
                      label: 'All ${hovered.name}',
                      onTap: () => _select(() => widget.onSelectPrimary(hovered!)),
                    ),
                    for (final e in subs)
                      AppDropdownMenuRow(
                        label: e.value,
                        onTap: () =>
                            _select(() => widget.onSelectSub(hovered!, e.key, e.value)),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: dropdownLink,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: toggleDropdown,
        child: AppDropdownButton(label: widget.label),
      ),
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
