import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/donation_impact.dart';
import '../../models/stock_out.dart';
import '../../services/impact_service.dart';
import '../../state/auth_state.dart';
import '../../state/data_bus.dart';
import '../../widgets/stat_card.dart';

/// Donor-facing page for showing donation acknowledgments and impact updates.
///
/// Internal inventory details such as remaining stock, waste, expiration,
/// adjustments, and batch quantities are not shown to donors.
class ImpactsPage extends StatefulWidget {
  const ImpactsPage({super.key});

  @override
  State<ImpactsPage> createState() => _ImpactsPageState();
}

class _ImpactsPageState extends State<ImpactsPage>
    with DataBusRefreshMixin<ImpactsPage> {
  final ImpactService _service = ImpactService();

  List<DonationImpactLine> _lines = [];
  bool _loading = true;
  String? _error;

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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
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
    // Treatment means the donated item was used in animal treatment.
    // Adjustment is also treated as general shelter usage for now.
    final impactedDonations = _lines.where((line) {
      return line.contributions.any((c) {
        return c.kind == ImpactEventKind.treatment ||
            (c.kind == ImpactEventKind.stockOut &&
                c.stockOutReason == StockOutReason.adjustment);
      });
    }).length;

    // Gets only treatment-related impact records.
    final treatmentContributions = _lines
        .expand((line) => line.contributions)
        .where((c) => c.kind == ImpactEventKind.treatment);

    // Counts unique treatments that were supported by donor items.
    final treatmentCount = treatmentContributions
        .map((c) => c.treatmentId)
        .whereType<String>()
        .toSet()
        .length;

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

        // Summary cards for the donor's donation impact.
        StatCardRow(
          cards: [
            StatCard(
              label: 'Items Donated',
              value: '${_lines.length}',
              icon: Icons.volunteer_activism_outlined,
              accent: AppColors.roleDonor,
            ),
            StatCard(
              label: 'Donations Used',
              value: '$impactedDonations',
              icon: Icons.favorite_outline,
              accent: AppColors.primary,
            ),
            StatCard(
              label: 'Treatments Helped',
              value: '$treatmentCount',
              icon: Icons.medical_services_outlined,
              accent: AppColors.roleStaff,
            ),
          ],
        ),

        const SizedBox(height: 20),

        if (_lines.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
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
        else
          // Creates one impact card for every donated item.
          for (final line in _lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ImpactCard(line: line),
            ),
      ],
    );
  }
}

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
    final impactUpdates = line.contributions.where((c) {
      if (c.kind == ImpactEventKind.treatment) {
        return true;
      }

      if (c.kind == ImpactEventKind.stockOut &&
          c.stockOutReason == StockOutReason.adjustment) {
        return true;
      }

      return false;
    }).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Displays the donated item's name and date received.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.roleDonor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.volunteer_activism_outlined,
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
                _formatDate(line.receivedDate),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.mutedForeground,
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
            icon: Icons.check_circle_outline,
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
          for (final impact in impactUpdates) ...[
            const SizedBox(height: 14),
            _ImpactMessage(
              icon: Icons.favorite,
              color: AppColors.primary,
              title: 'Your Donation Made an Impact!',
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
class _ImpactMessage extends StatelessWidget {
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.mutedForeground,
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
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
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

// Converts a DateTime into a donor-friendly date such as "Aug 8, 2026".
String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';