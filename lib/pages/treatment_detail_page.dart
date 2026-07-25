import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../services/inventory_service.dart';
import '../services/treatment_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import '../widgets/search_select_field.dart';

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
  final InventoryService _inventoryService = InventoryService();

  TreatmentRecord? _record;
  List<TreatmentItemUsed> _itemsUsed = [];
  List<InventoryItem> _items = [];
  bool _loading = true;
  bool _notFound = false;
  bool _addingItem = false;

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
      final results = await Future.wait([
        _service.fetchItemsUsed(widget.treatId),
        _inventoryService.fetchItems(),
      ]);
      if (!mounted) return;
      setState(() {
        _record = record;
        _itemsUsed = results[0] as List<TreatmentItemUsed>;
        _items = results[1] as List<InventoryItem>;
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

  Future<void> _openAddItemDialog() async {
    if (_items.isEmpty) return;
    final currentUser = context.read<AuthController>().profile;
    final existingByItemId = <String, List<TreatmentItemUsed>>{};
    for (final u in _itemsUsed) {
      (existingByItemId[u.itemId] ??= []).add(u);
    }
    final result = await showDialog<_AddTreatmentItemResult>(
      context: context,
      builder: (context) => _AddTreatmentItemDialog(
        items: _items,
        existingByItemId: existingByItemId,
        defaultAdministeredBy: currentUser?.fullName ?? '',
      ),
    );
    if (result == null || !mounted) return;

    final performedByUserId = currentUser?.userId;
    if (performedByUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not identify the signed-in user.')));
      return;
    }

    setState(() => _addingItem = true);
    try {
      await _service.addTreatmentItem(
        treatId: widget.treatId,
        item: result.input,
        administeredByName: result.administeredBy,
        performedByUserId: performedByUserId,
        dateAdministered: result.dateAdministered,
      );
      if (!mounted) return;
      setState(() => _addingItem = false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _addingItem = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not add item: $e')));
    }
  }

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

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Items Used',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              TextButton.icon(
                onPressed: (_addingItem || _items.isEmpty) ? null : _openAddItemDialog,
                icon: _addingItem
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add, size: 16),
                label: const Text('Add Item'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'This treatment is ongoing -- log another item (or another dose of one '
            'already listed) as it happens.',
            style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
          ),
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

class _AddTreatmentItemResult {
  final TreatmentItemInput input;
  final String administeredBy;
  final DateTime dateAdministered;

  const _AddTreatmentItemResult({
    required this.input,
    required this.administeredBy,
    required this.dateAdministered,
  });
}

/// Dialog for logging another item (or another dose of one already given
/// during this treatment) against an already-existing, ongoing treatment.
/// Re-picking an item already in [existingByItemId] does NOT merge with or
/// overwrite its prior dose(s) -- see [TreatmentService.addTreatmentItem] --
/// it's always written as its own separate, independently-timed dose. This
/// surfaces the prior dose(s) as context, not a merge warning.
class _AddTreatmentItemDialog extends StatefulWidget {
  final List<InventoryItem> items;
  final Map<String, List<TreatmentItemUsed>> existingByItemId;
  final String defaultAdministeredBy;

  const _AddTreatmentItemDialog({
    required this.items,
    required this.existingByItemId,
    required this.defaultAdministeredBy,
  });

  @override
  State<_AddTreatmentItemDialog> createState() => _AddTreatmentItemDialogState();
}

class _AddTreatmentItemDialogState extends State<_AddTreatmentItemDialog> {
  final _formKey = GlobalKey<FormState>();
  final _itemCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  late final _administeredByCtrl =
      TextEditingController(text: widget.defaultAdministeredBy);
  DateTime _dateAdministered = DateTime.now();
  InventoryItem? _selectedItem;

  @override
  void dispose() {
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _administeredByCtrl.dispose();
    super.dispose();
  }

  /// Mirrors AddTreatmentPage's `_inputFromItem` -- the dose unit is fixed
  /// to the item's own configuration, not a per-transaction choice.
  TreatmentItemInput _inputFromItem(InventoryItem item, double qty) {
    final doseUnitId = item.dispenseUnitId ?? item.packageUnitId ?? item.purchaseUnitId;
    final doseUnitAbbr =
        item.dispenseUnitAbbr ?? item.packageUnitAbbr ?? item.purchaseUnitAbbr;
    return TreatmentItemInput(
      itemId: item.itemId,
      itemName: item.itemName,
      doseUnitId: doseUnitId,
      doseUnitAbbr: doseUnitAbbr,
      deductible: item.stockOutIsDeductible,
      stockQty: item.stockQty,
      packageQuantity: item.packageQuantity,
      packageStockQty: item.packageStockQty,
      qty: qty,
    );
  }

  /// The max dose this can validly deduct, in dose-unit terms -- see
  /// AddTreatmentPage's `_ItemRow._maxDoseQty` for the same logic.
  double get _maxDoseQty {
    final item = _selectedItem;
    if (item == null || !item.stockOutIsDeductible) return double.infinity;
    final packageQuantity = item.packageQuantity;
    if (packageQuantity == null) return item.stockQty;
    return item.packageStockQty ?? item.stockQty * packageQuantity;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateAdministered,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateAdministered = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final item = _selectedItem;
    if (item == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select an item.')));
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    Navigator.of(context).pop(_AddTreatmentItemResult(
      input: _inputFromItem(item, qty),
      administeredBy: _administeredByCtrl.text.trim(),
      dateAdministered: _dateAdministered,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final item = _selectedItem;
    final priorDoses = item == null ? null : widget.existingByItemId[item.itemId];
    final mostRecentDose = priorDoses == null || priorDoses.isEmpty
        ? null
        : priorDoses.reduce(
            (a, b) => a.consumedDate.isAfter(b.consumedDate) ? a : b);
    final doseUnitAbbr =
        item?.dispenseUnitAbbr ?? item?.packageUnitAbbr ?? item?.purchaseUnitAbbr;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Item to Treatment'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchSelectField<InventoryItem>(
                labelText: 'Item',
                controller: _itemCtrl,
                options: widget.items,
                displayStringForOption: (i) => i.itemName,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                onSelected: (picked) => setState(() {
                  _selectedItem = picked;
                  _qtyCtrl.text = '1';
                }),
              ),
              if (mostRecentDose != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Already given ${priorDoses!.length} '
                  '${priorDoses.length == 1 ? 'time' : 'times'} in this treatment -- most '
                  'recently ${formatQty(mostRecentDose.dispensedQty)} '
                  '${mostRecentDose.dispenseUnitAbbr} on ${_formatDate(mostRecentDose.consumedDate)}. '
                  'This will be logged as a separate, additional dose.',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: doseUnitAbbr == null ? 'Dose' : 'Dose ($doseUnitAbbr)'),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Invalid';
                  if (n > _maxDoseQty) return 'Only ${formatQty(_maxDoseQty)} left';
                  return null;
                },
              ),
              if (item != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      item.stockOutIsDeductible
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                      size: 14,
                      color: item.stockOutIsDeductible
                          ? AppColors.roleManager
                          : AppColors.mutedForeground,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.stockOutIsDeductible
                            ? 'Will deduct from stock'
                            : 'Logged only — no stock conversion available for this '
                                'item\'s dispense unit',
                        style:
                            const TextStyle(fontSize: 12, color: AppColors.mutedForeground),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _administeredByCtrl,
                decoration: const InputDecoration(labelText: 'Administered by'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date administered'),
                  child: Text(_formatDate(_dateAdministered)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Add'),
        ),
      ],
    );
  }
}
