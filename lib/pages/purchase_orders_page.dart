import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../models/replenishment_item.dart';
import '../models/supplier.dart';
import '../services/replenishment_service.dart';
import '../services/supplier_service.dart';
import '../state/data_bus.dart';
import '../widgets/page_loading.dart';
// =============================================================================
// ORDERING
// =============================================================================
//
// PANEL REVISION:
//
// Purchase and Replenishment are presented to Staff as one Ordering module.
//
// TAB 1:
//   Replenishment
//   - 30-day normalized usage
//   - ADU
//   - Lead Time
//   - Safety Stock
//   - ROP
//   - Current usable stock
//   - Suggested shortfall
//
// TAB 2:
//   Purchase History
//   - existing public.purchase transactions
//   - read-only purchase details open in a modal
//
// SIYAM does NOT automatically generate purchase records from ROP.
// =============================================================================

enum _PurchaseModuleTab {
  replenishment,
  purchaseHistory,
}

class PurchaseOrdersPage extends StatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  State<PurchaseOrdersPage> createState() =>
      _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends State<PurchaseOrdersPage>
    with DataBusRefreshMixin<PurchaseOrdersPage> {
  final SupplierService _supplierService = SupplierService();
  final ReplenishmentService _replenishmentService =
      ReplenishmentService();

  final _purchaseSearchCtrl = TextEditingController();
  final _replenishmentSearchCtrl = TextEditingController();

  List<PurchaseOrder> _orders = [];
  List<ReplenishmentItem> _replenishment = [];

  bool _loading = true;
  String? _error;

  _PurchaseModuleTab _tab =
      _PurchaseModuleTab.replenishment;

  String _purchaseSearch = '';
  String _replenishmentSearch = '';

  ReplenishmentPriority? _priorityFilter;
  bool _customRopOnly = false;

  int _replenishmentPage = 0;
  static const int _replenishmentPageSize = 12;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _purchaseSearchCtrl.dispose();
    _replenishmentSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void onExternalDataChanged() =>
      _load(silent: true);

  // ===========================================================================
  // LOAD BOTH SIDES OF THE MERGED MODULE
  // ===========================================================================

  Future<void> _load({
    bool silent = false,
  }) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results =
          await Future.wait<Object?>([
        _supplierService.fetchAllPurchaseOrders(),
        _replenishmentService
            .fetchReplenishmentItems(),
      ]);

      if (!mounted) return;

      setState(() {
        _orders =
            results[0] as List<PurchaseOrder>;

        _replenishment =
            results[1]
                as List<ReplenishmentItem>;

        _loading = false;

        if (_replenishmentPage >=
            _replenishmentPageCount) {
          _replenishmentPage =
              _replenishmentPageCount - 1;
        }
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error =
              'Could not load ordering data: $e';
          _loading = false;
        });
      }
    }
  }

  // ===========================================================================
  // PURCHASE SEARCH
  // ===========================================================================

  List<PurchaseOrder>
      get _filteredOrders {
    final query =
        _purchaseSearch.trim().toLowerCase();

    if (query.isEmpty) {
      return _orders;
    }

    return _orders.where((order) {
      return order.suppName
              .toLowerCase()
              .contains(query) ||
          order.receivedBy
              .toLowerCase()
              .contains(query) ||
          order.buyerName
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  void _clearPurchaseSearch() {
    _purchaseSearchCtrl.clear();

    setState(() {
      _purchaseSearch = '';
    });
  }

  Future<void> _showPurchaseDetails(
    PurchaseOrder order,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _PurchaseDetailsDialog(
          order: order,
          service: _supplierService,
        );
      },
    );
  }

  // ===========================================================================
  // REPLENISHMENT FILTERS
  // ===========================================================================

  bool get _hasReplenishmentFilters =>
      _replenishmentSearch.trim().isNotEmpty ||
      _priorityFilter != null ||
      _customRopOnly;

  List<ReplenishmentItem>
      get _filteredReplenishment {
    final query =
        _replenishmentSearch
            .trim()
            .toLowerCase();

    return _replenishment.where((row) {
      final matchesSearch =
          query.isEmpty ||
          row.item.itemName
              .toLowerCase()
              .contains(query) ||
          row.item.itemCategory
              .toLowerCase()
              .contains(query) ||
          row.item.purchaseUnitAbbr
              .toLowerCase()
              .contains(query);

      final matchesPriority =
          _priorityFilter == null ||
          row.priority == _priorityFilter;

      final matchesRopMode =
          !_customRopOnly ||
          row.usesCustomRop;

      return matchesSearch &&
          matchesPriority &&
          matchesRopMode;
    }).toList();
  }

  int get _replenishmentPageCount {
    final count =
        (_filteredReplenishment.length /
                _replenishmentPageSize)
            .ceil();

    return count < 1 ? 1 : count;
  }

  List<ReplenishmentItem>
      get _replenishmentPageItems {
    final filtered =
        _filteredReplenishment;

    final start =
        _replenishmentPage *
        _replenishmentPageSize;

    if (start >= filtered.length) {
      return const [];
    }

    final proposedEnd =
        start + _replenishmentPageSize;

    final end =
        proposedEnd > filtered.length
            ? filtered.length
            : proposedEnd;

    return filtered.sublist(
      start,
      end,
    );
  }

  void _clearReplenishmentSearch() {
    _replenishmentSearchCtrl.clear();

    setState(() {
      _replenishmentSearch = '';
      _replenishmentPage = 0;
    });
  }

  void _resetReplenishmentFilters() {
    _replenishmentSearchCtrl.clear();

    setState(() {
      _replenishmentSearch = '';
      _priorityFilter = null;
      _customRopOnly = false;
      _replenishmentPage = 0;
    });
  }

  // ===========================================================================
  // SUMMARY
  // ===========================================================================

  int get _criticalCount =>
      _replenishment
          .where(
            (row) =>
                row.priority ==
                ReplenishmentPriority.critical,
          )
          .length;

  int get _customRopCount =>
      _replenishment
          .where(
            (row) =>
                row.usesCustomRop,
          )
          .length;

  bool get _showingAllReplenishment =>
      _priorityFilter == null &&
      !_customRopOnly;

  void _showAllReplenishment() {
    setState(() {
      _priorityFilter = null;
      _customRopOnly = false;
      _replenishmentPage = 0;
    });
  }

  void _toggleCriticalSummary() {
    setState(() {
      final alreadySelected =
          _priorityFilter ==
                  ReplenishmentPriority.critical &&
              !_customRopOnly;

      _priorityFilter = alreadySelected
          ? null
          : ReplenishmentPriority.critical;

      _customRopOnly = false;
      _replenishmentPage = 0;
    });
  }

  void _toggleCustomRopSummary() {
    setState(() {
      final alreadySelected =
          _customRopOnly;

      _customRopOnly =
          !alreadySelected;

      // Summary filters are intentionally mutually exclusive so the manager/
      // staff can always understand exactly what the list is showing.
      _priorityFilter = null;
      _replenishmentPage = 0;
    });
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
if (_loading) {
  return const PageLoading(
    message: 'Loading purchase orders',
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
                color:
                    AppColors.mutedForeground,
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
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 18),
        _buildTabSelector(),
        const SizedBox(height: 20),

        if (_tab ==
            _PurchaseModuleTab.replenishment)
          _buildReplenishmentTab()
        else
          _buildPurchaseHistoryTab(),
      ],
    );
  }

  // ===========================================================================
  // HEADER
  // ===========================================================================

  Widget _buildHeader() {
    final showRecordPurchase =
        _tab ==
        _PurchaseModuleTab.purchaseHistory;

    final titleBlock = const Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Ordering',
          style: TextStyle(
            fontSize: 24,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Review replenishment needs and recorded purchase history in one place.',
          style: TextStyle(
            fontSize: 13,
            color:
                AppColors.mutedForeground,
          ),
        ),
      ],
    );

    final recordPurchaseButton =
        ElevatedButton.icon(
      onPressed: () => context.push(
        '/inventory/add?type=purchased',
      ),
      icon: const Icon(
        Icons.add,
        size: 18,
      ),
      label:
          const Text('Record Purchase'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile =
            constraints.maxWidth < 600;

        if (mobile) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              titleBlock,

              if (showRecordPurchase) ...[
                const SizedBox(height: 14),

                SizedBox(
                  width: double.infinity,
                  child:
                      recordPurchaseButton,
                ),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: titleBlock,
            ),

            if (showRecordPurchase) ...[
              const SizedBox(width: 16),
              recordPurchaseButton,
            ],
          ],
        );
      },
    );
  }

  // ===========================================================================
  // TAB SELECTOR
  // ===========================================================================

  Widget _buildTabSelector() {
    return Align(
      alignment: Alignment.centerLeft,
      child:
          SegmentedButton<
              _PurchaseModuleTab>(
        segments: const [
          ButtonSegment(
            value:
                _PurchaseModuleTab
                    .replenishment,
            icon: Icon(
              Icons.autorenew_outlined,
              size: 18,
            ),
            label:
                Text('Replenishment'),
          ),
          ButtonSegment(
            value:
                _PurchaseModuleTab
                    .purchaseHistory,
            icon: Icon(
              Icons
                  .receipt_long_outlined,
              size: 18,
            ),
            label:
                Text('Purchase History'),
          ),
        ],
        selected: {_tab},
        showSelectedIcon: false,
        onSelectionChanged: (selection) {
          setState(() {
            _tab = selection.first;
          });
        },
      ),
    );
  }

  // ===========================================================================
  // REPLENISHMENT TAB
  // ===========================================================================

  Widget _buildReplenishmentTab() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // ---------------------------------------------------------------------
        // SUMMARY CARDS
        // ---------------------------------------------------------------------

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              icon: Icons
                  .inventory_2_outlined,
              label:
                  'Needs Replenishment',
              value:
                  '${_replenishment.length}',
              helper:
                  'At or below calculated ROP',
              selected:
                  _showingAllReplenishment,
              onTap:
                  _showAllReplenishment,
            ),
            _SummaryCard(
              icon:
                  Icons.warning_amber_rounded,
              label: 'Critical',
              value: '$_criticalCount',
              helper:
                  'No usable stock remaining',
              selected:
                  _priorityFilter ==
                          ReplenishmentPriority
                              .critical &&
                      !_customRopOnly,
              onTap:
                  _toggleCriticalSummary,
            ),
            _SummaryCard(
              icon:
                  Icons.tune_outlined,
              label: 'Custom ROP',
              value: '$_customRopCount',
              helper:
                  'Using item-specific settings',
              selected:
                  _customRopOnly,
              onTap:
                  _toggleCustomRopSummary,
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // FORMULA NOTE
        // ---------------------------------------------------------------------

        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: const Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ROP = (30-day Average Daily Usage × Lead Time) + Safety Stock. '
                  'Current stock is taken from usable inventory batches and normalized '
                  'to the item\'s purchase unit.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ---------------------------------------------------------------------
        // LIST CARD
        // ---------------------------------------------------------------------

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius:
                BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildReplenishmentFilters(),
              const Divider(height: 1),

              if (_replenishment.isEmpty)
                const _EmptyState(
                  icon:
                      Icons.check_circle_outline,
                  title:
                      'Nothing needs replenishment',
                  message:
                      'All items are currently above their calculated reorder points.',
                )
              else if (_filteredReplenishment
                  .isEmpty)
                _EmptyState(
                  icon: Icons.search_off,
                  title:
                      'No items match your filters',
                  message:
                      'Clear the search or priority filter to see other replenishment items.',
                  actionLabel:
                      'Reset Filters',
                  onAction:
                      _resetReplenishmentFilters,
                )
              else ...[
                if (MediaQuery.sizeOf(context).width < 1000)
                  Column(
                    children: [
                      for (var i = 0;
                          i < _replenishmentPageItems.length;
                          i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                          ),
                        _ReplenishmentMobileRow(
                          row: _replenishmentPageItems[i],
                        ),
                      ],
                    ],
                  )
                else
                  Column(
                    children: [
                      const _ReplenishmentHeader(),
                      const Divider(height: 1),
                      for (var i = 0;
                          i < _replenishmentPageItems.length;
                          i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                          ),
                        _ReplenishmentDesktopRow(
                          row: _replenishmentPageItems[i],
                        ),
                      ],
                    ],
                  ),

                const Divider(height: 1),
                _buildReplenishmentPagination(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReplenishmentFilters() {
    final narrow =
        MediaQuery.sizeOf(context).width < 940;

    final search = TextField(
      controller: _replenishmentSearchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(
          Icons.search,
          size: 18,
        ),
        suffixIcon: _replenishmentSearch.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: _clearReplenishmentSearch,
                icon: const Icon(
                  Icons.close,
                  size: 18,
                ),
              ),
        hintText: 'Search item, category, or unit',
      ),
      onChanged: (value) {
        setState(() {
          _replenishmentSearch = value;
          _replenishmentPage = 0;
        });
      },
    );

    final filters = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PriorityChoice(
          label: 'All',
          selected: _priorityFilter == null,
          onTap: () {
            setState(() {
              _priorityFilter = null;
              _customRopOnly = false;
              _replenishmentPage = 0;
            });
          },
        ),
        _PriorityChoice(
          label: 'Critical',
          selected:
              _priorityFilter ==
              ReplenishmentPriority.critical,
          onTap: () {
            setState(() {
              _priorityFilter =
                  ReplenishmentPriority.critical;
              _customRopOnly = false;
              _replenishmentPage = 0;
            });
          },
        ),
        _PriorityChoice(
          label: 'High',
          selected:
              _priorityFilter ==
              ReplenishmentPriority.high,
          onTap: () {
            setState(() {
              _priorityFilter =
                  ReplenishmentPriority.high;
              _customRopOnly = false;
              _replenishmentPage = 0;
            });
          },
        ),
        _PriorityChoice(
          label: 'Medium',
          selected:
              _priorityFilter ==
              ReplenishmentPriority.medium,
          onTap: () {
            setState(() {
              _priorityFilter =
                  ReplenishmentPriority.medium;
              _customRopOnly = false;
              _replenishmentPage = 0;
            });
          },
        ),
        if (_hasReplenishmentFilters)
          TextButton.icon(
            onPressed: _resetReplenishmentFilters,
            icon: const Icon(
              Icons.filter_alt_off_outlined,
              size: 16,
            ),
            label: const Text('Reset'),
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: narrow
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                search,
                const SizedBox(height: 12),
                filters,
              ],
            )
          : Row(
              children: [
                Expanded(child: search),
                const SizedBox(width: 16),
                filters,
              ],
            ),
    );
  }

  Widget _buildReplenishmentPagination() {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_filteredReplenishment.length} item'
              '${_filteredReplenishment.length == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12.5,
                color:
                    AppColors.mutedForeground,
              ),
            ),
          ),
          TextButton.icon(
            onPressed:
                _replenishmentPage > 0
                    ? () {
                        setState(() {
                          _replenishmentPage--;
                        });
                      }
                    : null,
            icon: const Icon(
              Icons.chevron_left,
              size: 16,
            ),
            label:
                const Text('Previous'),
          ),
          const SizedBox(width: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius:
                  BorderRadius.circular(999),
            ),
            child: Text(
              '${_replenishmentPage + 1} / $_replenishmentPageCount',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed:
                _replenishmentPage <
                        _replenishmentPageCount -
                            1
                    ? () {
                        setState(() {
                          _replenishmentPage++;
                        });
                      }
                    : null,
            icon: const Icon(
              Icons.chevron_right,
              size: 16,
            ),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PURCHASE HISTORY TAB
  // ===========================================================================

  Widget _buildPurchaseHistoryTab() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _orders.length == 1
                    ? '1 recorded purchase transaction'
                    : '${_orders.length} recorded purchase transactions',
                style: const TextStyle(
                  fontSize: 13,
                  color:
                      AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: 380,
          child: TextField(
            controller:
                _purchaseSearchCtrl,
            onChanged: (value) {
              setState(() {
                _purchaseSearch = value;
              });
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
              ),
              suffixIcon:
                  _purchaseSearch.isEmpty
                      ? null
                      : IconButton(
                          tooltip:
                              'Clear search',
                          onPressed:
                              _clearPurchaseSearch,
                          icon:
                              const Icon(
                            Icons.close,
                            size: 18,
                          ),
                        ),
              hintText:
                  'Search supplier or staff',
              isDense: true,
            ),
          ),
        ),

        const SizedBox(height: 18),

        if (_orders.isEmpty)
          const _EmptyState(
            icon:
                Icons.receipt_long_outlined,
            title:
                'No purchase history yet',
            message:
                'Record a purchase from Inventory → Stock In.',
          )
        else if (_filteredOrders.isEmpty)
          _EmptyState(
            icon: Icons.search_off,
            title:
                'No purchases match your search',
            message:
                'Try another supplier or staff name.',
            actionLabel:
                'Clear Search',
            onAction:
                _clearPurchaseSearch,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Column(
              children: [
                for (var i = 0;
                    i <
                        _filteredOrders
                            .length;
                    i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                    ),
                  _PurchaseOrderRow(
                    order:
                        _filteredOrders[i],
                    onTap: () =>
                        _showPurchaseDetails(
                      _filteredOrders[i],
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
// SUMMARY CARD
// =============================================================================

class _SummaryCard
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final bool selected;
  final VoidCallback onTap;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 230,
      child: Material(
        color: Colors.transparent,
        borderRadius:
            BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(16),
          hoverColor: AppColors.primary
              .withValues(
            alpha: 0.035,
          ),
          child: AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 140,
            ),
            padding:
                const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                      .withValues(
                      alpha: 0.055,
                    )
                  : AppColors.card,
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : AppColors.border,
                width: selected
                    ? 1.5
                    : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary
                            .withValues(
                            alpha: 0.13,
                          )
                        : AppColors.secondary,
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  alignment:
                      Alignment.center,
                  child: Icon(
                    icon,
                    size: 19,
                    color:
                        AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              value,
                              style:
                                  const TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ),
                          if (selected)
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color:
                                  AppColors.primary,
                            ),
                        ],
                      ),
                      Text(
                        label,
                        style:
                            const TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        helper,
                        style:
                            const TextStyle(
                          fontSize: 11.5,
                          color: AppColors
                              .mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        selected
                            ? 'Filter active'
                            : 'Click to filter',
                        style: TextStyle(
                          fontSize: 10.3,
                          fontWeight:
                              FontWeight.w600,
                          color: selected
                              ? AppColors.primary
                              : AppColors
                                  .mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// PRIORITY FILTER
// =============================================================================

class _PriorityChoice
    extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PriorityChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      selectedColor:
          AppColors.primary,
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : AppColors.foreground,
        fontWeight: selected
            ? FontWeight.w700
            : FontWeight.w500,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.primary
            : AppColors.border,
      ),
    );
  }
}

// =============================================================================
// REPLENISHMENT ROW HELPERS
// =============================================================================

(String, Color) _priorityMeta(
  ReplenishmentPriority priority,
) {
  switch (priority) {
    case ReplenishmentPriority.critical:
      return (
        'Critical',
        AppColors.stockOut,
      );

    case ReplenishmentPriority.high:
      return (
        'High',
        AppColors.stockLow,
      );

    case ReplenishmentPriority.medium:
      return (
        'Medium',
        AppColors.stockNeedsRestock,
      );
  }
}

class _PriorityBadge
    extends StatelessWidget {
  final ReplenishmentPriority priority;

  const _PriorityBadge({
    required this.priority,
  });

  @override
  Widget build(BuildContext context) {
    final meta =
        _priorityMeta(priority);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: meta.$2.withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        meta.$1,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight:
              FontWeight.w700,
          color: meta.$2,
        ),
      ),
    );
  }
}

