import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../models/monthly_usage_report.dart';
import '../../services/report_service.dart';
import '../../state/data_bus.dart';

// =============================================================================
// STAFF REPORTS - WBS 6.1 MONTHLY USAGE REPORT
// =============================================================================
//
// Staff sees only the operational information needed for day-to-day inventory
// work.
//
// INCLUDED
// - Month selector
// - Items Used
// - Usage Records
// - Items With Losses
// - Loss Records
// - Search
// - Interactive summary-card filters
// - Item / Category / Used / Usage Records / Lost / Loss Records
// - Read-only item details
// - Pagination
//
// NOT INCLUDED
// - ROP calculations / ROP configuration analytics
// - Manager settings
// - Audit Trail (to be handled separately later)
//
// REPORT RULES COME FROM ReportService:
// - Treatment consumption -> Used
// - Normal dispense -> Used
// - Waste / Expired -> Lost
// - Adjustment -> excluded
// - Quantities are normalized to the item's purchase unit
//
// CROSS-PLATFORM
// - Desktop/tablet: report table
// - Mobile/APK: stacked item cards
// - AppShell remains the page-level scroller
// =============================================================================

enum _UsageFocus {
  all,
  itemsUsed,
  usageRecords,
  itemsWithLosses,
  lossRecords,
}

class StaffReportsPage extends StatefulWidget {
  const StaffReportsPage({super.key});

  @override
  State<StaffReportsPage> createState() =>
      _StaffReportsPageState();
}

