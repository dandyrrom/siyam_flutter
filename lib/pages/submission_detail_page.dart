import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
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

  // Supabase client used to access the private donation proof image.
  final SupabaseClient _client = Supabase.instance.client;

  DonationSubmission? _submission;
  AppUser? _donor;
  List<DonationLineItem> _receivedItems = [];

  // Temporary signed URL used to display the private proof photo.
  String? _proofSignedUrl;

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
      final submission =
          await _donationService.fetchSubmission(widget.subId);

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

      // Gets a temporary signed URL from the private donation-proofs bucket.
      String? proofSignedUrl;

      if (submission.proofImg != null &&
          submission.proofImg!.trim().isNotEmpty) {
        try {
          proofSignedUrl = await _client.storage
              .from('donation-proofs')
              .createSignedUrl(
                submission.proofImg!,
                60 * 10,
              );
        } catch (_) {
          // If Storage fails, keep the URL null so the page can show
          // the existing image error state without breaking the whole page.
          proofSignedUrl = null;
        }
      }

      if (!mounted) return;

      setState(() {
        _submission = submission;
        _donor = results[0] as AppUser?;
        _receivedItems =
            results[1] as List<DonationLineItem>;

        // Saves the signed URL used by Image.network below.
        _proofSignedUrl = proofSignedUrl;

        _loading = false;
        _acting = false;
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

  // Opens the donation proof image in a larger dialog.
  void _openProofImage() {
    if (_proofSignedUrl == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 900,
            maxHeight: 700,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Donation Proof',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Allows staff to zoom and pan the proof image.
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    _proofSignedUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 200,
                        child: Center(
                          child: Text(
                            'Could not display the proof image.',
                            style: TextStyle(
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('Reject donation from ${_submission!.donorName}?'),
        content: const Text(
            'The donor will no longer be able to have this submission stocked in.'),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.destructive),
            onPressed: () =>
                Navigator.of(context).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final updatedByUserId =
        context.read<AuthController>().profile?.userId;

    if (updatedByUserId == null) return;

    setState(() => _acting = true);

    try {
      await _donationService.rejectSubmission(
          subId: widget.subId,
          updatedByUserId: updatedByUserId);

      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() => _acting = false);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Could not reject donation: $e')));
    }
  }

  Future<void> _approve() async {
    final currentUser =
        context.read<AuthController>().profile;

    if (currentUser == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title:
            Text('Approve donation from ${_submission!.donorName}?'),
        content: const Text(
          'This marks the submission approved. Once the items physically '
          'arrive, come back here to confirm receipt and stock them in.',
        ),
        actions: [
          TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(context).pop(true),
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
          SnackBar(
              content:
                  Text('Could not approve donation: $e')));
    }
  }

  Future<void> _confirmItemsReceived() async {
    setState(() => _acting = true);

    try {
      await _donationService.markSubmissionReceived(
          subId: widget.subId);

      await _load();
    } catch (e) {
      if (!mounted) return;

      setState(() => _acting = false);

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Could not confirm items received: $e')));
    }
  }

  Future<void> _stockIn() async {
    await context.push(
        '/inventory/add?type=donated&subId=${widget.subId}');

    if (!mounted) return;

    _load();
  }

  Widget _buildActionPanel(DonationSubmission sub) {
    switch (sub.status) {
      case SubmissionStatus.pending:
        return _ActionPanel(
          icon: Icons.rate_review_outlined,
          iconColor: AppColors.warning,
          title: 'Awaiting your review',
          description:
              'Approve this submission to accept the donation, or reject it '
              'if it cannot be accepted. This decision is shown to the donor.',
          actions: [
            OutlinedButton(
              onPressed: _acting ? null : _reject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.destructive,
                side:
                    const BorderSide(color: AppColors.destructive),
              ),
              child: const Text('Reject'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _acting ? null : _approve,
              child: const Text('Approve'),
            ),
          ],
        );

      case SubmissionStatus.approved:
        return _ActionPanel(
          icon: Icons.local_shipping_outlined,
          iconColor: AppColors.primary,
          title: 'Waiting for items to arrive',
          description:
              'Once the donor drops off (or you receive) the items in '
              'person, confirm receipt to move this donation forward.',
          actions: [
            ElevatedButton.icon(
              onPressed:
                  _acting ? null : _confirmItemsReceived,
              icon: const Icon(
                  Icons.inventory_outlined,
                  size: 18,
              ),
              label:
                  const Text('Confirm Items Received'),
            ),
          ],
        );

      case SubmissionStatus.received:
        return _ActionPanel(
          icon: Icons.checklist_outlined,
          iconColor: AppColors.primary,
          title: 'Items received — ready to stock in',
          description:
              'Record what was received into inventory to complete this '
              'donation. This is the final step.',
          actions: [
            ElevatedButton.icon(
              onPressed: _acting ? null : _stockIn,
              icon: const Icon(
                  Icons.inventory_2_outlined,
                  size: 18,
              ),
              label:
                  const Text('Stock In Items'),
            ),
          ],
        );

      case SubmissionStatus.stocked:
        return const _InfoPanel(
          icon: Icons.check_circle_outline,
          color: AppColors.primary,
          title: 'Fully stocked in',
          description:
              'All items from this donation have been added to inventory. '
              'No further action is needed.',
        );

      case SubmissionStatus.rejected:
        return const _InfoPanel(
          icon: Icons.cancel_outlined,
          color: AppColors.destructive,
          title: 'Donation rejected',
          description:
              'This submission was rejected and cannot proceed further.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator());
    }

    if (_notFound || _submission == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
                Icons.volunteer_activism_outlined,
                size: 40,
                color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            const Text(
                'Submission not found',
                style:
                    TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextButton(
               onPressed: () {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/donations');
  }
},
                child:
                    const Text('Back to Donations')),
          ],
        ),
      );
    }

    final sub = _submission!;
    final (statusLabel, statusColor) =
        _statusMeta(sub.status);

    final hasReceivedItems =
        _receivedItems.isNotEmpty;

    return ConstrainedBox(
      constraints:
          const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () =>
                context.go('/donations'),
            icon:
                const Icon(Icons.arrow_back, size: 16),
            label:
                const Text('Back to Donations'),
            style: TextButton.styleFrom(
                foregroundColor:
                    AppColors.mutedForeground),
          ),

          const SizedBox(height: 8),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      sub.donorName,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight:
                              FontWeight.w800),
                    ),

                    const SizedBox(height: 4),

                    InkWell(
                      borderRadius:
                          BorderRadius.circular(6),
                      onTap: () async {
                        await Clipboard.setData(
                            ClipboardData(
                                text: sub.subId));

                        if (!context.mounted) return;

                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Submission ID copied')),
                        );
                      },
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min,
                        children: [
                          Text(
                            sub.subId,
                            style:
                                const TextStyle(
                              fontSize: 12.5,
                              color: AppColors
                                  .mutedForeground,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.copy,
                            size: 13,
                            color: AppColors
                                .mutedForeground,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(
                      alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          FontWeight.w700,
                      color: statusColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          _StatusStepper(status: sub.status),

          const SizedBox(height: 24),

          const _SectionLabel('Donor'),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _FieldBlock(
                      label: 'Name',
                      value: sub.donorName),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _FieldBlock(
                      label: 'Email',
                      value:
                          _donor?.email ?? '—'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _FieldBlock(
                    label: 'Contact number',
                    value:
                        (_donor?.contactNum?.isNotEmpty ??
                                false)
                            ? _donor!.contactNum!
                            : '—',
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const _SectionLabel(
              'Submission details'),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FieldBlock(
                    label: 'Submitted',
                    value:
                        _formatDate(sub.dateSub)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FieldBlock(
                  label: 'Preferred drop-off',
                  value: sub.schedDate == null
                      ? 'Not specified'
                      : _formatDate(
                          sub.schedDate!),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FieldBlock(
                  label: 'Last updated by',
                  value: sub.updatedByName ??
                      'Not yet reviewed',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Notes',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color:
                    AppColors.mutedForeground),
          ),

          const SizedBox(height: 6),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius:
                  BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.border),
            ),
            child: Text(
              (sub.notes?.isNotEmpty ?? false)
                  ? sub.notes!
                  : 'No notes provided.',
              style: TextStyle(
                fontSize: 13.5,
                color:
                    (sub.notes?.isNotEmpty ?? false)
                        ? AppColors.foreground
                        : AppColors
                            .mutedForeground,
              ),
            ),
          ),

          if (sub.proofImg?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),

            const Text(
              'Proof photo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppColors.mutedForeground,
              ),
            ),

            const SizedBox(height: 6),

            // Adds a border around the proof image and makes it clickable.
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border,
                  width: 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: _proofSignedUrl != null
                    ? InkWell(
                        // Opens a larger proof image preview when clicked.
                        onTap: _openProofImage,
                        child: Stack(
                          children: [
                            Image.network(
                              _proofSignedUrl!,
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) =>
                                      _ProofImageError(
                                path: sub.proofImg!,
                              ),
                            ),

                            // Shows staff that the image can be expanded.
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(
                                    alpha: 0.55,
                                  ),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.zoom_in,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Click to expand',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Colors.white,
                                        fontWeight:
                                            FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _ProofImageError(
                        path: sub.proofImg!,
                      ),
              ),
            ),
          ],

          if (hasReceivedItems) ...[
            const SizedBox(height: 20),

            const _SectionLabel(
                'Items received'),

            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius:
                    BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Padding(
                    padding:
                        EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                            flex: 3,
                            child: _HeaderCell(
                                'Item')),
                        Expanded(
                            flex: 2,
                            child:
                                _HeaderCell('Qty')),
                      ],
                    ),
                  ),

                  const Divider(height: 1),

                  for (final item
                      in _receivedItems)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              item.itemName,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                                '${item.qty} ${item.itemUom}'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          _buildActionPanel(sub),
        ],
      ),
    );
  }
}

