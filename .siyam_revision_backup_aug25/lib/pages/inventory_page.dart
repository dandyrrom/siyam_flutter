import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../models/replenishment_item.dart';
import '../services/inventory_service.dart';
import '../services/replenishment_service.dart';
import '../state/app_operation_controller.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/hoverable_row.dart';
import '../widgets/stock_out_dialog.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

enum _SortOption {
  nameAsc,
  nameDesc,
  stockAsc,
  stockDesc,
}

class _InventoryPageState extends State<InventoryPage>
    with DataBusRefreshMixin<InventoryPage> {
  final InventoryService _service = InventoryService();
  final ReplenishmentService _replenishmentService =
      ReplenishmentService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<InventoryItem> _items = [];
  Map<String, ReplenishmentItem> _replenishmentByItemId = {};

  bool _loading = true;
  String? _error;

  // Only the newest inventory fetch is allowed to update the page.
  // This prevents an older DataBus refresh from overwriting the final
  // refresh after Goods Received closes.
  int _loadRequestId = 0;

  // Inventory stays mounted underneath Goods Received. Several database
  // writes can ping DataChangeBus while that page is still open. Ignore
  // those intermediate refreshes and do one clean reload after it closes.
  bool _goodsReceivedOpen = false;

  String _search = '';

  String? _selectedPCategoryId;
  String? _selectedSCategoryId;
  String _categoryLabel = 'Category';

  StockLevel? _stockLevelFilter;
  AcquisitionSource? _sourceFilter;

  _SortOption _sortOption = _SortOption.nameAsc;

  int _pageSize = 12;
  int _page = 0;

  // ==========================================================================
  // CURRENT USABLE STOCK
  // ==========================================================================
  //
  // IMPORTANT:
  // InventoryItem.currentUsableStockQty is now batch-aware.
  //
  // When inventory_batch records exist it excludes:
  // - expired batches
  // - quarantined batches
  // - depleted batches
  //
  // Legacy aggregate values are used only as fallback when no batch history
  // exists.
  // ==========================================================================

  double _currentStockQty(InventoryItem item) {
    return item.currentUsableStockQty;
  }

  String _currentStockUnit(InventoryItem item) {
    return item.currentUsableStockUnit;
  }

  String? _equivalentStockLabel(InventoryItem item) {
    if (!item.hasPackageBreakdown) return null;

    return '≈ ${formatQty(item.currentPurchaseUnitEquivalent)} '
        '${item.purchaseUnitAbbr} equivalent';
  }

  String? _packageConversionLabel(InventoryItem item) {
    if (!item.hasPackageBreakdown) return null;

    return '1 ${item.purchaseUnitAbbr} = '
        '${formatQty(item.packageQuantity!)} ${item.packageUnitAbbr}';
  }

  // ==========================================================================
  // EXPIRY HELPERS
  // ==========================================================================

  static const List<String> _monthAbbrev = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatExpiryDate(DateTime date) {
    return '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
  }

  String? _nearestExpiryDetail(InventoryItem item) {
    final date = item.nearestExpiryDate;
    final days = item.daysUntilNearestExpiry;

    if (date == null || days == null) return null;

    if (days == 0) {
      return '${_formatExpiryDate(date)} · Expires today';
    }

    if (days == 1) {
      return '${_formatExpiryDate(date)} · 1 day left';
    }

    return '${_formatExpiryDate(date)} · $days days left';
  }

  Color _nearestExpiryColor(InventoryItem item) {
    if (item.expiresToday || item.isExpiringSoon) {
      return AppColors.warning;
    }

    return AppColors.mutedForeground;
  }

  // ==========================================================================
  // INITIALIZATION
  // ==========================================================================

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

  // ==========================================================================
  // FILTER STATE
  // ==========================================================================

  bool get _hasActiveFilters =>
      _search.isNotEmpty ||
      _selectedPCategoryId != null ||
      _stockLevelFilter != null ||
      _sourceFilter != null ||
      _sortOption != _SortOption.nameAsc;

  void _resetFilters() {
    setState(() {
      _search = '';
      _searchCtrl.clear();

      _selectedPCategoryId = null;
      _selectedSCategoryId = null;
      _categoryLabel = 'Category';

      _stockLevelFilter = null;
      _sourceFilter = null;

      _sortOption = _SortOption.nameAsc;
      _page = 0;
    });
  }

  // ==========================================================================
  // DATA
  // ==========================================================================

  @override
  void onExternalDataChanged() {
    if (_goodsReceivedOpen) {
      return;
    }

    _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
  final requestId = ++_loadRequestId;

  if (!silent) {
    setState(() {
      _loading = true;
      _error = null;
    });
  }

  try {
    Future<List<Object?>> fetchInventory() {
      return Future.wait<Object?>([
        _service.fetchItems(),
        _replenishmentService.fetchReplenishmentItems(),
      ]);
    }

    // Normal page loads use the global interaction guard so users cannot
    // repeatedly navigate/click while Inventory is still being prepared.
    //
    // Background DataBus refreshes remain silent and do NOT block the app.
    final results = silent
        ? await fetchInventory()
        : await AppOperationController.instance.run<List<Object?>>(
            message: 'Loading inventory...',
            action: fetchInventory,
          );

    if (!mounted || requestId != _loadRequestId) {
      return;
    }

    final items =
        results[0] as List<InventoryItem>;

    final replenishmentRows =
        results[1] as List<ReplenishmentItem>;

    setState(() {
      _items = items;

      _replenishmentByItemId = {
        for (final row in replenishmentRows)
          row.item.itemId: row,
      };

      _loading = false;
    });
  } catch (e) {
    if (!mounted || requestId != _loadRequestId) {
      return;
    }

    if (!silent) {
      setState(() {
        _error =
            'Could not load inventory: $e';

        _loading = false;
      });
    }
  }
}

  // ==========================================================================
  // CATEGORY OPTIONS
  // ==========================================================================

  List<_PrimaryCategoryOption> get _primaryCategories {
    final byId = <String, _PrimaryCategoryOption>{};

    for (final item in _items) {
      final option = byId.putIfAbsent(
        item.pCategoryId,
        () => _PrimaryCategoryOption(
          id: item.pCategoryId,
          name: item.pCategoryName,
        ),
      );

      if (item.sCategoryId != null && item.sCategoryName != null) {
        option.subcategories[item.sCategoryId!] = item.sCategoryName!;
      }
    }

    final list = byId.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return list;
  }

  void _selectCategory({
    String? pCategoryId,
    String? sCategoryId,
    required String label,
  }) {
    setState(() {
      _selectedPCategoryId = pCategoryId;
      _selectedSCategoryId = sCategoryId;
      _categoryLabel = label;
      _page = 0;
    });
  }

  // ==========================================================================
  // FILTER + SORT
  // ==========================================================================

  List<InventoryItem> get _filtered {
    final list = _items.where((item) {
      final matchesSearch = _search.isEmpty ||
          item.itemName.toLowerCase().contains(_search.toLowerCase());

      final matchesCategory = _selectedSCategoryId != null
          ? item.sCategoryId == _selectedSCategoryId
          : _selectedPCategoryId != null
              ? item.pCategoryId == _selectedPCategoryId
              : true;

      final matchesStockLevel =
          _stockLevelFilter == null ||
          _stockLevelFor(item) == _stockLevelFilter;

      final matchesSource =
          _sourceFilter == null || item.acquisitionSource == _sourceFilter;

      return matchesSearch &&
          matchesCategory &&
          matchesStockLevel &&
          matchesSource;
    }).toList();

    switch (_sortOption) {
      case _SortOption.nameAsc:
        list.sort((a, b) => a.itemName.compareTo(b.itemName));
        break;

      case _SortOption.nameDesc:
        list.sort((a, b) => b.itemName.compareTo(a.itemName));
        break;

      case _SortOption.stockAsc:
        list.sort(
          (a, b) => _currentStockQty(a).compareTo(_currentStockQty(b)),
        );
        break;

      case _SortOption.stockDesc:
        list.sort(
          (a, b) => _currentStockQty(b).compareTo(_currentStockQty(a)),
        );
        break;
    }

    return list;
  }

  (String, IconData) _sortMeta(_SortOption option) {
    switch (option) {
      case _SortOption.nameAsc:
        return ('Name (A–Z)', Icons.arrow_upward);

      case _SortOption.nameDesc:
        return ('Name (Z–A)', Icons.arrow_downward);

      case _SortOption.stockAsc:
        return ('Stock (Low–High)', Icons.arrow_upward);

      case _SortOption.stockDesc:
        return ('Stock (High–Low)', Icons.arrow_downward);
    }
  }

  (String, Color) _sourceMeta(AcquisitionSource source) {
    switch (source) {
      case AcquisitionSource.purchased:
        return ('Purchased', AppColors.roleStaff);

      case AcquisitionSource.donated:
        return ('Donated', AppColors.roleDonor);

      case AcquisitionSource.both:
        return ('Both', AppColors.primary);

      case AcquisitionSource.none:
        return ('None', AppColors.mutedForeground);
    }
  }

  // ==========================================================================
  // PAGINATION
  // ==========================================================================

  int get _pageCount {
    return (_filtered.length / _pageSize).ceil().clamp(1, 999);
  }

  List<InventoryItem> get _pageItems {
    final start = _page * _pageSize;

    if (start >= _filtered.length) {
      return const [];
    }

    final end = (start + _pageSize).clamp(0, _filtered.length);

    return _filtered.sublist(start, end);
  }

  // ==========================================================================
  // GOODS RECEIVED
  // ==========================================================================
  //
  // Inventory remains mounted while the Goods Received page is pushed above
  // it. DataBus may refresh this page while the stock-in transaction is still
  // completing, so always perform one final full reload after the form closes.
  // ==========================================================================

  Future<void> _openGoodsReceived({String? itemId}) async {
    if (_goodsReceivedOpen) {
      return;
    }

    final route = itemId == null
        ? '/inventory/add'
        : '/inventory/add?itemId=$itemId';

    _goodsReceivedOpen = true;

    // Invalidate any older Inventory fetch that may still be running before
    // the Goods Received page opens.
    _loadRequestId++;

    try {
      await context.push(route);

      if (!mounted) return;

      // Let GoRouter finish removing the Goods Received page before rebuilding
      // Inventory. This avoids repaint/layout glitches on Flutter Web.
      await WidgetsBinding.instance.endOfFrame;

      if (!mounted) return;

      // Show the normal Inventory loading state while the final authoritative
      // batch-aware data is fetched from Supabase.
      await _load();

      if (!mounted) return;

      // Keep DataBus refreshes suspended through the first fully-painted
      // Inventory frame so queued stock-in pings cannot immediately repaint it.
      await WidgetsBinding.instance.endOfFrame;
    } finally {
      _goodsReceivedOpen = false;
    }
  }

  // ==========================================================================
  // DISPENSE
  // ==========================================================================
  //
  // Internal function/service names remain stockOut to avoid breaking the
  // already-working backend. Only staff-facing terminology is changed.
  // ==========================================================================

  Future<void> _openDispenseDialog({InventoryItem? item}) async {
    final result = await showStockOutDialog(
      context,
      service: _service,
      recordedByUserId:
          context.read<AuthController>().profile!.userId,
      item: item,
      items: _items,
    );

    if (!mounted) return;

    if (result != null) {
      final (usedItem, qty) = result;

      context.push(
        '/medical-records/add'
        '?itemId=${usedItem.itemId}'
        '&qty=$qty',
      );

      return;
    }

    _load();
  }

  // ==========================================================================
  // STOCK LEVEL
  // ==========================================================================
  //
  // Inventory status is now aligned with Ordering's calculated ROP:
  //
  // - Out of Stock: no usable stock remains
  // - Low Stock: usable stock is at/below calculated ROP
  // - In Stock: usable stock is above calculated ROP
  //
  // The old fixed low-stock threshold is intentionally NOT used here.
  // ==========================================================================

  StockLevel _stockLevelFor(InventoryItem item) {
    if (item.isOutOfStock) {
      return StockLevel.outOfStock;
    }

    if (_replenishmentByItemId.containsKey(item.itemId)) {
      return StockLevel.low;
    }

    return StockLevel.inStock;
  }

  ReplenishmentItem? _replenishmentFor(
    InventoryItem item,
  ) {
    return _replenishmentByItemId[item.itemId];
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

  // ==========================================================================
  // MOBILE ACTION DIALOG
  // ==========================================================================

  void _showActionDialog(
    BuildContext context,
    InventoryItem item,
  ) {
    final equivalentLabel = _equivalentStockLabel(item);
    final conversionLabel = _packageConversionLabel(item);
    final expiryDetail = _nearestExpiryDetail(item);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.80,
              ),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.mutedForeground,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      item.itemName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 10),

                    // ========================================================
                    // CURRENT USABLE STOCK
                    // ========================================================

                    Text(
                      '${formatQty(_currentStockQty(item))} '
                      '${_currentStockUnit(item)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (equivalentLabel != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        equivalentLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedForeground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    if (conversionLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        conversionLabel,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.mutedForeground,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    // ========================================================
                    // EXPIRY INFORMATION
                    // ========================================================

                    if (item.hasExpiredStock) ...[
                      const SizedBox(height: 10),
                      _ExpiryNotice(
                        icon: Icons.error_outline,
                        text:
                            '${formatQty(item.expiredBatchStockQty)} '
                            '${item.currentUsableStockUnit} expired · '
                            'awaiting removal',
                        color: AppColors.destructive,
                      ),
                    ],

                    if (expiryDetail != null) ...[
                      const SizedBox(height: 6),
                      _ExpiryNotice(
                        icon: Icons.schedule_outlined,
                        text: expiryDetail,
                        color: _nearestExpiryColor(item),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Text(
                      item.pCategoryName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 8),

                    // ========================================================
                    // ACTIONS
                    // ========================================================

                    _buildActionTile(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.primary,
                      label: 'Goods Received',
                      onTap: () async {
                        Navigator.pop(context);

                        await _openGoodsReceived(
                          itemId: item.itemId,
                        );
                      },
                    ),

                    _buildActionTile(
                      icon: Icons.arrow_downward,
                      iconColor: AppColors.destructive,
                      label: 'Dispense',
                      onTap: () {
                        Navigator.pop(context);

                        _openDispenseDialog(item: item);
                      },
                    ),

                    _buildActionTile(
                      icon: Icons.visibility,
                      iconColor: AppColors.mutedForeground,
                      label: 'View Details',
                      onTap: () {
                        Navigator.pop(context);

                        context.push(
                          '/inventory/${item.itemId}',
                        );
                      },
                    ),

                    const SizedBox(height: 4),

                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(
        icon,
        color: iconColor,
        size: 20,
      ),
      title: Text(
        label,
        style: const TextStyle(fontSize: 15),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 8,
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.of(context).size.width < 600;

    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text(
              'Refreshing inventory...',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ====================================================================
        // HEADER
        // ====================================================================
        //
        // PANEL FEEDBACK:
        // Simplified inventory entry points.
        //
        // OLD:
        // New menu + Stock In
        //
        // NEW:
        // Goods Received + Dispense
        // ====================================================================

        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inventory',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                '${_items.length} items',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _openGoodsReceived,
                      icon: const Icon(
                        Icons.inventory_2_outlined,
                        size: 18,
                      ),
                      label: const Text('Goods Received'),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openDispenseDialog,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.destructive,
                      ),
                      icon: const Icon(
                        Icons.arrow_downward,
                        size: 18,
                      ),
                      label: const Text('Dispense'),
                    ),
                  ),
                ],
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Inventory',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openGoodsReceived,
                    icon: const Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                    ),
                    label: const Text('Goods Received'),
                  ),

                  const SizedBox(width: 12),

                  OutlinedButton.icon(
                    onPressed: _openDispenseDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.destructive,
                    ),
                    icon: const Icon(
                      Icons.arrow_downward,
                      size: 18,
                    ),
                    label: const Text('Dispense'),
                  ),
                ],
              ),
            ],
          ),

        const SizedBox(height: 2),

        if (!isMobile)
          Text(
            '${_items.length} items',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.mutedForeground,
            ),
          ),

        const SizedBox(height: 20),

        // ====================================================================
        // MAIN CARD
        // ====================================================================

        Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================================
              // FILTERS
              // ==================================================================

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
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _search = value;
                            _page = 0;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search items',
                          hintStyle: TextStyle(
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            size: 18,
                          ),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),

                    _CategoryFilterMenu(
                      label: _categoryLabel,
                      primaryCategories: _primaryCategories,
                      onSelectAll: () {
                        _selectCategory(
                          label: 'Category',
                        );
                      },
                      onSelectPrimary: (primary) {
                        _selectCategory(
                          pCategoryId: primary.id,
                          label: primary.name,
                        );
                      },
                      onSelectSub: (
                        primary,
                        subId,
                        subName,
                      ) {
                        _selectCategory(
                          pCategoryId: primary.id,
                          sCategoryId: subId,
                          label: subName,
                        );
                      },
                    ),

                    AppDropdown<StockLevel?>(
                      label: _stockLevelFilter == null
                          ? 'Stock Level'
                          : _stockLevelMeta(
                              _stockLevelFilter!,
                            ).$1,
                      options: [
                        const AppDropdownOption(
                          null,
                          'All levels',
                        ),
                        AppDropdownOption(
                          StockLevel.inStock,
                          _stockLevelMeta(
                            StockLevel.inStock,
                          ).$1,
                        ),
                        AppDropdownOption(
                          StockLevel.low,
                          _stockLevelMeta(
                            StockLevel.low,
                          ).$1,
                        ),
                        AppDropdownOption(
                          StockLevel.outOfStock,
                          _stockLevelMeta(
                            StockLevel.outOfStock,
                          ).$1,
                        ),
                      ],
                      onSelect: (value) {
                        setState(() {
                          _stockLevelFilter = value;
                          _page = 0;
                        });
                      },
                    ),

                    AppDropdown<AcquisitionSource?>(
                      label: _sourceFilter == null
                          ? 'Source'
                          : _sourceMeta(
                              _sourceFilter!,
                            ).$1,
                      options: [
                        const AppDropdownOption(
                          null,
                          'All sources',
                        ),
                        for (final source
                            in AcquisitionSource.values)
                          AppDropdownOption(
                            source,
                            _sourceMeta(source).$1,
                          ),
                      ],
                      onSelect: (value) {
                        setState(() {
                          _sourceFilter = value;
                          _page = 0;
                        });
                      },
                    ),

                    AppDropdown<_SortOption>(
                      label:
                          'Sort: ${_sortMeta(_sortOption).$1}',
                      options: [
                        for (final option in _SortOption.values)
                          AppDropdownOption(
                            option,
                            _sortMeta(option).$1,
                          ),
                      ],
                      onSelect: (value) {
                        setState(() {
                          _sortOption = value;
                        });
                      },
                    ),

                    if (_hasActiveFilters)
                      TextButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                          size: 16,
                        ),
                        label: const Text('Reset Filters'),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // ==================================================================
              // EMPTY STATES
              // ==================================================================

              if (_items.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 56,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 36,
                          color: AppColors.mutedForeground,
                        ),
                        SizedBox(height: 10),
                        Text(
                          'No items in inventory yet',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Items you add will show up here.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filtered.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 48,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 32,
                          color: AppColors.mutedForeground,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No items match your filters.',
                          style: TextStyle(
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // ==============================================================
                // DESKTOP TABLE HEADER
                // ==============================================================

                if (!isMobile)
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _HeaderCell('ID'),
                        ),
                        Expanded(
                          flex: 4,
                          child: _HeaderCell('Item name'),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _HeaderCell('Category'),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: _HeaderCell('Stock'),
                        ),
                        SizedBox(width: 16),

                        // =====================================================
                        // EXPIRY COLUMN
                        // =====================================================

                        Expanded(
                          flex: 3,
                          child: _HeaderCell('Expiry'),
                        ),
                        SizedBox(width: 16),

                        Expanded(
                          flex: 2,
                          child: _HeaderCell('Stock Level'),
                        ),
                        SizedBox(
                          width: 56,
                          child: _HeaderCell(
                            'Action',
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!isMobile)
                  const Divider(height: 1),

                // ==============================================================
                // ITEM ROWS
                // ==============================================================

                Column(
                  children: [
                    for (var index = 0;
                        index < _pageItems.length;
                        index++) ...[
                      if (index > 0)
                        const Divider(height: 1),

                      Builder(
                        builder: (context) {
                          final item = _pageItems[index];

                          final stockLevel =
                              _stockLevelFor(item);

                          final (levelLabel, levelColor) =
                              _stockLevelMeta(stockLevel);

                          final replenishment =
                              _replenishmentFor(item);

                          final currentStockQty =
                              _currentStockQty(item);

                          final currentStockUnit =
                              _currentStockUnit(item);

                          final equivalentLabel =
                              _equivalentStockLabel(item);

                          // ====================================================
                          // DESKTOP ROW
                          // ====================================================

                          if (!isMobile) {
                            return HoverableRow(
                              onTap: () {
                                context.push(
                                  '/inventory/${item.itemId}',
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        item.displayId,
                                        style: const TextStyle(
                                          color:
                                              AppColors.mutedForeground,
                                        ),
                                      ),
                                    ),

                                    Expanded(
                                      flex: 4,
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: RichText(
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              text: TextSpan(
                                                style: const TextStyle(
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color:
                                                      AppColors.foreground,
                                                ),
                                                children: [
                                                  TextSpan(
                                                    text: item.itemName,
                                                  ),
                                                  if (item.packageLabel !=
                                                      null)
                                                    TextSpan(
                                                      text:
                                                          ' ${item.packageLabel}',
                                                      style:
                                                          const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w400,
                                                        color: AppColors
                                                            .mutedForeground,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          if (item.isOutOfStock) ...[
                                            const SizedBox(width: 8),
                                            _SmallBadge(
                                              label: 'Out of Stock',
                                              color:
                                                  AppColors.stockOut,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment:
                                            Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                AppColors.secondary,
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            item.pCategoryName,
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    // ==========================================
                                    // USABLE STOCK
                                    // ==========================================

                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${formatQty(currentStockQty)} '
                                            '$currentStockUnit',
                                            overflow:
                                                TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w700,
                                            ),
                                          ),
                                          if (equivalentLabel != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              equivalentLabel,
                                              overflow:
                                                  TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                color: AppColors
                                                    .mutedForeground,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    // ==========================================
                                    // EXPIRY
                                    // ==========================================

                                    Expanded(
                                      flex: 3,
                                      child: _ExpiryCell(
                                        item: item,
                                        formatDate:
                                            _formatExpiryDate,
                                      ),
                                    ),

                                    const SizedBox(width: 16),

                                    // ==========================================
                                    // STOCK LEVEL
                                    // ==========================================

                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _SmallBadge(
                                            label: levelLabel,
                                            color: levelColor,
                                          ),
                                          if (stockLevel ==
                                                  StockLevel.low &&
                                              replenishment != null) ...[
                                            const SizedBox(height: 3),
                                            Text(
                                              'ROP ${formatQty(replenishment.reorderPoint)} '
                                              '${item.purchaseUnitAbbr}',
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                color: AppColors
                                                    .mutedForeground,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // ==========================================
                                    // ACTION
                                    // ==========================================

                                    SizedBox(
                                      width: 56,
                                      child: Align(
                                        alignment:
                                            Alignment.centerRight,
                                        child:
                                            AppMenuButton<String>(
                                          alignRight: true,
                                          options: const [
                                            AppDropdownOption(
                                              'view',
                                              'View details',
                                            ),
                                            AppDropdownOption(
                                              'receive',
                                              'Goods Received',
                                            ),
                                            AppDropdownOption(
                                              'dispense',
                                              'Dispense',
                                            ),
                                          ],
                                          onSelected: (value) {
                                            if (value ==
                                                'receive') {
                                              _openGoodsReceived(
                                                itemId: item.itemId,
                                              );
                                            }

                                            if (value ==
                                                'dispense') {
                                              _openDispenseDialog(
                                                item: item,
                                              );
                                            }

                                            if (value == 'view') {
                                              context.push(
                                                '/inventory/${item.itemId}',
                                              );
                                            }
                                          },
                                          triggerBuilder: (
                                            context,
                                            isOpen,
                                          ) {
                                            return const Padding(
                                              padding:
                                                  EdgeInsets.all(6),
                                              child: Icon(
                                                Icons.more_horiz,
                                                size: 18,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          // ====================================================
                          // MOBILE CARD
                          // ====================================================

                          return InkWell(
                            onTap: () {
                              _showActionDialog(
                                context,
                                item,
                              );
                            },
                            borderRadius:
                                BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.displayId,
                                        style: const TextStyle(
                                          color:
                                              AppColors.mutedForeground,
                                          fontSize: 12,
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      Expanded(
                                        child: Text(
                                          item.itemName,
                                          style: const TextStyle(
                                            fontWeight:
                                                FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      ),

                                      const Icon(
                                        Icons.chevron_right,
                                        size: 18,
                                        color:
                                            AppColors.mutedForeground,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 7),

                                  Row(
                                    children: [
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.secondary,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          item.pCategoryName,
                                          style: const TextStyle(
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 8),

                                      _SmallBadge(
                                        label: levelLabel,
                                        color: levelColor,
                                        small: true,
                                      ),

                                      const Spacer(),

                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${formatQty(currentStockQty)} '
                                            '$currentStockUnit',
                                            style: const TextStyle(
                                              fontWeight:
                                                  FontWeight.w700,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (equivalentLabel != null)
                                            Text(
                                              equivalentLabel,
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: AppColors
                                                    .mutedForeground,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),

                                  // ==========================================
                                  // MOBILE EXPIRY
                                  // ==========================================

                                  if (item.hasExpiredStock ||
                                      item.nearestExpiryDate !=
                                          null) ...[
                                    const SizedBox(height: 8),
                                    _ExpiryCell(
                                      item: item,
                                      formatDate:
                                          _formatExpiryDate,
                                      compact: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),

                const Divider(height: 1),

                // ==============================================================
                // PAGINATION
                // ==============================================================

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: isMobile
                      ? Column(
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Show',
                                  style:
                                      TextStyle(fontSize: 12.5),
                                ),
                                const SizedBox(width: 8),
                                AppDropdown<int>(
                                  label: '$_pageSize',
                                  options: const [
                                    12,
                                    25,
                                    50,
                                  ]
                                      .map(
                                        (number) =>
                                            AppDropdownOption(
                                          number,
                                          '$number',
                                        ),
                                      )
                                      .toList(),
                                  onSelect: (value) {
                                    setState(() {
                                      _pageSize = value;
                                      _page = 0;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Per Page',
                                  style:
                                      TextStyle(fontSize: 12.5),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            _PaginationControls(
                              page: _page,
                              pageCount: _pageCount,
                              onPrevious: _page > 0
                                  ? () {
                                      setState(() {
                                        _page--;
                                      });
                                    }
                                  : null,
                              onNext:
                                  _page < _pageCount - 1
                                      ? () {
                                          setState(() {
                                            _page++;
                                          });
                                        }
                                      : null,
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Show',
                                  style:
                                      TextStyle(fontSize: 12.5),
                                ),
                                const SizedBox(width: 8),
                                AppDropdown<int>(
                                  label: '$_pageSize',
                                  options: const [
                                    12,
                                    25,
                                    50,
                                  ]
                                      .map(
                                        (number) =>
                                            AppDropdownOption(
                                          number,
                                          '$number',
                                        ),
                                      )
                                      .toList(),
                                  onSelect: (value) {
                                    setState(() {
                                      _pageSize = value;
                                      _page = 0;
                                    });
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Per Page',
                                  style:
                                      TextStyle(fontSize: 12.5),
                                ),
                              ],
                            ),

                            _PaginationControls(
                              page: _page,
                              pageCount: _pageCount,
                              onPrevious: _page > 0
                                  ? () {
                                      setState(() {
                                        _page--;
                                      });
                                    }
                                  : null,
                              onNext:
                                  _page < _pageCount - 1
                                      ? () {
                                          setState(() {
                                            _page++;
                                          });
                                        }
                                      : null,
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

// =============================================================================
// EXPIRY CELL
// =============================================================================

class _ExpiryCell extends StatelessWidget {
  final InventoryItem item;
  final String Function(DateTime) formatDate;
  final bool compact;

  const _ExpiryCell({
    required this.item,
    required this.formatDate,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final expiry = item.nearestExpiryDate;
    final days = item.daysUntilNearestExpiry;

    final children = <Widget>[];

    // =========================================================================
    // EXPIRED STOCK
    // =========================================================================
    //
    // This stock remains physically present but is excluded from usable stock.
    // Staff must explicitly remove it using:
    //
    // Dispense -> Dispense Type -> Expired
    // =========================================================================

    if (item.hasExpiredStock) {
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 13,
              color: AppColors.destructive,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${formatQty(item.expiredBatchStockQty)} '
                '${item.currentUsableStockUnit} expired',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.destructive,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // =========================================================================
    // NEAREST USABLE EXPIRY
    // =========================================================================

    if (expiry != null && days != null) {
      if (children.isNotEmpty) {
        children.add(
          const SizedBox(height: 3),
        );
      }

      final isWarning =
          item.isExpiringSoon || item.expiresToday;

      String timing;

      if (days == 0) {
        timing = 'today';
      } else if (days == 1) {
        timing = '1 day';
      } else {
        timing = '$days days';
      }

      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.schedule_outlined,
              size: 13,
              color: isWarning
                  ? AppColors.warning
                  : AppColors.mutedForeground,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                '${formatDate(expiry)} · $timing',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: isWarning
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isWarning
                      ? AppColors.warning
                      : AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (children.isEmpty) {
      return Text(
        item.hasBatchHistory ? 'No expiry' : '—',
        style: TextStyle(
          fontSize: compact ? 10.5 : 11.5,
          color: AppColors.mutedForeground,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

// =============================================================================
// EXPIRY NOTICE
// =============================================================================

class _ExpiryNotice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _ExpiryNotice({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SMALL BADGE
// =============================================================================

class _SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;

  const _SmallBadge({
    required this.label,
    required this.color,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: small ? 10.5 : 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// =============================================================================
// PAGINATION
// =============================================================================

class _PaginationControls extends StatelessWidget {
  final int page;
  final int pageCount;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PaginationControls({
    required this.page,
    required this.pageCount,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: onPrevious,
          icon: const Icon(
            Icons.chevron_left,
            size: 16,
          ),
          label: const Text('Previous'),
        ),

        const SizedBox(width: 4),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${page + 1} / $pageCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),

        const SizedBox(width: 4),

        TextButton.icon(
          onPressed: onNext,
          icon: const Icon(
            Icons.chevron_right,
            size: 16,
          ),
          label: const Text('Next'),
        ),
      ],
    );
  }
}

// =============================================================================
// PRIMARY CATEGORY OPTION
// =============================================================================

class _PrimaryCategoryOption {
  final String id;
  final String name;

  final Map<String, String> subcategories = {};

  _PrimaryCategoryOption({
    required this.id,
    required this.name,
  });
}

// =============================================================================
// CATEGORY FILTER
// =============================================================================

class _CategoryFilterMenu extends StatefulWidget {
  final String label;
  final List<_PrimaryCategoryOption> primaryCategories;
  final VoidCallback onSelectAll;
  final ValueChanged<_PrimaryCategoryOption> onSelectPrimary;

  final void Function(
    _PrimaryCategoryOption p,
    String subId,
    String subName,
  ) onSelectSub;

  const _CategoryFilterMenu({
    required this.label,
    required this.primaryCategories,
    required this.onSelectAll,
    required this.onSelectPrimary,
    required this.onSelectSub,
  });

  @override
  State<_CategoryFilterMenu> createState() =>
      _CategoryFilterMenuState();
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

    for (final primary in widget.primaryCategories) {
      if (primary.id == _hoveredPrimaryId) {
        hovered = primary;
      }
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
                    onTap: () {
                      _select(widget.onSelectAll);
                    },
                  ),

                  for (final primary
                      in widget.primaryCategories)
                    MouseRegion(
                      onEnter: (_) {
                        _hoveredPrimaryId = primary.id;
                        rebuildDropdown();
                      },
                      child: AppDropdownMenuRow(
                        label: primary.name,
                        hasChildren:
                            primary.subcategories.isNotEmpty,
                        onTap: () {
                          _select(
                            () {
                              widget.onSelectPrimary(primary);
                            },
                          );
                        },
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
                      onTap: () {
                        _select(
                          () {
                            widget.onSelectPrimary(hovered!);
                          },
                        );
                      },
                    ),

                    for (final entry in subs)
                      AppDropdownMenuRow(
                        label: entry.value,
                        onTap: () {
                          _select(
                            () {
                              widget.onSelectSub(
                                hovered!,
                                entry.key,
                                entry.value,
                              );
                            },
                          );
                        },
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
        child: AppDropdownButton(
          label: widget.label,
        ),
      ),
    );
  }
}

// =============================================================================
// TABLE HEADER
// =============================================================================

class _HeaderCell extends StatelessWidget {
  final String label;
  final bool alignEnd;

  const _HeaderCell(
    this.label, {
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignEnd
          ? Alignment.centerRight
          : Alignment.centerLeft,
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