class _StaffReportsPageState extends State<StaffReportsPage>
    with DataBusRefreshMixin<StaffReportsPage> {
  final ReportService _service = ReportService();
  final TextEditingController _searchCtrl =
      TextEditingController();

  MonthlyUsageReport? _report;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  _UsageFocus _focus = _UsageFocus.all;

  bool _loading = true;
  String? _error;
  String _search = '';

  int _page = 0;

  static const int _pageSize = 15;

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
      final report =
          await _service.fetchMonthlyUsage(
        _selectedMonth,
      );

      if (!mounted) return;

      setState(() {
        _report = report;
        _loading = false;
        _error = null;

        if (_page >= _pageCount) {
          _page = _pageCount - 1;
        }

        if (_page < 0) {
          _page = 0;
        }
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error =
              'Could not load monthly usage report: $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _changeMonth(
    DateTime month,
  ) async {
    setState(() {
      _selectedMonth = DateTime(
        month.year,
        month.month,
        1,
      );
      _focus = _UsageFocus.all;
      _page = 0;
      _loading = true;
      _error = null;
    });

    try {
      final report =
          await _service.fetchMonthlyUsage(
        _selectedMonth,
      );

      if (!mounted) return;

      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not load monthly usage report: $e';
        _loading = false;
      });
    }
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================

  List<MonthlyUsageRow> get _filteredRows {
    final report = _report;

    if (report == null) {
      return const [];
    }

    final query =
        _search.trim().toLowerCase();

    final rows = report.rows.where((row) {
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

      switch (_focus) {
        case _UsageFocus.itemsUsed:
          return row.usedQty > 0;

        case _UsageFocus.usageRecords:
          return row.usageEvents > 0;

        case _UsageFocus.itemsWithLosses:
          return row.lossQty > 0;

        case _UsageFocus.lossRecords:
          return row.lossEvents > 0;

        case _UsageFocus.all:
          return true;
      }
    }).toList();

    switch (_focus) {
      case _UsageFocus.itemsUsed:
        rows.sort(
          (a, b) =>
              b.usedQty.compareTo(a.usedQty),
        );
        break;

      case _UsageFocus.usageRecords:
        rows.sort((a, b) {
          final byRecords =
              b.usageEvents.compareTo(
            a.usageEvents,
          );

          if (byRecords != 0) {
            return byRecords;
          }

          return b.usedQty.compareTo(
            a.usedQty,
          );
        });
        break;

      case _UsageFocus.itemsWithLosses:
        rows.sort(
          (a, b) =>
              b.lossQty.compareTo(a.lossQty),
        );
        break;

      case _UsageFocus.lossRecords:
        rows.sort((a, b) {
          final byRecords =
              b.lossEvents.compareTo(
            a.lossEvents,
          );

          if (byRecords != 0) {
            return byRecords;
          }

          return b.lossQty.compareTo(
            a.lossQty,
          );
        });
        break;

      case _UsageFocus.all:
        break;
    }

    return rows;
  }

  String get _focusLabel {
    switch (_focus) {
      case _UsageFocus.itemsUsed:
        return 'Items used';

      case _UsageFocus.usageRecords:
        return 'Usage records';

      case _UsageFocus.itemsWithLosses:
        return 'Items with losses';

      case _UsageFocus.lossRecords:
        return 'Loss records';

      case _UsageFocus.all:
        return 'All monthly activity';
    }
  }

  bool get _hasFilters =>
      _focus != _UsageFocus.all ||
      _search.isNotEmpty;

  void _selectFocus(
    _UsageFocus focus,
  ) {
    setState(() {
      _focus =
          _focus == focus
              ? _UsageFocus.all
              : focus;

      _page = 0;
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();

    setState(() {
      _search = '';
      _page = 0;
    });
  }

  void _clearFilters() {
    _searchCtrl.clear();

    setState(() {
      _search = '';
      _focus = _UsageFocus.all;
      _page = 0;
    });
  }

  // ===========================================================================
  // PAGINATION
  // ===========================================================================

  int get _pageCount {
    final count = _filteredRows.length;

    if (count == 0) {
      return 1;
    }

    return ((count - 1) ~/ _pageSize) + 1;
  }

  List<MonthlyUsageRow> get _pageRows {
    final rows = _filteredRows;

    if (rows.isEmpty) {
      return const [];
    }

    final safePage =
        _page.clamp(
      0,
      _pageCount - 1,
    );

    final start =
        safePage * _pageSize;

    final end =
        (start + _pageSize) > rows.length
            ? rows.length
            : start + _pageSize;

    return rows.sublist(
      start,
      end,
    );
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
                color:
                    AppColors.mutedForeground,
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

    final report = _report;

    if (report == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports',
          style: TextStyle(
            fontSize: 24,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        const Text(
          'Review monthly inventory use and stock losses recorded by the shelter.',
          style: TextStyle(
            fontSize: 13,
            color:
                AppColors.mutedForeground,
          ),
        ),

        const SizedBox(height: 18),

        _buildControls(),

        const SizedBox(height: 16),

        _SummaryGrid(
          cards: [
            _SummaryCard(
              icon:
                  Icons.inventory_2_outlined,
              value:
                  '${report.itemsUsed}',
              label: 'Items Used',
              helper:
                  'Different items used this month',
              selected:
                  _focus ==
                  _UsageFocus.itemsUsed,
              onTap: () =>
                  _selectFocus(
                _UsageFocus.itemsUsed,
              ),
            ),
            _SummaryCard(
              icon:
                  Icons.receipt_long_outlined,
              value:
                  '${report.usageEvents}',
              label: 'Usage Records',
              helper:
                  'Times stock use was recorded',
              selected:
                  _focus ==
                  _UsageFocus.usageRecords,
              onTap: () =>
                  _selectFocus(
                _UsageFocus.usageRecords,
              ),
            ),
            _SummaryCard(
              icon:
                  Icons.warning_amber_outlined,
              value:
                  '${report.itemsWithLosses}',
              label:
                  'Items With Losses',
              helper:
                  'Items that expired or were wasted',
              selected:
                  _focus ==
                  _UsageFocus.itemsWithLosses,
              onTap: () =>
                  _selectFocus(
                _UsageFocus.itemsWithLosses,
              ),
            ),
            _SummaryCard(
              icon:
                  Icons.delete_outline,
              value:
                  '${report.lossEvents}',
              label: 'Loss Records',
              helper:
                  'Times stock expired or was wasted',
              selected:
                  _focus ==
                  _UsageFocus.lossRecords,
              onTap: () =>
                  _selectFocus(
                _UsageFocus.lossRecords,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        _ActiveFilterBar(
          label: _focusLabel,
          active: _hasFilters,
          resultCount:
              _filteredRows.length,
          onClear:
              _clearFilters,
        ),

        const SizedBox(height: 12),

        _buildReportList(),

        if (_filteredRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildPagination(),
        ],

        const SizedBox(height: 14),

        const _ReportExplanation(),
      ],
    );
  }

  // ===========================================================================
  // CONTROLS
  // ===========================================================================

  Widget _buildControls() {
    final mobile =
        MediaQuery.sizeOf(context)
                .width <
            760;

    final monthPicker =
        _MonthPicker(
      selectedMonth:
          _selectedMonth,
      months:
          _monthOptions(),
      onSelected:
          _changeMonth,
    );

    final search = TextField(
      controller: _searchCtrl,
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: const Icon(
          Icons.search,
          size: 18,
        ),
        suffixIcon:
            _search.isEmpty
                ? null
                : IconButton(
                    tooltip:
                        'Clear search',
                    onPressed:
                        _clearSearch,
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                    ),
                  ),
        hintText:
            'Search item or category',
      ),
      onChanged: (value) {
        setState(() {
          _search = value;
          _page = 0;
        });
      },
    );

    if (mobile) {
      return Column(
        children: [
          monthPicker,
          const SizedBox(height: 10),
          search,
        ],
      );
    }

    return Row(
      children: [
        SizedBox(
          width: 230,
          child: monthPicker,
        ),
        const SizedBox(width: 12),
        Expanded(child: search),
      ],
    );
  }

  // ===========================================================================
  // REPORT LIST
  // ===========================================================================

  Widget _buildReportList() {
    final report = _report!;
    final rows = _pageRows;

    if (report.rows.isEmpty) {
      return const _EmptyState(
        icon:
            Icons.event_busy_outlined,
        title:
            'No monthly activity',
        message:
            'No inventory use or stock losses were recorded for this month.',
      );
    }

    if (rows.isEmpty) {
      return _EmptyState(
        icon: Icons.search_off,
        title:
            'No matching records',
        message:
            'Try another search or clear the selected filter.',
        actionLabel:
            'Clear Filters',
        onAction:
            _clearFilters,
      );
    }

    final mobile =
        MediaQuery.sizeOf(context)
                .width <
            980;

    return Container(
      width: double.infinity,
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
          if (!mobile)
            const _ReportHeader(),

          if (!mobile)
            const Divider(height: 1),

          for (var i = 0;
              i < rows.length;
              i++) ...[
            if (i > 0)
              const Divider(height: 1),

            if (mobile)
              _MobileReportRow(
                row: rows[i],
                onTap: () =>
                    _showItemDetails(
                  rows[i],
                ),
              )
            else
              _DesktopReportRow(
                row: rows[i],
                onTap: () =>
                    _showItemDetails(
                  rows[i],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // ITEM DETAILS
  // ===========================================================================

  Future<void> _showItemDetails(
    MonthlyUsageRow row,
  ) async {
    final unit =
        row.item.purchaseUnitAbbr;

    await showDialog<void>(
      context: context,
      builder: (
        dialogContext,
      ) {
        final screen =
            MediaQuery.sizeOf(
          dialogContext,
        );

        return Dialog(
          backgroundColor:
              Colors.white,
          surfaceTintColor:
              Colors.white,
          insetPadding:
              const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight:
                  screen.height * 0.82,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    20,
                    18,
                    12,
                    14,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(
                          color: AppColors
                              .primary
                              .withValues(
                            alpha: 0.09,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            11,
                          ),
                        ),
                        alignment:
                            Alignment.center,
                        child: const Icon(
                          Icons
                              .inventory_2_outlined,
                          size: 20,
                          color: AppColors
                              .primary,
                        ),
                      ),

                      const SizedBox(
                        width: 11,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              row.item
                                  .itemName,
                              style:
                                  const TextStyle(
                                fontSize:
                                    20,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),

                            const SizedBox(
                              height: 3,
                            ),

                            Text(
                              '${row.item.itemCategory} · ${_monthYear(_selectedMonth)}',
                              style:
                                  const TextStyle(
                                fontSize:
                                    11.8,
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
                            Navigator.of(
                          dialogContext,
                        ).pop(),
                        icon: const Icon(
                          Icons.close,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Flexible(
                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets
                            .all(
                      18,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child:
                                  _MetricBox(
                                label:
                                    'Used',
                                value:
                                    _qty(
                                  row.usedQty,
                                  unit,
                                ),
                                helper:
                                    'Stock consumed for treatments or normal dispensing.',
                                icon: Icons
                                    .inventory_outlined,
                                accent:
                                    AppColors.primary,
                              ),
                            ),

                            const SizedBox(
                              width: 10,
                            ),

                            Expanded(
                              child:
                                  _MetricBox(
                                label:
                                    'Lost',
                                value:
                                    _qty(
                                  row.lossQty,
                                  unit,
                                ),
                                helper:
                                    'Stock removed because it expired or was wasted.',
                                icon: Icons
                                    .delete_outline,
                                accent:
                                    AppColors.stockOut,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        const Text(
                          'Recorded Activity',
                          style:
                              TextStyle(
                            fontSize: 13,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        _DetailRow(
                          label:
                              'Usage records',
                          value:
                              '${row.usageEvents}',
                          explanation:
                              'How many times this item was recorded as used.',
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        _DetailRow(
                          label:
                              'Loss records',
                          value:
                              '${row.lossEvents}',
                          explanation:
                              'How many times stock was removed because it expired or was wasted.',
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        Container(
                          width:
                              double.infinity,
                          padding:
                              const EdgeInsets
                                  .all(
                            12,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                AppColors
                                    .secondary,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              12,
                            ),
                            border:
                                Border.all(
                              color:
                                  AppColors
                                      .border,
                            ),
                          ),
                          child: Text(
                            'All quantities are shown in the item\'s purchase unit ($unit). '
                            'Inventory adjustments are corrections, so they are not counted as use or loss.',
                            style:
                                const TextStyle(
                              fontSize:
                                  11.5,
                              height: 1.4,
                              color: AppColors
                                  .mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1),

                Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
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
                          Navigator.of(
                        dialogContext,
                      ).pop(),
                      child: const Text(
                        'Close',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // PAGINATION
  // ===========================================================================

  Widget _buildPagination() {
    final total =
        _filteredRows.length;

    final start =
        total == 0
            ? 0
            : (_page * _pageSize) + 1;

    final endCandidate =
        (_page + 1) * _pageSize;

    final end =
        endCandidate > total
            ? total
            : endCandidate;

    return Row(
      children: [
        Expanded(
          child: Text(
            '$start-$end of $total '
            '${total == 1 ? 'item' : 'items'}',
            style: const TextStyle(
              fontSize: 11.5,
              color:
                  AppColors.mutedForeground,
            ),
          ),
        ),

        TextButton(
          onPressed:
              _page <= 0
                  ? null
                  : () {
                      setState(() {
                        _page--;
                      });
                    },
          child:
              const Text('Previous'),
        ),

        const SizedBox(width: 4),

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: AppColors.primary
                .withValues(
              alpha: 0.09,
            ),
            borderRadius:
                BorderRadius.circular(
              999,
            ),
          ),
          child: Text(
            '${_page + 1} / $_pageCount',
            style: const TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.primary,
            ),
          ),
        ),

        const SizedBox(width: 4),

        TextButton(
          onPressed:
              _page >=
                      _pageCount - 1
                  ? null
                  : () {
                      setState(() {
                        _page++;
                      });
                    },
          child: const Text('Next'),
        ),
      ],
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
// MONTH PICKER
// =============================================================================

class _MonthPicker
    extends StatelessWidget {
  final DateTime selectedMonth;
  final List<DateTime> months;
  final ValueChanged<DateTime>
      onSelected;

  const _MonthPicker({
    required this.selectedMonth,
    required this.months,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DateTime>(
      tooltip: '',
      position:
          PopupMenuPosition.under,
      offset:
          const Offset(0, 4),
      color: Colors.white,
      surfaceTintColor:
          Colors.white,
      elevation: 7,
      onSelected: onSelected,
      itemBuilder: (
        menuContext,
      ) {
        return [
          for (final month
              in months)
            PopupMenuItem<DateTime>(
              value: month,
              height: 44,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    child:
                        _sameMonth(
                          month,
                          selectedMonth,
                        )
                            ? const Icon(
                                Icons
                                    .check,
                                size: 16,
                                color:
                                    AppColors.primary,
                              )
                            : null,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Text(
                    _monthYear(
                      month,
                    ),
                    style:
                        TextStyle(
                      fontSize: 13,
                      fontWeight:
                          _sameMonth(
                            month,
                            selectedMonth,
                          )
                              ? FontWeight
                                  .w600
                              : FontWeight
                                  .w400,
                    ),
                  ),
                ],
              ),
            ),
        ];
      },
      child: InputDecorator(
        isEmpty: false,
        decoration:
            const InputDecoration(
          labelText: 'Month',
          isDense: true,
          prefixIcon: Icon(
            Icons
                .calendar_month_outlined,
            size: 18,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _monthYear(
                  selectedMonth,
                ),
                maxLines: 1,
                overflow:
                    TextOverflow
                        .ellipsis,
                style:
                    const TextStyle(
                  fontSize: 13,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: AppColors
                  .mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SUMMARY CARDS
// =============================================================================

class _SummaryGrid
    extends StatelessWidget {
  final List<Widget> cards;

  const _SummaryGrid({
    required this.cards,
  });

  @override
  Widget build(BuildContext context) {
    final width =
        MediaQuery.sizeOf(context)
            .width;

    if (width < 650) {
      return Column(
        children: [
          for (var i = 0;
              i < cards.length;
              i++) ...[
            if (i > 0)
              const SizedBox(
                height: 10,
              ),
            SizedBox(
              width:
                  double.infinity,
              height: 112,
              child: cards[i],
            ),
          ],
        ],
      );
    }

    if (width < 1100) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child:
                    SizedBox(
                  height: 112,
                  child: cards[0],
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child:
                    SizedBox(
                  height: 112,
                  child: cards[1],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 10,
          ),
          Row(
            children: [
              Expanded(
                child:
                    SizedBox(
                  height: 112,
                  child: cards[2],
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child:
                    SizedBox(
                  height: 112,
                  child: cards[3],
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0;
            i < cards.length;
            i++) ...[
          if (i > 0)
            const SizedBox(
              width: 10,
            ),
          Expanded(
            child: SizedBox(
              height: 112,
              child: cards[i],
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard
    extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String helper;
  final bool selected;
  final VoidCallback onTap;

  const _SummaryCard({
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
          BorderRadius.circular(
        16,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        hoverColor: AppColors
            .primary
            .withValues(
          alpha: 0.035,
        ),
        child:
            AnimatedContainer(
          duration:
              const Duration(
            milliseconds: 130,
          ),
          padding:
              const EdgeInsets.all(
            14,
          ),
          decoration:
              BoxDecoration(
            color: selected
                ? AppColors.primary
                    .withValues(
                    alpha: 0.055,
                  )
                : AppColors.card,
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            border:
                Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border,
              width: selected
                  ? 1.5
                  : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color: AppColors
                      .primary
                      .withValues(
                    alpha: 0.09,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    11,
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

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      value,
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      helper,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 10.8,
                        height: 1.25,
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
      ),
    );
  }
}

// =============================================================================
// FILTER BAR
// =============================================================================

class _ActiveFilterBar
    extends StatelessWidget {
  final String label;
  final bool active;
  final int resultCount;
  final VoidCallback onClear;

  const _ActiveFilterBar({
    required this.label,
    required this.active,
    required this.resultCount,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            active
                ? 'Showing: $label · $resultCount ${resultCount == 1 ? 'item' : 'items'}'
                : '$label · $resultCount ${resultCount == 1 ? 'item' : 'items'}',
            style: const TextStyle(
              fontSize: 11.8,
              color:
                  AppColors.mutedForeground,
            ),
          ),
        ),

        if (active)
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(
              Icons
                  .filter_alt_off_outlined,
              size: 16,
            ),
            label: const Text(
              'Clear Filters',
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// DESKTOP REPORT
// =============================================================================

class _ReportHeader
    extends StatelessWidget {
  const _ReportHeader();

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
          Expanded(
            flex: 4,
            child:
                _HeaderCell('Item'),
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
            child:
                _HeaderCell('Used'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _HeaderCell(
              'Usage Records',
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child:
                _HeaderCell('Lost'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: _HeaderCell(
              'Loss Records',
            ),
          ),
          SizedBox(width: 22),
        ],
      ),
    );
  }
}

class _DesktopReportRow
    extends StatelessWidget {
  final MonthlyUsageRow row;
  final VoidCallback onTap;

  const _DesktopReportRow({
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
        hoverColor: AppColors
            .primary
            .withValues(
          alpha: 0.03,
        ),
        child: Padding(
          padding:
              const EdgeInsets
                  .symmetric(
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
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 12.8,
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                flex: 3,
                child: Text(
                  row.item
                      .itemCategory,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 11.8,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                flex: 2,
                child: Text(
                  _qty(
                    row.usedQty,
                    unit,
                  ),
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                flex: 2,
                child: Text(
                  '${row.usageEvents}',
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                flex: 2,
                child: Text(
                  _qty(
                    row.lossQty,
                    unit,
                  ),
                  style: TextStyle(
                    fontWeight:
                        row.lossQty > 0
                            ? FontWeight
                                .w600
                            : FontWeight
                                .w400,
                    color:
                        row.lossQty > 0
                            ? AppColors
                                .stockOut
                            : null,
                  ),
                ),
              ),

              const SizedBox(
                width: 12,
              ),

              Expanded(
                flex: 2,
                child: Text(
                  '${row.lossEvents}',
                ),
              ),

              const SizedBox(
                width: 4,
              ),

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
// MOBILE REPORT
// =============================================================================

class _MobileReportRow
    extends StatelessWidget {
  final MonthlyUsageRow row;
  final VoidCallback onTap;

  const _MobileReportRow({
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
              const EdgeInsets.all(
            15,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.item
                          .itemName,
                      style:
                          const TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons
                        .chevron_right,
                    size: 18,
                    color: AppColors
                        .mutedForeground,
                  ),
                ],
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                row.item
                    .itemCategory,
                style:
                    const TextStyle(
                  fontSize: 11,
                  color: AppColors
                      .mutedForeground,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              Wrap(
                spacing: 20,
                runSpacing: 9,
                children: [
                  _MiniMetric(
                    label: 'Used',
                    value: _qty(
                      row.usedQty,
                      unit,
                    ),
                  ),
                  _MiniMetric(
                    label:
                        'Usage Records',
                    value:
                        '${row.usageEvents}',
                  ),
                  _MiniMetric(
                    label: 'Lost',
                    value: _qty(
                      row.lossQty,
                      unit,
                    ),
                    danger:
                        row.lossQty > 0,
                  ),
                  _MiniMetric(
                    label:
                        'Loss Records',
                    value:
                        '${row.lossEvents}',
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
// DETAILS
// =============================================================================

class _MetricBox
    extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color accent;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      padding:
          const EdgeInsets.all(
        13,
      ),
      decoration:
          BoxDecoration(
        color: accent.withValues(
          alpha: 0.055,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border: Border.all(
          color: accent.withValues(
            alpha: 0.20,
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
                width: 30,
                height: 30,
                decoration:
                    BoxDecoration(
                  color: accent
                      .withValues(
                    alpha: 0.11,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    9,
                  ),
                ),
                alignment:
                    Alignment.center,
                child: Icon(
                  icon,
                  size: 16,
                  color: accent,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            label,
            style:
                const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          Expanded(
            child: Text(
              helper,
              maxLines: 3,
              overflow:
                  TextOverflow
                      .ellipsis,
              style:
                  const TextStyle(
                fontSize: 10.8,
                height: 1.3,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow
    extends StatelessWidget {
  final String label;
  final String value;
  final String explanation;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration:
          BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  label,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  explanation,
                  style:
                      const TextStyle(
                    fontSize: 10.8,
                    height: 1.3,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style:
                const TextStyle(
              fontSize: 17,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric
    extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;

  const _MiniMetric({
    required this.label,
    required this.value,
    this.danger = false,
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
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
              color: danger
                  ? AppColors.stockOut
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EXPLANATION
// =============================================================================

class _ReportExplanation
    extends StatelessWidget {
  const _ReportExplanation();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color: AppColors.secondary,
        borderRadius:
            BorderRadius.circular(
          12,
        ),
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
            size: 16,
            color:
                AppColors.primary,
          ),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              'Used means stock consumed through treatments or normal dispensing. '
              'Lost means stock removed because it expired or was wasted. '
              'Inventory adjustments are not counted because they are corrections.',
              style: TextStyle(
                fontSize: 11.3,
                height: 1.4,
                color: AppColors
                    .mutedForeground,
              ),
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

class _HeaderCell
    extends StatelessWidget {
  final String label;

  const _HeaderCell(
    this.label,
  );

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight:
            FontWeight.w700,
        color:
            AppColors.mutedForeground,
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
        vertical: 46,
      ),
      decoration:
          BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: AppColors
                .mutedForeground,
          ),
          const SizedBox(
            height: 9,
          ),
          Text(
            title,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            message,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 11.8,
              color: AppColors
                  .mutedForeground,
            ),
          ),
          if (actionLabel !=
                  null &&
              onAction !=
                  null) ...[
            const SizedBox(
              height: 12,
            ),
            OutlinedButton(
              onPressed:
                  onAction,
              child:
                  Text(
                actionLabel!,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

bool _sameMonth(
  DateTime a,
  DateTime b,
) =>
    a.year == b.year &&
    a.month == b.month;

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
) =>
    '${_monthNames[date.month - 1]} ${date.year}';

String _qty(
  double value,
  String unit,
) =>
    '${_formatQty(value)} $unit';

String _formatQty(
  double value,
) {
  if (value ==
      value.roundToDouble()) {
    return value
        .toInt()
        .toString();
  }

  return value
      .toStringAsFixed(3)
      .replaceFirst(
        RegExp(r'0+$'),
        '',
      )
      .replaceFirst(
        RegExp(r'\.$'),
        '',
      );
}