class _RopModeBadge
    extends StatelessWidget {
  final bool custom;

  const _RopModeBadge({
    required this.custom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: custom
            ? AppColors.primary.withValues(
                alpha: 0.10,
              )
            : AppColors.secondary,
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        custom ? 'Custom' : 'Default',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight:
              FontWeight.w600,
          color: custom
              ? AppColors.primary
              : AppColors
                  .mutedForeground,
        ),
      ),
    );
  }
}

String _qty(
  double value,
  String unit,
) {
  return '${formatQty(value)} $unit';
}

String _suggestedLabel(
  ReplenishmentItem row,
) {
  if (row.suggestedQty <=
      0.000000001) {
    return 'At ROP';
  }

  return _qty(
    row.suggestedQty,
    row.item.purchaseUnitAbbr,
  );
}

// =============================================================================
// DESKTOP REPLENISHMENT TABLE
// =============================================================================

class _ReplenishmentHeader
    extends StatelessWidget {
  const _ReplenishmentHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child:
                _HeaderCell('Priority'),
          ),
          Expanded(
            flex: 3,
            child: _HeaderCell('Item'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child:
                _HeaderCell('Current'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child:
                _HeaderCell('30d Usage'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _HeaderCell('ADU'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _HeaderCell('ROP'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child:
                _HeaderCell('Suggested'),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 76,
            child:
                _HeaderCell('Settings'),
          ),
          SizedBox(width: 22),
        ],
      ),
    );
  }
}

