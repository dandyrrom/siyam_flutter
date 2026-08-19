import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../models/donation.dart';
import '../../services/donation_service.dart';
import '../../state/auth_state.dart';
import '../../state/data_bus.dart';

// Controls the donor-friendly history filters shown at the top of the page.
enum _DonationHistoryFilter {
  all,
  review,
  inProgress,
  completed,
}

class DonorDonationsPage extends StatefulWidget {
  const DonorDonationsPage({super.key});

  @override
  State<DonorDonationsPage> createState() => _DonorDonationsPageState();
}

class _DonorDonationsPageState extends State<DonorDonationsPage>
    with DataBusRefreshMixin<DonorDonationsPage> {
  final DonationService _service = DonationService();

  List<DonationSubmission> _submissions = [];

  bool _loading = true;
  String? _error;

  _DonationHistoryFilter _filter = _DonationHistoryFilter.all;

  @override
  void initState() {
    super.initState();

    // Loads the logged-in donor's submissions when the page opens.
    _load();
  }

  @override
  void onExternalDataChanged() {
    // Refreshes the page when donation data changes elsewhere in the system.
    _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    final donorId =
        context.read<AuthController>().profile?.userId;

    if (donorId == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Gets only the logged-in donor's submissions.
      final rows =
          await _service.fetchSubmissions(donorId: donorId);

      if (!mounted) return;

      setState(() {
        _submissions = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error = 'Could not load your donations: $e';
          _loading = false;
        });
      }
    }
  }

  // Returns donor-friendly labels instead of internal workflow terminology.
  (String, Color) _statusMeta(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.pending:
        return (
          'Under Review',
          AppColors.warning,
        );

      case SubmissionStatus.approved:
        return (
          'Accepted',
          AppColors.primary,
        );

      case SubmissionStatus.received:
        return (
          'Received by Shelter',
          AppColors.primary,
        );

      case SubmissionStatus.stocked:
        return (
          'Completed',
          AppColors.primary,
        );

      case SubmissionStatus.rejected:
        return (
          'Not Accepted',
          AppColors.destructive,
        );
    }
  }

  // Provides a clear explanation of what each donation status means.
  String _statusDescription(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.pending:
        return 'Your donation request was submitted successfully and is '
            'currently waiting for shelter staff to review it.';

      case SubmissionStatus.approved:
        return 'Your donation has been accepted. You can proceed with the '
            'planned drop-off or delivery of your donated items.';

      case SubmissionStatus.received:
        return 'The shelter has confirmed receiving your donation. Your '
            'items are now being prepared for recording in the shelter inventory.';

      case SubmissionStatus.stocked:
        return 'Your donated items have been successfully recorded and are '
            'now available to support the shelter and the animals in its care.';

      case SubmissionStatus.rejected:
        return 'The shelter was unable to accept this donation request. '
            'You may contact the shelter if you need more information.';
    }
  }

  // Returns the submissions that match the selected donor-friendly filter.
  List<DonationSubmission> get _filteredSubmissions {
    return _submissions.where((submission) {
      switch (_filter) {
        case _DonationHistoryFilter.all:
          return true;

        case _DonationHistoryFilter.review:
          return submission.status ==
              SubmissionStatus.pending;

        case _DonationHistoryFilter.inProgress:
          return submission.status ==
                  SubmissionStatus.approved ||
              submission.status ==
                  SubmissionStatus.received;

        case _DonationHistoryFilter.completed:
          return submission.status ==
              SubmissionStatus.stocked;
      }
    }).toList();
  }

  void _setFilter(_DonationHistoryFilter filter) {
    setState(() {
      _filter = filter;
    });
  }

  Future<void> _openDetailDialog(
    DonationSubmission sub,
  ) async {
    final bool isMobile =
        MediaQuery.of(context).size.width < 600;

    List<DonationLineItem>? items;
    String? itemsError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            context,
            setDialogState,
          ) {
            // Completed donations can show the items that were actually
            // received and recorded by shelter staff.
            if (sub.status ==
                    SubmissionStatus.stocked &&
                items == null &&
                itemsError == null) {
              _service
                  .fetchReceivedItems(sub.subId)
                  .then((rows) {
                if (!context.mounted) return;

                setDialogState(() {
                  items = rows;
                });
              }).catchError((e) {
                if (!context.mounted) return;

                setDialogState(() {
                  itemsError =
                      'Could not load donated items.';
                });
              });
            }

            final (statusLabel, statusColor) =
                _statusMeta(sub.status);

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(20),
              ),
              titlePadding:
                  const EdgeInsets.fromLTRB(
                22,
                20,
                12,
                0,
              ),
              contentPadding:
                  const EdgeInsets.fromLTRB(
                22,
                18,
                22,
                10,
              ),
              actionsPadding:
                  const EdgeInsets.fromLTRB(
                16,
                4,
                16,
                14,
              ),

              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Donation Details',
                      style: TextStyle(
                        fontSize:
                            isMobile ? 18 : 20,
                        fontWeight:
                            FontWeight.w700,
                      ),
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
                    ),
                  ),
                ],
              ),

              content: SizedBox(
                width: isMobile
                    ? double.infinity
                    : 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize:
                        MainAxisSize.min,
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ==============================================
                      // STATUS
                      // ==============================================
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(14),
                        decoration:
                            BoxDecoration(
                          color: statusColor
                              .withValues(
                            alpha: 0.06,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                                  12),
                          border: Border.all(
                            color: statusColor
                                .withValues(
                              alpha: 0.22,
                            ),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration:
                                  BoxDecoration(
                                color: statusColor
                                    .withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                            10),
                              ),
                              child: Icon(
                                _statusIcon(
                                  sub.status,
                                ),
                                size: 19,
                                color:
                                    statusColor,
                              ),
                            ),

                            const SizedBox(
                                width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                children: [
                                  Text(
                                    statusLabel,
                                    style:
                                        TextStyle(
                                      fontSize:
                                          14,
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                      color:
                                          statusColor,
                                    ),
                                  ),
                                  const SizedBox(
                                      height: 4),
                                  Text(
                                    _statusDescription(
                                      sub.status,
                                    ),
                                    style:
                                        const TextStyle(
                                      fontSize:
                                          12.5,
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

                      const SizedBox(height: 20),

                      const _DialogSectionLabel(
                        'Donation Timeline',
                      ),

                      const SizedBox(height: 10),

                      _DetailRow(
                        label: 'Submitted',
                        value: _formatDate(
                          sub.dateSub,
                        ),
                      ),

                      _DetailRow(
                        label:
                            'Preferred drop-off',
                        value: sub.schedDate ==
                                null
                            ? 'Not specified'
                            : _formatDate(
                                sub.schedDate!,
                              ),
                      ),

                      if (sub.dateReceived !=
                          null)
                        _DetailRow(
                          label:
                              'Received by shelter',
                          value: _formatDate(
                            sub.dateReceived!,
                          ),
                        ),

                      if (sub.updatedByName !=
                          null)
                        _DetailRow(
                          label: 'Reviewed by',
                          value:
                              sub.updatedByName!,
                        ),

                      if (sub.notes?.trim().isNotEmpty ??
                          false) ...[
                        const SizedBox(
                            height: 10),

                        const _DialogSectionLabel(
                          'Your Note',
                        ),

                        const SizedBox(height: 8),

                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(
                                  14),
                          decoration:
                              BoxDecoration(
                            color:
                                AppColors.card,
                            borderRadius:
                                BorderRadius
                                    .circular(12),
                            border:
                                Border.all(
                              color:
                                  AppColors.border,
                            ),
                          ),
                          child: Text(
                            sub.notes!,
                            style:
                                const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],

                      // ==============================================
                      // ITEMS RECEIVED
                      // ==============================================
                      if (sub.status ==
                          SubmissionStatus
                              .stocked) ...[
                        const SizedBox(
                            height: 20),

                        const _DialogSectionLabel(
                          'Items Received',
                        ),

                        const SizedBox(height: 4),

                        const Text(
                          'These are the items recorded by the shelter from this donation.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors
                                .mutedForeground,
                          ),
                        ),

                        const SizedBox(
                            height: 10),

                        if (itemsError != null)
                          Container(
                            width:
                                double.infinity,
                            padding:
                                const EdgeInsets
                                    .all(12),
                            decoration:
                                BoxDecoration(
                              color: AppColors
                                  .destructive
                                  .withValues(
                                alpha: 0.06,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                          10),
                            ),
                            child: Text(
                              itemsError!,
                              style:
                                  const TextStyle(
                                fontSize: 12.5,
                                color: AppColors
                                    .destructive,
                              ),
                            ),
                          )
                        else if (items == null)
                          const Padding(
                            padding:
                                EdgeInsets
                                    .symmetric(
                              vertical: 18,
                            ),
                            child: Center(
                              child:
                                  CircularProgressIndicator(),
                            ),
                          )
                        else if (items!.isEmpty)
                          const Text(
                            'No item details are available for this donation.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors
                                  .mutedForeground,
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
                                          12),
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
                                        items!
                                            .length;
                                    i++) ...[
                                  if (i > 0)
                                    const Divider(
                                      height: 1,
                                    ),

                                  Padding(
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      horizontal:
                                          14,
                                      vertical:
                                          12,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child:
                                              Text(
                                            items![i]
                                                .itemName,
                                            style:
                                                const TextStyle(
                                              fontWeight:
                                                  FontWeight
                                                      .w600,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(
                                            width:
                                                12),
                                        Text(
                                          '${items![i].qty} ${items![i].itemUom}',
                                          style:
                                              const TextStyle(
                                            fontSize:
                                                12.5,
                                            color: AppColors
                                                .mutedForeground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // The X button already closes the dialog,
              // so there is no redundant "Close" text button.
              actions: const [],
            );
          },
        );
      },
    );
  }

  IconData _statusIcon(
    SubmissionStatus status,
  ) {
    switch (status) {
      case SubmissionStatus.pending:
        return Icons.schedule_outlined;

      case SubmissionStatus.approved:
        return Icons
            .check_circle_outline;

      case SubmissionStatus.received:
        return Icons
            .local_shipping_outlined;

      case SubmissionStatus.stocked:
        return Icons.done_all_outlined;

      case SubmissionStatus.rejected:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile =
        MediaQuery.of(context).size.width < 600;

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

    final reviewCount = _submissions
        .where(
          (s) =>
              s.status ==
              SubmissionStatus.pending,
        )
        .length;

    final inProgressCount = _submissions
        .where(
          (s) =>
              s.status ==
                  SubmissionStatus.approved ||
              s.status ==
                  SubmissionStatus.received,
        )
        .length;

    final completedCount = _submissions
        .where(
          (s) =>
              s.status ==
              SubmissionStatus.stocked,
        )
        .length;

    final filteredSubmissions =
        _filteredSubmissions;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // ============================================================
        // HEADER
        // ============================================================
        if (isMobile)
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'My Donations',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 4),

              const Text(
                'Track your donation requests and see when your items are received by the shelter.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color:
                      AppColors.mutedForeground,
                ),
              ),

              const SizedBox(height: 14),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await context.push(
                      '/donate',
                    );

                    if (!mounted) return;

                    await _load();
                  },
                  icon: const Icon(
                    Icons.favorite_outline,
                    size: 18,
                  ),
                  label: const Text(
                    'Make a Donation',
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Donations',
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Track your donation requests and see when your items are received by the shelter.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 20),

              ElevatedButton.icon(
                onPressed: () async {
                  await context.push(
                    '/donate',
                  );

                  if (!mounted) return;

                  await _load();
                },
                icon: const Icon(
                  Icons.favorite_outline,
                  size: 18,
                ),
                label: const Text(
                  'Make a Donation',
                ),
              ),
            ],
          ),

        const SizedBox(height: 24),

        // ============================================================
        // CLICKABLE DONATION HISTORY FILTERS
        // ============================================================
        LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final compact =
                constraints.maxWidth < 760;

            final cardWidth =
                constraints.maxWidth < 500
                    ? constraints.maxWidth
                    : (constraints.maxWidth -
                            12) /
                        2;

            if (compact) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child:
                        _DonationFilterCard(
                      label:
                          'All Donations',
                      description:
                          'Your complete history',
                      value:
                          '${_submissions.length}',
                      icon: Icons
                          .volunteer_activism_outlined,
                      accent:
                          AppColors.roleDonor,
                      selected: _filter ==
                          _DonationHistoryFilter
                              .all,
                      onTap: () =>
                          _setFilter(
                        _DonationHistoryFilter
                            .all,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child:
                        _DonationFilterCard(
                      label:
                          'Under Review',
                      description:
                          'Waiting for staff review',
                      value:
                          '$reviewCount',
                      icon: Icons
                          .schedule_outlined,
                      accent:
                          AppColors.warning,
                      selected: _filter ==
                          _DonationHistoryFilter
                              .review,
                      onTap: () =>
                          _setFilter(
                        _DonationHistoryFilter
                            .review,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child:
                        _DonationFilterCard(
                      label:
                          'In Progress',
                      description:
                          'Accepted or received',
                      value:
                          '$inProgressCount',
                      icon: Icons
                          .local_shipping_outlined,
                      accent:
                          AppColors.primary,
                      selected: _filter ==
                          _DonationHistoryFilter
                              .inProgress,
                      onTap: () =>
                          _setFilter(
                        _DonationHistoryFilter
                            .inProgress,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child:
                        _DonationFilterCard(
                      label: 'Completed',
                      description:
                          'Recorded by the shelter',
                      value:
                          '$completedCount',
                      icon: Icons
                          .done_all_outlined,
                      accent:
                          AppColors.primary,
                      selected: _filter ==
                          _DonationHistoryFilter
                              .completed,
                      onTap: () =>
                          _setFilter(
                        _DonationHistoryFilter
                            .completed,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child:
                      _DonationFilterCard(
                    label: 'All Donations',
                    description:
                        'Your complete history',
                    value:
                        '${_submissions.length}',
                    icon: Icons
                        .volunteer_activism_outlined,
                    accent:
                        AppColors.roleDonor,
                    selected: _filter ==
                        _DonationHistoryFilter
                            .all,
                    onTap: () => _setFilter(
                      _DonationHistoryFilter
                          .all,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child:
                      _DonationFilterCard(
                    label: 'Under Review',
                    description:
                        'Waiting for staff review',
                    value: '$reviewCount',
                    icon: Icons
                        .schedule_outlined,
                    accent:
                        AppColors.warning,
                    selected: _filter ==
                        _DonationHistoryFilter
                            .review,
                    onTap: () => _setFilter(
                      _DonationHistoryFilter
                          .review,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child:
                      _DonationFilterCard(
                    label: 'In Progress',
                    description:
                        'Accepted or received',
                    value:
                        '$inProgressCount',
                    icon: Icons
                        .local_shipping_outlined,
                    accent:
                        AppColors.primary,
                    selected: _filter ==
                        _DonationHistoryFilter
                            .inProgress,
                    onTap: () => _setFilter(
                      _DonationHistoryFilter
                          .inProgress,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child:
                      _DonationFilterCard(
                    label: 'Completed',
                    description:
                        'Recorded by the shelter',
                    value:
                        '$completedCount',
                    icon: Icons
                        .done_all_outlined,
                    accent:
                        AppColors.primary,
                    selected: _filter ==
                        _DonationHistoryFilter
                            .completed,
                    onTap: () => _setFilter(
                      _DonationHistoryFilter
                          .completed,
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 22),

        // ============================================================
        // HISTORY SECTION
        // ============================================================
        Row(
          children: [
            const Expanded(
              child: Text(
                'Donation History',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            if (_filter !=
                _DonationHistoryFilter.all)
              TextButton.icon(
                onPressed: () =>
                    _setFilter(
                  _DonationHistoryFilter.all,
                ),
                icon: const Icon(
                  Icons.close,
                  size: 16,
                ),
                label:
                    const Text('Show all'),
              ),
          ],
        ),

        const SizedBox(height: 4),

        Text(
          '${filteredSubmissions.length} ${filteredSubmissions.length == 1 ? 'donation' : 'donations'} shown',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.mutedForeground,
          ),
        ),

        const SizedBox(height: 12),

        if (_submissions.isEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(
              vertical: 56,
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons
                        .volunteer_activism_outlined,
                    size: 38,
                    color: AppColors
                        .mutedForeground,
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'You haven\'t made a donation yet',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    'Your donation requests and their progress will appear here.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    onPressed: () async {
                      await context.push(
                        '/donate',
                      );

                      if (!mounted) return;

                      await _load();
                    },
                    icon: const Icon(
                      Icons.favorite_outline,
                      size: 18,
                    ),
                    label: const Text(
                      'Make Your First Donation',
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (filteredSubmissions
            .isEmpty)
          Padding(
            padding:
                const EdgeInsets.symmetric(
              vertical: 48,
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons
                        .filter_alt_off_outlined,
                    size: 34,
                    color: AppColors
                        .mutedForeground,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No donations in this stage',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose another category to view the rest of your donation history.',
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () =>
                        _setFilter(
                      _DonationHistoryFilter
                          .all,
                    ),
                    child: const Text(
                      'View all donations',
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
                        filteredSubmissions
                            .length;
                    i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                    ),

                  _SubmissionRow(
                    submission:
                        filteredSubmissions[i],
                    statusMeta: _statusMeta(
                      filteredSubmissions[i]
                          .status,
                    ),
                    onTap: () =>
                        _openDetailDialog(
                      filteredSubmissions[i],
                    ),
                    isMobile: isMobile,
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
// CLICKABLE DONATION FILTER CARD
// ============================================================================

class _DonationFilterCard extends StatefulWidget {
  final String label;
  final String description;
  final String value;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _DonationFilterCard({
    required this.label,
    required this.description,
    required this.value,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_DonationFilterCard> createState() =>
      _DonationFilterCardState();
}

class _DonationFilterCardState
    extends State<_DonationFilterCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final highlighted =
        widget.selected || _hovering;

    return MouseRegion(
      cursor:
          SystemMouseCursors.click,
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
          padding:
              const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.selected
                ? widget.accent
                    .withValues(
                        alpha: 0.07)
                : AppColors.card,
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color: highlighted
                  ? widget.accent
                      .withValues(
                          alpha: 0.65)
                  : AppColors.border,
              width:
                  widget.selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration:
                    BoxDecoration(
                  color: widget.accent
                      .withValues(
                          alpha: 0.10),
                  borderRadius:
                      BorderRadius.circular(
                          10),
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
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      widget.label,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            widget.selected
                                ? FontWeight
                                    .w700
                                : FontWeight
                                    .w600,
                      ),
                    ),

                    const SizedBox(
                        height: 2),

                    Text(
                      widget.description,
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

              const SizedBox(width: 8),

              Text(
                widget.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight:
                      FontWeight.w800,
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
// DONATION HISTORY ROW
// ============================================================================

class _SubmissionRow extends StatelessWidget {
  final DonationSubmission submission;
  final (String, Color) statusMeta;
  final VoidCallback onTap;
  final bool isMobile;

  const _SubmissionRow({
    required this.submission,
    required this.statusMeta,
    required this.onTap,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    final sub = submission;
    final (statusLabel, statusColor) =
        statusMeta;

    final statusBadge = Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: statusColor.withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(
          fontSize:
              isMobile ? 10.5 : 11.5,
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      ),
    );

    return _HoverableDonationRow(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal:
              isMobile ? 14 : 18,
          vertical:
              isMobile ? 13 : 15,
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            // Donation status icon.
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: statusColor
                    .withValues(
                  alpha: 0.08,
                ),
                borderRadius:
                    BorderRadius.circular(
                        10),
              ),
              child: Icon(
                _rowStatusIcon(
                    sub.status),
                size: 19,
                color: statusColor,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  Text(
                    'Donation submitted ${_formatDate(sub.dateSub)}',
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      fontSize:
                          isMobile
                              ? 13.5
                              : 14.5,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    sub.schedDate == null
                        ? 'No preferred drop-off date'
                        : 'Preferred drop-off: ${_formatDate(sub.schedDate!)}',
                    style:
                        const TextStyle(
                      fontSize: 12,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),

                  // On mobile, the status sits below the date
                  // so the layout stays readable.
                  if (isMobile) ...[
                    const SizedBox(height: 7),

                    Align(
                      alignment:
                          Alignment.centerLeft,
                      child: statusBadge,
                    ),
                  ],
                ],
              ),
            ),

            // On desktop, the status gets a dedicated centered area
            // so every badge lines up vertically and horizontally.
            if (!isMobile) ...[
              const SizedBox(width: 16),

              SizedBox(
                width: 160,
                child: Center(
                  child: statusBadge,
                ),
              ),
            ],

            const SizedBox(width: 8),

            const SizedBox(
              width: 24,
              child: Center(
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HOVERABLE HISTORY ROW
// ============================================================================

class _HoverableDonationRow extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _HoverableDonationRow({
    required this.child,
    required this.onTap,
  });

  @override
  State<_HoverableDonationRow>
      createState() =>
          _HoverableDonationRowState();
}

class _HoverableDonationRowState
    extends State<_HoverableDonationRow> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          SystemMouseCursors.click,
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
      child: InkWell(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 120,
          ),
          color: _hovering
              ? AppColors.muted
                  .withValues(alpha: 0.35)
              : Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

// ============================================================================
// DETAIL DIALOG HELPERS
// ============================================================================

class _DialogSectionLabel extends StatelessWidget {
  final String text;

  const _DialogSectionLabel(
    this.text,
  );

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
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
          const EdgeInsets.only(
        bottom: 11,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
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

// ============================================================================
// STATUS ICON
// ============================================================================

IconData _rowStatusIcon(
  SubmissionStatus status,
) {
  switch (status) {
    case SubmissionStatus.pending:
      return Icons.schedule_outlined;

    case SubmissionStatus.approved:
      return Icons
          .check_circle_outline;

    case SubmissionStatus.received:
      return Icons
          .local_shipping_outlined;

    case SubmissionStatus.stocked:
      return Icons.done_all_outlined;

    case SubmissionStatus.rejected:
      return Icons.cancel_outlined;
  }
}

// ============================================================================
// DATE FORMAT
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

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';