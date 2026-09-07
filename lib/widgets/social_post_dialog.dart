import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../services/dashboard_service.dart';
import '../services/donation_service.dart';

// =============================================================================
// SUPPLY NEEDS CAPTION
// =============================================================================

String buildReplenishmentCaption(
  List<ReplenishmentAlert> alerts, {
  String shelterName = 'Dumaguete Animal Sanctuary',
}) {
  final critical = alerts
      .where(
        (alert) =>
            alert.priority ==
            ReplenishmentPriority.critical,
      )
      .toList();

  final high = alerts
      .where(
        (alert) =>
            alert.priority ==
            ReplenishmentPriority.high,
      )
      .toList();

  final medium = alerts
      .where(
        (alert) =>
            alert.priority ==
            ReplenishmentPriority.medium,
      )
      .toList();

  String remainingLine(
    ReplenishmentAlert alert,
  ) {
    return '• ${alert.itemName} — '
        '${formatQty(alert.stockQty)} '
        '${alert.unitAbbr} remaining';
  }

  String criticalLine(
    ReplenishmentAlert alert,
  ) {
    return '• ${alert.itemName} — OUT OF STOCK';
  }

  final buffer = StringBuffer();

  if (alerts.isEmpty) {
    buffer
      ..writeln(
        'A little update from $shelterName 🐾',
      )
      ..writeln()
      ..writeln(
        'Today our supply shelves are in good shape, and that is because '
        'people continue to remember the animals in our care. Every bag, '
        'bottle, box and small donation helps our team get through another '
        'day of feeding, cleaning and caring for our rescues.',
      )
      ..writeln()
      ..writeln(
        'Thank you to our staff, volunteers and supporters who keep showing '
        'up for the animals. We are very grateful for you. ❤️',
      )
      ..writeln()
      ..writeln(
        'Please like, comment and share this post so more people can continue '
        'to see updates from the sanctuary.',
      )
      ..writeln()
      ..writeln(
        'Every Life Matters.',
      )
      ..writeln()
      ..write(
        '#DumagueteAnimalSanctuary #EveryLifeMatters',
      );

    return buffer.toString();
  }

  buffer
    ..writeln(
      'A little update from $shelterName 🐾',
    )
    ..writeln()
    ..writeln(
      'Every day our team is feeding, cleaning, treating and caring for the '
      'animals who depend on us. Some of the supplies we use for them are '
      'running low, and we could really use a little help keeping the shelves '
      'ready for the days ahead.',
    )
    ..writeln()
    ..writeln(
      'These are the supplies we currently need:',
    );

  if (critical.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(
        '🔴 URGENTLY NEEDED',
      );

    for (final alert in critical) {
      buffer.writeln(
        criticalLine(alert),
      );
    }
  }

  if (high.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(
        '🟠 RUNNING LOW',
      );

    for (final alert in high) {
      buffer.writeln(
        remainingLine(alert),
      );
    }
  }

  if (medium.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(
        '🟡 ALSO NEEDED',
      );

    for (final alert in medium) {
      buffer.writeln(
        remainingLine(alert),
      );
    }
  }

  buffer
    ..writeln()
    ..writeln(
      'If you can help with any of these supplies, please send us a message '
      'so we can coordinate drop-off. For medicines or veterinary supplies, '
      'please message us first so we can confirm what is currently needed.',
    )
    ..writeln()
    ..writeln(
      'Please like, comment and share this post as soon as you see it. '
      'Sharing helps this update reach more people who may be able to help '
      'the animals.',
    )
    ..writeln()
    ..writeln(
      'Thank you to our staff, volunteers and supporters who continue to '
      'show up for the rescues every day. Every contribution, big or small, '
      'helps us keep going. ❤️',
    )
    ..writeln()
    ..writeln(
      'Special thanks to [add staff / volunteer / editor name here] for '
      'helping with this update.',
    )
    ..writeln()
    ..writeln(
      'DONATION DETAILS',
    )
    ..writeln(
      'GCash — Christine Askew',
    )
    ..writeln(
      '• Number: [Add official DAS GCash number]',
    )
    ..writeln()
    ..writeln(
      'BDO',
    )
    ..writeln(
      '• Account name: [Add official DAS account name]',
    )
    ..writeln(
      '• Account number: [Add official DAS BDO account number]',
    )
    ..writeln()
    ..writeln(
      'Every Life Matters.',
    )
    ..writeln()
    ..write(
      '#DumagueteAnimalSanctuary #EveryLifeMatters',
    );

  return buffer.toString();
}