class _ReplenishmentDesktopRow
    extends StatelessWidget {
  final ReplenishmentItem row;

  const _ReplenishmentDesktopRow({
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    final unit =
        row.item.purchaseUnitAbbr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(
          '/inventory/${row.item.itemId}?from=purchase-orders',
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: Align(
                  alignment:
                      Alignment.centerLeft,
                  child: _PriorityBadge(
                    priority:
                        row.priority,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      row.item.itemName,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      row.item.itemCategory,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 11.5,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  _qty(
                    row.currentStockPurchaseUnits,
                    unit,
                  ),
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  _qty(
                    row.usage30PurchaseUnits,
                    unit,
                  ),
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  '${formatQty(row.averageDailyUsage)} $unit/day',
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Tooltip(
                  message:
                      '(${formatQty(row.averageDailyUsage)} × ${row.leadTimeDays} days) + '
                      '${formatQty(row.safetyStockQty)} $unit safety stock',
                  child: Text(
                    _qty(
                      row.reorderPoint,
                      unit,
                    ),
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  _suggestedLabel(row),
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 76,
                child: Align(
                  alignment:
                      Alignment.centerLeft,
                  child: _RopModeBadge(
                    custom:
                        row.usesCustomRop,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors
                    .mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MOBILE REPLENISHMENT ROW
// =============================================================================

class _ReplenishmentMobileRow
    extends StatelessWidget {
  final ReplenishmentItem row;

  const _ReplenishmentMobileRow({
    required this.row,
  });

  @override
  Widget build(BuildContext context) {
    final unit =
        row.item.purchaseUnitAbbr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.go(
          '/inventory/${row.item.itemId}?from=purchase-orders',
        ),
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _PriorityBadge(
                    priority:
                        row.priority,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.item.itemName,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 14.5,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ),
                  _RopModeBadge(
                    custom:
                        row.usesCustomRop,
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors
                        .mutedForeground,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                row.item.itemCategory,
                style:
                    const TextStyle(
                  fontSize: 11.5,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 18,
                runSpacing: 10,
                children: [
                  _MiniMetric(
                    label: 'Current',
                    value: _qty(
                      row.currentStockPurchaseUnits,
                      unit,
                    ),
                  ),
                  _MiniMetric(
                    label: '30d Usage',
                    value: _qty(
                      row.usage30PurchaseUnits,
                      unit,
                    ),
                  ),
                  _MiniMetric(
                    label: 'ADU',
                    value:
                        '${formatQty(row.averageDailyUsage)} $unit/day',
                  ),
                  _MiniMetric(
                    label: 'ROP',
                    value: _qty(
                      row.reorderPoint,
                      unit,
                    ),
                  ),
                  _MiniMetric(
                    label: 'Suggested',
                    value:
                        _suggestedLabel(row),
                  ),
                  _MiniMetric(
                    label: 'Lead / Safety',
                    value:
                        '${row.leadTimeDays}d / ${formatQty(row.safetyStockQty)} $unit',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMetric
    extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 145,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color:
                  AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            overflow:
                TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PURCHASE HISTORY ROW
// =============================================================================

class _PurchaseOrderRow
    extends StatelessWidget {
  final PurchaseOrder order;
  final VoidCallback onTap;

  const _PurchaseOrderRow({
    required this.order,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  crossAxisAlignment:
                      WrapCrossAlignment
                          .center,
                  children: [
                    SizedBox(
                      width: 220,
                      child: Text(
                        order.suppName,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight
                                  .w600,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text(
                        _formatDate(
                          order.receivedDate,
                        ),
                        style:
                            const TextStyle(
                          fontSize: 13,
                          color: AppColors
                              .mutedForeground,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: _MetaLine(
                        label:
                            'Received by',
                        value: order
                                .receivedBy
                                .isEmpty
                            ? '—'
                            : order
                                .receivedBy,
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: _MetaLine(
                        label:
                            'Recorded by',
                        value:
                            order.buyerName,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.visibility_outlined,
                size: 18,
                color: AppColors
                    .mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// =============================================================================
// PURCHASE HISTORY DETAILS MODAL
// =============================================================================
//
// This modal belongs ONLY to the Purchase History tab.
//
// It does not modify the Replenishment tab, ROP calculations, filters,
// pagination, item-detail navigation, or Record Purchase flow.
//
// Close / outside click / Android system Back dismiss only this modal.
// GoRouter history is not changed.
// =============================================================================

class _PurchaseDetailsDialog extends StatefulWidget {
  final PurchaseOrder order;
  final SupplierService service;

  const _PurchaseDetailsDialog({
    required this.order,
    required this.service,
  });

  @override
  State<_PurchaseDetailsDialog> createState() =>
      _PurchaseDetailsDialogState();
}

class _PurchaseDetailsDialogState
    extends State<_PurchaseDetailsDialog> {
  late final Future<List<OrderLineItem>>
      _itemsFuture;

  @override
  void initState() {
    super.initState();

    _itemsFuture =
        widget.service.fetchOrderItems(
      widget.order.purId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final screen =
        MediaQuery.sizeOf(context);

    // Keep the purchase-details modal visually stable while its items load.
    // Desktop/tablet use a consistent 720 x 600 maximum footprint.
    // Smaller APK/mobile screens use the available width and 82% of height.
    final dialogWidth =
        screen.width < 752
            ? screen.width - 32
            : 720.0;

    final responsiveHeight =
        screen.height * 0.82;

    final dialogHeight =
        responsiveHeight < 600
            ? responsiveHeight
            : 600.0;

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding:
          const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // -----------------------------------------------------------------
            // HEADER
            // -----------------------------------------------------------------

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                18,
                12,
                14,
              ),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration:
                        BoxDecoration(
                      color: AppColors.primary
                          .withValues(
                        alpha: 0.09,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                    alignment:
                        Alignment.center,
                    child: const Icon(
                      Icons
                          .receipt_long_outlined,
                      size: 20,
                      color:
                          AppColors.primary,
                    ),
                  ),

                  const SizedBox(width: 11),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.suppName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Purchase received ${_formatDate(order.receivedDate)}',
                          style: const TextStyle(
                            fontSize: 11.8,
                            color: AppColors
                                .mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    tooltip: 'Close',
                    onPressed: () =>
                        Navigator.of(context)
                            .pop(),
                    icon: const Icon(
                      Icons.close,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // -----------------------------------------------------------------
            // DATA
            // -----------------------------------------------------------------

            Expanded(
              child:
                  FutureBuilder<
                      List<OrderLineItem>>(
                future: _itemsFuture,
                builder: (
                  context,
                  snapshot,
                ) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Padding(
                      padding:
                          EdgeInsets.symmetric(
                        vertical: 48,
                      ),
                      child: Center(
                        child:
                            CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding:
                          const EdgeInsets.all(
                        24,
                      ),
                      child: Column(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 32,
                            color: AppColors
                                .mutedForeground,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Could not load purchase details.',
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${snapshot.error}',
                            textAlign:
                                TextAlign.center,
                            style:
                                const TextStyle(
                              fontSize: 11.5,
                              color: AppColors
                                  .mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final items =
                      snapshot.data ??
                          const <OrderLineItem>[];

                  final total =
                      items.fold<double>(
                    0,
                    (
                      sum,
                      item,
                    ) =>
                        sum +
                        item.qty *
                            item.unitCost,
                  );

                  return SingleChildScrollView(
                    padding:
                        const EdgeInsets.all(
                      18,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Purchase Details',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 10),

                        _PurchaseDetailSummary(
                          order: order,
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Items Received',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${items.length} '
                              '${items.length == 1 ? 'item' : 'items'}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        if (items.isEmpty)
                          Container(
                            width:
                                double.infinity,
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              vertical: 26,
                            ),
                            decoration:
                                BoxDecoration(
                              color: AppColors
                                  .secondary,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                              border:
                                  Border.all(
                                color: AppColors
                                    .border,
                              ),
                            ),
                            child: const Center(
                              child: Text(
                                'No items logged for this purchase.',
                                style:
                                    TextStyle(
                                  color: AppColors
                                      .mutedForeground,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            decoration:
                                BoxDecoration(
                              color:
                                  AppColors.card,
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),
                              border:
                                  Border.all(
                                color:
                                    AppColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                for (var i = 0;
                                    i <
                                        items.length;
                                    i++) ...[
                                  if (i > 0)
                                    const Divider(
                                      height: 1,
                                    ),
                                  _PurchaseDetailItemRow(
                                    item:
                                        items[i],
                                  ),
                                ],
                              ],
                            ),
                          ),

                        const SizedBox(height: 14),

                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration:
                              BoxDecoration(
                            color: AppColors
                                .primary
                                .withValues(
                              alpha: 0.055,
                            ),
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            border:
                                Border.all(
                              color: AppColors
                                  .primary
                                  .withValues(
                                alpha: 0.18,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Purchase Total',
                                  style:
                                      TextStyle(
                                    fontSize: 12.5,
                                    fontWeight:
                                        FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '₱${total.toStringAsFixed(2)}',
                                style:
                                    const TextStyle(
                                  fontSize: 17,
                                  fontWeight:
                                      FontWeight.w800,
                                  color: AppColors
                                      .primary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Read-only purchase record. Closing this window keeps you on the Purchase History tab.',
                          style: TextStyle(
                            fontSize: 10.8,
                            height: 1.35,
                            color: AppColors
                                .mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                10,
              ),
              child: Align(
                alignment:
                    Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context)
                          .pop(),
                  child:
                      const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseDetailSummary
    extends StatelessWidget {
  final PurchaseOrder order;

  const _PurchaseDetailSummary({
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <
            620;

    final cards = [
      _PurchaseDetailInfoCard(
        label: 'Date received',
        value:
            _formatDate(
          order.receivedDate,
        ),
        icon:
            Icons.calendar_today_outlined,
      ),
      _PurchaseDetailInfoCard(
        label: 'Received by',
        value:
            order.receivedBy.trim().isEmpty
                ? 'Not specified'
                : order.receivedBy,
        icon:
            Icons.inventory_outlined,
      ),
      _PurchaseDetailInfoCard(
        label: 'Recorded by',
        value: order.buyerName,
        icon: Icons.person_outline,
      ),
    ];

    if (mobile) {
      return Column(
        children: [
          for (var i = 0;
              i < cards.length;
              i++) ...[
            if (i > 0)
              const SizedBox(height: 8),
            cards[i],
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        for (var i = 0;
            i < cards.length;
            i++) ...[
          if (i > 0)
            const SizedBox(width: 8),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

class _PurchaseDetailInfoCard
    extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _PurchaseDetailInfoCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 17,
            color:
                AppColors.mutedForeground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.8,
                    fontWeight:
                        FontWeight.w600,
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

class _PurchaseDetailItemRow
    extends StatelessWidget {
  final OrderLineItem item;

  const _PurchaseDetailItemRow({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <
            620;

    final subtotal =
        item.qty * item.unitCost;

    if (mobile) {
      return Padding(
        padding:
            const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              item.itemName,
              style: const TextStyle(
                fontSize: 12.8,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _PurchaseDetailMiniValue(
                  label: 'Quantity',
                  value:
                      '${formatQty(item.qty)} '
                      '${item.itemUom}',
                ),
                _PurchaseDetailMiniValue(
                  label: 'Unit cost',
                  value:
                      '₱${item.unitCost.toStringAsFixed(2)}',
                ),
                _PurchaseDetailMiniValue(
                  label: 'Subtotal',
                  value:
                      '₱${subtotal.toStringAsFixed(2)}',
                  strong: true,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              item.itemName,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              '${formatQty(item.qty)} '
              '${item.itemUom}',
              style:
                  const TextStyle(
                fontSize: 11.8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              '₱${item.unitCost.toStringAsFixed(2)}',
              style:
                  const TextStyle(
                fontSize: 11.8,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              '₱${subtotal.toStringAsFixed(2)}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11.8,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseDetailMiniValue
    extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _PurchaseDetailMiniValue({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 125,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.3,
              color:
                  AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            overflow:
                TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.8,
              fontWeight:
                  strong
                      ? FontWeight.w700
                      : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaLine
    extends StatelessWidget {
  final String label;
  final String value;

  const _MetaLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color:
                AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight:
                FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// COMMON SMALL WIDGETS
// =============================================================================

class _HeaderCell
    extends StatelessWidget {
  final String label;

  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          Alignment.centerLeft,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight:
              FontWeight.w700,
          color:
              AppColors.mutedForeground,
        ),
      ),
    );
  }
}

class _EmptyState
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 52,
        horizontal: 24,
      ),
      child: Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 34,
              color:
                  AppColors.mutedForeground,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color:
                    AppColors.mutedForeground,
              ),
            ),
            if (actionLabel != null &&
                onAction != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onAction,
                child:
                    Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _monthAbbrev = [
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

String _formatDate(DateTime date) {
  return '${_monthAbbrev[date.month - 1]} '
      '${date.day}, ${date.year}';
}
