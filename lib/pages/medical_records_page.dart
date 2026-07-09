import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/inventory_item.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../services/inventory_service.dart';
import '../services/pet_service.dart';
import '../services/treatment_service.dart';
import '../state/auth_state.dart';
import '../widgets/stat_card.dart';

class MedicalRecordsPage extends StatefulWidget {
  const MedicalRecordsPage({super.key});

  @override
  State<MedicalRecordsPage> createState() => _MedicalRecordsPageState();
}

class _MedicalRecordsPageState extends State<MedicalRecordsPage> {
  final TreatmentService _treatmentService = TreatmentService();
  final PetService _petService = PetService();
  final InventoryService _inventoryService = InventoryService();

  List<TreatmentRecord> _treatments = [];
  List<Pet> _pets = [];
  List<InventoryItem> _items = [];
  int _totalItemsUsed = 0;

  bool _loading = true;
  String? _error;
  String _search = '';

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
        _treatmentService.fetchTreatments(),
        _petService.fetchPets(),
        _inventoryService.fetchItems(),
        _treatmentService.fetchTotalItemsUsed(),
      ]);
      if (!mounted) return;
      setState(() {
        _treatments = results[0] as List<TreatmentRecord>;
        _pets = results[1] as List<Pet>;
        _items = results[2] as List<InventoryItem>;
        _totalItemsUsed = results[3] as int;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load medical records: $e';
        _loading = false;
      });
    }
  }

  List<TreatmentRecord> get _filtered {
    if (_search.isEmpty) return _treatments;
    final q = _search.toLowerCase();
    return _treatments
        .where((t) =>
            t.petName.toLowerCase().contains(q) || t.treatName.toLowerCase().contains(q))
        .toList();
  }

  IconData _speciesIcon(PetSpecies species) =>
      species == PetSpecies.dog ? Icons.pets : Icons.pets_outlined;

  Future<void> _openDetailDialog(TreatmentRecord record) async {
    List<TreatmentItemUsed>? itemsUsed;
    String? itemsError;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (itemsUsed == null && itemsError == null) {
            _treatmentService.fetchItemsUsed(record.treatId).then((rows) {
              setDialogState(() => itemsUsed = rows);
            }).catchError((e) {
              setDialogState(() => itemsError = 'Could not load items used: $e');
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(_speciesIcon(record.petSpecies), size: 20, color: AppColors.mutedForeground),
                const SizedBox(width: 8),
                Expanded(child: Text(record.petName, overflow: TextOverflow.ellipsis)),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(label: 'Treatment', value: record.treatName),
                    _DetailRow(label: 'Performed by', value: record.performedByName),
                    _DetailRow(label: 'Date', value: _formatDate(record.recDate)),
                    if (record.notes != null && record.notes!.isNotEmpty)
                      _DetailRow(label: 'Notes', value: record.notes!),
                    const SizedBox(height: 8),
                    const Text('Items Used',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    const SizedBox(height: 8),
                    if (itemsError != null)
                      Text(itemsError!, style: const TextStyle(color: AppColors.destructive))
                    else if (itemsUsed == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (itemsUsed!.isEmpty)
                      const Text('No inventory items were logged for this treatment.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground))
                    else
                      for (final item in itemsUsed!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(child: Text(item.itemName)),
                              Text('${item.qtyUsed} ${item.itemUom}',
                                  style: const TextStyle(color: AppColors.mutedForeground)),
                            ],
                          ),
                        ),
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

  Future<void> _openLogTreatmentDialog() async {
    if (_pets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add an animal before logging a treatment.')));
      return;
    }

    final userId = context.read<AuthController>().profile?.userId;
    if (userId == null) return;

    final treatNameCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    Pet selectedPet = _pets.first;
    final List<TreatmentItemInput> itemRows = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Log Treatment'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<Pet>(
                      initialValue: selectedPet,
                      decoration: const InputDecoration(labelText: 'Animal'),
                      items: _pets
                          .map((p) => DropdownMenuItem(value: p, child: Text(p.petName)))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedPet = v ?? _pets.first),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: treatNameCtrl,
                      decoration: const InputDecoration(labelText: 'Treatment'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Items Used',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        TextButton.icon(
                          onPressed: _items.isEmpty
                              ? null
                              : () => setDialogState(() {
                                    final available = _items
                                        .where((i) => !itemRows.any((r) => r.itemId == i.itemId))
                                        .toList();
                                    if (available.isEmpty) return;
                                    final first = available.first;
                                    itemRows.add(TreatmentItemInput(
                                      itemId: first.itemId,
                                      itemName: first.itemName,
                                      itemUom: first.itemUom,
                                      stockQty: first.stockQty,
                                    ));
                                  }),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add item'),
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
                                  itemRows[idx] = TreatmentItemInput(
                                    itemId: picked.itemId,
                                    itemName: picked.itemName,
                                    itemUom: picked.itemUom,
                                    stockQty: picked.stockQty,
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
                                  if (n > row.stockQty) return 'Only ${row.stockQty} left';
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
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(context).pop();
                try {
                  await _treatmentService.createTreatment(
                    petId: selectedPet.petId,
                    userId: userId,
                    treatName: treatNameCtrl.text.trim(),
                    notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                    items: itemRows,
                  );
                  _load();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Could not log treatment: $e')));
                }
              },
              child: const Text('Log Treatment'),
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

    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final thisWeekCount = _treatments.where((t) => t.recDate.isAfter(weekAgo)).length;
    final distinctAnimals = _treatments.map((t) => t.petId).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('Medical Records',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            ElevatedButton.icon(
              onPressed: _openLogTreatmentDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Log Treatment'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('${_treatments.length} treatments logged',
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
        const SizedBox(height: 20),
        StatCardRow(cards: [
          StatCard(
            label: 'Total Treatments',
            value: '${_treatments.length}',
            icon: Icons.medical_services_outlined,
            accent: AppColors.roleStaff,
          ),
          StatCard(
            label: 'This Week',
            value: '$thisWeekCount',
            icon: Icons.calendar_today_outlined,
            accent: AppColors.roleStaff,
          ),
          StatCard(
            label: 'Animals Treated',
            value: '$distinctAnimals',
            icon: Icons.pets_outlined,
            accent: AppColors.roleStaff,
          ),
          StatCard(
            label: 'Items Used (Total)',
            value: '$_totalItemsUsed',
            icon: Icons.inventory_2_outlined,
            accent: AppColors.roleStaff,
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: 280,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Search by animal or treatment…',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_treatments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.medical_services_outlined,
                      size: 36, color: AppColors.mutedForeground),
                  SizedBox(height: 10),
                  Text('No treatments logged yet', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  Text('No records match your search.',
                      style: TextStyle(color: AppColors.mutedForeground)),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisExtent: 130,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final record = _filtered[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openDetailDialog(record),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(_speciesIcon(record.petSpecies),
                              size: 20, color: AppColors.mutedForeground),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(record.petName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(record.treatName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Text(record.performedByName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.mutedForeground)),
                          ),
                          Text(_formatDate(record.recDate),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.mutedForeground)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
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