// =============================================================================
// DONOR THANK-YOU CAPTION
// =============================================================================

String buildDonorThankYouCaption({
  required DateTime month,
  required List<String> donorNames,
}) {
  final monthLabel =
      '${_monthNames[month.month - 1]} ${month.year}';

  final buffer = StringBuffer();

  buffer
    ..writeln(
      '💚 A heartfelt thank you to our $monthLabel donors!',
    )
    ..writeln()
    ..writeln(
      'We are incredibly grateful to everyone who supported '
      'Dumaguete Animal Sanctuary this month. Your generosity helps us '
      'continue feeding, treating, protecting and caring for the animals '
      'who depend on us every day.',
    );

  if (donorNames.isNotEmpty) {
    buffer
      ..writeln()
      ..writeln(
        'A special thank you to:',
      )
      ..writeln();

    for (final name in donorNames) {
      buffer.writeln(
        '• $name',
      );
    }
  }

  buffer
    ..writeln()
    ..writeln(
      'Every donation, big or small, makes a real difference in the lives '
      'of our rescues. Thank you for being part of their journey and for '
      'continuing to stand with the sanctuary. 🐾❤️',
    )
    ..writeln()
    ..writeln(
      'Every Life Matters.',
    )
    ..writeln()
    ..write(
      '#DumagueteAnimalSanctuary #EveryLifeMatters #ThankYou',
    );

  return buffer.toString();
}

// =============================================================================
// DIALOG ENTRY POINT
// =============================================================================

Future<void> showSocialPostDialog(
  BuildContext context, {
  required List<ReplenishmentAlert> alerts,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (
      dialogContext,
    ) {
      return _SocialPostDialog(
        alerts: alerts,
      );
    },
  );
}

// =============================================================================
// SOCIAL POST DIALOG
// =============================================================================

class _SocialPostDialog
    extends StatefulWidget {
  final List<ReplenishmentAlert> alerts;

  const _SocialPostDialog({
    required this.alerts,
  });

  @override
  State<_SocialPostDialog> createState() =>
      _SocialPostDialogState();
}

