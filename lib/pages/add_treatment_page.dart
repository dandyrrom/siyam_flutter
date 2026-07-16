import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/inventory_item.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../services/inventory_service.dart';
import '../services/pet_service.dart';
import '../services/treatment_service.dart';
import '../state/auth_state.dart';
import '../widgets/search_select_field.dart';

/// Staff-only "Add Treatment" page. If [prefillItemId] is provided (from
/// the Inventory list's Stock Out -> Treatment action), one item row is
/// pre-populated with that item and [prefillQty].
class AddTreatmentPage extends StatefulWidget {
  final String? prefillItemId;
  final String? prefillQty;
  const AddTreatmentPage({super.key, this.prefillItemId, this.prefillQty});

  @override
  State<AddTreatmentPage> createState() => _AddTreatmentPageState();
}

class _AddTreatmentPageState extends State<AddTreatmentPage> {
  final TreatmentService _treatmentService = TreatmentService();
  final PetService _petService = PetService();
  final InventoryService _inventoryService = InventoryService();

  final _formKey = GlobalKey<FormState>();
  final _treatNameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _petCtrl = TextEditingController();
  final _administeredByCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  bool _saving = false;

  List<Pet> _pets = [];
  List<InventoryItem> _items = [];

  Pet? _selectedPet;
  DateTime _dateAdministered = DateTime.now();
  final List<TreatmentItemInput> _itemRows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _treatNameCtrl.dispose();
    _notesCtrl.dispose();
    _petCtrl.dispose();
    _administeredByCtrl.dispose();
    super.dispose();
  }

  /// Builds a form row for [item] -- the dose unit is fixed to the item's
  /// own configuration (dispense_unit, falling back to package_unit then
  /// purchase_unit), not a per-transaction choice.
  TreatmentItemInput _inputFromItem(InventoryItem item, {double qty = 1}) {
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
      qty: qty,
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final currentUser = context.read<AuthController>().profile;
    try {
      final results = await Future.wait([
        _petService.fetchPets(),
        _inventoryService.fetchItems(),
      ]);
      if (!mounted) return;

      final items = results[1] as List<InventoryItem>;

      if (widget.prefillItemId != null) {
        final match =
            items.where((i) => i.itemId == widget.prefillItemId).cast<InventoryItem?>().firstWhere(
                  (i) => i != null,
                  orElse: () => null,
                );
        if (match != null) {
          final qty = double.tryParse(widget.prefillQty ?? '') ?? 1;
          _itemRows.add(_inputFromItem(match, qty: qty));
        }
      }

      setState(() {
        _pets = results[0] as List<Pet>;
        _items = items;
        _selectedPet = _pets.isEmpty ? null : _pets.first;
        _petCtrl.text = _selectedPet?.petName ?? '';
        _administeredByCtrl.text = currentUser?.fullName ?? '';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load form data: $e';
        _loading = false;
      });
    }
  }

  void _addItemRow() {
    final available = _items.where((i) => !_itemRows.any((r) => r.itemId == i.itemId)).toList();
    if (available.isEmpty) return;
    setState(() => _itemRows.add(_inputFromItem(available.first)));
  }

  Future<void> _pickDateAdministered() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateAdministered,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateAdministered = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPet == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a pet.')));
      return;
    }
    if (_itemRows.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Add at least one item used.')));
      return;
    }
    final performedByUserId = context.read<AuthController>().profile?.userId;
    if (performedByUserId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not identify the signed-in user.')));
      return;
    }

    setState(() => _saving = true);
    try {
      await _treatmentService.createTreatment(
        petId: _selectedPet!.petId,
        administeredByName: _administeredByCtrl.text.trim(),
        performedByUserId: performedByUserId,
        treatName: _treatNameCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        dateAdministered: _dateAdministered,
        items: _itemRows,
      );
      if (!mounted) return;
      context.go('/medical-records');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not log treatment: $e')));
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

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
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
          const Text('Add Treatment',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _treatNameCtrl,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _pets.isEmpty
                          ? const TextField(
                              enabled: false,
                              decoration: InputDecoration(labelText: 'Pet (none available)'),
                            )
                          : SearchSelectField<Pet>(
                              labelText: 'Pet',
                              controller: _petCtrl,
                              options: _pets,
                              displayStringForOption: (p) => p.petName,
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? 'Required' : null,
                              onSelected: (p) => setState(() => _selectedPet = p),
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'Notes (optional)'),
                  maxLines: 3,
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Item Quantity',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    TextButton.icon(
                      onPressed: _items.isEmpty ? null : _addItemRow,
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add item'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_itemRows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Add at least one item used in this treatment.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                  ),
                for (final row in _itemRows) _ItemRow(
                  key: ValueKey(row.itemId),
                  row: row,
                  items: _items,
                  usedItemIds: _itemRows
                      .where((r) => r != row)
                      .map((r) => r.itemId)
                      .toSet(),
                  onRemove: () => setState(() => _itemRows.remove(row)),
                  onItemChanged: (picked) => setState(() {
                    final idx = _itemRows.indexOf(row);
                    _itemRows[idx] = _inputFromItem(picked, qty: row.qty);
                  }),
                  onChanged: () => setState(() {}),
                ),
                const SizedBox(height: 20),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _administeredByCtrl,
                        decoration: const InputDecoration(labelText: 'Administered by'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDateAdministered,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date administered'),
                          child: Text(_formatDate(_dateAdministered)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => context.go('/medical-records'),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final TreatmentItemInput row;
  final List<InventoryItem> items;
  final Set<String> usedItemIds;
  final VoidCallback onRemove;
  final ValueChanged<InventoryItem> onItemChanged;
  final VoidCallback onChanged;

  const _ItemRow({
    super.key,
    required this.row,
    required this.items,
    required this.usedItemIds,
    required this.onRemove,
    required this.onItemChanged,
    required this.onChanged,
  });

  /// The max dose quantity this row can validly deduct, in dose-unit terms.
  /// Only meaningful when [row.deductible] -- otherwise usage is logged
  /// without a stock check, since there's no conversion to validate against.
  double get _maxDoseQty {
    if (!row.deductible) return double.infinity;
    final packageQuantity = row.packageQuantity;
    return packageQuantity == null ? row.stockQty : row.stockQty * packageQuantity;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: row.itemId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Item'),
                  items: items
                      .where((i) => i.itemId == row.itemId || !usedItemIds.contains(i.itemId))
                      .map((i) => DropdownMenuItem(value: i.itemId, child: Text(i.itemName)))
                      .toList(),
                  onChanged: (v) {
                    final picked = items.firstWhere((i) => i.itemId == v);
                    onItemChanged(picked);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: formatQty(row.qty),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Dose (${row.doseUnitAbbr})'),
                  onChanged: (v) => row.qty = double.tryParse(v) ?? 0,
                  validator: (v) {
                    final n = double.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Invalid';
                    if (n > _maxDoseQty) return 'Only ${formatQty(_maxDoseQty)} left';
                    return null;
                  },
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          Row(
            children: [
              Icon(
                row.deductible ? Icons.check_circle_outline : Icons.info_outline,
                size: 14,
                color: row.deductible ? AppColors.roleManager : AppColors.mutedForeground,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  row.deductible
                      ? 'Will deduct from stock'
                      : 'Logged only — no stock conversion available for this item\'s dispense unit',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground),
                ),
              ),
            ],
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
