import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../models/donation.dart';
import '../services/donation_service.dart';
import '../state/data_bus.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/hoverable_row.dart';

class DonationsPage extends StatefulWidget {
  const DonationsPage({super.key});

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage>
    with DataBusRefreshMixin<DonationsPage> {
  // Service used to load donation submissions from the database.
  final DonationService _service = DonationService();

  List<DonationSubmission> _submissions = [];
  bool _loading = true;
  String? _error;

  String _search = '';

  // null means all submission statuses are shown.
  SubmissionStatus? _statusFilter;

  @override
  void initState() {
    super.initState();

    // Loads all donation submissions when the page first opens.
    _load();
  }

  @override
  void onExternalDataChanged() {
    // Refreshes the donation list when another part of the system changes data.
    _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Gets all donor submissions from the database.
      final submissions = await _service.fetchSubmissions();

      if (!mounted) return;

      setState(() {
        _submissions = submissions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error = 'Could not load donations: $e';
          _loading = false;
        });
      }
    }
  }

  // Filters submissions using the donor search and selected status.
  List<DonationSubmission> get _filtered {
    return _submissions.where((submission) {
      final matchesSearch =
          _search.isEmpty ||
          submission.donorName
              .toLowerCase()
              .contains(_search.toLowerCase());

      final matchesStatus =
          _statusFilter == null ||
          submission.status == _statusFilter;

      return matchesSearch && matchesStatus;
    }).toList();
  }

  // Returns the display label and color used for each submission status.
  (String, Color) _statusMeta(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.pending:
        return ('Pending', AppColors.warning);

      case SubmissionStatus.approved:
        return ('Approved', AppColors.primary);

      case SubmissionStatus.rejected:
        return ('Rejected', AppColors.destructive);

      case SubmissionStatus.received:
        return ('Received', AppColors.primary);

      case SubmissionStatus.stocked:
        return ('Stocked In', AppColors.primary);
    }
  }

  // Sets the list status filter when staff clicks one of the summary cards.
  void _filterByStatus(SubmissionStatus status) {
    setState(() {
      _statusFilter = status;
    });
  }

  // Opens a donation submission and refreshes the donations page
  // automatically when staff returns from the detail page.
  Future<void> _openSubmission(DonationSubmission submission) async {
    await context.push(
      '/donations/${submission.subId}',
    );

    if (!mounted) return;

    // Gets the newest submission statuses and updates the cards/list.
    await _load();
  }

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

    // Counts the submissions in each important staff workflow stage.
    final pendingCount = _submissions
        .where(
          (s) => s.status == SubmissionStatus.pending,
        )
        .length;

    final approvedCount = _submissions
        .where(
          (s) => s.status == SubmissionStatus.approved,
        )
        .length;

    final receivedCount = _submissions
        .where(
          (s) => s.status == SubmissionStatus.received,
        )
        .length;

    final stockedCount = _submissions
        .where(
          (s) => s.status == SubmissionStatus.stocked,
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ============================================================
        // PAGE HEADER
        // ============================================================
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Donations',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            // Allows staff to manually record direct / walk-in donations.
            ElevatedButton.icon(
              onPressed: () async {
                await context.push(
                  '/inventory/add?type=donated',
                );

                if (!mounted) return;

                // Refreshes after returning from manual donation stock-in.
                await _load();
              },
              icon: const Icon(
                Icons.add,
                size: 18,
              ),
              label: const Text(
                'Add Donation',
              ),
            ),
          ],
        ),

        const SizedBox(height: 2),

        Text(
          '${_submissions.length} submissions',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),

        const SizedBox(height: 20),

        // ============================================================
        // CLICKABLE STAFF WORKFLOW CARDS
        // ============================================================
        //
        // These cards are shortcuts for filtering submissions based on
        // what staff currently needs to work on.
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 760;

            if (compact) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 500
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _FilterStatCard(
                      label: 'Pending Review',
                      description: 'Needs manager decision',
                      value: '$pendingCount',
                      icon: Icons.schedule_outlined,
                      accent: AppColors.warning,
                      selected:
                          _statusFilter == SubmissionStatus.pending,
                      onTap: () => _filterByStatus(
                        SubmissionStatus.pending,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 500
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _FilterStatCard(
                      label: 'Approved',
                      description: 'Waiting for arrival',
                      value: '$approvedCount',
                      icon: Icons.check_circle_outline,
                      accent: AppColors.primary,
                      selected:
                          _statusFilter == SubmissionStatus.approved,
                      onTap: () => _filterByStatus(
                        SubmissionStatus.approved,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 500
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _FilterStatCard(
                      label: 'Ready to Stock In',
                      description: 'Items already received',
                      value: '$receivedCount',
                      icon: Icons.inventory_2_outlined,
                      accent: AppColors.roleStaff,
                      selected:
                          _statusFilter == SubmissionStatus.received,
                      onTap: () => _filterByStatus(
                        SubmissionStatus.received,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 500
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _FilterStatCard(
                      label: 'Stocked In',
                      description: 'Completed donations',
                      value: '$stockedCount',
                      icon: Icons.done_all_outlined,
                      accent: AppColors.primary,
                      selected:
                          _statusFilter == SubmissionStatus.stocked,
                      onTap: () => _filterByStatus(
                        SubmissionStatus.stocked,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _FilterStatCard(
                    label: 'Pending Review',
                    description: 'Needs manager decision',
                    value: '$pendingCount',
                    icon: Icons.schedule_outlined,
                    accent: AppColors.warning,
                    selected:
                        _statusFilter == SubmissionStatus.pending,
                    onTap: () => _filterByStatus(
                      SubmissionStatus.pending,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FilterStatCard(
                    label: 'Approved',
                    description: 'Waiting for arrival',
                    value: '$approvedCount',
                    icon: Icons.check_circle_outline,
                    accent: AppColors.primary,
                    selected:
                        _statusFilter == SubmissionStatus.approved,
                    onTap: () => _filterByStatus(
                      SubmissionStatus.approved,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FilterStatCard(
                    label: 'Ready to Stock In',
                    description: 'Items already received',
                    value: '$receivedCount',
                    icon: Icons.inventory_2_outlined,
                    accent: AppColors.roleStaff,
                    selected:
                        _statusFilter == SubmissionStatus.received,
                    onTap: () => _filterByStatus(
                      SubmissionStatus.received,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FilterStatCard(
                    label: 'Stocked In',
                    description: 'Completed donations',
                    value: '$stockedCount',
                    icon: Icons.done_all_outlined,
                    accent: AppColors.primary,
                    selected:
                        _statusFilter == SubmissionStatus.stocked,
                    onTap: () => _filterByStatus(
                      SubmissionStatus.stocked,
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // ============================================================
        // SEARCH + STATUS FILTER
        // ============================================================
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                  ),
                  hintText: 'Search by donor',
                  isDense: true,
                ),
              ),
            ),

            // Status dropdown remains available for All and Rejected,
            // in addition to the clickable workflow cards above.
            AppDropdown<SubmissionStatus?>(
              label: _statusFilter == null
                  ? 'All statuses'
                  : _statusMeta(_statusFilter!).$1,
              options: [
                const AppDropdownOption(
                  null,
                  'All statuses',
                ),
                for (final status in SubmissionStatus.values)
                  AppDropdownOption(
                    status,
                    _statusMeta(status).$1,
                  ),
              ],
              onSelect: (value) {
                setState(() {
                  _statusFilter = value;
                });
              },
            ),

            // Shows a small reset shortcut when a status filter is active.
            if (_statusFilter != null)
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _statusFilter = null;
                  });
                },
                icon: const Icon(
                  Icons.close,
                  size: 16,
                ),
                label: const Text(
                  'Clear filter',
                ),
              ),
          ],
        ),

        const SizedBox(height: 20),

        // ============================================================
        // SUBMISSION LIST
        // ============================================================
        if (_submissions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 56,
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.volunteer_activism_outlined,
                    size: 36,
                    color: AppColors.mutedForeground,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No donations yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 48,
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 32,
                    color: AppColors.mutedForeground,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No donations match your filters.',
                    style: TextStyle(
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border,
              ),
            ),

            // AppShell already handles scrolling, so this remains a plain Column.
            child: Column(
              children: [
                // Desktop column headings.
                if (MediaQuery.of(context).size.width >= 700) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _TableHeader(
                            'Donor',
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _TableHeader(
                            'Submitted',
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: _TableHeader(
                            'Drop-off',
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: _TableHeader(
                            'Status',
                          ),
                        ),
                        SizedBox(
                          width: 130,
                          child: _TableHeader(
                            '',
                          ),
                        ),
                        SizedBox(
                          width: 30,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],

                for (var i = 0; i < _filtered.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                    ),

                  _SubmissionRow(
                    submission: _filtered[i],
                    statusMeta:
                        _statusMeta(_filtered[i].status),
                    isMobile:
                        MediaQuery.of(context).size.width < 700,

                    // Opens the submission and reloads the database
                    // automatically when staff returns.
                    onOpen: () => _openSubmission(
                      _filtered[i],
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

// ============================================================================
// CLICKABLE FILTER CARD
// ============================================================================

/// Dashboard-style summary card used as a shortcut for filtering donations.
///
/// Hovering gives staff visual feedback on desktop, while clicking the card
/// immediately filters the submission list below.
class _FilterStatCard extends StatefulWidget {
  final String label;
  final String description;
  final String value;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _FilterStatCard({
    required this.label,
    required this.description,
    required this.value,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_FilterStatCard> createState() =>
      _FilterStatCardState();
}

class _FilterStatCardState extends State<_FilterStatCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.selected || _hovering;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) {
        setState(() {
          _hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovering = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 150,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.accent.withValues(alpha: 0.08)
                : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlighted
                  ? widget.accent.withValues(alpha: 0.65)
                  : AppColors.border,
              width: widget.selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: widget.accent.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: Icon(
                  widget.icon,
                  size: 20,
                  color: widget.accent,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: widget.selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: AppColors.foreground,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      widget.description,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color:
                            AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: widget.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SUBMISSION ROW
// ============================================================================

class _SubmissionRow extends StatelessWidget {
  final DonationSubmission submission;
  final (String, Color) statusMeta;
  final bool isMobile;

  // Opens the submission detail page.
  final VoidCallback onOpen;

  const _SubmissionRow({
    required this.submission,
    required this.statusMeta,
    required this.isMobile,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final sub = submission;
    final (statusLabel, statusColor) = statusMeta;

    // Passive status badge. All actual workflow actions are handled inside
    // SubmissionDetailPage to avoid duplicate buttons on the list page.
    final statusBadge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(
          alpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      ),
    );

    // Indicates that the submission contains a donor proof image.
    final proofIndicator =
        sub.proofImg != null &&
                sub.proofImg!.trim().isNotEmpty
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 15,
                    color:
                        AppColors.mutedForeground,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Proof attached',
                    style: TextStyle(
                      fontSize: 11.5,
                      color:
                          AppColors.mutedForeground,
                    ),
                  ),
                ],
              )
            : const SizedBox.shrink();

    return HoverableRow(
      // Opens the complete submission details.
      //
      // The DonationsPage handles refreshing when staff returns.
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        child: isMobile
            ? Row(
                crossAxisAlignment:
                    CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                sub.donorName,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            statusBadge,
                          ],
                        ),

                        const SizedBox(height: 6),

                        Wrap(
                          spacing: 12,
                          runSpacing: 5,
                          children: [
                            Text(
                              'Submitted ${_formatDate(sub.dateSub)}',
                              style:
                                  const TextStyle(
                                fontSize: 12,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),
                            Text(
                              sub.schedDate == null
                                  ? 'No drop-off date'
                                  : 'Drop-off ${_formatDate(sub.schedDate!)}',
                              style:
                                  const TextStyle(
                                fontSize: 12,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),
                            proofIndicator,
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.mutedForeground,
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      sub.donorName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatDate(sub.dateSub),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color:
                            AppColors.mutedForeground,
                      ),
                    ),
                  ),

                  Expanded(
                    flex: 2,
                    child: Text(
                      sub.schedDate == null
                          ? 'Not specified'
                          : _formatDate(sub.schedDate!),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color:
                            AppColors.mutedForeground,
                      ),
                    ),
                  ),

                  SizedBox(
                    width: 130,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: statusBadge,
                    ),
                  ),

                  SizedBox(
                    width: 130,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: proofIndicator,
                    ),
                  ),

                  const SizedBox(
                    width: 30,
                    child: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color:
                          AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ============================================================================
// TABLE HEADER
// ============================================================================

class _TableHeader extends StatelessWidget {
  final String label;

  const _TableHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: AppColors.mutedForeground,
      ),
    );
  }
}

// ============================================================================
// DATE FORMATTING
// ============================================================================

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

// Converts the submission date into a readable format such as Aug 11, 2026.
String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';