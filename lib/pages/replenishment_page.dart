import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';
import '../mock/mock_database.dart';
import '../models/inventory_item.dart';
import '../services/expiry_alerts.dart';
import '../services/inventory_service.dart';
import '../state/data_bus.dart';
import '../widgets/app_dropdown.dart';

/// Priority tier for the Replenishment List -- a direct relabeling of the
/// existing [StockLevel] tiers (outOfStock/low/needsRestock), not a new
/// stored attribute. See CLAUDE.md's Data Scope Rule: no `priority_level`
/// column exists, so this is derived, not persisted.
enum _Priority { critical, high, medium }

_Priority? _priorityFor(StockLevel level) {
  switch (level) {
    case StockLevel.outOfStock:
      return _Priority.critical;
    case StockLevel.low:
      return _Priority.high;
    case StockLevel.needsRestock:
      return _Priority.medium;
    case StockLevel.inStock:
      return null;
  }
}

(String, Color) _priorityMeta(_Priority p) {
  switch (p) {
    case _Priority.critical:
      return ('Critical', AppColors.stockOut);
    case _Priority.high:
      return ('High', AppColors.stockLow);
    case _Priority.medium:
      return ('Medium', AppColors.stockNeedsRestock);
  }
}

/// One row on the Replenishment List: an item that needs restocking plus the
/// figures derived from existing fields (no schema additions -- see
/// updated_db.md and the approved plan for this feature).
class _ReplenishmentRow {
  final InventoryItem item;
  final _Priority priority;

  /// max(0, low_stock_threshold - stockQty), in purchase-unit terms. This is
  /// "how much to buy to clear the low-stock floor", not a true "restock to
  /// ideal" figure -- there is no ideal-stock/reorder-point column to target.
  final double qtyToBuy;

  final DateTime? nearestExpiry;

  _ReplenishmentRow({
    required this.item,
    required this.priority,
    required this.qtyToBuy,
    required this.nearestExpiry,
  });
}

class ReplenishmentPage extends StatefulWidget {
  const ReplenishmentPage({super.key});

  @override
  State<ReplenishmentPage> createState() => _ReplenishmentPageState();
}

