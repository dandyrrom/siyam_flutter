import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/inventory_item.dart';
import '../../models/monthly_usage_report.dart';
import '../../models/replenishment_item.dart';
import '../../services/replenishment_service.dart';
import '../../services/report_service.dart';
import '../../state/data_bus.dart';
import '../../widgets/app_dropdown.dart';

// =============================================================================
// MANAGER REPORTS
// =============================================================================
//
// WBS / DOCUMENTATION ALIGNMENT
//
// 4.1 Monthly Usage Report
//   - Shows what inventory was used during a selected month.
//   - Separates normal usage from waste / expiry losses.
//   - Summary cards are interactive filters.
//   - Keeps loss-event count inside item details instead of duplicating it
//     in the top-level summary/table.
//   - Supports a top-level inventory category filter.
//
// 4.3 Reorder Point with Safety Stock Calculations
//   - Reuses the SAME ReplenishmentService used by Staff.
//   - Main table stays simple and operational.
//   - Complete calculation details remain available on demand.
//
// 4.2 Audit Trail remains on its separate /audit-trail page.
//
// UX PRINCIPLE
//   Show the manager what they need to decide first.
//   Keep technical calculation details available, but not in the main table.
//
// DISPLAY RULE
//   Report quantities are DISPLAYED with at most 2 decimal places.
//   Stored values/calculations keep their original precision.
// =============================================================================

enum _ReportTab {
  monthlyUsage,
  ropStatus,
}

enum _UsageFocus {
  all,
  itemsUsed,
  usageEvents,
  itemsWithLosses,
}

enum _RopFocus {
  all,
  critical,
  high,
  custom,
}

class ManagerReportsPage extends StatefulWidget {
  const ManagerReportsPage({super.key});

  @override
  State<ManagerReportsPage> createState() =>
      _ManagerReportsPageState();
}

