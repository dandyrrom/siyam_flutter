import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/donation.dart';
import '../services/donation_service.dart';
import '../state/auth_state.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/stat_card.dart';

class DonationsPage extends StatefulWidget {
  const DonationsPage({super.key});

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  final DonationService _service = DonationService();

  List<DonationSubmission> _submissions = [];
  bool _loading = true;
  String? _error;

  String _search = '';
  SubmissionStatus? _statusFilter; // null = All

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final submissions = await _service.fetchSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = submissions;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load donations: $e';
        _loading = false;
      });
    }
  }

  List<DonationSubmission> get _filtered {
    return _submissions.where((s) {
      final matchesSearch =
          _search.isEmpty || s.donorName.toLowerCase().contains(_search.toLowerCase());
      final matchesStatus = _statusFilter == null || s.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  (String, Color) _statusMeta(SubmissionStatus status) {
    switch (status) {
      case SubmissionStatus.pending:
        return ('Pending', AppColors.warning);
      case SubmissionStatus.approved:
        return ('Approved', AppColors.primary);
      case SubmissionStatus.rejected:
        return ('Rejected', AppColors.destructive);
    }
  }

  Future<void> _reject(DonationSubmission sub) async {
    final updatedByUserId = context.read<AuthController>().profile?.userId;
    if (updatedByUserId == null) return;
    try {
      await _service.rejectSubmission(subId: sub.subId, updatedByUserId: updatedByUserId);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not reject donation: $e')));
    }
  }

  /// Approving is a lightweight status change only -- it doesn't collect
  /// items here. Staff can stock in right away (redirects to the Stock In
  /// form, pre-filled for this donation) or later via the Stock In form's
  /// "Link to submission" picker, since an approved-but-unlinked submission
  /// already shows up there.
  Future<void> _approve(DonationSubmission sub) async {
    final currentUser = context.read<AuthController>().profile;
    if (currentUser == null) return;

    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Approve donation from ${sub.donorName}?'),
        content: const Text(
          'This marks the submission approved. You can record the items '
          'received now, or later from Inventory > Stock In > Link to submission.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('approve'),
            child: const Text('Approve'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop('approve_and_stock_in'),
            child: const Text('Approve & Stock In'),
          ),
        ],
      ),
    );
    if (choice == null) return;

    try {
      await _service.updateSubmissionStatus(
        subId: sub.subId,
        status: SubmissionStatus.approved,
        updatedByUserId: currentUser.userId,
      );
      if (!mounted) return;
      if (choice == 'approve_and_stock_in') {
        context.push('/inventory/add?type=donated&subId=${sub.subId}');
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Approved. Stock in items anytime from Inventory > Stock In.')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not approve donation: $e')));
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
              child: Text('Donations',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            ElevatedButton.icon(
              onPressed: () => context.push('/inventory/add?type=donated'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Donation'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('${_submissions.length} submissions',
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
        const SizedBox(height: 20),
        StatCardRow(cards: [
          StatCard(
            label: 'Total Submissions',
            value: '${_submissions.length}',
            icon: Icons.volunteer_activism_outlined,
            accent: AppColors.roleStaff,
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Search by donor…',
                  isDense: true,
                ),
              ),
            ),
            AppDropdown<SubmissionStatus?>(
              label: _statusFilter == null ? 'Status' : _statusMeta(_statusFilter!).$1,
              options: [
                const AppDropdownOption(null, 'All statuses'),
                for (final s in SubmissionStatus.values)
                  AppDropdownOption(s, _statusMeta(s).$1),
              ],
              onSelect: (v) => setState(() => _statusFilter = v),
            ),
          ],
        ),
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
        else if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 32, color: AppColors.mutedForeground),
                  SizedBox(height: 8),
                  Text('No donations match your filters.',
                      style: TextStyle(color: AppColors.mutedForeground)),
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
                for (var i = 0; i < _filtered.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _SubmissionRow(
                    submission: _filtered[i],
                    statusMeta: _statusMeta(_filtered[i].status),
                    onReject: () => _reject(_filtered[i]),
                    onApprove: () => _approve(_filtered[i]),
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
  final VoidCallback onReject;
  final VoidCallback onApprove;

  const _SubmissionRow({
    required this.submission,
    required this.statusMeta,
    required this.onReject,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) {
    final sub = submission;
    final (statusLabel, statusColor) = statusMeta;
    return InkWell(
      onTap: () => context.push('/donations/${sub.subId}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 200,
              child: Text(sub.donorName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            SizedBox(
              width: 160,
              child: Text('Submitted ${_formatDate(sub.dateSub)}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
            ),
            SizedBox(
              width: 160,
              child: Text(
                  sub.schedDate == null
                      ? 'No drop-off date'
                      : 'Drop-off ${_formatDate(sub.schedDate!)}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
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
            if (sub.status == SubmissionStatus.pending) ...[
              OutlinedButton(
                onPressed: onReject,
                child: const Text('Reject'),
              ),
              ElevatedButton(
                onPressed: onApprove,
                child: const Text('Approve'),
              ),
            ],
          ],
        ),
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