class _SocialPostDialogState
    extends State<_SocialPostDialog> {
  final DonationService _donationService =
      DonationService();

  late final TextEditingController
      _supplyCaptionCtrl;

  late final TextEditingController
      _donorCaptionCtrl;

  final TextEditingController _searchCtrl =
      TextEditingController();

  int _selectedTab = 0;

  DateTime _selectedMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    1,
  );

  MonthlyDonorSummary? _donorSummary;

  final Set<String> _includedDonors =
      <String>{};

  bool _loadingDonors = false;

  String? _donorError;

  @override
  void initState() {
    super.initState();

    _supplyCaptionCtrl =
        TextEditingController(
      text: buildReplenishmentCaption(
        widget.alerts,
      ),
    );

    _donorCaptionCtrl =
        TextEditingController();

    _searchCtrl.addListener(
      _onSearchChanged,
    );
  }

  @override
  void dispose() {
    _supplyCaptionCtrl.dispose();

    _donorCaptionCtrl.dispose();

    _searchCtrl
      ..removeListener(
        _onSearchChanged,
      )
      ..dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;

    setState(() {});
  }

  // ==========================================================================
  // TAB
  // ==========================================================================

  void _changeTab(
    int tab,
  ) {
    if (_selectedTab == tab) {
      return;
    }

    setState(() {
      _selectedTab = tab;
    });

    if (tab == 1 &&
        _donorSummary == null &&
        !_loadingDonors) {
      _loadDonorSummary();
    }
  }

  // ==========================================================================
  // DONOR SUMMARY
  // ==========================================================================

  Future<void> _loadDonorSummary() async {
    if (_loadingDonors) {
      return;
    }

    setState(() {
      _loadingDonors = true;
      _donorError = null;
    });

    try {
      final summary =
          await _donationService
              .fetchMonthlyDonorSummary(
        _selectedMonth,
      );

      if (!mounted) return;

      setState(() {
        _donorSummary = summary;

        _includedDonors
          ..clear()
          ..addAll(
            summary.donorNames,
          );

        _loadingDonors = false;
        _donorError = null;

        _searchCtrl.clear();
      });

      _regenerateDonorCaption();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loadingDonors = false;
        _donorError =
            'Could not load the donor summary for this month.';
      });
    }
  }

  void _regenerateDonorCaption() {
    final summary = _donorSummary;

    if (summary == null) {
      return;
    }

    final names = summary.donorNames
        .where(
          _includedDonors.contains,
        )
        .toList();

    _donorCaptionCtrl.text =
        buildDonorThankYouCaption(
      month: _selectedMonth,
      donorNames: names,
    );
  }

  void _toggleDonor(
    String name,
  ) {
    setState(() {
      if (_includedDonors.contains(
        name,
      )) {
        _includedDonors.remove(
          name,
        );
      } else {
        _includedDonors.add(
          name,
        );
      }
    });

    _regenerateDonorCaption();
  }

  List<String> get _filteredDonors {
    final donors =
        _donorSummary?.donorNames ??
        const <String>[];

    final query =
        _searchCtrl.text
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      return donors;
    }

    return donors
        .where(
          (name) =>
              name
                  .toLowerCase()
                  .contains(
                    query,
                  ),
        )
        .toList();
  }

  // ==========================================================================
  // MONTH
  // ==========================================================================

  List<DateTime> get _monthOptions {
    final current =
        DateTime(
      DateTime.now().year,
      DateTime.now().month,
      1,
    );

    return List.generate(
      24,
      (index) =>
          DateTime(
        current.year,
        current.month - index,
        1,
      ),
    );
  }

  Future<void> _changeMonth(
    DateTime? month,
  ) async {
    if (month == null) {
      return;
    }

    final sameMonth =
        month.year ==
                _selectedMonth.year &&
            month.month ==
                _selectedMonth.month;

    if (sameMonth) {
      return;
    }

    setState(() {
      _selectedMonth = month;
      _donorSummary = null;

      _includedDonors.clear();

      _donorCaptionCtrl.clear();

      _searchCtrl.clear();
    });

    await _loadDonorSummary();
  }

  // ==========================================================================
  // COPY
  // ==========================================================================

  Future<void> _copyCurrentCaption() async {
    final controller =
        _selectedTab == 0
            ? _supplyCaptionCtrl
            : _donorCaptionCtrl;

    await Clipboard.setData(
      ClipboardData(
        text: controller.text,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content: Text(
          'Caption copied',
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final screen =
        MediaQuery.sizeOf(
      context,
    );
final dialogWidth =
    screen.width < 1192
        ? screen.width - 32
        : 1160.0;

final dialogHeight =
    screen.height < 832
        ? screen.height - 32
        : 800.0;

final compact =
    dialogWidth < 780;

    return Dialog(
      backgroundColor:
          Colors.white,
      surfaceTintColor:
          Colors.white,
      insetPadding:
          const EdgeInsets.all(
        16,
      ),
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: Column(
          children: [
            // ================================================================
            // HEADER
            // ================================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                20,
                18,
                12,
                14,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration:
                        BoxDecoration(
                      color: AppColors
                          .roleStaff
                          .withValues(
                        alpha:
                            0.10,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        11,
                      ),
                    ),
                    alignment:
                        Alignment.center,
                    child:
                        const Icon(
                      Icons
                          .campaign_outlined,
                      size: 20,
                      color: AppColors
                          .roleStaff,
                    ),
                  ),

                  const SizedBox(
                    width: 11,
                  ),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Social Media Template',
                          style:
                              TextStyle(
                            fontSize:
                                18,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),

                        SizedBox(
                          height: 2,
                        ),

                        Text(
                          'Create ready-to-copy shelter posts',
                          style:
                              TextStyle(
                            fontSize:
                                11.5,
                            color: AppColors
                                .mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    tooltip: 'Close',
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    icon:
                        const Icon(
                      Icons.close,
                      size: 19,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 1,
            ),

            // ================================================================
            // TABS
            // ================================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                12,
                18,
                10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child:
                        _TemplateTab(
                      label:
                          'Supply Needs',
                      icon:
                          Icons
                              .inventory_2_outlined,
                      selected:
                          _selectedTab ==
                              0,
                      onTap: () {
                        _changeTab(
                          0,
                        );
                      },
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child:
                        _TemplateTab(
                      label:
                          'Donor Summary',
                      icon:
                          Icons
                              .volunteer_activism_outlined,
                      selected:
                          _selectedTab ==
                              1,
                      onTap: () {
                        _changeTab(
                          1,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const Divider(
              height: 1,
            ),

            // ================================================================
            // TAB CONTENT
            // ================================================================

            Expanded(
              child:
                  _selectedTab == 0
                      ? _buildSupplyTab()
                      : _buildDonorTab(
                          compact,
                        ),
            ),

            const Divider(
              height: 1,
            ),

            // ================================================================
            // FOOTER
            // ================================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                16,
                8,
                16,
                10,
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    child:
                        const Text(
                      'Close',
                    ),
                  ),

                  const SizedBox(
                    width: 6,
                  ),

                  ElevatedButton.icon(
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          AppColors
                              .roleStaff,
                    ),
                    onPressed:
                        _selectedTab ==
                                    1 &&
                                _loadingDonors
                            ? null
                            : _copyCurrentCaption,
                    icon:
                        const Icon(
                      Icons
                          .copy_outlined,
                      size: 16,
                    ),
                    label:
                        const Text(
                      'Copy caption',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SUPPLY NEEDS TAB
  // ==========================================================================

  Widget _buildSupplyTab() {
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
            'SUPPLY NEEDS POST',
            style:
                TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors
                      .mutedForeground,
              letterSpacing:
                  0.4,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          _EditableFacebookPreview(
            controller:
                _supplyCaptionCtrl,
            minLines: 14,
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DONOR THANK YOU TAB
  // ==========================================================================

  Widget _buildDonorTab(
    bool compact,
  ) {
    if (_loadingDonors) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_donorError != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons
                    .error_outline,
                size: 32,
                color: AppColors
                    .mutedForeground,
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                _donorError!,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontSize:
                      12.5,
                  color: AppColors
                      .mutedForeground,
                ),
              ),

              const SizedBox(
                height: 12,
              ),

              OutlinedButton(
                onPressed:
                    _loadDonorSummary,
                child:
                    const Text(
                  'Retry',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final summary =
        _donorSummary;

    if (summary == null) {
      return const SizedBox.shrink();
    }

    if (compact) {
      return SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          18,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildDonorLeftPanel(
              summary,
              fixedHeight:
                  false,
            ),

            const SizedBox(
              height: 18,
            ),

            _buildDonorPostPanel(),
          ],
        ),
      );
    }

    return Padding(
      padding:
          const EdgeInsets.all(
        18,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 360,
            child:
                _buildDonorLeftPanel(
              summary,
              fixedHeight:
                  true,
            ),
          ),

          const SizedBox(
            width: 18,
          ),

          Expanded(
            child:
                _buildDonorPostPanel(),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // DONOR LEFT PANEL
  // ==========================================================================

  Widget _buildDonorLeftPanel(
    MonthlyDonorSummary summary, {
    required bool fixedHeight,
  }) {
    final content = Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // ====================================================================
        // MONTH
        // ====================================================================

        const Text(
          'MONTH',
          style:
              TextStyle(
            fontSize: 11,
            fontWeight:
                FontWeight.w700,
            color:
                AppColors
                    .mutedForeground,
            letterSpacing:
                0.4,
          ),
        ),

        const SizedBox(
          height: 6,
        ),

        PopupMenuButton<DateTime>(
          popUpAnimationStyle: AnimationStyle.noAnimation,
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          constraints: const BoxConstraints(
            maxHeight: 320,
            minWidth: 320,
          ),
          color: AppColors.card,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          onSelected: (month) {
            _changeMonth(month);
          },
          itemBuilder: (context) {
            return _monthOptions
                .map(
                  (month) => PopupMenuItem<DateTime>(
                    value: month,
                    height: 44,
                    child: Text(
                      _monthLabel(month),
                      style: const TextStyle(
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                )
                .toList();
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _monthLabel(_selectedMonth),
                    style: const TextStyle(
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        const SizedBox(
          height: 18,
        ),

        // ====================================================================
        // MONTHLY SUMMARY
        // ====================================================================

        const Text(
          'MONTHLY SUMMARY',
          style:
              TextStyle(
            fontSize: 11,
            fontWeight:
                FontWeight.w700,
            color:
                AppColors
                    .mutedForeground,
            letterSpacing:
                0.4,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        Row(
          children: [
            Expanded(
              child:
                  _SummaryCard(
                value:
                    '${summary.donorCount}',
                label:
                    'Donors',
              ),
            ),

            const SizedBox(
              width: 7,
            ),

            Expanded(
              child:
                  _SummaryCard(
                value:
                    '${summary.donationCount}',
                label:
                    'Donations',
              ),
            ),

            const SizedBox(
              width: 7,
            ),

            Expanded(
              child:
                  _SummaryCard(
                value:
                    '${summary.itemsDonated}',
                label:
                    'Items',
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 18,
        ),

        // ====================================================================
        // DONORS
        // ====================================================================

        Row(
          children: [
            const Expanded(
              child: Text(
                'DONORS TO INCLUDE',
                style:
                    TextStyle(
                  fontSize:
                      11,
                  fontWeight:
                      FontWeight
                          .w700,
                  color: AppColors
                      .mutedForeground,
                  letterSpacing:
                      0.4,
                ),
              ),
            ),

            Text(
              '${_includedDonors.length} selected',
              style:
                  const TextStyle(
                fontSize:
                    10.5,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 7,
        ),

        if (summary.donorNames.isEmpty)
          Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              16,
            ),
            decoration:
                BoxDecoration(
              color:
                  AppColors.card,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              border:
                  Border.all(
                color:
                    AppColors.border,
              ),
            ),
            child:
                const Text(
              'No stocked donations were recorded for this month.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    12,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          )
        else ...[
          TextField(
            controller:
                _searchCtrl,
            decoration:
                const InputDecoration(
              isDense: true,
              hintText:
                  'Search donors',
              prefixIcon:
                  Icon(
                Icons.search,
                size: 18,
              ),
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          if (fixedHeight)
            Expanded(
              child:
                  _buildDonorList(),
            )
          else
            SizedBox(
              height: 230,
              child:
                  _buildDonorList(),
            ),
        ],
      ],
    );

    if (!fixedHeight) {
      return content;
    }

    return SizedBox(
      height:
          510,
      child:
          content,
    );
  }

  // ==========================================================================
  // DONOR LIST
  // ==========================================================================

  Widget _buildDonorList() {
    if (_filteredDonors.isEmpty) {
      return Container(
        decoration:
            BoxDecoration(
          border:
              Border.all(
            color:
                AppColors.border,
          ),
          borderRadius:
              BorderRadius.circular(
            12,
          ),
        ),
        child:
            const Center(
          child: Text(
            'No donors found.',
            style:
                TextStyle(
              fontSize: 12,
              color:
                  AppColors
                      .mutedForeground,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        border:
            Border.all(
          color:
              AppColors.border,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      clipBehavior:
          Clip.antiAlias,
      child:
          ListView.builder(
        padding:
            const EdgeInsets.symmetric(
          vertical: 4,
        ),
        itemCount:
            _filteredDonors.length,
        itemBuilder:
            (
          context,
          index,
        ) {
          final name =
              _filteredDonors[
                  index];

          return CheckboxListTile(
            dense:
                true,
            value:
                _includedDonors
                    .contains(
              name,
            ),
            onChanged: (
              _,
            ) {
              _toggleDonor(
                name,
              );
            },
            controlAffinity:
                ListTileControlAffinity
                    .leading,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal:
                  8,
            ),
            title:
                Text(
              name,
              style:
                  const TextStyle(
                fontSize:
                    12.5,
                fontWeight:
                    FontWeight
                        .w500,
              ),
            ),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // RIGHT POST PANEL
  // ==========================================================================

  Widget _buildDonorPostPanel() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Expanded(
              child: Text(
                'THANK-YOU POST',
                style:
                    TextStyle(
                  fontSize:
                      11,
                  fontWeight:
                      FontWeight
                          .w700,
                  color: AppColors
                      .mutedForeground,
                  letterSpacing:
                      0.4,
                ),
              ),
            ),

            Text(
              'Click the post to edit',
              style:
                  TextStyle(
                fontSize:
                    10.5,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 7,
        ),

        _EditableFacebookPreview(
          controller:
              _donorCaptionCtrl,
          minLines:
              22,
        ),
      ],
    );
  }
}

// =============================================================================
// TEMPLATE TAB
// =============================================================================

class _TemplateTab
    extends StatelessWidget {
  final String label;

  final IconData icon;

  final bool selected;

  final VoidCallback onTap;

  const _TemplateTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap:
          onTap,
      borderRadius:
          BorderRadius.circular(
        10,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        decoration:
            BoxDecoration(
          color:
              selected
                  ? AppColors
                      .roleStaff
                      .withValues(
                    alpha:
                        0.10,
                  )
                  : Colors
                      .transparent,
          borderRadius:
              BorderRadius.circular(
            10,
          ),
          border:
              Border.all(
            color:
                selected
                    ? AppColors
                        .roleStaff
                        .withValues(
                      alpha:
                          0.35,
                    )
                    : AppColors
                        .border,
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size:
                  17,
              color:
                  selected
                      ? AppColors
                          .roleStaff
                      : AppColors
                          .mutedForeground,
            ),

            const SizedBox(
              width: 7,
            ),

            Flexible(
              child: Text(
                label,
                overflow:
                    TextOverflow
                        .ellipsis,
                style:
                    TextStyle(
                  fontSize:
                      12.5,
                  fontWeight:
                      selected
                          ? FontWeight
                              .w700
                          : FontWeight
                              .w600,
                  color:
                      selected
                          ? AppColors
                              .roleStaff
                          : AppColors
                              .foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SUMMARY CARD
// =============================================================================

class _SummaryCard
    extends StatelessWidget {
  final String value;

  final String label;

  const _SummaryCard({
    required this.value,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            8,
        vertical:
            11,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.roleStaff
                .withValues(
          alpha:
              0.05,
        ),
        borderRadius:
            BorderRadius.circular(
          11,
        ),
        border:
            Border.all(
          color:
              AppColors.roleStaff
                  .withValues(
            alpha:
                0.15,
          ),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style:
                const TextStyle(
              fontSize:
                  18,
              fontWeight:
                  FontWeight.w800,
              color:
                  AppColors.roleStaff,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            label,
            textAlign:
                TextAlign.center,
            maxLines:
                1,
            overflow:
                TextOverflow
                    .ellipsis,
            style:
                const TextStyle(
              fontSize:
                  10.5,
              color:
                  AppColors
                      .mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// EDITABLE FACEBOOK PREVIEW
// =============================================================================

class _EditableFacebookPreview
    extends StatelessWidget {
  final TextEditingController controller;

  final int minLines;

  const _EditableFacebookPreview({
    required this.controller,
    required this.minLines,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        border:
            Border.all(
          color:
              AppColors.border,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ==================================================================
          // FACEBOOK-STYLE HEADER
          // ==================================================================

          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal:
                  12,
              vertical:
                  10,
            ),
            decoration:
                const BoxDecoration(
              border:
                  Border(
                bottom:
                    BorderSide(
                  color:
                      AppColors.border,
                ),
              ),
            ),
            child:
                const Row(
              children: [
                CircleAvatar(
                  radius:
                      16,
                  backgroundColor:
                      AppColors.primary,
                  child:
                      Text(
                    'DAS',
                    style:
                        TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          9,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                ),

                SizedBox(
                  width:
                      10,
                ),

                Expanded(
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        'Dumaguete Animal Sanctuary',
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            TextStyle(
                          fontSize:
                              13,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),

                      Text(
                        'Just now · Public',
                        style:
                            TextStyle(
                          fontSize:
                              11,
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

          // ==================================================================
          // EDITABLE POST BODY
          // ==================================================================

          TextField(
            controller:
                controller,
            minLines:
                minLines,
            maxLines:
                minLines + 8,
            keyboardType:
                TextInputType.multiline,
            style:
                const TextStyle(
              fontSize:
                  12.5,
              height:
                  1.55,
            ),
            decoration:
                const InputDecoration(
              border:
                  InputBorder.none,
              focusedBorder:
                  InputBorder.none,
              enabledBorder:
                  InputBorder.none,
              contentPadding:
                  EdgeInsets.all(
                14,
              ),
              hintText:
                  'Write your post...',
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MONTH HELPERS
// =============================================================================

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

String _monthLabel(
  DateTime month,
) =>
    '${_monthNames[month.month - 1]} ${month.year}';