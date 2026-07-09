import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/donation.dart';
import '../models/inventory_item.dart';
import '../services/donation_service.dart';
import '../services/inventory_service.dart';
import '../state/auth_state.dart';
import '../widgets/create_item_dialog.dart';
import '../widgets/stat_card.dart';

class DonationsPage extends StatefulWidget {
  const DonationsPage({super.key});

  @override
  State<DonationsPage> createState() => _DonationsPageState();
}

class _DonationsPageState extends State<DonationsPage> {
  final DonationService _service = DonationService();
  final InventoryService _inventoryService = InventoryService();

  List<DonationSubmission> _submissions = [];
  List<InventoryItem> _items = [];
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
      final results = await Future.wait([
        _service.fetchSubmissions(),
        _inventoryService.fetchItems(),
      ]);
      if (!mounted) return;
      setState(() {
        _submissions = results[0] as List<DonationSubmission>;
        _items = results[1] as List<InventoryItem>;
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
    final revById = context.read<AuthController>().profile?.userId;
    if (revById == null) return;
    try {
      await _service.rejectSubmission(subId: sub.subId, revById: revById);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not reject donation: $e')));
    }
  }

  Future<void> _openApproveDialog(DonationSubmission sub) async {
    final revById = context.read<AuthController>().profile?.userId;
    if (revById == null) return;

    final formKey = GlobalKey<FormState>();
    final List<DonationItemInput> itemRows = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Approve Donation from ${sub.donorName}'),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Record what was actually received. This will add to inventory stock.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: [
                        const Text('Items Received',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        Wrap(
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                final newItem = await showCreateItemDialog(context,
                                    service: _inventoryService);
                                if (newItem == null) return;
                                setDialogState(() {
                                  _items.add(newItem);
                                  itemRows.add(DonationItemInput(
                                    itemId: newItem.itemId,
                                    itemName: newItem.itemName,
                                    itemUom: newItem.itemUom,
                                  ));
                                });
                              },
                              icon: const Icon(Icons.add_box_outlined, size: 16),
                              label: const Text('New item'),
                            ),
                            TextButton.icon(
                              onPressed: () => setDialogState(() {
                                final available = _items
                                    .where((i) => !itemRows.any((r) => r.itemId == i.itemId))
                                    .toList();
                                if (available.isEmpty) return;
                                final first = available.first;
                                itemRows.add(DonationItemInput(
                                  itemId: first.itemId,
                                  itemName: first.itemName,
                                  itemUom: first.itemUom,
                                ));
                              }),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add item'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    for (final row in itemRows)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                initialValue: row.itemId,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Item'),
                                items: _items
                                    .map((i) => DropdownMenuItem(
                                        value: i.itemId, child: Text(i.itemName)))
                                    .toList(),
                                onChanged: (v) => setDialogState(() {
                                  final picked = _items.firstWhere((i) => i.itemId == v);
                                  final idx = itemRows.indexOf(row);
                                  itemRows[idx] = DonationItemInput(
                                    itemId: picked.itemId,
                                    itemName: picked.itemName,
                                    itemUom: picked.itemUom,
                                    qty: row.qty,
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                key: ValueKey(row.itemId),
                                initialValue: '${row.qty}',
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: 'Qty (${row.itemUom})'),
                                onChanged: (v) => row.qty = int.tryParse(v) ?? 0,
                                validator: (v) {
                                  final n = int.tryParse(v ?? '');
                                  if (n == null || n <= 0) return 'Invalid';
                                  return null;
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: () => setDialogState(() => itemRows.remove(row)),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                      ),
                    if (itemRows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Add at least one item to approve this donation.',
                            style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: itemRows.isEmpty
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      Navigator.of(context).pop();
                      try {
                        await _service.approveSubmission(
                          subId: sub.subId,
                          donorId: sub.donorId,
                          revById: revById,
                          items: itemRows,
                        );
                        _load();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not approve donation: $e')));
                      }
                    },
              child: const Text('Approve & Record'),
            ),
          ],
        ),
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
        const Text('Donations',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
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
            DropdownButton<SubmissionStatus?>(
              value: _statusFilter,
              hint: const Text('Status'),
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(value: null, child: Text('All statuses')),
                ...SubmissionStatus.values.map(
                    (s) => DropdownMenuItem(value: s, child: Text(_statusMeta(s).$1))),
              ],
              onChanged: (v) => setState(() => _statusFilter = v),
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
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filtered.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final sub = _filtered[index];
                final (statusLabel, statusColor) = _statusMeta(sub.status);
                return Padding(
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
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.mutedForeground)),
                      ),
                      SizedBox(
                        width: 160,
                        child: Text(
                            sub.schedDate == null
                                ? 'No drop-off date'
                                : 'Drop-off ${_formatDate(sub.schedDate!)}',
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.mutedForeground)),
                      ),
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
                      if (sub.status == SubmissionStatus.pending) ...[
                        OutlinedButton(
                          onPressed: () => _reject(sub),
                          child: const Text('Reject'),
                        ),
                        ElevatedButton(
                          onPressed: () => _openApproveDialog(sub),
                          child: const Text('Approve'),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