/// Displays an error when the private proof image cannot be loaded.
class _ProofImageError extends StatelessWidget {
  final String path;

  const _ProofImageError({
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(12),
        border:
            Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: const Text(
        'Could not load proof image.',
        style: TextStyle(
          fontSize: 12.5,
          color: AppColors.mutedForeground,
        ),
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
      padding:
          const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FieldBlock extends StatelessWidget {
  final String label;
  final String value;

  const _FieldBlock({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color:
                AppColors.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

enum _StepState {
  done,
  current,
  upcoming,
}

/// Horizontal progress indicator for the submission lifecycle:
/// Submitted -> Approved -> Received -> Stocked In. Collapses to a single
/// rejected banner when the terminal `rejected` state is reached, since
/// that branches off "Submitted" rather than continuing the happy path.
class _StatusStepper extends StatelessWidget {
  final SubmissionStatus status;

  const _StatusStepper({
    required this.status,
  });

  static const _labels = [
    'Submitted',
    'Approved',
    'Received',
    'Stocked In',
  ];

  int get _activeIndex {
    switch (status) {
      case SubmissionStatus.pending:
        return 0;
      case SubmissionStatus.approved:
        return 1;
      case SubmissionStatus.received:
        return 2;
      case SubmissionStatus.stocked:
        return 3;
      case SubmissionStatus.rejected:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (status == SubmissionStatus.rejected) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: AppColors.destructive
              .withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.destructive
                .withValues(alpha: 0.3),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.cancel_outlined,
              size: 18,
              color: AppColors.destructive,
            ),
            SizedBox(width: 8),
            Text(
              'Submitted, then rejected',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.destructive,
              ),
            ),
          ],
        ),
      );
    }

    final active = _activeIndex;

    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          _StepDot(
            index: i,
            label: _labels[i],
            state: i < active
                ? _StepState.done
                : i == active
                    ? _StepState.current
                    : _StepState.upcoming,
          ),
          if (i != _labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(
                  bottom: 18,
                ),
                color: i < active
                    ? AppColors.primary
                    : AppColors.border,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  final int index;
  final String label;
  final _StepState state;

  const _StepDot({
    required this.index,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final Color fill = switch (state) {
      _StepState.done => AppColors.primary,
      _StepState.current => AppColors.primary,
      _StepState.upcoming => AppColors.muted,
    };

    final Color textColor = switch (state) {
      _StepState.done => AppColors.foreground,
      _StepState.current => AppColors.foreground,
      _StepState.upcoming =>
        AppColors.mutedForeground,
    };

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: state == _StepState.upcoming
                ? Colors.transparent
                : fill,
            border: Border.all(
              color: state == _StepState.upcoming
                  ? AppColors.border
                  : AppColors.primary,
              width: state == _StepState.current
                  ? 2
                  : 1,
            ),
          ),
          alignment: Alignment.center,
          child: state == _StepState.done
              ? const Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                )
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: state ==
                            _StepState.current
                        ? Colors.white
                        : AppColors
                            .mutedForeground,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight:
                state == _StepState.current
                    ? FontWeight.w700
                    : FontWeight.w500,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

/// Contextual "what happens next" card shown at the bottom of the page --
/// pairs an explanation of the current stage with its action button(s), so
/// staff know *why* they're clicking a button, not just what it's labeled.
class _ActionPanel extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<Widget> actions;

  const _ActionPanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(
                alpha: 0.12,
              ),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.4,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  crossAxisAlignment:
                      WrapCrossAlignment.center,
                  children: actions,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Terminal-state variant of [_ActionPanel] with no actions -- used once
/// the submission is rejected or fully stocked in.
class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _InfoPanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight:
                        FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
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