class _ManagerReportsPageState extends State<ManagerReportsPage>
    with DataBusRefreshMixin<ManagerReportsPage> {
  final ReportService _reportService = ReportService();
  final ReplenishmentService _replenishmentService =
      ReplenishmentService();

  final _usageSearchCtrl = TextEditingController();
  final _ropSearchCtrl = TextEditingController();

  _ReportTab _tab = _ReportTab.monthlyUsage;
  _UsageFocus _usageFocus = _UsageFocus.all;
  _RopFocus _ropFocus = _RopFocus.all;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  MonthlyUsageReport? _monthlyUsage;
  List<ReplenishmentItem> _ropRows = [];

  bool _loading = true;
  String? _error;

  String _usageSearch = '';
  String _ropSearch = '';

  // Top-level category only (e.g. Medical, Food).
  //
  // We intentionally use pCategoryName instead of itemCategory so selecting
  // Medical also includes Medical > Tablets, Medical > Vaccine, etc.
  String? _usageCategoryFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _usageSearchCtrl.dispose();
    _ropSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void onExternalDataChanged() {
    _load(silent: true);
  }

  // ===========================================================================
  // LOAD
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
      final results = await Future.wait<Object?>([
        _reportService.fetchMonthlyUsage(
          _selectedMonth,
        ),
        _replenishmentService.fetchReplenishmentItems(),
      ]);

      if (!mounted) return;

      setState(() {
        _monthlyUsage =
            results[0] as MonthlyUsageReport;

        _ropRows =
            results[1] as List<ReplenishmentItem>;

        // If a category disappears from the newly loaded month, return to All.
        if (_usageCategoryFilter != null &&
            !_usageCategoryOptions.contains(
              _usageCategoryFilter,
            )) {
          _usageCategoryFilter = null;
        }

        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error = 'Could not load reports: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _changeMonth(
    DateTime month,
  ) async {
    setState(() {
      _selectedMonth = month;
      _usageFocus = _UsageFocus.all;
      _usageCategoryFilter = null;
      _loading = true;
      _error = null;
    });

    try {
      final report =
          await _reportService.fetchMonthlyUsage(
        month,
      );

      if (!mounted) return;

      setState(() {
        _monthlyUsage = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not load monthly usage: $e';
        _loading = false;
      });
    }
  }

  // ===========================================================================
  // MONTHLY USAGE FILTERS
  // ===========================================================================

  List<String> get _usageCategoryOptions {
    final report = _monthlyUsage;

    if (report == null) {
      return const [];
    }

    final categories = <String>{};

    for (final row in report.rows) {
      final category =
          row.item.pCategoryName.trim();

      if (category.isNotEmpty) {
        categories.add(category);
      }
    }

    final values = categories.toList()
      ..sort(
        (a, b) =>
            a.toLowerCase().compareTo(
                  b.toLowerCase(),
                ),
      );

    return values;
  }

  List<MonthlyUsageRow> get _filteredUsageRows {
    final report = _monthlyUsage;

    if (report == null) {
      return const [];
    }

    final query =
        _usageSearch.trim().toLowerCase();

    final rows = report.rows.where((row) {
      final matchesSearch =
          query.isEmpty ||
          row.item.itemName
              .toLowerCase()
              .contains(query) ||
          row.item.itemCategory
              .toLowerCase()
              .contains(query);

      final matchesCategory =
          _usageCategoryFilter == null ||
          row.item.pCategoryName ==
              _usageCategoryFilter;

      if (!matchesSearch ||
          !matchesCategory) {
        return false;
      }

      if (_usageFocus == _UsageFocus.itemsUsed) {
        return row.usedQty > 0;
      }

      if (_usageFocus == _UsageFocus.usageEvents) {
        return row.usageEvents > 0;
      }

      if (_usageFocus == _UsageFocus.itemsWithLosses) {
        return row.lossQty > 0;
      }

      return true;
    }).toList();

    if (_usageFocus == _UsageFocus.itemsUsed) {
      rows.sort(
        (a, b) => b.usedQty.compareTo(a.usedQty),
      );
    } else if (_usageFocus == _UsageFocus.usageEvents) {
      rows.sort((a, b) {
        final byEvents =
            b.usageEvents.compareTo(a.usageEvents);

        if (byEvents != 0) {
          return byEvents;
        }

        return b.usedQty.compareTo(a.usedQty);
      });
    } else if (_usageFocus == _UsageFocus.itemsWithLosses) {
      rows.sort(
        (a, b) => b.lossQty.compareTo(a.lossQty),
      );
    }

    return rows;
  }

  String get _usageFocusLabel {
    String focusLabel;

    if (_usageFocus == _UsageFocus.itemsUsed) {
      focusLabel = 'Items used';
    } else if (_usageFocus ==
        _UsageFocus.usageEvents) {
      focusLabel = 'Usage records';
    } else if (_usageFocus ==
        _UsageFocus.itemsWithLosses) {
      focusLabel = 'Items with losses';
    } else {
      focusLabel = 'All activity';
    }

    if (_usageCategoryFilter == null) {
      return focusLabel;
    }

    return '$focusLabel • $_usageCategoryFilter';
  }

  void _selectUsageFocus(
    _UsageFocus focus,
  ) {
    setState(() {
      _usageFocus =
          _usageFocus == focus
              ? _UsageFocus.all
              : focus;
    });
  }

  void _clearUsageSearch() {
    _usageSearchCtrl.clear();

    setState(() {
      _usageSearch = '';
    });
  }

  void _clearUsageFilters() {
    _usageSearchCtrl.clear();

    setState(() {
      _usageSearch = '';
      _usageFocus = _UsageFocus.all;
      _usageCategoryFilter = null;
    });
  }

  // ===========================================================================
  // ROP FILTERS
  // ===========================================================================

  List<ReplenishmentItem> get _filteredRopRows {
    final query =
        _ropSearch.trim().toLowerCase();

    return _ropRows.where((row) {
      final matchesSearch =
          query.isEmpty ||
          row.item.itemName
              .toLowerCase()
              .contains(query) ||
          row.item.itemCategory
              .toLowerCase()
              .contains(query);

      if (!matchesSearch) {
        return false;
      }

      if (_ropFocus == _RopFocus.critical) {
        return row.priority ==
            ReplenishmentPriority.critical;
      }

      if (_ropFocus == _RopFocus.high) {
        return row.priority ==
            ReplenishmentPriority.high;
      }

      if (_ropFocus == _RopFocus.custom) {
        return row.usesCustomRop;
      }

      return true;
    }).toList();
  }

  String get _ropFocusLabel {
    if (_ropFocus == _RopFocus.critical) {
      return 'Critical items';
    }

    if (_ropFocus == _RopFocus.high) {
      return 'High-priority items';
    }

    if (_ropFocus == _RopFocus.custom) {
      return 'Custom ROP items';
    }

    return 'All replenishment needs';
  }

  void _selectRopFocus(
    _RopFocus focus,
  ) {
    setState(() {
      _ropFocus =
          _ropFocus == focus
              ? _RopFocus.all
              : focus;
    });
  }

  void _clearRopSearch() {
    _ropSearchCtrl.clear();

    setState(() {
      _ropSearch = '';
    });
  }

  void _clearRopFilters() {
    _ropSearchCtrl.clear();

    setState(() {
      _ropSearch = '';
      _ropFocus = _RopFocus.all;
    });
  }

  // ===========================================================================
  // PAGE
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(
                Icons.refresh,
                size: 17,
              ),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        const Text(
          'Review shelter inventory usage, losses, and current replenishment needs.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),

        const SizedBox(height: 18),

        _buildTabs(),

        const SizedBox(height: 20),

        if (_tab == _ReportTab.monthlyUsage)
          _buildMonthlyUsage()
        else
          _buildRopStatus(),
      ],
    );
  }

  Widget _buildTabs() {
    return Align(
      alignment: Alignment.centerLeft,
      child: SegmentedButton<_ReportTab>(
        segments: const [
          ButtonSegment(
            value: _ReportTab.monthlyUsage,
            icon: Icon(
              Icons.calendar_month_outlined,
              size: 18,
            ),
            label: Text('Monthly Usage'),
          ),
          ButtonSegment(
            value: _ReportTab.ropStatus,
            icon: Icon(
              Icons.inventory_2_outlined,
              size: 18,
            ),
            label: Text('ROP Status'),
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
  // 4.1 MONTHLY USAGE
  // ===========================================================================

  Widget _buildMonthlyUsage() {
    final report = _monthlyUsage!;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildMonthAndSearch(),

        const SizedBox(height: 16),

        _EqualSummaryCards(
          cards: [
            _InteractiveSummaryCard(
              icon: Icons.inventory_outlined,
              value: '${report.itemsUsed}',
              label: 'Items Used',
              helper: 'Items consumed this month',
              selected:
                  _usageFocus == _UsageFocus.itemsUsed,
              onTap: () => _selectUsageFocus(
                _UsageFocus.itemsUsed,
              ),
            ),
            _InteractiveSummaryCard(
              icon: Icons.swap_vert_rounded,
              value: '${report.usageEvents}',
              label: 'Usage Records',
              helper: 'Times stock use was recorded',
              selected:
                  _usageFocus == _UsageFocus.usageEvents,
              onTap: () => _selectUsageFocus(
                _UsageFocus.usageEvents,
              ),
            ),
            _InteractiveSummaryCard(
              icon: Icons.warning_amber_outlined,
              value: '${report.itemsWithLosses}',
              label: 'Items With Losses',
              helper: 'Items with waste or expiry',
              selected:
                  _usageFocus ==
                  _UsageFocus.itemsWithLosses,
              onTap: () => _selectUsageFocus(
                _UsageFocus.itemsWithLosses,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        _ActiveFilterBar(
          label: _usageFocusLabel,
          active:
              _usageFocus != _UsageFocus.all ||
              _usageSearch.isNotEmpty ||
              _usageCategoryFilter != null,
          onClear: _clearUsageFilters,
        ),

        const SizedBox(height: 14),

        _buildUsageList(),
      ],
    );
  }

  // UI ORDER MARKER: REPORTS_SEARCH_LEFT_V2
  Widget _buildMonthAndSearch() {
    final narrow =
        MediaQuery.sizeOf(context).width < 850;

    final monthPicker =
        AppDropdown<DateTime>(
      label: _monthYear(
        _selectedMonth,
      ),
      options: [
        for (final month
            in _monthOptions())
          AppDropdownOption(
            month,
            _monthYear(month),
          ),
      ],
      onSelect: (month) {
        if (month !=
            _selectedMonth) {
          _changeMonth(month);
        }
      },
      expand: narrow,
    );

    final categoryPicker =
        AppDropdown<String?>(
      label:
          _usageCategoryFilter ??
          'All Categories',
      options: [
        const AppDropdownOption<
            String?>(
          null,
          'All Categories',
        ),
        for (final category
            in _usageCategoryOptions)
          AppDropdownOption<String?>(
            category,
            category,
          ),
      ],
      onSelect: (category) {
        setState(() {
          _usageCategoryFilter =
              category;
        });
      },
      expand: narrow,
    );

    final search = TextField(
      controller: _usageSearchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(
          Icons.search,
          size: 18,
        ),
        suffixIcon:
            _usageSearch.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: _clearUsageSearch,
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                    ),
                  ),
        hintText: 'Search item or category',
      ),
      onChanged: (value) {
        setState(() {
          _usageSearch = value;
        });
      },
    );

    if (narrow) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: 10),
          monthPicker,
          const SizedBox(height: 10),
          categoryPicker,
        ],
      );
    }

    // Desktop order is explicitly forced left-to-right:
    //
    // [ SEARCH................................ ] [ MONTH ] [ CATEGORY ]
    //
    // Search is the FIRST child and therefore stays on the far LEFT.
    // The two compact filters are grouped together on the RIGHT.
    return Row(
      textDirection: TextDirection.ltr,
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Expanded(
          child: search,
        ),
        const SizedBox(width: 12),
        Row(
          mainAxisSize:
              MainAxisSize.min,
          textDirection:
              TextDirection.ltr,
          children: [
            SizedBox(
              width: 220,
              child: monthPicker,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 210,
              child: categoryPicker,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUsageList() {
    final rows = _filteredUsageRows;

    if (_monthlyUsage!.rows.isEmpty) {
      return const _EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No usage recorded',
        message:
            'There are no inventory usage or loss records for this month.',
      );
    }

    if (rows.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off,
        title: 'No matching records',
        message:
            'Try another search, category, or clear the selected summary filter.',
        actionLabel: 'Clear Filters',
        onAction: _clearUsageFilters,
      );
    }

    final mobile =
        MediaQuery.sizeOf(context).width < 980;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          if (!mobile)
            const _UsageHeader(),

          if (!mobile)
            const Divider(height: 1),

          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1),

            if (mobile)
              _UsageMobileRow(
                row: rows[i],
                onTap: () => _showUsageDetails(
                  rows[i],
                ),
              )
            else
              _UsageDesktopRow(
                row: rows[i],
                onTap: () => _showUsageDetails(
                  rows[i],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _showUsageDetails(
    MonthlyUsageRow row,
  ) async {
    final unit =
        row.item.purchaseUnitAbbr;

    final totalMoved =
        row.usedQty + row.lossQty;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding:
              const EdgeInsets.fromLTRB(
            22,
            20,
            22,
            0,
          ),
          contentPadding:
              const EdgeInsets.fromLTRB(
            22,
            14,
            22,
            8,
          ),
          title: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                row.item.itemName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _InfoPill(
                    icon: Icons.category_outlined,
                    label: row.item.itemCategory,
                  ),
                  _InfoPill(
                    icon: Icons.calendar_month_outlined,
                    label: _monthYear(
                      _selectedMonth,
                    ),
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 540,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),

                  // -----------------------------------------------------------
                  // BIG, EASY-TO-READ MONTHLY NUMBERS
                  // -----------------------------------------------------------

                  Row(
                    children: [
                      Expanded(
                        child: _UsageMetricCard(
                          icon:
                              Icons.inventory_outlined,
                          label: 'Used this month',
                          value: _qty(
                            row.usedQty,
                            unit,
                          ),
                          helper:
                              'Stock used for treatments or normal dispensing.',
                          accent:
                              AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _UsageMetricCard(
                          icon:
                              Icons.delete_outline,
                          label: 'Lost this month',
                          value: _qty(
                            row.lossQty,
                            unit,
                          ),
                          helper:
                              'Stock removed because it expired or was wasted.',
                          accent:
                              AppColors.stockOut,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // -----------------------------------------------------------
                  // SIMPLE ACTIVITY VISUAL
                  // -----------------------------------------------------------

                  const _DialogSectionTitle(
                    'Monthly Stock Movement',
                  ),

                  const SizedBox(height: 3),

                  Text(
                    totalMoved <= 0
                        ? 'No stock movement was recorded for this item during the selected month.'
                        : 'This shows how the recorded stock movement was split between normal use and losses.',
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color:
                          AppColors.mutedForeground,
                    ),
                  ),

                  const SizedBox(height: 10),

                  _StockMovementBar(
                    usedQty: row.usedQty,
                    lossQty: row.lossQty,
                    unit: unit,
                  ),

                  const SizedBox(height: 18),

                  // -----------------------------------------------------------
                  // RECORD COUNTS, WITH BASIC ENGLISH EXPLANATIONS
                  // -----------------------------------------------------------

                  const _DialogSectionTitle(
                    'Recorded Activity',
                  ),

                  _ExplainedCountRow(
                    icon:
                        Icons.medical_services_outlined,
                    label: 'Usage records',
                    value: '${row.usageEvents}',
                    explanation:
                        'How many times this item was recorded as used.',
                    accent: AppColors.primary,
                  ),

                  const SizedBox(height: 8),

                  _ExplainedCountRow(
                    icon:
                        Icons.warning_amber_outlined,
                    label: 'Loss records',
                    value: '${row.lossEvents}',
                    explanation:
                        'How many times stock was removed because it expired or was wasted.',
                    accent: AppColors.stockOut,
                  ),

                  const SizedBox(height: 18),

                  // -----------------------------------------------------------
                  // PLAIN-ENGLISH DEFINITIONS
                  // -----------------------------------------------------------

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: AppColors.secondary,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'What do these numbers mean?',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight:
                                    FontWeight.w700,
                                color:
                                    AppColors.foreground,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Used means stock that was consumed in treatments or normal dispensing. '
                          'Lost means stock that was removed because it expired or was wasted. '
                          'Inventory adjustments are not counted as usage or losses.',
                          style: TextStyle(
                            fontSize: 11.8,
                            height: 1.45,
                            color:
                                AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    'All quantities are shown in the item\'s purchase unit ($unit).',
                    style: const TextStyle(
                      fontSize: 11,
                      color:
                          AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actionsPadding:
              const EdgeInsets.fromLTRB(
            18,
            0,
            18,
            14,
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(
                dialogContext,
              ).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // 4.3 ROP STATUS
  // ===========================================================================

  Widget _buildRopStatus() {
    final critical =
        _ropRows
            .where(
              (row) =>
                  row.priority ==
                  ReplenishmentPriority.critical,
            )
            .length;

    final high =
        _ropRows
            .where(
              (row) =>
                  row.priority ==
                  ReplenishmentPriority.high,
            )
            .length;

    final custom =
        _ropRows
            .where(
              (row) => row.usesCustomRop,
            )
            .length;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _EqualSummaryCards(
          cards: [
            _InteractiveSummaryCard(
              icon: Icons.inventory_2_outlined,
              value: '${_ropRows.length}',
              label: 'Needs Replenishment',
              helper: 'At or below current ROP',
              selected:
                  _ropFocus == _RopFocus.all,
              onTap: () {
                setState(() {
                  _ropFocus = _RopFocus.all;
                });
              },
            ),
            _InteractiveSummaryCard(
              icon:
                  Icons.warning_amber_rounded,
              value: '$critical',
              label: 'Critical',
              helper: 'No usable stock remaining',
              selected:
                  _ropFocus == _RopFocus.critical,
              onTap: () => _selectRopFocus(
                _RopFocus.critical,
              ),
            ),
            _InteractiveSummaryCard(
              icon:
                  Icons.priority_high_rounded,
              value: '$high',
              label: 'High Priority',
              helper: 'Requires closer attention',
              selected:
                  _ropFocus == _RopFocus.high,
              onTap: () => _selectRopFocus(
                _RopFocus.high,
              ),
            ),
            _InteractiveSummaryCard(
              icon: Icons.tune_outlined,
              value: '$custom',
              label: 'Custom ROP',
              helper:
                  'Using item-specific settings',
              selected:
                  _ropFocus == _RopFocus.custom,
              onTap: () => _selectRopFocus(
                _RopFocus.custom,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        TextField(
          controller: _ropSearchCtrl,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(
              Icons.search,
              size: 18,
            ),
            suffixIcon:
                _ropSearch.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearRopSearch,
                        icon: const Icon(
                          Icons.close,
                          size: 18,
                        ),
                      ),
            hintText: 'Search item or category',
          ),
          onChanged: (value) {
            setState(() {
              _ropSearch = value;
            });
          },
        ),

        const SizedBox(height: 14),

        _ActiveFilterBar(
          label: _ropFocusLabel,
          active:
              _ropFocus != _RopFocus.all ||
              _ropSearch.isNotEmpty,
          onClear: _clearRopFilters,
        ),

        const SizedBox(height: 14),

        _buildRopList(),
      ],
    );
  }

  Widget _buildRopList() {
    final rows = _filteredRopRows;

    if (_ropRows.isEmpty) {
      return const _EmptyState(
        icon: Icons.check_circle_outline,
        title: 'No replenishment needed',
        message:
            'All items are currently above their reorder points.',
      );
    }

    if (rows.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off,
        title: 'No matching items',
        message:
            'Try another search or clear the selected summary filter.',
        actionLabel: 'Clear Filters',
        onAction: _clearRopFilters,
      );
    }

    final mobile =
        MediaQuery.sizeOf(context).width < 1050;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          if (!mobile)
            const _RopHeader(),

          if (!mobile)
            const Divider(height: 1),

          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1),

            if (mobile)
              _RopMobileRow(
                row: rows[i],
                onDetails: () => _showRopDetails(
                  rows[i],
                ),
              )
            else
              _RopDesktopRow(
                row: rows[i],
                onDetails: () => _showRopDetails(
                  rows[i],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRopDetails(
    ReplenishmentItem row,
  ) async {
    final unit =
        row.item.purchaseUnitAbbr;

    final rawRop =
        (row.averageDailyUsage *
                row.leadTimeDays) +
            row.safetyStockQty;

    final stockCoverDays =
        row.averageDailyUsage > 0
            ? row.currentStockPurchaseUnits /
                row.averageDailyUsage
            : null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding:
              const EdgeInsets.fromLTRB(
            22,
            20,
            22,
            0,
          ),
          contentPadding:
              const EdgeInsets.fromLTRB(
            22,
            16,
            22,
            8,
          ),
          title: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.item.itemName,
                    ),

                    const SizedBox(height: 3),

                    Text(
                      row.item.itemCategory,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            FontWeight.w400,
                        color:
                            AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              _PriorityBadge(
                priority: row.priority,
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  // -----------------------------------------------------------
                  // CURRENT SITUATION
                  // -----------------------------------------------------------

                  const _DialogSectionTitle(
                    'Current Situation',
                  ),

                  _DetailLine(
                    label: 'Current stock',
                    value: _qty(
                      row.currentStockPurchaseUnits,
                      unit,
                    ),
                    strong: true,
                  ),

                  _DetailLine(
                    label:
                        'Used in last 30 days',
                    value: _qty(
                      row.usage30PurchaseUnits,
                      unit,
                    ),
                  ),

                  _DetailLine(
                    label: 'Reorder point',
                    value: _qty(
                      row.reorderPoint,
                      unit,
                    ),
                    strong: true,
                  ),

                  if (stockCoverDays != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(
                        top: 5,
                      ),
                      child: Text(
                        'At the recent usage rate, current stock represents about '
                        '${_reportQtyNumber(stockCoverDays)} days of supply.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color:
                              AppColors.mutedForeground,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // -----------------------------------------------------------
                  // RECOMMENDED ACTION
                  // -----------------------------------------------------------

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(
                        alpha: 0.07,
                      ),
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary
                            .withValues(
                          alpha: 0.22,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recommended Action',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Replenish ${_qty(row.suggestedQty, unit)}',
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 4),
                        Text(
                          row.currentStockPurchaseUnits <= 0
                              ? 'This item has no usable stock remaining. '
                                  'Replenish it to restore stock to the recommended level.'
                              : 'Current stock is at or below the reorder point. '
                                  'The suggested quantity brings stock back to the recommended level.',
                          style: const TextStyle(
                            fontSize: 11.8,
                            height: 1.4,
                            color:
                                AppColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // -----------------------------------------------------------
                  // ROP SETTINGS
                  // -----------------------------------------------------------

                  const _DialogSectionTitle(
                    'ROP Settings',
                  ),

                  _DetailLine(
                    label: 'Lead time',
                    value:
                        '${row.leadTimeDays} days',
                  ),

                  _DetailLine(
                    label: 'Safety stock',
                    value: _qty(
                      row.safetyStockQty,
                      unit,
                    ),
                  ),

                  _DetailLine(
                    label: 'Settings',
                    value:
                        row.usesCustomRop
                            ? 'Custom'
                            : 'System default',
                  ),

                  const SizedBox(height: 8),

                  // -----------------------------------------------------------
                  // OPTIONAL EXPLANATION
                  // -----------------------------------------------------------

                  Theme(
                    data: Theme.of(dialogContext).copyWith(
                      dividerColor:
                          Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding:
                          const EdgeInsets.only(
                        bottom: 4,
                      ),
                      title: const Text(
                        'How was this calculated?',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight:
                              FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'View the ROP formula and usage rate.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color:
                              AppColors.mutedForeground,
                        ),
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(
                            12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                AppColors.secondary,
                            borderRadius:
                                BorderRadius.circular(
                              12,
                            ),
                            border: Border.all(
                              color:
                                  AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              _DetailLine(
                                label: 'ADU',
                                value:
                                    '${_reportQtyNumber(row.averageDailyUsage)} $unit/day',
                              ),

                              const SizedBox(
                                height: 4,
                              ),

                              const Text(
                                'ROP = (Average Daily Usage × Lead Time) + Safety Stock',
                                style: TextStyle(
                                  fontSize: 11.8,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),

                              const SizedBox(
                                height: 5,
                              ),

                              Text(
                                '(${_reportQtyNumber(row.averageDailyUsage)} × '
                                '${row.leadTimeDays}) + '
                                '${_reportQtyNumber(row.safetyStockQty)} '
                                '= ${_reportQtyNumber(rawRop)} $unit',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors
                                      .mutedForeground,
                                ),
                              ),

                              const SizedBox(
                                height: 8,
                              ),

                              Text(
                                'The calculated value is rounded up to '
                                '${_reportQtyNumber(row.reorderPoint)} $unit so the reorder point '
                                'uses a practical whole purchase quantity.',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  height: 1.4,
                                  color: AppColors
                                      .mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(
                dialogContext,
              ).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  List<DateTime> _monthOptions() {
    final now = DateTime.now();

    return [
      for (var i = 0; i < 12; i++)
        DateTime(
          now.year,
          now.month - i,
          1,
        ),
    ];
  }
}

// =============================================================================
// EQUAL INTERACTIVE SUMMARY CARDS
// =============================================================================

class _EqualSummaryCards
    extends StatelessWidget {
  final List<Widget> cards;

  const _EqualSummaryCards({
    required this.cards,
  });

  Widget _row(
    List<Widget> children,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        for (var i = 0;
            i < children.length;
            i++) ...[
          if (i > 0)
            const SizedBox(width: 12),

          Expanded(
            child: SizedBox(
              height: 118,
              child: children[i],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context).width;

    if (width < 650) {
      return Column(
        children: [
          for (var i = 0;
              i < cards.length;
              i++) ...[
            if (i > 0)
              const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 112,
              child: cards[i],
            ),
          ],
        ],
      );
    }

    if (width < 1120) {
      return Column(
        children: [
          _row(
            cards.take(2).toList(),
          ),
          const SizedBox(height: 12),
          _row(
            cards.skip(2).toList(),
          ),
        ],
      );
    }

    return _row(cards);
  }
}

class _InteractiveSummaryCard
    extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String helper;
  final bool selected;
  final VoidCallback onTap;

  const _InteractiveSummaryCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.helper,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius:
          BorderRadius.circular(16),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: onTap,
        hoverColor: AppColors.primary
            .withValues(
          alpha: 0.04,
        ),
        child: AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 140,
          ),
          width: double.infinity,
          height: double.infinity,
          padding:
              const EdgeInsets.all(15),
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
              width: selected ? 1.5 : 1,
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
                  color: AppColors.primary
                      .withValues(
                    alpha: selected
                        ? 0.14
                        : 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 19,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    Text(
                      label,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Expanded(
                      child: Text(
                        helper,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.3,
                          height: 1.25,
                          color: AppColors
                              .mutedForeground,
                        ),
                      ),
                    ),

                    Text(
                      selected
                          ? 'Selected'
                          : 'Click to filter',
                      style: TextStyle(
                        fontSize: 10.5,
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
    );
  }
}

// =============================================================================
// ACTIVE FILTER BAR
// =============================================================================

class _ActiveFilterBar
    extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onClear;

  const _ActiveFilterBar({
    required this.label,
    required this.active,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            active
                ? 'Showing: $label'
                : label,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors
                  .mutedForeground,
            ),
          ),
        ),

        if (active)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(
              Icons.filter_alt_off_outlined,
              size: 16,
            ),
            label:
                const Text('Clear Filters'),
          ),
      ],
    );
  }
}

// =============================================================================
// MONTHLY USAGE TABLE
// =============================================================================

class _UsageHeader
    extends StatelessWidget {
  const _UsageHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: _HeaderCell('Item'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 3,
            child:
                _HeaderCell('Category'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _HeaderCell('Used'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child:
                _HeaderCell('Usage Records'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child:
                _HeaderCell('Lost'),
          ),
          SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _UsageDesktopRow
    extends StatelessWidget {
  final MonthlyUsageRow row;
  final VoidCallback onTap;

  const _UsageDesktopRow({
    required this.row,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unit =
        row.item.purchaseUnitAbbr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.primary
            .withValues(
          alpha: 0.035,
        ),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  row.item.itemName,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                flex: 3,
                child: Text(
                  row.item.itemCategory,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                flex: 2,
                child: Text(
                  _qty(
                    row.usedQty,
                    unit,
                  ),
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                flex: 2,
                child: Text(
                  '${row.usageEvents}',
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                flex: 2,
                child: Text(
                  _qty(
                    row.lossQty,
                    unit,
                  ),
                ),
              ),

              const SizedBox(width: 6),

              const Icon(
                Icons.chevron_right,
                size: 18,
                color:
                    AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageMobileRow
    extends StatelessWidget {
  final MonthlyUsageRow row;
  final VoidCallback onTap;

  const _UsageMobileRow({
    required this.row,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final unit =
        row.item.purchaseUnitAbbr;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.item.itemName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),

                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors
                        .mutedForeground,
                  ),
                ],
              ),

              const SizedBox(height: 2),

              Text(
                row.item.itemCategory,
                style: const TextStyle(
                  fontSize: 11.5,
                  color:
                      AppColors.mutedForeground,
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 18,
                runSpacing: 8,
                children: [
                  _MiniMetric(
                    label: 'Used',
                    value: _qty(
                      row.usedQty,
                      unit,
                    ),
                  ),
                  _MiniMetric(
                    label: 'Usage Records',
                    value:
                        '${row.usageEvents}',
                  ),
                  _MiniMetric(
                    label: 'Lost',
                    value: _qty(
                      row.lossQty,
                      unit,
                    ),
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

// =============================================================================
// ROP TABLE
// =============================================================================

class _RopHeader
    extends StatelessWidget {
  const _RopHeader();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
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
            width: 90,
            child:
                _HeaderCell('Priority'),
          ),
          SizedBox(width: 12),
          SizedBox(width: 72),
        ],
      ),
    );
  }
}

class _RopDesktopRow
    extends StatelessWidget {
  final ReplenishmentItem row;
  final VoidCallback onDetails;

  const _RopDesktopRow({
    required this.row,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final unit =
        row.item.purchaseUnitAbbr;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  row.item.itemName,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 3),

                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment:
                      WrapCrossAlignment.center,
                  children: [
                    Text(
                      row.item.itemCategory,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                    _SettingsBadge(
                      custom:
                          row.usesCustomRop,
                    ),
                  ],
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
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 2,
            child: Text(
              _qty(
                row.reorderPoint,
                unit,
              ),
              style: const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            flex: 2,
            child: Text(
              _qty(
                row.suggestedQty,
                unit,
              ),
              style: const TextStyle(
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(width: 12),

          SizedBox(
            width: 90,
            child: _PriorityBadge(
              priority: row.priority,
            ),
          ),

          const SizedBox(width: 12),

          SizedBox(
            width: 72,
            child: TextButton(
              onPressed: onDetails,
              child: const Text('Details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RopMobileRow
    extends StatelessWidget {
  final ReplenishmentItem row;
  final VoidCallback onDetails;

  const _RopMobileRow({
    required this.row,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final unit =
        row.item.purchaseUnitAbbr;

    return Padding(
      padding:
          const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.item.itemName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),

              _PriorityBadge(
                priority: row.priority,
              ),
            ],
          ),

          const SizedBox(height: 4),

          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                row.item.itemCategory,
                style: const TextStyle(
                  fontSize: 11.5,
                  color:
                      AppColors.mutedForeground,
                ),
              ),
              _SettingsBadge(
                custom:
                    row.usesCustomRop,
              ),
            ],
          ),

          const SizedBox(height: 10),

          Wrap(
            spacing: 18,
            runSpacing: 8,
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
                label: 'ROP',
                value: _qty(
                  row.reorderPoint,
                  unit,
                ),
              ),
              _MiniMetric(
                label: 'Suggested',
                value: _qty(
                  row.suggestedQty,
                  unit,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDetails,
              icon: const Icon(
                Icons.info_outline,
                size: 16,
              ),
              label:
                  const Text('Details'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsBadge
    extends StatelessWidget {
  final bool custom;

  const _SettingsBadge({
    required this.custom,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 2,
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
          fontSize: 10,
          fontWeight:
              FontWeight.w600,
          color: custom
              ? AppColors.primary
              : AppColors.mutedForeground,
        ),
      ),
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
    final (label, color) =
        _priorityMeta(priority);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight:
              FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

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

// =============================================================================
// MONTHLY USAGE DIALOG HELPERS
// =============================================================================

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: AppColors.mutedForeground,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final Color accent;

  const _UsageMetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 142,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(
          alpha: 0.065,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent.withValues(
            alpha: 0.24,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 17,
                  color: accent,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Text(
              helper,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.3,
                height: 1.35,
                color:
                    AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockMovementBar extends StatelessWidget {
  final double usedQty;
  final double lossQty;
  final String unit;

  const _StockMovementBar({
    required this.usedQty,
    required this.lossQty,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final total = usedQty + lossQty;

    final usedFraction =
        total <= 0 ? 0.0 : usedQty / total;

    final lossFraction =
        total <= 0 ? 0.0 : lossQty / total;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius:
              BorderRadius.circular(999),
          child: Container(
            height: 12,
            color: AppColors.border,
            child: total <= 0
                ? null
                : Row(
                    children: [
                      if (usedFraction > 0)
                        Expanded(
                          flex: (usedFraction * 1000)
                              .round()
                              .clamp(1, 1000),
                          child: Container(
                            color:
                                AppColors.primary,
                          ),
                        ),
                      if (lossFraction > 0)
                        Expanded(
                          flex: (lossFraction * 1000)
                              .round()
                              .clamp(1, 1000),
                          child: Container(
                            color:
                                AppColors.stockOut,
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 18,
          runSpacing: 7,
          children: [
            _LegendValue(
              color: AppColors.primary,
              label: 'Used',
              value:
                  '${_reportQtyNumber(usedQty)} $unit',
            ),
            _LegendValue(
              color: AppColors.stockOut,
              label: 'Lost',
              value:
                  '${_reportQtyNumber(lossQty)} $unit',
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendValue extends StatelessWidget {
  final Color color;
  final String label;
  final String value;

  const _LegendValue({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label  ',
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.mutedForeground,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: AppColors.foreground,
          ),
        ),
      ],
    );
  }
}

class _ExplainedCountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String explanation;
  final Color accent;

  const _ExplainedCountRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.explanation,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: 0.09,
              ),
              borderRadius:
                  BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 16,
              color: accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.3,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  explanation,
                  style: const TextStyle(
                    fontSize: 11.2,
                    height: 1.3,
                    color:
                        AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// COMMON
// =============================================================================

class _DialogSectionTitle
    extends StatelessWidget {
  final String text;

  const _DialogSectionTitle(
    this.text,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 5,
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight:
              FontWeight.w700,
        ),
      ),
    );
  }
}

class _HeaderCell
    extends StatelessWidget {
  final String label;

  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight:
            FontWeight.w700,
        color:
            AppColors.mutedForeground,
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
      width: 126,
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

class _DetailLine
    extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _DetailLine({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color:
                    AppColors.mutedForeground,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: strong
                    ? FontWeight.w700
                    : FontWeight.w500,
              ),
            ),
          ),
        ],
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
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 48,
      ),
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
          Icon(
            icon,
            size: 34,
            color:
                AppColors.mutedForeground,
          ),

          const SizedBox(height: 9),

          Text(
            title,
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            message,
            textAlign:
                TextAlign.center,
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
    );
  }
}

// =============================================================================
// REPORT QUANTITY DISPLAY
// =============================================================================
//
// Reports use at most 2 decimal places for readability.
//
// Examples:
// 41       -> 41
// 3.6      -> 3.6
// 0.333    -> 0.33
// 0.038    -> 0.04
// 0.017    -> 0.02
//
// Values smaller than 0.01 but greater than zero are shown as <0.01 rather
// than 0 so the report never visually turns real usage into "no usage".
//
// This is DISPLAY ONLY. No stored quantity or calculation is rounded.
// =============================================================================

String _reportQtyNumber(
  double value,
) {
  if (!value.isFinite) {
    return value.toString();
  }

  if (value == 0) {
    return '0';
  }

  if (value.abs() < 0.005) {
    return value.isNegative
        ? '>-0.01'
        : '<0.01';
  }

  final rounded =
      value.toStringAsFixed(2);

  return rounded
      .replaceFirst(
        RegExp(r'0+$'),
        '',
      )
      .replaceFirst(
        RegExp(r'\.$'),
        '',
      );
}

String _qty(
  double value,
  String unit,
) {
  return '${_reportQtyNumber(value)} $unit';
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _monthYear(
  DateTime date,
) {
  return '${_monthNames[date.month - 1]} ${date.year}';
}
