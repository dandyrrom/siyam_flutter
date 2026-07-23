import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/donation.dart';
import '../services/auth_service.dart';
import '../services/donation_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';

/// Staff-only detail view for a single donor submission (public.submission):
/// full donor + submission details, plus the status flow -- Reject/Approve
/// while pending, then once approved an "Items Received" confirmation gate
/// (`status` -> received, `date_received` set), which reveals the Stock In
/// entry point (`status` -> stocked, once a `donation` row is linked --
/// see [DonationService.fetchReceivedItems]).
class SubmissionDetailPage extends StatefulWidget {
  final String subId;
  const SubmissionDetailPage({super.key, required this.subId});

  @override
  State<SubmissionDetailPage> createState() => _SubmissionDetailPageState();
}

class _SubmissionDetailPageState extends State<SubmissionDetailPage>
    with DataBusRefreshMixin<SubmissionDetailPage> {
  final DonationService _donationService = DonationService();
  final AuthService _authService = AuthService();

  DonationSubmission? _submission;
  AppUser? _donor;
  List<DonationLineItem> _receivedItems = [];
  bool _loading = true;
  bool _notFound = false;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _notFound = false;
      });
    }
    try {
      final submission = await _donationService.fetchSubmission(widget.subId);
      if (submission == null) {
        if (!mounted) return;
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }
      final results = await Future.wait([
        _authService.fetchProfile(submission.donorId),
        _donationService.fetchReceivedItems(widget.subId),
      ]);
      if (!mounted) return;
      setState(() {
        _submission = submission;
        _donor = results[0] as AppUser?;
        _receivedItems = results[1] as List<DonationLineItem>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _notFound = true;
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

  Future<void> _reject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject donation from ${_submission!.donorName}?'),
        content: const Text(
            'The donor will no longer be able to have this submission stocked in.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final updatedByUserId = context.read<AuthController>().profile?.userId;
    if (updatedByUserId == null) return;
    setState(() => _acting = true);
    try {
      await _donationService.rejectSubmission(
          subId: widget.subId, updatedByUserId: updatedByUserId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reject donation: $e')));
    }
  }

  Future<void> _approve() async {
    final currentUser = context.read<AuthController>().profile;
    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Approve donation from ${_submission!.donorName}?'),
        content: const Text(
          'This marks the submission approved. Once the items physically '
          'arrive, come back here to confirm receipt and stock them in.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _acting = true);
    try {
      await _donationService.updateSubmissionStatus(
        subId: widget.subId,
        status: SubmissionStatus.approved,
        updatedByUserId: currentUser.userId,
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not approve donation: $e')));
    }
  }

  Future<void> _confirmItemsReceived() async {
    setState(() => _acting = true);
    try {
      await _donationService.markSubmissionReceived(subId: widget.subId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _acting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not confirm items received: $e')));
    }
  }

  Future<void> _stockIn() async {
    await context.push('/inventory/add?type=donated&subId=${widget.subId}');
    if (!mounted) return;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notFound || _submission == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.volunteer_activism_outlined,
                size: 40, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            const Text('Submission not found',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => context.go('/donations'),
                child: const Text('Back to Donations')),
          ],
        ),
      );
    }

    final sub = _submission!;
    final (statusLabel, statusColor) = _statusMeta(sub.status);
    final hasReceivedItems = _receivedItems.isNotEmpty;
    final showItemsReceivedButton = sub.status == SubmissionStatus.approved;
    final showStockInButton = sub.status == SubmissionStatus.received;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/donations'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Donations'),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.donorName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: sub.subId));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Submission ID copied')));
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(sub.subId,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.mutedForeground)),
                          const SizedBox(width: 4),
                          const Icon(Icons.copy,
                              size: 13, color: AppColors.mutedForeground),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Donor'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _FieldBlock(label: 'Name', value: sub.donorName),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child:
                      _FieldBlock(label: 'Email', value: _donor?.email ?? '—'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _FieldBlock(
                      label: 'Contact number',
                      value: (_donor?.contactNum?.isNotEmpty ?? false)
                          ? _donor!.contactNum!
                          : '—'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Submission details'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FieldBlock(
                    label: 'Submitted', value: _formatDate(sub.dateSub)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FieldBlock(
                    label: 'Preferred drop-off',
                    value: sub.schedDate == null
                        ? 'Not specified'
                        : _formatDate(sub.schedDate!)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FieldBlock(
                    label: 'Last updated by',
                    value: sub.updatedByName ?? 'Not yet reviewed'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Notes',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.mutedForeground)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              (sub.notes?.isNotEmpty ?? false)
                  ? sub.notes!
                  : 'No notes provided.',
              style: TextStyle(
                  fontSize: 13.5,
                  color: (sub.notes?.isNotEmpty ?? false)
                      ? AppColors.foreground
                      : AppColors.mutedForeground),
            ),
          ),
          if (sub.proofImg?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            const Text('Proof photo',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.mutedForeground)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                sub.proofImg!,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: Text('Could not load image: ${sub.proofImg}',
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.mutedForeground)),
                ),
              ),
            ),
          ],
          if (hasReceivedItems) ...[
            const SizedBox(height: 20),
            const _SectionLabel('Items received'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: _HeaderCell('Item')),
                        Expanded(flex: 2, child: _HeaderCell('Qty')),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  for (final item in _receivedItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                              flex: 3,
                              child: Text(item.itemName,
                                  overflow: TextOverflow.ellipsis)),
                          Expanded(
                              flex: 2,
                              child: Text('${item.qty} ${item.itemUom}')),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (sub.status == SubmissionStatus.pending) ...[
                OutlinedButton(
                  onPressed: _acting ? null : _reject,
                  child: const Text('Reject'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _acting ? null : _approve,
                  child: const Text('Approve'),
                ),
              ] else if (showItemsReceivedButton)
                ElevatedButton.icon(
                  onPressed: _acting ? null : _confirmItemsReceived,
                  icon: const Icon(Icons.inventory_outlined, size: 18),
                  label: const Text('Items Received'),
                )
              else if (showStockInButton)
                ElevatedButton.icon(
                  onPressed: _acting ? null : _stockIn,
                  icon: const Icon(Icons.inventory_2_outlined, size: 18),
                  label: const Text('Stock In'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  final String label;
  final String value;
  const _FieldBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        Text(value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  const _HeaderCell(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: AppColors.mutedForeground,
      ),
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

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
