import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../models/inventory_item.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../services/treatment_service.dart';
import '../state/data_bus.dart';

/// Full detail page for one treatment record, mirroring the structure of
/// InventoryItemPage. Surfaces every TREATMENT/TREATMENT_ITEM column --
/// including who recorded the treatment and when, distinct from who
/// administered it and when, since the schema tracks those separately.
class TreatmentDetailPage extends StatefulWidget {
  final String treatId;
  const TreatmentDetailPage({super.key, required this.treatId});

  @override
  State<TreatmentDetailPage> createState() => _TreatmentDetailPageState();
}

class _TreatmentDetailPageState extends State<TreatmentDetailPage>
    with DataBusRefreshMixin<TreatmentDetailPage> {
  final TreatmentService _service = TreatmentService();

  TreatmentRecord? _record;
  List<TreatmentItemUsed> _itemsUsed = [];
  bool _loading = true;
  bool _notFound = false;

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
      final treatments = await _service.fetchTreatments();
      final record = treatments
          .where((t) => t.treatId == widget.treatId)
          .cast<TreatmentRecord?>()
          .firstWhere((t) => t != null, orElse: () => null);
      if (record == null) {
        if (!mounted) return;
        setState(() {
          _notFound = true;
          _loading = false;
        });
        return;
      }
      final itemsUsed = await _service.fetchItemsUsed(widget.treatId);
      if (!mounted) return;
      setState(() {
        _record = record;
        _itemsUsed = itemsUsed;
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

  IconData _speciesIcon(PetSpecies species) =>
      species == PetSpecies.dog ? Icons.pets : Icons.pets_outlined;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_notFound || _record == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.medical_services_outlined,
                size: 40, color: AppColors.mutedForeground),
            const SizedBox(height: 12),
            const Text('Treatment not found', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextButton(
                onPressed: () => context.go('/medical-records'),
                child: const Text('Back to Medical Records')),
          ],
        ),
      );
    }

    final record = _record!;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/medical-records'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Medical Records'),
            style: TextButton.styleFrom(foregroundColor: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(_speciesIcon(record.petSpecies), size: 22, color: AppColors.mutedForeground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(record.treatName,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            record.petBreed == null || record.petBreed!.isEmpty
                ? record.petName
                : '${record.petName} · ${record.petBreed}',
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FieldBlock(label: 'Performed by', value: record.performedByName),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FieldBlock(
                    label: 'Date administered', value: _formatDate(record.recDate)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FieldBlock(label: 'Recorded by', value: record.recordedByName),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FieldBlock(label: 'Recorded date', value: _formatDate(record.loggedDate)),
              ),
            ],
          ),
          if (record.notes != null && record.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _FieldBlock(label: 'Notes', value: record.notes!),
          ],
          const SizedBox(height: 24),

          const Text('Items Used', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (_itemsUsed.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No inventory items were logged for this treatment.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _itemsUsed.length; i++) ...[
                    if (i > 0) const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_itemsUsed[i].itemName,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('Given by ${_itemsUsed[i].givenBy}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.mutedForeground)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                                '${formatQty(_itemsUsed[i].dispensedQty)} ${_itemsUsed[i].dispenseUnitAbbr}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Given ${_formatDate(_itemsUsed[i].consumedDate)}',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.mutedForeground)),
                                Text(
                                    'Recorded by ${_itemsUsed[i].recordedByName} · ${_formatDate(_itemsUsed[i].recordedDate)}',
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.mutedForeground)),
                              ],
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
      ),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Text(value, style: const TextStyle(fontSize: 14)),
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
