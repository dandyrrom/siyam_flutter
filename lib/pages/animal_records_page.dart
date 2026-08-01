import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/pet.dart';
import '../services/pet_service.dart';
import '../state/data_bus.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/stat_card.dart';

class AnimalRecordsPage extends StatefulWidget {
  const AnimalRecordsPage({super.key});

  @override
  State<AnimalRecordsPage> createState() => _AnimalRecordsPageState();
}

class _AnimalRecordsPageState extends State<AnimalRecordsPage>
    with DataBusRefreshMixin<AnimalRecordsPage> {
  final PetService _service = PetService();

  List<Pet> _pets = [];
  bool _loading = true;
  String? _error;

  String _search = '';
  PetSpecies? _speciesFilter; // null = All
  PetStatus? _statusFilter; // null = All

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
        _error = null;
      });
    }
    try {
      final pets = await _service.fetchPets();
      if (!mounted) return;
      setState(() {
        _pets = pets;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'Could not load animal records: $e';
          _loading = false;
        });
      }
    }
  }

  List<Pet> get _filtered {
    return _pets.where((p) {
      final matchesSearch =
          _search.isEmpty || p.petName.toLowerCase().contains(_search.toLowerCase());
      final matchesSpecies = _speciesFilter == null || p.species == _speciesFilter;
      final matchesStatus = _statusFilter == null || p.status == _statusFilter;
      return matchesSearch && matchesSpecies && matchesStatus;
    }).toList();
  }

  (String, Color) _statusMeta(PetStatus status) {
    switch (status) {
      case PetStatus.available:
        return ('Available', AppColors.primary);
      case PetStatus.underTreatment:
        return ('Under Treatment', AppColors.warning);
      case PetStatus.adopted:
        return ('Adopted', AppColors.accent);
    }
  }

  IconData _speciesIcon(PetSpecies species) {
    return species == PetSpecies.dog ? Icons.pets : Icons.pets_outlined;
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _openAnimalFormDialog({Pet? pet}) async {
    final isEdit = pet != null;
    final nameCtrl = TextEditingController(text: pet?.petName ?? '');
    final breedCtrl = TextEditingController(text: pet?.breed ?? '');
    final formKey = GlobalKey<FormState>();
    PetSpecies species = pet?.species ?? PetSpecies.dog;
    PetGender gender = pet?.gender ?? PetGender.male;
    PetStatus status = pet?.status ?? PetStatus.available;
    bool spayedNeutered = pet?.spayedNeutered ?? false;
    var saving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? 'Edit Animal' : 'Add Animal'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    autofocus: !isEdit,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<PetSpecies>(
                    label: 'Species',
                    initialValue: species,
                    options: PetSpecies.values
                        .map((s) =>
                            AppDropdownOption(s, s == PetSpecies.dog ? 'Dog' : 'Cat'))
                        .toList(),
                    onChanged: (v) => setDialogState(() => species = v),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: breedCtrl,
                    decoration: const InputDecoration(labelText: 'Breed (optional)'),
                  ),
                  const SizedBox(height: 12),
                  AppDropdownField<PetGender>(
                    label: 'Gender',
                    initialValue: gender,
                    options: PetGender.values
                        .map((g) =>
                            AppDropdownOption(g, g == PetGender.male ? 'Male' : 'Female'))
                        .toList(),
                    onChanged: (v) => setDialogState(() => gender = v),
                  ),
                  if (isEdit) ...[
                    const SizedBox(height: 12),
                    AppDropdownField<PetStatus>(
                      label: 'Status',
                      initialValue: status,
                      options: PetStatus.values
                          .map((s) => AppDropdownOption(s, _statusMeta(s).$1))
                          .toList(),
                      onChanged: (v) => setDialogState(() => status = v),
                    ),
                  ],
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text('Spayed / Neutered'),
                    value: spayedNeutered,
                    onChanged: saving
                        ? null
                        : (v) => setDialogState(() => spayedNeutered = v ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(builderContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);

                      final successMessage = isEdit
                          ? '${nameCtrl.text.trim()} updated successfully'
                          : '${nameCtrl.text.trim()} added successfully';

                      try {
                        if (isEdit) {
                          await _service.updatePet(
                            petId: pet.petId,
                            petName: nameCtrl.text.trim(),
                            species: species,
                            gender: gender,
                            status: status,
                            breed: breedCtrl.text.trim().isEmpty
                                ? null
                                : breedCtrl.text.trim(),
                            spayedNeutered: spayedNeutered,
                          );
                        } else {
                          await _service.createPet(
                            petName: nameCtrl.text.trim(),
                            species: species,
                            gender: gender,
                            breed: breedCtrl.text.trim().isEmpty
                                ? null
                                : breedCtrl.text.trim(),
                            spayedNeutered: spayedNeutered,
                          );
                        }

                        if (builderContext.mounted) {
                          Navigator.of(builderContext).pop();
                        }

                        if (!mounted) return;
                        _showSuccessSnackBar(successMessage);
                        await _load();
                      } catch (e) {
                        if (!builderContext.mounted) return;
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(builderContext).clearSnackBars();
                        ScaffoldMessenger.of(builderContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not ${isEdit ? 'update' : 'add'} animal: $e',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isEdit ? const Text('Save Changes') : const Text('Add Animal'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    breedCtrl.dispose();
  }

  Future<void> _openDetailDialog(Pet pet) async {
    final (statusLabel, statusColor) = _statusMeta(pet.status);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(_speciesIcon(pet.species), size: 20, color: AppColors.mutedForeground),
            const SizedBox(width: 8),
            Expanded(child: Text(pet.petName, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Species', value: pet.species == PetSpecies.dog ? 'Dog' : 'Cat'),
              _DetailRow(label: 'Breed', value: pet.breed ?? '—'),
              _DetailRow(label: 'Gender', value: pet.gender == PetGender.male ? 'Male' : 'Female'),
              _DetailRow(label: 'Spayed/Neutered', value: pet.spayedNeutered ? 'Yes' : 'No'),
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
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openAnimalFormDialog(pet: pet);
            },
            child: const Text('Edit Animal'),
          ),
          AppMenuButton<PetStatus>(
            tooltip: 'Update status',
            options: PetStatus.values
                .map((s) => AppDropdownOption(s, _statusMeta(s).$1))
                .toList(),
            onSelected: (status) async {
              Navigator.of(context).pop();
              try {
                await _service.updateStatus(petId: pet.petId, status: status);
                if (!mounted) return;
                await _load();
                if (!mounted) return;
                _showSuccessSnackBar(
                  '${pet.petName}\'s status updated to ${_statusMeta(status).$1}',
                );
              } catch (e) {
                if (!mounted) return;
                _showErrorSnackBar('Could not update status for ${pet.petName}: $e');
              }
            },
            triggerBuilder: (context, isOpen) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Update Status', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // MOBILE DETECTION: Check if screen width is less than 600px
    // ============================================================
    final bool isMobile = MediaQuery.of(context).size.width < 600;

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

    final totalCount = _pets.length;
    final availableCount = _pets.where((p) => p.status == PetStatus.available).length;
    final treatmentCount = _pets.where((p) => p.status == PetStatus.underTreatment).length;
    final adoptedCount = _pets.where((p) => p.status == PetStatus.adopted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ============================================================
        // HEADER: Stacked on mobile, Row on web
        // ============================================================
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Animal Records',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _openAnimalFormDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Add Animal'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('Animal Records',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _openAnimalFormDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Animal'),
                  ),
                ],
              ),
        const SizedBox(height: 2),
        Text('$totalCount animals',
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
        const SizedBox(height: 20),

        // ============================================================
        // STAT CARDS: Stacked on mobile, Row on web
        // ============================================================
        isMobile
            ? Column(
                children: [
                  _buildMobileStatCard(
                    label: 'Total Animals',
                    value: '$totalCount',
                    icon: Icons.pets_outlined,
                    accent: AppColors.roleManager,
                  ),
                  const SizedBox(height: 10),
                  _buildMobileStatCard(
                    label: 'Available',
                    value: '$availableCount',
                    icon: Icons.check_circle_outline,
                    accent: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  _buildMobileStatCard(
                    label: 'Under Treatment',
                    value: '$treatmentCount',
                    icon: Icons.medical_services_outlined,
                    accent: AppColors.warning,
                  ),
                  const SizedBox(height: 10),
                  _buildMobileStatCard(
                    label: 'Adopted',
                    value: '$adoptedCount',
                    icon: Icons.home_outlined,
                    accent: AppColors.accent,
                  ),
                ],
              )
            : StatCardRow(cards: [
                StatCard(
                  label: 'Total Animals',
                  value: '$totalCount',
                  icon: Icons.pets_outlined,
                  accent: AppColors.roleManager,
                ),
                StatCard(
                  label: 'Available',
                  value: '$availableCount',
                  icon: Icons.check_circle_outline,
                  accent: AppColors.primary,
                ),
                StatCard(
                  label: 'Under Treatment',
                  value: '$treatmentCount',
                  icon: Icons.medical_services_outlined,
                  accent: AppColors.warning,
                ),
                StatCard(
                  label: 'Adopted',
                  value: '$adoptedCount',
                  icon: Icons.home_outlined,
                  accent: AppColors.accent,
                ),
              ]),
        const SizedBox(height: 20),

        // ============================================================
        // FILTERS: Responsive layout
        // ============================================================
        Wrap(
          spacing: isMobile ? 8 : 12,
          runSpacing: isMobile ? 8 : 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isMobile ? double.infinity : 280,
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Search animals…',
                  isDense: true,
                ),
              ),
            ),
            AppDropdown<PetSpecies?>(
              label: _speciesFilter == null
                  ? 'Species'
                  : (_speciesFilter == PetSpecies.dog ? 'Dog' : 'Cat'),
              options: const [
                AppDropdownOption(null, 'All species'),
                AppDropdownOption(PetSpecies.dog, 'Dog'),
                AppDropdownOption(PetSpecies.cat, 'Cat'),
              ],
              onSelect: (v) => setState(() => _speciesFilter = v),
            ),
            AppDropdown<PetStatus?>(
              label: _statusFilter == null ? 'Status' : _statusMeta(_statusFilter!).$1,
              options: [
                const AppDropdownOption(null, 'All statuses'),
                for (final s in PetStatus.values) AppDropdownOption(s, _statusMeta(s).$1),
              ],
              onSelect: (v) => setState(() => _statusFilter = v),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ============================================================
        // EMPTY STATES OR GRID
        // ============================================================
        if (_pets.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.pets_outlined, size: 36, color: AppColors.mutedForeground),
                  SizedBox(height: 10),
                  Text('No animals recorded yet', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  Text('No animals match your filters.',
                      style: TextStyle(color: AppColors.mutedForeground)),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isMobile ? 160 : 320,
              mainAxisExtent: isMobile ? 130 : 150,
              crossAxisSpacing: isMobile ? 10 : 16,
              mainAxisSpacing: isMobile ? 10 : 16,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final pet = _filtered[index];
              final (statusLabel, statusColor) = _statusMeta(pet.status);
              return _Hoverable(
                builder: (context, isHovered) => InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openDetailDialog(pet),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isHovered
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : AppColors.border,
                        width: isHovered ? 1.5 : 1,
                      ),
                      boxShadow: isHovered
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_speciesIcon(pet.species),
                                size: isMobile ? 18 : 20,
                                color: isHovered
                                    ? AppColors.primary
                                    : AppColors.mutedForeground),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(pet.petName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: isMobile ? 13 : 14,
                                    color: isHovered ? AppColors.primary : null,
                                  )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(pet.breed ?? (pet.species == PetSpecies.dog ? 'Dog' : 'Cat'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12.5,
                              color: AppColors.mutedForeground,
                            )),
                        const Spacer(),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: isHovered ? 0.2 : 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: isMobile ? 10 : 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // MOBILE STAT CARD
  // ============================================================
  Widget _buildMobileStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: accent),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Hoverable extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovered) builder;

  const _Hoverable({required this.builder});

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.builder(context, _isHovered),
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
            width: 130,
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