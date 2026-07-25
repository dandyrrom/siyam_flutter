import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/donation.dart';
import '../../services/donation_service.dart';
import '../../state/auth_state.dart';
import '../../state/data_bus.dart';
import '../../widgets/stat_card.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    final donorId = context.read<AuthController>().profile?.userId;
    if (donorId == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _service.fetchSubmissions(donorId: donorId);
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

  Future<void> _openDetailDialog(DonationSubmission sub) async {
    List<DonationLineItem>? items;
    String? itemsError;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (sub.status == SubmissionStatus.stocked &&
              items == null &&
              itemsError == null) {
            _service.fetchReceivedItems(sub.subId).then((rows) {
              setDialogState(() => items = rows);
            }).catchError((e) {
              setDialogState(() => itemsError = 'Could not load items: $e');
            });
          }

          final (statusLabel, statusColor) = _statusMeta(sub.status);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Donation Details'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'Submitted', value: _formatDate(sub.dateSub)),
                    _DetailRow(
                        label: 'Drop-off Date',
                        value: sub.schedDate == null ? '—' : _formatDate(sub.schedDate!)),
                    if (sub.updatedByName != null)
                      _DetailRow(label: 'Reviewed by', value: sub.updatedByName!),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                    ),
                    if (sub.status == SubmissionStatus.stocked) ...[
                      const SizedBox(height: 16),
                      const Text('Items Received',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      const SizedBox(height: 8),
                      if (itemsError != null)
                        Text(itemsError!, style: const TextStyle(color: AppColors.destructive))
                      else if (items == null)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (items!.isEmpty)
                        const Text('No items on file for this donation.',
                            style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground))
                      else
                        for (final item in items!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(item.itemName)),
                                Text('${item.qty} ${item.itemUom}',
                                    style: const TextStyle(color: AppColors.mutedForeground)),
                              ],
                            ),
                          ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
            ],
          );
        },
      ),
    );
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
            Text(_error!, style: const TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final pendingCount =
        _submissions.where((s) => s.status == SubmissionStatus.pending).length;
    final approvedCount =
        _submissions.where((s) => s.status == SubmissionStatus.approved).length;
    final rejectedCount =
        _submissions.where((s) => s.status == SubmissionStatus.rejected).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('My Donations',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            ElevatedButton.icon(
              onPressed: () => context.go('/donate'),
              icon: const Icon(Icons.favorite_outline, size: 18),
              label: const Text('Donate Now'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        StatCardRow(cards: [
          StatCard(
            label: 'Total Submissions',
            value: '${_submissions.length}',
            icon: Icons.volunteer_activism_outlined,
            accent: AppColors.roleDonor,
          ),
          StatCard(
            label: 'Pending',
            value: '$pendingCount',
            icon: Icons.schedule_outlined,
            accent: AppColors.warning,
          ),
          StatCard(
            label: 'Approved',
            value: '$approvedCount',
            icon: Icons.check_circle_outline,
            accent: AppColors.primary,
          ),
          StatCard(
            label: 'Rejected',
            value: '$rejectedCount',
            icon: Icons.cancel_outlined,
            accent: AppColors.destructive,
          ),
        ]),
        const SizedBox(height: 20),
        if (_submissions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.volunteer_activism_outlined,
                      size: 36, color: AppColors.mutedForeground),
                  SizedBox(height: 10),
                  Text('No donations yet', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            // Plain Column (not ListView) -- AppShell already scrolls, and a
            // nested ListView+InkWell triggers layout asserts on Flutter Web.
            child: Column(
              children: [
                for (var i = 0; i < _submissions.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _SubmissionRow(
                    submission: _submissions[i],
                    statusMeta: _statusMeta(_submissions[i].status),
                    onTap: () => _openDetailDialog(_submissions[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _SubmissionRow extends StatelessWidget {
  final DonationSubmission submission;
  final (String, Color) statusMeta;
  final VoidCallback onTap;

  const _SubmissionRow({
    required this.submission,
    required this.statusMeta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = submission;
    final (statusLabel, statusColor) = statusMeta;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Submitted ${_formatDate(sub.dateSub)}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (sub.schedDate != null)
                    Text('Drop-off: ${_formatDate(sub.schedDate!)}',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(statusLabel,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
