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

  // Track if the widget is mounted and safe for state updates
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    // Use WidgetsBinding to ensure the widget is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  // Safe state update method
  void _safeSetState(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!_isMounted || !mounted) return;

    if (!silent) {
      _safeSetState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final pets = await _service.fetchPets();
      if (!_isMounted || !mounted) return;
      _safeSetState(() {
        _pets = pets;
        _loading = false;
      });
    } catch (e) {
      if (!_isMounted || !mounted) return;
      if (!silent) {
        _safeSetState(() {
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

  void _showSuccessSnackBar(BuildContext context, String message) {
    // Check if the context is still valid
    if (!_isMounted || !mounted) return;
    
    // Use a try-catch to handle any context issues
    try {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          width: 500,
        ),
      );
    } catch (e) {
      debugPrint('Failed to show success snackbar: $e');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    if (!_isMounted || !mounted) return;
    
    try {
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
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          width: 500,
        ),
      );
    } catch (e) {
      debugPrint('Failed to show error snackbar: $e');
    }
  }

  // Custom elevated button with hover effect
  Widget _buildElevatedButton({
    required VoidCallback? onPressed,
    required Widget child,
    bool isLoading = false,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isHovered 
                  ? (backgroundColor ?? AppColors.primary).withValues(alpha: 0.85)
                  : backgroundColor ?? AppColors.primary,
              foregroundColor: foregroundColor ?? Colors.white,
              elevation: isHovered ? 8 : 2,
              shadowColor: Colors.black.withValues(alpha: isHovered ? 0.3 : 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : child,
          ),
        );
      },
    );
  }

  // Custom text button with hover effect
  Widget _buildTextButton({
    required VoidCallback? onPressed,
    required Widget child,
    Color? foregroundColor,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: isHovered 
                  ? (foregroundColor ?? AppColors.mutedForeground).withValues(alpha: 0.7)
                  : foregroundColor ?? AppColors.mutedForeground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: child,
          ),
        );
      },
    );
  }

  // Custom icon button with hover effect
  Widget _buildIconButton({
    required VoidCallback? onPressed,
    required IconData icon,
    Color? color,
    bool? disabled,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: IconButton(
            icon: Icon(icon),
            onPressed: disabled == true ? null : onPressed,
            color: isHovered && disabled != true
                ? (color ?? AppColors.mutedForeground).withValues(alpha: 0.7)
                : color ?? AppColors.mutedForeground,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        );
      },
    );
  }

  // Custom action button with hover effect (for Edit/Update buttons)
  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isHovered 
                    ? (backgroundColor ?? AppColors.primary).withValues(alpha: 0.85)
                    : backgroundColor ?? AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: (backgroundColor ?? AppColors.primary).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: foregroundColor ?? Colors.white),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(color: foregroundColor ?? Colors.white)),
                ],
              ),
            ),
          ),
        );
      },
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

    // Store the current context for snackbar display
    final currentContext = context;

    await showDialog(
      context: currentContext,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_outlined : Icons.add,
                size: 20,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(isEdit ? 'Edit Animal' : 'Add Animal'),
              ),
              _buildIconButton(
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                icon: Icons.close,
                color: AppColors.mutedForeground,
                disabled: saving,
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      autofocus: !isEdit,
                      decoration: const InputDecoration(labelText: 'Name *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    AppDropdownField<PetSpecies>(
                      label: 'Species *',
                      initialValue: species,
                      options: PetSpecies.values
                          .map((s) => AppDropdownOption(
                              s, s == PetSpecies.dog ? 'Dog' : 'Cat'))
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
                      label: 'Gender *',
                      initialValue: gender,
                      options: PetGender.values
                          .map((g) => AppDropdownOption(
                              g, g == PetGender.male ? 'Male' : 'Female'))
                          .toList(),
                      onChanged: (v) => setDialogState(() => gender = v),
                    ),
                    const SizedBox(height: 12),
                    AppDropdownField<PetStatus>(
                      label: 'Status *',
                      initialValue: status,
                      options: PetStatus.values
                          .map((s) => AppDropdownOption(s, _statusMeta(s).$1))
                          .toList(),
                      onChanged: (v) => setDialogState(() => status = v),
                    ),
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
          ),
          actions: [
            _buildTextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            _buildElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
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
                            status: status,
                            breed: breedCtrl.text.trim().isEmpty
                                ? null
                                : breedCtrl.text.trim(),
                            spayedNeutered: spayedNeutered,
                          );
                        }
                        
                        // Close the dialog
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        
                        // Show snackbar after dialog is closed
                        await Future.delayed(const Duration(milliseconds: 100));
                        
                        if (!_isMounted || !mounted) return;
                        _showSuccessSnackBar(
                          currentContext,
                          isEdit
                              ? '${nameCtrl.text.trim()} updated successfully'
                              : '${nameCtrl.text.trim()} added successfully',
                        );
                        
                        // Refresh the data
                        await _load();
                      } catch (e) {
                        if (!context.mounted) return;
                        setDialogState(() => saving = false);
                        _showErrorSnackBar(
                          currentContext,
                          'Could not ${isEdit ? 'update' : 'add'} animal: $e',
                        );
                      }
                    },
              child: Text(isEdit ? 'Save Changes' : 'Add Animal'),
              isLoading: saving,
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
    final currentContext = context;

    await showDialog(
      context: currentContext,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(_speciesIcon(pet.species), size: 20, color: AppColors.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(pet.petName, overflow: TextOverflow.ellipsis),
            ),
            _buildIconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.close,
              color: AppColors.mutedForeground,
            ),
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
          _buildActionButton(
            onTap: () {
              Navigator.of(context).pop();
              _openAnimalFormDialog(pet: pet);
            },
            icon: Icons.edit_outlined,
            label: 'Edit Animal',
          ),
          _buildActionButton(
            onTap: () {
              // The Update Status button needs to show a dropdown
              // We'll use the AppMenuButton for that
            },
            icon: Icons.update,
            label: 'Update Status',
          ),
          // Use AppMenuButton for Update Status with the same hover style
          AppMenuButton<PetStatus>(
            tooltip: 'Update status',
            options: PetStatus.values
                .map((s) => AppDropdownOption(s, _statusMeta(s).$1))
                .toList(),
            onSelected: (status) async {
              Navigator.of(context).pop();
              try {
                await _service.updateStatus(petId: pet.petId, status: status);
                if (!_isMounted || !mounted) return;
                await _load();
                if (!_isMounted || !mounted) return;
                _showSuccessSnackBar(
                  currentContext,
                  '${pet.petName}\'s status updated to ${_statusMeta(status).$1}',
                );
              } catch (e) {
                if (!_isMounted || !mounted) return;
                _showErrorSnackBar(
                  currentContext,
                  'Could not update status for ${pet.petName}: $e',
                );
              }
            },
            triggerBuilder: (context, isOpen) => _buildActionButton(
              onTap: () {},
              icon: Icons.update,
              label: 'Update Status',
            ),
          ),
        ],
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

    final totalCount = _pets.length;
    final availableCount = _pets.where((p) => p.status == PetStatus.available).length;
    final treatmentCount = _pets.where((p) => p.status == PetStatus.underTreatment).length;
    final adoptedCount = _pets.where((p) => p.status == PetStatus.adopted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
        StatCardRow(cards: [
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
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 150,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final pet = _filtered[index];
              final (statusLabel, statusColor) = _statusMeta(pet.status);
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openDetailDialog(pet),
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
                          Icon(_speciesIcon(pet.species),
                              size: 20, color: AppColors.mutedForeground),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(pet.petName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(pet.breed ?? (pet.species == PetSpecies.dog ? 'Dog' : 'Cat'),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(statusLabel,
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                        ),
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