class _ReplenishmentPageState extends State<ReplenishmentPage>
    with DataBusRefreshMixin<ReplenishmentPage> {
  final InventoryService _service = InventoryService();
  final _searchCtrl = TextEditingController();

  List<_ReplenishmentRow> _rows = [];
  bool _loading = true;
  String? _error;

  String _search = '';
  _Priority? _priorityFilter; // null = All

  int _pageSize = 12;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  bool get _hasActiveFilters =>
      _search.isNotEmpty || _priorityFilter != null;

  void _resetFilters() {
    setState(() {
      _search = '';
      _searchCtrl.clear();
      _priorityFilter = null;
      _page = 0;
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final items = await _service.fetchItems();
      final threshold = lowStockPurchaseUnitThreshold;
      final db = MockDatabase.instance;

      final rows = <_ReplenishmentRow>[];
      for (final item in items) {
        final priority = _priorityFor(item.stockLevel);
        if (priority == null) continue;
        rows.add(_ReplenishmentRow(
          item: item,
          priority: priority,
          qtyToBuy: math.max(0.0, threshold - item.stockQty),
          nearestExpiry: nearestBatchExpiry(db, item.itemId),
        ));
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'Could not load replenishment list: $e';
          _loading = false;
        });
      }
    }
  }

  List<_ReplenishmentRow> get _filtered {
    final list = _rows.where((r) {
      final matchesSearch = _search.isEmpty ||
          r.item.itemName.toLowerCase().contains(_search.toLowerCase());
      final matchesPriority =
          _priorityFilter == null || r.priority == _priorityFilter;
      return matchesSearch && matchesPriority;
    }).toList();

    list.sort((a, b) {
      final byPriority = a.priority.index.compareTo(b.priority.index);
      if (byPriority != 0) return byPriority;
      return a.item.stockQty.compareTo(b.item.stockQty);
    });
    return list;
  }

  int get _pageCount => (_filtered.length / _pageSize).ceil().clamp(1, 999);

  List<_ReplenishmentRow> get _pageItems {
    final start = _page * _pageSize;
    if (start >= _filtered.length) return const [];
    final end = (start + _pageSize).clamp(0, _filtered.length);
    return _filtered.sublist(start, end);
  }

  String _expiryLabel(_ReplenishmentRow row) {
    final expiry = row.nearestExpiry;
    if (expiry == null) return 'No batch on file';
    final warningDays = MockDatabase.instance.systemSettings.expirationWarningDays;
    final days = expiry.difference(DateTime.now()).inDays;
    if (days < 0) return 'Expired ${-days}d ago';
    if (days <= warningDays) return 'Expires in ${days}d';
    return 'Expires ${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
  }

  bool _expiryIsUrgent(_ReplenishmentRow row) {
    final expiry = row.nearestExpiry;
    if (expiry == null) return false;
    final warningDays = MockDatabase.instance.systemSettings.expirationWarningDays;
    return expiry.difference(DateTime.now()).inDays <= warningDays;
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: const TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Replenishment',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          '${_rows.length} items need restocking',
          style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 20),

        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FILTER BAR
              Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: isMobile ? double.infinity : 360,
                      child: TextField(
                        controller: _searchCtrl,
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
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(16)),
                            borderSide:
                                BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                    AppDropdown<_Priority?>(
                      label: _priorityFilter == null
                          ? 'Priority'
                          : _priorityMeta(_priorityFilter!).$1,
                      options: [
                        const AppDropdownOption(null, 'All priorities'),
                        for (final p in _Priority.values)
                          AppDropdownOption(p, _priorityMeta(p).$1),
                      ],
                      onSelect: (v) => setState(() {
                        _priorityFilter = v;
                        _page = 0;
                      }),
                    ),
                    if (_hasActiveFilters)
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                        label: const Text('Reset Filters'),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),

              if (_rows.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 56),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 36, color: AppColors.stockInStock),
                        SizedBox(height: 10),
                        Text('Nothing needs restocking',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 4),
                        Text('All items are above their stock thresholds.',
                            style: TextStyle(
                                fontSize: 12.5, color: AppColors.mutedForeground)),
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
                        Icon(Icons.search_off,
                            size: 32, color: AppColors.mutedForeground),
                        SizedBox(height: 8),
                        Text('No items match your filters.',
                            style: TextStyle(color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
                )
              else ...[
                if (!isMobile)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: _HeaderCell('Priority')),
                        Expanded(flex: 4, child: _HeaderCell('Item name')),
                        SizedBox(width: 16),
                        Expanded(flex: 2, child: _HeaderCell('Current Stock')),
                        SizedBox(width: 16),
                        Expanded(flex: 2, child: _HeaderCell('Qty to Buy')),
                        SizedBox(width: 16),
                        Expanded(flex: 3, child: _HeaderCell('Nearest Expiry')),
                      ],
                    ),
                  ),
                if (!isMobile) const Divider(height: 1),
                Column(
                  children: [
                    for (var i = 0; i < _pageItems.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _ReplenishmentRowTile(
                        row: _pageItems[i],
                        isMobile: isMobile,
                        expiryLabel: _expiryLabel(_pageItems[i]),
                        expiryIsUrgent: _expiryIsUrgent(_pageItems[i]),
                        onTap: () => context
                            .push('/inventory/${_pageItems[i].item.itemId}'),
                      ),
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
                            onSelect: (v) => setState(() {
                              _pageSize = v;
                              _page = 0;
                            }),
                          ),
                          const SizedBox(width: 8),
                          const Text('Per Page', style: TextStyle(fontSize: 12.5)),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton.icon(
                            onPressed:
                                _page > 0 ? () => setState(() => _page--) : null,
                            icon: const Icon(Icons.chevron_left, size: 16),
                            label: const Text('Previous'),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('${_page + 1} / $_pageCount',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ),
                          const SizedBox(width: 4),
                          TextButton.icon(
                            onPressed: _page < _pageCount - 1
                                ? () => setState(() => _page++)
                                : null,
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

class _ReplenishmentRowTile extends StatelessWidget {
  final _ReplenishmentRow row;
  final bool isMobile;
  final String expiryLabel;
  final bool expiryIsUrgent;
  final VoidCallback onTap;

  const _ReplenishmentRowTile({
    required this.row,
    required this.isMobile,
    required this.expiryLabel,
    required this.expiryIsUrgent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final item = row.item;
    final (priorityLabel, priorityColor) = _priorityMeta(row.priority);
    final expiryColor =
        expiryIsUrgent ? AppColors.warning : AppColors.mutedForeground;

    Widget priorityBadge() => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: priorityColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(priorityLabel,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: priorityColor)),
        );

    final qtyToBuyText = row.qtyToBuy > 0
        ? '${formatQty(row.qtyToBuy)} ${item.purchaseUnitAbbr}'
        : 'At threshold';

    if (!isMobile) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Align(
                    alignment: Alignment.centerLeft, child: priorityBadge()),
              ),
              Expanded(
                flex: 4,
                child: Text(item.itemName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: AppColors.foreground)),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(
                    '${formatQty(item.displayStockQty)} ${item.displayStockUnit}',
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: Text(qtyToBuyText,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: Text(expiryLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: expiryColor,
                        fontWeight:
                            expiryIsUrgent ? FontWeight.w600 : FontWeight.w400)),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                priorityBadge(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.itemName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                      overflow: TextOverflow.ellipsis),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.mutedForeground),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                    '${formatQty(item.displayStockQty)} ${item.displayStockUnit} on hand',
                    style: const TextStyle(fontSize: 12.5)),
                const Spacer(),
                Text(qtyToBuyText,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Text(expiryLabel,
                style: TextStyle(
                    fontSize: 12,
                    color: expiryColor,
                    fontWeight:
                        expiryIsUrgent ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
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
