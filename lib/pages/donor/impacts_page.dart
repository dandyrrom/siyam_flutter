import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/donation_impact.dart';
import '../../models/stock_out.dart';
import '../../services/impact_service.dart';
import '../../state/auth_state.dart';
import '../../state/data_bus.dart';

/// Donor-facing page for showing donation acknowledgments and impact updates.
///
/// Internal inventory details such as remaining stock, waste, expiration,
/// adjustments, and batch quantities are not shown to donors.
class ImpactsPage extends StatefulWidget {
  const ImpactsPage({super.key});

  @override
  State<ImpactsPage> createState() => _ImpactsPageState();
}

// Controls which type of donor impact record is currently shown.
enum _ImpactFilter {
  all,
  used,
  treatment,
}

class _ImpactsPageState extends State<ImpactsPage>
    with DataBusRefreshMixin<ImpactsPage> {
  final ImpactService _service = ImpactService();

  List<DonationImpactLine> _lines = [];
  bool _loading = true;
  String? _error;

  // Current impact card filter.
  _ImpactFilter _filter = _ImpactFilter.all;

  // Search text used to filter donor impact messages.
  String _search = '';

  @override
  void initState() {
    super.initState();

    // Loads the logged-in donor's donation impact records when the page opens.
    _load();
  }

  @override
  void onExternalDataChanged() {
    // Reloads the donor's impact records when inventory data changes.
    _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    // Gets the currently logged-in donor's user ID.
    final donorId = context.read<AuthController>().profile?.userId;
    if (donorId == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // Gets this donor's donations and their impact records from Supabase.
      final lines = await _service.fetchDonorImpact(donorId);

      if (!mounted) return;

      setState(() {
        _lines = lines;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error = 'Could not load your impact: $e';
          _loading = false;
        });
      }
    }
  }

  // Returns true when a donated item has already produced a meaningful
  // donor-facing impact event.
  bool _hasImpact(DonationImpactLine line) {
    return line.contributions.any((c) {
      return c.kind == ImpactEventKind.treatment ||
          (c.kind == ImpactEventKind.stockOut &&
              c.stockOutReason == StockOutReason.adjustment);
    });
  }

  // Returns true when a donated item contributed specifically to treatment.
  bool _hasTreatment(DonationImpactLine line) {
    return line.contributions.any(
      (c) => c.kind == ImpactEventKind.treatment,
    );
  }

  // Creates the donor-facing acknowledgment message used for searching.
  String _receivedMessage(DonationImpactLine line) {
    return 'Thank you! Your donated ${line.itemName} was successfully '
        'received by Dumaguete Animal Sanctuary. We truly appreciate '
        'your support for the animals in our care.';
  }

  // Creates the donor-facing impact message used for searching.
  String _impactMessage(DonationImpactLine line) {
    return 'The ${line.itemName} you donated was put to use at '
        'Dumaguete Animal Sanctuary. Thank you for your contribution '
        'and for helping us continue caring for the animals.';
  }

  // Filters donation records using both the selected summary card and
  // the donor's search text.
  List<DonationImpactLine> get _filteredLines {
    final query = _search.trim().toLowerCase();

    return _lines.where((line) {
      // First applies the selected summary card filter.
      final matchesFilter = switch (_filter) {
        _ImpactFilter.all => true,
        _ImpactFilter.used => _hasImpact(line),
        _ImpactFilter.treatment => _hasTreatment(line),
      };

      if (!matchesFilter) {
        return false;
      }

      // No search text means every record matching the card filter is shown.
      if (query.isEmpty) {
        return true;
      }

      // Allows donors to search by item name or words appearing in
      // their acknowledgment / impact messages.
      final searchableText = [
        line.itemName,
        'Donation Received',
        _receivedMessage(line),
        if (_hasImpact(line)) 'Your Donation Made an Impact!',
        if (_hasImpact(line)) _impactMessage(line),
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();
  }

  // Changes the currently selected impact filter.
  void _setFilter(_ImpactFilter filter) {
    setState(() {
      _filter = filter;
    });
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

    // Counts how many donated items have already made an impact.
    //
    // Treatment means the donated item was used in animal treatment.
    // Adjustment is also treated as general shelter usage for now.
    final impactedDonations =
        _lines.where(_hasImpact).length;

    // Gets only treatment-related impact records.
    final treatmentContributions = _lines
        .expand((line) => line.contributions)
        .where(
          (c) => c.kind == ImpactEventKind.treatment,
        );

    // Counts unique treatments that were supported by donor items.
    final treatmentCount = treatmentContributions
        .map((c) => c.treatmentId)
        .whereType<String>()
        .toSet()
        .length;

    final filteredLines = _filteredLines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Impact',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          'See how your donations are helping animals in our care.',
          style: TextStyle(
            color: AppColors.mutedForeground,
          ),
        ),

        const SizedBox(height: 20),

        // ============================================================
        // CLICKABLE IMPACT SUMMARY CARDS
        // ============================================================
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;

            if (compact) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: constraints.maxWidth < 480
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _ImpactFilterCard(
                      label: 'Items Donated',
                      description: 'View all donations',
                      value: '${_lines.length}',
                      icon:
                          Icons.volunteer_activism_outlined,
                      accent: AppColors.roleDonor,
                      selected:
                          _filter == _ImpactFilter.all,
                      onTap: () =>
                          _setFilter(_ImpactFilter.all),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 480
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _ImpactFilterCard(
                      label: 'Donations Used',
                      description: 'Already made an impact',
                      value: '$impactedDonations',
                      icon: Icons.favorite_outline,
                      accent: AppColors.primary,
                      selected:
                          _filter == _ImpactFilter.used,
                      onTap: () =>
                          _setFilter(_ImpactFilter.used),
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth < 480
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 12) / 2,
                    child: _ImpactFilterCard(
                      label: 'Treatments Helped',
                      description: 'Used for animal care',
                      value: '$treatmentCount',
                      icon:
                          Icons.medical_services_outlined,
                      accent: AppColors.roleStaff,
                      selected:
                          _filter == _ImpactFilter.treatment,
                      onTap: () => _setFilter(
                        _ImpactFilter.treatment,
                      ),
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(
                  child: _ImpactFilterCard(
                    label: 'Items Donated',
                    description: 'View all donations',
                    value: '${_lines.length}',
                    icon:
                        Icons.volunteer_activism_outlined,
                    accent: AppColors.roleDonor,
                    selected:
                        _filter == _ImpactFilter.all,
                    onTap: () =>
                        _setFilter(_ImpactFilter.all),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _ImpactFilterCard(
                    label: 'Donations Used',
                    description: 'Already made an impact',
                    value: '$impactedDonations',
                    icon: Icons.favorite_outline,
                    accent: AppColors.primary,
                    selected:
                        _filter == _ImpactFilter.used,
                    onTap: () =>
                        _setFilter(_ImpactFilter.used),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _ImpactFilterCard(
                    label: 'Treatments Helped',
                    description: 'Used for animal care',
                    value: '$treatmentCount',
                    icon:
                        Icons.medical_services_outlined,
                    accent: AppColors.roleStaff,
                    selected:
                        _filter == _ImpactFilter.treatment,
                    onTap: () => _setFilter(
                      _ImpactFilter.treatment,
                    ),
                  ),
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // ============================================================
        // MESSAGE SEARCH
        // ============================================================
        //
        // Searches the item name and donor-facing acknowledgment / impact
        // messages without exposing any private inventory information.
        SizedBox(
          width: 360,
          child: TextField(
            onChanged: (value) {
              setState(() {
                _search = value;
              });
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
              ),
              hintText: 'Search your impact messages',
              isDense: true,
              suffixIcon: _search.isNotEmpty
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        setState(() {
                          _search = '';
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                      ),
                    )
                  : null,
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Shows the donor which records are currently being displayed.
        Text(
          '${filteredLines.length} of ${_lines.length} donated items shown',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors.mutedForeground,
          ),
        ),

        const SizedBox(height: 20),

        // ============================================================
        // IMPACT MESSAGES
        // ============================================================
        if (_lines.isEmpty)
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
                  SizedBox(height: 4),
                  Text(
                    'Once your donation is received, it will appear here.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (filteredLines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 48,
            ),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off,
                    size: 34,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'No impact messages found',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Try another search or impact category.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filter = _ImpactFilter.all;
                        _search = '';
                      });
                    },
                    child: const Text(
                      'Show all donations',
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // Creates one impact card for every filtered donated item.
          for (final line in filteredLines)
            Padding(
              padding: const EdgeInsets.only(
                bottom: 16,
              ),
              child: _ImpactCard(
                line: line,
              ),
            ),
      ],
    );
  }
}

// ============================================================================
// CLICKABLE IMPACT FILTER CARD
// ============================================================================

/// Clickable summary card that filters the donor's impact messages.
///
/// Hovering provides visual feedback on desktop and clicking changes which
/// donation impact records are displayed below.
class _ImpactFilterCard extends StatefulWidget {
  final String label;
  final String description;
  final String value;
  final IconData icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const _ImpactFilterCard({
    required this.label,
    required this.description,
    required this.value,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_ImpactFilterCard> createState() =>
      _ImpactFilterCardState();
}

class _ImpactFilterCardState
    extends State<_ImpactFilterCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final highlighted =
        widget.selected || _hovering;

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
                ? widget.accent.withValues(
                    alpha: 0.08,
                  )
                : AppColors.card,
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color: highlighted
                  ? widget.accent.withValues(
                      alpha: 0.65,
                    )
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
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            widget.selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                        color:
                            AppColors.foreground,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      widget.description,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
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
// DONATION IMPACT CARD
// ============================================================================

class _ImpactCard extends StatelessWidget {
  final DonationImpactLine line;

  const _ImpactCard({
    required this.line,
  });

  @override
  Widget build(BuildContext context) {
    // Gets meaningful donor impact events.
    //
    // Treatment = donated item was used in animal treatment.
    // Adjustment = treated as general shelter usage for now.
    //
    // Waste and expired stock are intentionally not shown to donors.
    final impactUpdates =
        line.contributions.where((c) {
      if (c.kind ==
          ImpactEventKind.treatment) {
        return true;
      }

      if (c.kind ==
              ImpactEventKind.stockOut &&
          c.stockOutReason ==
              StockOutReason.adjustment) {
        return true;
      }

      return false;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // Displays the donated item's name and date received.
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.roleDonor
                      .withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons
                      .volunteer_activism_outlined,
                  size: 20,
                  color: AppColors.roleDonor,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  line.itemName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
              ),

              Text(
                _formatDate(
                    line.receivedDate),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // This thank-you message is always shown after the donation
          // has been successfully received and stocked in.
          _ImpactMessage(
            icon:
                Icons.check_circle_outline,
            color: AppColors.roleDonor,
            title: 'Donation Received',
            message:
                'Thank you! Your donated ${line.itemName} was successfully '
                'received by Dumaguete Animal Sanctuary. We truly appreciate '
                'your support for the animals in our care.',
            date: line.receivedDate,
          ),

          // Displays another message whenever the donated item has a
          // meaningful usage event such as Treatment or Adjustment.
          for (final impact
              in impactUpdates) ...[
            const SizedBox(height: 14),
            _ImpactMessage(
              icon: Icons.favorite,
              color: AppColors.primary,
              title:
                  'Your Donation Made an Impact!',
              message:
                  'The ${line.itemName} you donated was put to use at '
                  'Dumaguete Animal Sanctuary. Thank you for your contribution '
                  'and for helping us continue caring for the animals.',
              date: impact.date,
            ),
          ],
        ],
      ),
    );
  }
}

/// Reusable message shown inside each donation card.
///
/// Used for both the initial "Donation Received" acknowledgment and later
/// donation impact updates.
class _ImpactMessage
    extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final DateTime date;

  const _ImpactMessage({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color:
                color.withValues(alpha: 0.1),
            borderRadius:
                BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
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
                      title,
                      style:
                          const TextStyle(
                        fontSize: 14,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(date),
                    style:
                        const TextStyle(
                      fontSize: 11.5,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 5),

              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
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

// Converts a DateTime into a donor-friendly date such as "Aug 8, 2026".
String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';