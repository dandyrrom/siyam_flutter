import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_theme.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../services/pet_service.dart';
import '../services/treatment_service.dart';

class MedicalRecordsPage extends StatefulWidget {
  const MedicalRecordsPage({super.key});

  @override
  State<MedicalRecordsPage> createState() => _MedicalRecordsPageState();
}

class _MedicalRecordsPageState extends State<MedicalRecordsPage> {
  final TreatmentService _treatmentService = TreatmentService();
  final PetService _petService = PetService();

  List<TreatmentRecord> _treatments = [];
  List<Pet> _pets = [];

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
      ]);
      if (!mounted) return;
      setState(() {
        _treatments = results[0] as List<TreatmentRecord>;
        _pets = results[1] as List<Pet>;
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
              onPressed: _pets.isEmpty
                  ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Add an animal before logging a treatment.')))
                  : () => context.push('/medical-records/add'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Log Treatment'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('${_treatments.length} treatments logged',
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
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
                onTap: () => context.push('/medical-records/${record.treatId}'),
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

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
