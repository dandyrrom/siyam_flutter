import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../models/audit_entry.dart';
import '../services/audit_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/page_loading.dart';
// =============================================================================
// ROLE-AWARE AUDIT TRAIL
// =============================================================================
//
// Manager:
// - full permitted Audit Trail
// - all permitted modules/users
// - detailed before/after changes
//
// Staff:
// - "My Activity"
// - only the signed-in Staff account's Inventory + Medical activity
// - no Manager/configuration/account activity
// - no before/after change details
//
// This is intentionally NOT a developer/database log.
// Technical batch movements remain in batch_transaction_log.
//
// UI CONSISTENCY
// - Module, Action, and Date now use the same shared AppDropdown component
//   used by Animal Records, Suppliers, and Reports.
// - Audit filtering/data behavior is unchanged.
// =============================================================================

enum _AuditPeriod {
  all,
  today,
  sevenDays,
  thirtyDays,
}

class AuditTrailPage extends StatefulWidget {
  const AuditTrailPage({super.key});

  @override
  State<AuditTrailPage> createState() =>
      _AuditTrailPageState();
}

class _AuditTrailPageState extends State<AuditTrailPage>
    with DataBusRefreshMixin<AuditTrailPage> {
  final AuditService _service = AuditService();
  final _searchCtrl = TextEditingController();

  List<AuditEntry> _entries = [];

  bool _loading = true;
  String? _error;

  String _search = '';
  String? _moduleFilter;
  String? _actionFilter;
  _AuditPeriod _period = _AuditPeriod.all;

  int _page = 0;

  static const int _pageSize = 20;

  static const List<String> _managerModuleOptions = [
    'Accounts',
    'Animals',
    'Configuration',
    'Donations',
    'Inventory',
    'Medical',
    'Suppliers',
  ];

  static const List<String> _staffModuleOptions = [
    'Inventory',
    'Medical',
  ];

  AppUser? get _currentUser =>
      context.read<AuthController>().profile;

  bool get _isStaff =>
      _currentUser?.role == AppRole.staff;

  List<String> get _visibleModuleOptions =>
      _isStaff
          ? _staffModuleOptions
          : _managerModuleOptions;

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
      final user =
          context.read<AuthController>().profile;

      final isStaff =
          user?.role == AppRole.staff;

      final entries =
          await _service.fetchEntries(
        actorUserId:
            isStaff ? user!.userId : null,
        modules:
            isStaff
                ? _staffModuleOptions
                : null,
        includeChangeDetails:
            !isStaff,
      );

      if (!mounted) return;

      setState(() {
        _entries = entries;
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
              'Could not load audit trail: $e';
          _loading = false;
        });
      }
    }
  }

  // ===========================================================================
  // FILTERING
  // ===========================================================================

  DateTime get _todayStart {
    final now = DateTime.now();

    return DateTime(
      now.year,
      now.month,
      now.day,
    );
  }

  bool _matchesPeriod(
    AuditEntry entry,
  ) {
    final date = entry.createdAt;

    if (_period == _AuditPeriod.today) {
      return !date.isBefore(
        _todayStart,
      );
    }

    if (_period ==
        _AuditPeriod.sevenDays) {
      return !date.isBefore(
        _todayStart.subtract(
          const Duration(days: 6),
        ),
      );
    }

    if (_period ==
        _AuditPeriod.thirtyDays) {
      return !date.isBefore(
        _todayStart.subtract(
          const Duration(days: 29),
        ),
      );
    }

    return true;
  }

  List<AuditEntry> get _filtered {
    final query =
        _search.trim().toLowerCase();

    return _entries.where((entry) {
      if (_moduleFilter != null &&
          entry.module != _moduleFilter) {
        return false;
      }

      if (_actionFilter != null &&
          entry.action != _actionFilter) {
        return false;
      }

      if (!_matchesPeriod(entry)) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final haystack = [
        entry.summary,
        entry.actorName,
        entry.actorRole,
        entry.module,
        entry.entityLabel ?? '',
        _actionLabel(
          entry.action,
          isStaff: _isStaff,
        ),
      ].join(' ').toLowerCase();

      return haystack.contains(query);
    }).toList();
  }

  int get _pageCount {
    final count = _filtered.length;

    if (count == 0) {
      return 1;
    }

    return ((count - 1) ~/ _pageSize) + 1;
  }

  List<AuditEntry> get _pageEntries {
    final rows = _filtered;

    final safePage =
        _page.clamp(
      0,
      _pageCount - 1,
    );

    final start =
        safePage * _pageSize;

    final proposedEnd =
        start + _pageSize;

    final end =
        proposedEnd > rows.length
            ? rows.length
            : proposedEnd;

    if (start >= end) {
      return const [];
    }

    return rows.sublist(
      start,
      end,
    );
  }

  bool get _hasFilters =>
      _search.isNotEmpty ||
      _moduleFilter != null ||
      _actionFilter != null ||
      _period != _AuditPeriod.all;

  void _resetFilters() {
    _searchCtrl.clear();

    setState(() {
      _search = '';
      _moduleFilter = null;
      _actionFilter = null;
      _period = _AuditPeriod.all;
      _page = 0;
    });
  }

  // ===========================================================================
  // SUMMARY COUNTS
  // ===========================================================================

  int get _todayCount =>
      _entries
          .where(
            (entry) =>
                !entry.createdAt.isBefore(
              _todayStart,
            ),
          )
          .length;

  int _moduleCount(
    String module,
  ) {
    return _entries
        .where(
          (entry) =>
              entry.module == module,
        )
        .length;
  }

  void _selectModuleCard(
    String module,
  ) {
    setState(() {
      _moduleFilter =
          _moduleFilter == module
              ? null
              : module;

      _period = _AuditPeriod.all;
      _page = 0;
    });
  }

  void _selectTodayCard() {
    setState(() {
      _period =
          _period == _AuditPeriod.today
              ? _AuditPeriod.all
              : _AuditPeriod.today;

      _moduleFilter = null;
      _page = 0;
    });
  }

  // ===========================================================================
  // PAGE
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
 if (_loading) {
  return const PageLoading(
    message: 'Loading audit trail',
  );
}

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
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

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          _isStaff
              ? 'My Activity'
              : 'Audit Trail',
          style: const TextStyle(
            fontSize: 24,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          _isStaff
              ? 'Review the inventory and medical actions recorded under your account.'
              : 'Review important actions and changes made in SIYAM.',
          style: const TextStyle(
            fontSize: 13,
            color:
                AppColors.mutedForeground,
          ),
        ),

        const SizedBox(height: 18),

        _buildSummaryCards(),

        const SizedBox(height: 18),

        _buildFilters(),

        const SizedBox(height: 14),

        if (_hasFilters)
          _ActiveFilterSummary(
            resultCount:
                _filtered.length,
            onClear:
                _resetFilters,
          ),

        if (_hasFilters)
          const SizedBox(height: 12),

        _buildList(),

        if (_filtered.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildPagination(),
        ],
      ],
    );
  }

  // ===========================================================================
  // INTERACTIVE SUMMARY CARDS
  // ===========================================================================

  Widget _buildSummaryCards() {
    final cards = <Widget>[
      _AuditSummaryCard(
        icon: Icons.today_outlined,
        value: '$_todayCount',
        label: 'Today',
        helper:
            _isStaff
                ? 'Your actions today'
                : 'Actions recorded today',
        selected:
            _period == _AuditPeriod.today,
        onTap: _selectTodayCard,
      ),
      _AuditSummaryCard(
        icon:
            Icons.inventory_2_outlined,
        value:
            '${_moduleCount('Inventory')}',
        label: 'Inventory',
        helper:
            _isStaff
                ? 'Your inventory actions'
                : 'Stock and item actions',
        selected:
            _moduleFilter == 'Inventory',
        onTap: () =>
            _selectModuleCard(
          'Inventory',
        ),
      ),
      _AuditSummaryCard(
        icon:
            Icons.medical_services_outlined,
        value:
            '${_moduleCount('Medical')}',
        label: 'Medical',
        helper:
            _isStaff
                ? 'Your treatment actions'
                : 'Treatment actions',
        selected:
            _moduleFilter == 'Medical',
        onTap: () =>
            _selectModuleCard(
          'Medical',
        ),
      ),
    ];

    if (!_isStaff) {
      cards.add(
        _AuditSummaryCard(
          icon:
              Icons.settings_outlined,
          value:
              '${_moduleCount('Configuration')}',
          label:
              'Configuration',
          helper:
              'Settings and registry changes',
          selected:
              _moduleFilter ==
              'Configuration',
          onTap: () =>
              _selectModuleCard(
            'Configuration',
          ),
        ),
      );
    }

    return _AuditCardGrid(
      cards: cards,
    );
  }

  // ===========================================================================
  // FILTERS
  // ===========================================================================
  //
  // These three dropdowns deliberately use the shared AppDropdown widget.
  // That gives Audit the same rounded trigger, white flyout panel, shadow,
  // caret, and viewport-aware positioning used across the other SIYAM pages.
  // ===========================================================================

  Widget _buildFilters() {
    final width =
        MediaQuery.sizeOf(context).width;

    final narrow =
        width < 1180;

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
                    tooltip: 'Clear search',
                    onPressed: () {
                      _searchCtrl.clear();

                      setState(() {
                        _search = '';
                        _page = 0;
                      });
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                    ),
                  ),
        hintText:
            _isStaff
                ? 'Search your activity, item, or treatment'
                : 'Search user, action, item, animal, supplier',
      ),
      onChanged: (value) {
        setState(() {
          _search = value;
          _page = 0;
        });
      },
    );

    final module =
        AppDropdown<String?>(
      label:
          _moduleFilter ??
          'All modules',
      options: [
        const AppDropdownOption<String?>(
          null,
          'All modules',
        ),
        for (final value
            in _visibleModuleOptions)
          AppDropdownOption<String?>(
            value,
            value,
          ),
      ],
      onSelect: (value) {
        setState(() {
          _moduleFilter = value;
          _page = 0;
        });
      },
    );

    final action =
        AppDropdown<String?>(
      label:
          _actionFilter == null
              ? 'All actions'
              : _actionLabel(
                  _actionFilter!,
                  isStaff: _isStaff,
                ),
      options: [
        const AppDropdownOption<String?>(
          null,
          'All actions',
        ),
        const AppDropdownOption<String?>(
          'CREATE',
          'Created / recorded',
        ),
        const AppDropdownOption<String?>(
          'UPDATE',
          'Updated',
        ),
        AppDropdownOption<String?>(
          'DELETE',
          _isStaff
              ? 'Removed'
              : 'Archived',
        ),
      ],
      onSelect: (value) {
        setState(() {
          _actionFilter = value;
          _page = 0;
        });
      },
    );

    final period =
        AppDropdown<_AuditPeriod>(
      label: _periodLabel(_period),
      options: const [
        AppDropdownOption(
          _AuditPeriod.all,
          'All time',
        ),
        AppDropdownOption(
          _AuditPeriod.today,
          'Today',
        ),
        AppDropdownOption(
          _AuditPeriod.sevenDays,
          'Last 7 days',
        ),
        AppDropdownOption(
          _AuditPeriod.thirtyDays,
          'Last 30 days',
        ),
      ],
      onSelect: (value) {
        setState(() {
          _period = value;
          _page = 0;
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment:
                WrapCrossAlignment.center,
            children: [
              module,
              action,
              period,
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        Expanded(
          child: search,
        ),
        const SizedBox(width: 12),
        module,
        const SizedBox(width: 10),
        action,
        const SizedBox(width: 10),
        period,
      ],
    );
  }

  // ===========================================================================
  // LIST
  // ===========================================================================

  Widget _buildList() {
    final rows = _pageEntries;

    if (_entries.isEmpty) {
      return const _AuditEmptyState(
        icon:
            Icons.fact_check_outlined,
        title:
            'No audit activity yet',
        message:
            'New actions will appear here after the Audit Trail migration is installed.',
      );
    }

    if (rows.isEmpty) {
      return _AuditEmptyState(
        icon: Icons.search_off,
        title: 'No matching activity',
        message:
            'Try another search or clear the selected filters.',
        actionLabel: 'Clear Filters',
        onAction: _resetFilters,
      );
    }

    final mobile =
        MediaQuery.sizeOf(context)
                .width <
            820;

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
            const _AuditHeader(),

          if (!mobile)
            const Divider(height: 1),

          for (var i = 0;
              i < rows.length;
              i++) ...[
            if (i > 0)
              const Divider(height: 1),

            if (mobile)
              _AuditMobileRow(
                entry: rows[i],
                isStaff: _isStaff,
                onTap: () =>
                    _showDetails(
                  rows[i],
                ),
              )
            else
              _AuditDesktopRow(
                entry: rows[i],
                isStaff: _isStaff,
                onTap: () =>
                    _showDetails(
                  rows[i],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // DETAILS
  // ===========================================================================

  Future<void> _showDetails(
    AuditEntry entry,
  ) async {
    final changes =
        _changedFields(entry);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
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
                entry.summary,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  _ModuleBadge(
                    module:
                        entry.module,
                  ),
                  _ActionBadge(
                    action:
                        entry.action,
                    isStaff: _isStaff,
                  ),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            child:
                SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const _SectionTitle(
                    'Action Details',
                  ),

                  _DetailRow(
                    label:
                        'Performed by',
                    value:
                        entry.actorName,
                  ),

                  _DetailRow(
                    label: 'Role',
                    value:
                        entry.actorRole,
                  ),

                  if (entry.receivedBy != null)
                    _DetailRow(
                      label:
                          'Received by',
                      value:
                          entry.receivedBy!,
                    ),

                  _DetailRow(
                    label: 'Module',
                    value:
                        entry.module,
                  ),

                  _DetailRow(
                    label: 'Action',
                    value:
                        _actionLabel(
                      entry.action,
                      isStaff: _isStaff,
                    ),
                  ),

                  _DetailRow(
                    label:
                        'Date & time',
                    value:
                        _formatDateTime(
                      entry.createdAt,
                    ),
                  ),

                  if (entry.entityLabel !=
                          null &&
                      entry.entityLabel!
                          .trim()
                          .isNotEmpty)
                    _AuditEntityContext(
                      entityType:
                          entry.entityType,
                      entityLabel:
                          entry.entityLabel!,
                    ),

                  if (!_isStaff &&
                      entry.isUpdate &&
                      changes.isNotEmpty) ...[
                    const SizedBox(
                      height: 16,
                    ),
                    const _SectionTitle(
                      'What changed',
                    ),
                    for (final change
                        in changes)
                      _ChangeRow(
                        label:
                            change.label,
                        before:
                            change.before,
                        after:
                            change.after,
                      ),
                  ],

                  const SizedBox(height: 14),

                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.all(
                      12,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.secondary,
                      borderRadius:
                          BorderRadius
                              .circular(12),
                      border: Border.all(
                        color:
                            AppColors.border,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color:
                              AppColors.primary,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _isStaff
                                ? 'This page shows only the Inventory and Medical actions recorded under your own Staff account.'
                                : 'Performed by is the signed-in account that carried out or recorded the action in SIYAM. '
                                    'For stock-in records, Received by is the person who physically received the supplies on-site. '
                                    'These can be different people.',
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
              child:
                  const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // CHANGE DETAILS
  // ===========================================================================

  List<_AuditChange> _changedFields(
    AuditEntry entry,
  ) {
    final oldValues =
        entry.oldValues;

    final newValues =
        entry.newValues;

    if (oldValues == null ||
        newValues == null) {
      return const [];
    }

    final keys = <String>{
      ...oldValues.keys,
      ...newValues.keys,
    };

    final rows =
        <_AuditChange>[];

    for (final key in keys) {
      if (_hiddenChangeKeys.contains(
        key,
      )) {
        continue;
      }

      final before =
          oldValues[key];

      final after =
          newValues[key];

      if (_sameValue(
        before,
        after,
      )) {
        continue;
      }

      rows.add(
        _AuditChange(
          label:
              _fieldLabel(key),
          before:
              _displayValue(before),
          after:
              _displayValue(after),
        ),
      );
    }

    rows.sort(
      (a, b) => a.label
          .compareTo(b.label),
    );

    return rows;
  }

  bool _sameValue(
    dynamic a,
    dynamic b,
  ) {
    return a?.toString() ==
        b?.toString();
  }

  String _displayValue(
    dynamic value,
  ) {
    if (value == null) {
      return 'None';
    }

    if (value is bool) {
      return value
          ? 'Yes'
          : 'No';
    }

    final text =
        value.toString().trim();

    if (text.isEmpty) {
      return 'None';
    }

    return text;
  }

  static const Set<String>
      _hiddenChangeKeys = {
    'id',
    'itemid',
    'petid',
    'suppid',
    'donorid',
    'purchaseid',
    'treatid',
    'recordedby',
    'performedby',
    'createdby',
    'createdat',
    'updatedat',
    'created_at',
    'updated_at',
    'recordeddate',
    'receiveddate',
    'active_session_id',
    'active_session_last_seen',
    'total_purchase_stocks',
    'total_package_stocks',
    'total_package_stock_ins',
  };

  String _fieldLabel(
    String key,
  ) {
    const labels = {
      'name': 'Name',
      'fname': 'First name',
      'lname': 'Last name',
      'role': 'Role',
      'email': 'Email',
      'status': 'Status',
      'breed': 'Breed',
      'owner': 'Owner',
      'gender': 'Gender',
      'spayed_neutered':
          'Spayed / neutered',
      'contactnum':
          'Contact number',
      'contacttel':
          'Telephone',
      'address': 'Address',
      'type': 'Name',
      'abbr_name':
          'Unit abbreviation',
      'low_stock_threshold':
          'Low-stock threshold',
      'expiration_warning_days':
          'Expiration warning days',
      'default_lead_time_days':
          'Default lead time',
      'default_safety_stock_qty':
          'Default safety stock',
      'lead_time_days':
          'Lead time',
      'safety_stock_qty':
          'Safety stock',
      'notes': 'Notes',
      'reason': 'Reason',
    };

    final known =
        labels[key];

    if (known != null) {
      return known;
    }

    return key
        .replaceAll('_', ' ')
        .split(' ')
        .where(
          (word) =>
              word.isNotEmpty,
        )
        .map(
          (word) =>
              '${word[0].toUpperCase()}'
              '${word.substring(1)}',
        )
        .join(' ');
  }

  // ===========================================================================
  // PAGINATION
  // ===========================================================================

  Widget _buildPagination() {
    final total =
        _filtered.length;

    final start =
        total == 0
            ? 0
            : (_page * _pageSize) + 1;

    final proposedEnd =
        (_page + 1) * _pageSize;

    final end =
        proposedEnd > total
            ? total
            : proposedEnd;

    return Row(
      children: [
        Expanded(
          child: Text(
            '$start-$end of $total actions',
            style: const TextStyle(
              fontSize: 12,
              color:
                  AppColors.mutedForeground,
            ),
          ),
        ),

        TextButton.icon(
          onPressed:
              _page <= 0
                  ? null
                  : () {
                      setState(() {
                        _page--;
                      });
                    },
          icon: const Icon(
            Icons.chevron_left,
            size: 17,
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
            color: AppColors.primary
                .withValues(
              alpha: 0.10,
            ),
            borderRadius:
                BorderRadius.circular(
              999,
            ),
          ),
          child: Text(
            '${_page + 1} / $_pageCount',
            style: const TextStyle(
              fontSize: 11.5,
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
          child:
              const Text('Next'),
        ),
      ],
    );
  }
}

// =============================================================================
// SUMMARY CARD GRID
// =============================================================================

class _AuditCardGrid
    extends StatelessWidget {
  final List<Widget> cards;

  const _AuditCardGrid({
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
              height: 112,
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
              width:
                  double.infinity,
              height: 108,
              child: cards[i],
            ),
          ],
        ],
      );
    }

    if (width < 1080) {
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

class _AuditSummaryCard
    extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String helper;
  final bool selected;
  final VoidCallback onTap;

  const _AuditSummaryCard({
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
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(16),
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
                BorderRadius.circular(
              16,
            ),
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : AppColors.border,
              width:
                  selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color: AppColors.primary
                      .withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(11),
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

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
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
                      style:
                          const TextStyle(
                        fontSize: 12.5,
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
                        fontSize: 11,
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
// FILTER SUMMARY
// =============================================================================

class _ActiveFilterSummary
    extends StatelessWidget {
  final int resultCount;
  final VoidCallback onClear;

  const _ActiveFilterSummary({
    required this.resultCount,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '$resultCount matching '
            '${resultCount == 1 ? 'action' : 'actions'}',
            style: const TextStyle(
              fontSize: 12.5,
              color:
                  AppColors.mutedForeground,
            ),
          ),
        ),
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
// DESKTOP / MOBILE ROWS
// =============================================================================

class _AuditHeader
    extends StatelessWidget {
  const _AuditHeader();

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
            flex: 5,
            child:
                _HeaderCell('Activity'),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child:
                _HeaderCell('Performed By'),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 110,
            child:
                _HeaderCell('Module'),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 100,
            child:
                _HeaderCell('Action'),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 150,
            child:
                _HeaderCell('Date & Time'),
          ),
          SizedBox(width: 22),
        ],
      ),
    );
  }
}

class _AuditDesktopRow
    extends StatelessWidget {
  final AuditEntry entry;
  final bool isStaff;
  final VoidCallback onTap;

  const _AuditDesktopRow({
    required this.entry,
    required this.isStaff,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
                flex: 5,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.summary,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    if (entry.entityLabel !=
                            null &&
                        entry.entityLabel!
                            .trim()
                            .isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        entry.entityType ==
                                'purchase'
                            ? 'Stocked items: ${entry.entityLabel!}'
                            : entry.entityLabel!,
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors
                              .mutedForeground,
                        ),
                      ),
                    ],
                    if (entry.receivedBy != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Received by: ${entry.receivedBy}',
                        overflow:
                            TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.2,
                          fontWeight:
                              FontWeight.w500,
                          color: AppColors
                              .mutedForeground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.actorName,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      entry.actorRole,
                      style: const TextStyle(
                        fontSize: 10.8,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              SizedBox(
                width: 110,
                child: _ModuleBadge(
                  module:
                      entry.module,
                ),
              ),

              const SizedBox(width: 12),

              SizedBox(
                width: 100,
                child: _ActionBadge(
                  action:
                      entry.action,
                  isStaff: isStaff,
                ),
              ),

              const SizedBox(width: 12),

              SizedBox(
                width: 150,
                child: Text(
                  _formatDateTime(
                    entry.createdAt,
                  ),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
              ),

              const SizedBox(width: 4),

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

class _AuditMobileRow
    extends StatelessWidget {
  final AuditEntry entry;
  final bool isStaff;
  final VoidCallback onTap;

  const _AuditMobileRow({
    required this.entry,
    required this.isStaff,
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
              const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.summary,
                      style: const TextStyle(
                        fontSize: 13.5,
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

              if (entry.entityLabel != null &&
                  entry.entityLabel!
                      .trim()
                      .isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  entry.entityType ==
                          'purchase'
                      ? 'Stocked items: ${entry.entityLabel!}'
                      : entry.entityLabel!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color:
                        AppColors.mutedForeground,
                  ),
                ),
              ],

              const SizedBox(height: 7),

              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  _ModuleBadge(
                    module:
                        entry.module,
                  ),
                  _ActionBadge(
                    action:
                        entry.action,
                    isStaff: isStaff,
                  ),
                ],
              ),

              const SizedBox(height: 9),

              Text(
                '${entry.actorName} · ${entry.actorRole}',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                _formatDateTime(
                  entry.createdAt,
                ),
                style: const TextStyle(
                  fontSize: 11.2,
                  color:
                      AppColors.mutedForeground,
                ),
              ),

              if (entry.receivedBy != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Received by: ${entry.receivedBy}',
                  style: const TextStyle(
                    fontSize: 11.2,
                    fontWeight:
                        FontWeight.w500,
                    color:
                        AppColors.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// BADGES
// =============================================================================

class _ModuleBadge
    extends StatelessWidget {
  final String module;

  const _ModuleBadge({
    required this.module,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        module,
        overflow:
            TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight:
              FontWeight.w600,
          color:
              AppColors.mutedForeground,
        ),
      ),
    );
  }
}

class _ActionBadge
    extends StatelessWidget {
  final String action;
  final bool isStaff;

  const _ActionBadge({
    required this.action,
    required this.isStaff,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) =
        _actionMeta(
      action,
      isStaff: isStaff,
    );

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.10,
        ),
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        label,
        overflow:
            TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight:
              FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// =============================================================================
// DETAIL HELPERS
// =============================================================================

class _SectionTitle
    extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
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

class _AuditEntityContext
    extends StatelessWidget {
  final String entityType;
  final String entityLabel;

  const _AuditEntityContext({
    required this.entityType,
    required this.entityLabel,
  });

  @override
  Widget build(BuildContext context) {
    final clean =
        entityLabel.trim();

    if (entityType ==
        'treatment_item') {
      final fields =
          _parseContextFields(clean);

      if (fields.isNotEmpty) {
        return Padding(
          padding:
              const EdgeInsets.only(
            top: 8,
            bottom: 5,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                'Treatment details',
              ),
              _ContextCard(
                fields: fields,
              ),
            ],
          ),
        );
      }
    }

    if (entityType == 'purchase') {
      return Padding(
        padding:
            const EdgeInsets.only(
          top: 8,
          bottom: 5,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              'Stocked items',
            ),
            _ContextTextCard(
              text: clean,
            ),
          ],
        ),
      );
    }

    if (entityType == 'treatment') {
      final animal =
          clean.startsWith(
        'Animal: ',
      )
              ? clean.substring(8)
              : clean;

      return _DetailRow(
        label: 'Animal',
        value: animal,
      );
    }

    return _DetailRow(
      label: 'Record',
      value: clean,
    );
  }

  List<_ContextField>
      _parseContextFields(
    String value,
  ) {
    final parts = value
        .split(' · ')
        .map(
          (part) =>
              part.trim(),
        )
        .where(
          (part) =>
              part.isNotEmpty,
        )
        .toList();

    final fields =
        <_ContextField>[];

    for (final part in parts) {
      final separator =
          part.indexOf(':');

      if (separator <= 0 ||
          separator >=
              part.length - 1) {
        continue;
      }

      final rawLabel = part
          .substring(
            0,
            separator,
          )
          .trim();

      final fieldValue = part
          .substring(
            separator + 1,
          )
          .trim();

      if (rawLabel.isEmpty ||
          fieldValue.isEmpty) {
        continue;
      }

      final label =
          rawLabel == 'Qty'
              ? 'Quantity'
              : rawLabel;

      fields.add(
        _ContextField(
          label: label,
          value: fieldValue,
        ),
      );
    }

    return fields;
  }
}

class _ContextField {
  final String label;
  final String value;

  const _ContextField({
    required this.label,
    required this.value,
  });
}

class _ContextCard
    extends StatelessWidget {
  final List<_ContextField> fields;

  const _ContextCard({
    required this.fields,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0;
              i < fields.length;
              i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                color: AppColors.border,
              ),
            _ContextFieldRow(
              field: fields[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContextFieldRow
    extends StatelessWidget {
  final _ContextField field;

  const _ContextFieldRow({
    required this.field,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              field.label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              field.value,
              textAlign:
                  TextAlign.start,
              style: const TextStyle(
                fontSize: 12.2,
                height: 1.35,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextTextCard
    extends StatelessWidget {
  final String text;

  const _ContextTextCard({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final items = text
        .split(',')
        .map(
          (item) =>
              item.trim(),
        )
        .where(
          (item) =>
              item.isNotEmpty,
        )
        .toList();

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child:
          items.length <= 1
              ? Text(
                  text,
                  style:
                      const TextStyle(
                    fontSize: 12.2,
                    height: 1.4,
                    fontWeight:
                        FontWeight.w600,
                  ),
                )
              : Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item
                        in items)
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.card,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            999,
                          ),
                          border:
                              Border.all(
                            color:
                                AppColors.border,
                          ),
                        ),
                        child: Text(
                          item,
                          style:
                              const TextStyle(
                            fontSize: 11.5,
                            fontWeight:
                                FontWeight
                                    .w600,
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

  const _DetailRow({
    required this.label,
    required this.value,
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
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.2,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign:
                  TextAlign.start,
              style: const TextStyle(
                fontSize: 12.2,
                height: 1.35,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeRow
    extends StatelessWidget {
  final String label;
  final String before;
  final String after;

  const _ChangeRow({
    required this.label,
    required this.before,
    required this.after,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 8,
      ),
      padding:
          const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.secondary,
        borderRadius:
            BorderRadius.circular(11),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.8,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BeforeAfter(
                  label: 'Before',
                  value: before,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward,
                size: 15,
                color:
                    AppColors.mutedForeground,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BeforeAfter(
                  label: 'After',
                  value: after,
                  strong: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BeforeAfter
    extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _BeforeAfter({
    required this.label,
    required this.value,
    this.strong = false,
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
            fontSize: 10.3,
            color:
                AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight:
                strong
                    ? FontWeight.w700
                    : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AuditEmptyState
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _AuditEmptyState({
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

class _AuditChange {
  final String label;
  final String before;
  final String after;

  const _AuditChange({
    required this.label,
    required this.before,
    required this.after,
  });
}

// =============================================================================
// FORMATTERS
// =============================================================================

String _periodLabel(
  _AuditPeriod period,
) {
  switch (period) {
    case _AuditPeriod.today:
      return 'Today';
    case _AuditPeriod.sevenDays:
      return 'Last 7 days';
    case _AuditPeriod.thirtyDays:
      return 'Last 30 days';
    case _AuditPeriod.all:
      return 'All time';
  }
}

(String, Color) _actionMeta(
  String action, {
  required bool isStaff,
}) {
  if (action == 'CREATE') {
    return (
      'Created',
      AppColors.primary,
    );
  }

  if (action == 'DELETE') {
    return (
      isStaff
          ? 'Removed'
          : 'Archived',
      AppColors.stockOut,
    );
  }

  return (
    'Updated',
    AppColors.stockLow,
  );
}

String _actionLabel(
  String action, {
  required bool isStaff,
}) {
  if (action == 'CREATE') {
    return 'Created / recorded';
  }

  if (action == 'DELETE') {
    return isStaff
        ? 'Removed'
        : 'Archived';
  }

  return 'Updated';
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

String _formatDateTime(
  DateTime date,
) {
  final hour =
      date.hour == 0
          ? 12
          : date.hour > 12
              ? date.hour - 12
              : date.hour;

  final minute =
      date.minute
          .toString()
          .padLeft(2, '0');

  final amPm =
      date.hour >= 12
          ? 'PM'
          : 'AM';

  return '${_monthAbbrev[date.month - 1]} '
      '${date.day}, ${date.year} · '
      '$hour:$minute $amPm';
}
