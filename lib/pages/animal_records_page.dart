import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../services/pet_service.dart';
import '../services/treatment_service.dart';
import '../state/data_bus.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/stat_card.dart';

enum _AnimalSort {
  nameAZ,
  nameZA,
}

class AnimalRecordsPage extends StatefulWidget {
  const AnimalRecordsPage({super.key});

  @override
  State<AnimalRecordsPage> createState() => _AnimalRecordsPageState();
}

class _AnimalRecordsPageState extends State<AnimalRecordsPage>
    with DataBusRefreshMixin<AnimalRecordsPage> {
  final PetService _service = PetService();
  final TreatmentService _treatmentService = TreatmentService();

  List<Pet> _pets = [];
  List<TreatmentRecord> _treatments = [];

  bool _loading = true;
  String? _error;

  String _search = '';
  PetSpecies? _speciesFilter;
  PetStatus? _statusFilter;
  String? _breedFilter;
  _AnimalSort _sort = _AnimalSort.nameAZ;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  // ===========================================================================
  // LOAD
  // ===========================================================================
  //
  // Animal records are the primary data for this Manager page.
  //
  // Treatment loading is intentionally isolated so that a treatment-read
  // failure does NOT prevent the Manager from opening Animal Records.
  // ===========================================================================

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final pets = await _service.fetchPets();

      List<TreatmentRecord> treatments = [];

      try {
        treatments = await _treatmentService.fetchTreatments();
      } catch (_) {
        // LATEST TREATMENT FALLBACK:
        // Animal Records remains usable even if treatment summary data
        // cannot be loaded for the current role/session.
        treatments = [];
      }

      if (!mounted) return;

      setState(() {
        _pets = pets;
        _treatments = treatments;
        _loading = false;
        _error = null;
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

  // ===========================================================================
  // TEXT HELPERS
  // ===========================================================================

  String _cleanText(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String? _cleanOptional(String value) {
    final cleaned = _cleanText(value);
    return cleaned.isEmpty ? null : cleaned;
  }

  String _key(String? value) {
    return _cleanText(value ?? '').toLowerCase();
  }

  // ===========================================================================
  // BREED SEARCH TERMS
  // ===========================================================================
  //
  // A detailed mixed breed such as "Husky-Samoyed Mix" must be discoverable
  // using Husky, Samoyed, or Mix. The full breed description is also retained.
  //
  // We split only on clear mixed-breed separators so multi-word breeds such as
  // "German Shepherd" remain intact.
  // ===========================================================================

  List<String> _breedTerms(String? value) {
    final clean = _cleanText(value ?? '');

    if (clean.isEmpty) {
      return const [];
    }

    final terms = <String, String>{};

    void addTerm(String raw) {
      var term = _cleanText(raw);

      if (term.isEmpty) return;

      term = term.replaceAll(
        RegExp(
          r'\b(mixed?\s*breed|mixed|mix)\b',
          caseSensitive: false,
        ),
        '',
      );

      term = _cleanText(term);

      if (term.isEmpty) return;

      terms.putIfAbsent(
        term.toLowerCase(),
        () => term,
      );
    }

    // Keep the complete stored description.
    terms.putIfAbsent(
      clean.toLowerCase(),
      () => clean,
    );

    final parts = clean.split(
      RegExp(
        r'\s*(?:×|/|\+|&|-|–|—|\bx\b|\band\b)\s*',
        caseSensitive: false,
      ),
    );

    for (final part in parts) {
      addTerm(part);
    }

    if (RegExp(
      r'\b(mix|mixed)\b',
      caseSensitive: false,
    ).hasMatch(clean)) {
      terms.putIfAbsent(
        'mix',
        () => 'Mix',
      );
    }

    final values = terms.values.toList();

    values.sort(
      (a, b) =>
          a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return values;
  }

  bool _breedMatches(
    String? breed,
    String query,
  ) {
    final q = _key(query);

    if (q.isEmpty) return true;

    if (_key(breed).contains(q)) {
      return true;
    }

    return _breedTerms(breed).any(
      (term) => _key(term).contains(q),
    );
  }

  String _cleanError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  // ===========================================================================
  // LATEST TREATMENT
  // ===========================================================================
  //
  // Manager only sees the newest treatment as contextual information.
  //
  // No navigation to Staff-only Medical Records is exposed here.
  // ===========================================================================

  TreatmentRecord? _latestTreatmentForPet(String petId) {
    TreatmentRecord? latest;

    for (final treatment in _treatments) {
      if (treatment.petId != petId) continue;

      if (latest == null ||
          treatment.recDate.isAfter(latest.recDate)) {
        latest = treatment;
      }
    }

    return latest;
  }

  // ===========================================================================
  // BREED VALIDATION
  // ===========================================================================
  //
  // Panel feedback:
  // Generic values such as "Mixed Breed" are not detailed enough.
  //
  // Preferred:
  // Persian × Siamese
  // Labrador x German Shepherd
  // Husky-Samoyed Mix
  // Aspin / Beagle
  // ===========================================================================

  String? _validateBreed(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final clean = _cleanText(value);
    final lower = clean.toLowerCase();

    const genericMixedBreeds = {
      'mix',
      'mixed',
      'mixed breed',
      'mixed-breed',
    };

    if (genericMixedBreeds.contains(lower)) {
      return 'Specify the breeds in the mix';
    }

    final mentionsMix =
        RegExp(r'\bmix(ed)?\b').hasMatch(lower);

    if (mentionsMix) {
      final hasClearCombination =
          clean.contains('×') ||
          RegExp(r'\s[xX]\s').hasMatch(clean) ||
          clean.contains('/') ||
          clean.contains('+') ||
          clean.contains('-') ||
          clean.contains('–') ||
          clean.contains('—') ||
          RegExp(
            r'\sand\s',
            caseSensitive: false,
          ).hasMatch(clean);

      if (!hasClearCombination) {
        return 'Specify both breeds, e.g. Persian × Siamese';
      }
    }

    return null;
  }

  // ===========================================================================
  // BREED OPTIONS
  // ===========================================================================

  List<String> get _breedOptions {
    final breeds = <String, String>{};

    for (final pet in _pets) {
      final breed = pet.breed?.trim();

      if (breed == null || breed.isEmpty) {
        continue;
      }

      for (final term in _breedTerms(breed)) {
        breeds.putIfAbsent(
          term.toLowerCase(),
          () => term,
        );
      }
    }

    final values = breeds.values.toList();

    values.sort(
      (a, b) =>
          a.toLowerCase().compareTo(b.toLowerCase()),
    );

    return values;
  }

  // ===========================================================================
  // FILTER + SORT
  // ===========================================================================

  List<Pet> get _filtered {
    final q = _search.trim().toLowerCase();

    final result = _pets.where((pet) {
      final matchesSearch =
          q.isEmpty ||
          pet.petName.toLowerCase().contains(q) ||
          _breedMatches(pet.breed, q) ||
          (pet.owner ?? '').toLowerCase().contains(q);

      final matchesSpecies =
          _speciesFilter == null ||
          pet.species == _speciesFilter;

      final matchesStatus =
          _statusFilter == null ||
          pet.status == _statusFilter;

      final matchesBreed =
          _breedFilter == null ||
          _breedMatches(
            pet.breed,
            _breedFilter!,
          );

      return matchesSearch &&
          matchesSpecies &&
          matchesStatus &&
          matchesBreed;
    }).toList();

    result.sort((a, b) {
      final comparison = a.petName
          .toLowerCase()
          .compareTo(b.petName.toLowerCase());

      return _sort == _AnimalSort.nameAZ
          ? comparison
          : -comparison;
    });

    return result;
  }

  // ===========================================================================
  // DUPLICATE CHECK
  // ===========================================================================
  //
  // Same name alone is NOT considered a duplicate.
  //
  // We block:
  //
  // 1. Exact identifying details:
  //    Name + Species + Breed + Owner + Gender + Spayed/Neutered
  //
  // 2. Strong ownership duplicate:
  //    Same Name + Same Species + Same NON-EMPTY Owner
  //
  // This prevents the same owned animal from being entered twice just because
  // another descriptive field was entered differently.
  // ===========================================================================

  bool _isDuplicate({
    required String petName,
    required PetSpecies species,
    required PetGender gender,
    required bool spayedNeutered,
    String? breed,
    String? owner,
    String? excludePetId,
  }) {
    final ownerKey = _key(owner);

    return _pets.any((existing) {
      if (existing.petId == excludePetId) {
        return false;
      }

      final sameName =
          _key(existing.petName) == _key(petName);

      final sameSpecies =
          existing.species == species;

      final exactIdentity =
          sameName &&
          sameSpecies &&
          existing.gender == gender &&
          _key(existing.breed) == _key(breed) &&
          _key(existing.owner) == ownerKey &&
          existing.spayedNeutered == spayedNeutered;

      final sameOwnedAnimal =
          ownerKey.isNotEmpty &&
          sameName &&
          sameSpecies &&
          _key(existing.owner) == ownerKey;

      return exactIdentity || sameOwnedAnimal;
    });
  }

  // ===========================================================================
  // STATUS
  // ===========================================================================

  (String, Color) _statusMeta(PetStatus status) {
    switch (status) {
      case PetStatus.healthy:
        return ('Healthy', AppColors.primary);

      case PetStatus.underTreatment:
        return ('Under Treatment', AppColors.warning);

      case PetStatus.adopted:
        return ('Adopted', AppColors.accent);

      case PetStatus.deceased:
        return ('Deceased', AppColors.mutedForeground);
    }
  }

  IconData _speciesIcon(PetSpecies species) {
    return species == PetSpecies.dog
        ? Icons.pets
        : Icons.pets_outlined;
  }

  // ===========================================================================
  // SNACKBARS
  // ===========================================================================

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: AppColors.sageGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
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
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(message),
            ),
          ],
        ),
        backgroundColor: AppColors.destructive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ===========================================================================
  // ADD / EDIT ANIMAL
  // ===========================================================================

  Future<void> _openAnimalFormDialog({
    Pet? pet,
  }) async {
    final isEdit = pet != null;

    final nameCtrl = TextEditingController(
      text: pet?.petName ?? '',
    );

    final breedCtrl = TextEditingController(
      text: pet?.breed ?? '',
    );

    final ownerCtrl = TextEditingController(
      text: pet?.owner ?? '',
    );

    final formKey = GlobalKey<FormState>();

    PetSpecies species =
        pet?.species ?? PetSpecies.dog;

    PetGender gender =
        pet?.gender ?? PetGender.male;

    PetStatus status =
        pet?.status ?? PetStatus.healthy;

    bool spayedNeutered =
        pet?.spayedNeutered ?? false;

    bool saving = false;
    String? duplicateError;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            builderContext,
            setDialogState,
          ) {
            final screen =
                MediaQuery.sizeOf(builderContext);

            final contentWidth =
                screen.width < 520
                    ? screen.width - 96
                    : 430.0;

            final maxContentHeight =
                screen.height < 760
                    ? screen.height * 0.58
                    : 500.0;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isEdit
                    ? 'Edit Animal'
                    : 'Add Animal',
              ),
              content: SizedBox(
                width: contentWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: maxContentHeight,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          // ===================================================
                          // NAME
                          // ===================================================

                          TextFormField(
                            controller: nameCtrl,
                            autofocus: !isEdit,
                            onChanged: (_) {
                              setDialogState(() {
                                duplicateError = null;
                              });
                            },
                            decoration:
                                const InputDecoration(
                              labelText: 'Name',
                            ),
                            validator: (value) {
                              if (value == null ||
                                  value.trim().isEmpty) {
                                return 'Required';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 12),

                          // ===================================================
                          // SPECIES
                          // ===================================================

                          AppDropdownField<PetSpecies>(
                            label: 'Species',
                            initialValue: species,
                            options:
                                PetSpecies.values.map(
                              (value) {
                                return AppDropdownOption(
                                  value,
                                  value == PetSpecies.dog
                                      ? 'Dog'
                                      : 'Cat',
                                );
                              },
                            ).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                species = value;
                                duplicateError = null;
                              });
                            },
                          ),

                          const SizedBox(height: 12),

                          // ===================================================
                          // BREED
                          // ===================================================

                          TextFormField(
                            controller: breedCtrl,
                            onChanged: (_) {
                              setDialogState(() {
                                duplicateError = null;
                              });
                            },
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Breed (optional)',
                              hintText:
                                  'e.g. Husky-Samoyed Mix',
                              helperText:
                                  'For mixed breeds, specify the component breeds.',
                            ),
                            validator: _validateBreed,
                          ),

                          const SizedBox(height: 12),

                          // ===================================================
                          // OWNER
                          // ===================================================

                          TextFormField(
                            controller: ownerCtrl,
                            onChanged: (_) {
                              setDialogState(() {
                                duplicateError = null;
                              });
                            },
                            decoration:
                                const InputDecoration(
                              labelText:
                                  'Owner (optional)',
                              helperText:
                                  'Leave blank if no owner is known.',
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ===================================================
                          // GENDER
                          // ===================================================

                          AppDropdownField<PetGender>(
                            label: 'Gender',
                            initialValue: gender,
                            options:
                                PetGender.values.map(
                              (value) {
                                return AppDropdownOption(
                                  value,
                                  value == PetGender.male
                                      ? 'Male'
                                      : 'Female',
                                );
                              },
                            ).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                gender = value;
                                duplicateError = null;
                              });
                            },
                          ),

                          // ===================================================
                          // STATUS
                          // ===================================================

                          if (isEdit) ...[
                            const SizedBox(height: 12),

                            AppDropdownField<PetStatus>(
                              label: 'Status',
                              initialValue: status,
                              options:
                                  PetStatus.values.map(
                                (value) {
                                  return AppDropdownOption(
                                    value,
                                    _statusMeta(value).$1,
                                  );
                                },
                              ).toList(),
                              onChanged: (value) {
                                setDialogState(() {
                                  status = value;
                                });
                              },
                            ),
                          ],

                          const SizedBox(height: 8),

                          // ===================================================
                          // SPAYED / NEUTERED
                          // ===================================================

                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            title: const Text(
                              'Spayed / Neutered',
                            ),
                            value: spayedNeutered,
                            onChanged: saving
                                ? null
                                : (value) {
                                    setDialogState(() {
                                      spayedNeutered =
                                          value ?? false;
                                      duplicateError =
                                          null;
                                    });
                                  },
                          ),

                          // ===================================================
                          // DUPLICATE ERROR
                          // ===================================================

                          if (duplicateError != null) ...[
                            const SizedBox(height: 4),

                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 16,
                                  color:
                                      AppColors.destructive,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    duplicateError!,
                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                      color: AppColors
                                          .destructive,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(
                            builderContext,
                          ).pop();
                        },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!
                              .validate()) {
                            return;
                          }

                          final cleanName =
                              _cleanText(nameCtrl.text);

                          final cleanBreed =
                              _cleanOptional(
                            breedCtrl.text,
                          );

                          final cleanOwner =
                              _cleanOptional(
                            ownerCtrl.text,
                          );

                          // ===============================================
                          // DUPLICATE CHECK
                          // ===============================================

                          if (_isDuplicate(
                            petName: cleanName,
                            species: species,
                            gender: gender,
                            breed: cleanBreed,
                            owner: cleanOwner,
                            spayedNeutered:
                                spayedNeutered,
                            excludePetId: pet?.petId,
                          )) {
                            setDialogState(() {
                              duplicateError =
                                  'This animal already has a record with the same identifying details or owner.';
                            });

                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            duplicateError = null;
                          });

                          try {
                            if (isEdit) {
                              await _service.updatePet(
                                petId: pet.petId,
                                petName: cleanName,
                                species: species,
                                gender: gender,
                                status: status,
                                breed: cleanBreed,
                                owner: cleanOwner,
                                spayedNeutered:
                                    spayedNeutered,
                              );
                            } else {
                              await _service.createPet(
                                petName: cleanName,
                                species: species,
                                gender: gender,
                                breed: cleanBreed,
                                owner: cleanOwner,
                                spayedNeutered:
                                    spayedNeutered,
                              );
                            }

                            if (!builderContext.mounted) {
                              return;
                            }

                            Navigator.of(
                              builderContext,
                            ).pop();

                            if (!mounted) return;

                            _showSuccessSnackBar(
                              isEdit
                                  ? '$cleanName updated successfully'
                                  : '$cleanName added successfully',
                            );

                            await _load();
                          } catch (e) {
                            if (!builderContext.mounted) {
                              return;
                            }

                            setDialogState(() {
                              saving = false;
                            });

                            ScaffoldMessenger.of(
                              builderContext,
                            ).clearSnackBars();

                            ScaffoldMessenger.of(
                              builderContext,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _cleanError(e),
                                ),
                                backgroundColor:
                                    AppColors.destructive,
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEdit
                              ? 'Save Changes'
                              : 'Add Animal',
                        ),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    breedCtrl.dispose();
    ownerCtrl.dispose();
  }

  // ===========================================================================
  // ANIMAL DETAILS
  // ===========================================================================
  //
  // Manager sees:
  // - animal information
  // - current status
  // - latest treatment only
  //
  // Manager does NOT receive navigation to the Staff-only Medical module.
  // ===========================================================================

  Future<void> _openDetailDialog(
    Pet pet,
  ) async {
    final (
      statusLabel,
      statusColor,
    ) = _statusMeta(pet.status);

    final latestTreatment =
        _latestTreatmentForPet(pet.petId);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screen =
            MediaQuery.sizeOf(dialogContext);

        final contentWidth =
            screen.width < 620
                ? screen.width - 96
                : 520.0;

        final maxContentHeight =
            screen.height < 760
                ? screen.height * 0.62
                : 550.0;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                _speciesIcon(pet.species),
                size: 20,
                color:
                    AppColors.mutedForeground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pet.petName,
                  overflow:
                      TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: contentWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxContentHeight,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // =========================================================
                    // ANIMAL INFORMATION
                    // =========================================================

                    _DetailRow(
                      label: 'Species',
                      value:
                          pet.species ==
                                  PetSpecies.dog
                              ? 'Dog'
                              : 'Cat',
                    ),

                    _DetailRow(
                      label: 'Breed',
                      value: pet.breed ?? '—',
                    ),

                    _DetailRow(
                      label: 'Owner',
                      value: pet.owner ?? '—',
                    ),

                    _DetailRow(
                      label: 'Gender',
                      value:
                          pet.gender ==
                                  PetGender.male
                              ? 'Male'
                              : 'Female',
                    ),

                    _DetailRow(
                      label: 'Spayed/Neutered',
                      value:
                          pet.spayedNeutered
                              ? 'Yes'
                              : 'No',
                    ),

                    const SizedBox(height: 4),

                    // =========================================================
                    // STATUS
                    // =========================================================

                    Container(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            statusColor.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),

                    // =========================================================
                    // LATEST TREATMENT
                    // =========================================================

                    const SizedBox(height: 20),
                    const Divider(
                      height: 1,
                      color: AppColors.border,
                    ),
                    const SizedBox(height: 18),

                    const Row(
                      children: [
                        Icon(
                          Icons
                              .medical_services_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Latest Treatment',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      'Most recent recorded treatment for this animal.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (latestTreatment == null)
                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(
                          14,
                        ),
                        decoration:
                            BoxDecoration(
                          color: AppColors.card,
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          border: Border.all(
                            color:
                                AppColors.border,
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons
                                  .medical_services_outlined,
                              size: 17,
                              color: AppColors
                                  .mutedForeground,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'No treatment has been recorded for this animal.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors
                                      .mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      _LatestTreatmentCard(
                        record:
                            latestTreatment,
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text('Close'),
            ),

            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop();

                _openAnimalFormDialog(
                  pet: pet,
                );
              },
              child:
                  const Text('Edit Animal'),
            ),

            AppMenuButton<PetStatus>(
              tooltip: 'Update status',
              options:
                  PetStatus.values.map(
                (newStatus) {
                  return AppDropdownOption(
                    newStatus,
                    _statusMeta(
                      newStatus,
                    ).$1,
                  );
                },
              ).toList(),
              onSelected:
                  (newStatus) async {
                Navigator.of(
                  dialogContext,
                ).pop();

                try {
                  await _service
                      .updateStatus(
                    petId: pet.petId,
                    status: newStatus,
                  );

                  if (!mounted) return;

                  await _load();

                  if (!mounted) return;

                  _showSuccessSnackBar(
                    '${pet.petName}\'s status updated to '
                    '${_statusMeta(newStatus).$1}',
                  );
                } catch (e) {
                  if (!mounted) return;

                  _showErrorSnackBar(
                    'Could not update status for '
                    '${pet.petName}: ${_cleanError(e)}',
                  );
                }
              },
              triggerBuilder: (
                context,
                isOpen,
              ) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration:
                      BoxDecoration(
                    color: AppColors.primary,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                  child: const Text(
                    'Update Status',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // PAGE
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final isMobile =
        MediaQuery.sizeOf(context).width < 600;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(
                color:
                    AppColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final totalCount = _pets.length;

    final healthyCount = _pets
        .where(
          (pet) =>
              pet.status == PetStatus.healthy,
        )
        .length;

    final treatmentCount = _pets
        .where(
          (pet) =>
              pet.status ==
              PetStatus.underTreatment,
        )
        .length;

    final adoptedCount = _pets
        .where(
          (pet) =>
              pet.status == PetStatus.adopted,
        )
        .length;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // =====================================================================
        // HEADER
        // =====================================================================

        if (isMobile)
          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Animal Records',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child:
                    ElevatedButton.icon(
                  onPressed: () =>
                      _openAnimalFormDialog(),
                  icon: const Icon(
                    Icons.add,
                    size: 18,
                  ),
                  label: const Text(
                    'Add Animal',
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Animal Records',
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),

              ElevatedButton.icon(
                onPressed: () =>
                    _openAnimalFormDialog(),
                icon: const Icon(
                  Icons.add,
                  size: 18,
                ),
                label: const Text(
                  'Add Animal',
                ),
              ),
            ],
          ),

        const SizedBox(height: 2),

        Text(
          '$totalCount animals',
          style: const TextStyle(
            fontSize: 13,
            color:
                AppColors.mutedForeground,
          ),
        ),

        const SizedBox(height: 20),

        // =====================================================================
        // STAT CARDS
        // =====================================================================

        if (isMobile)
          Column(
            children: [
              _buildMobileStatCard(
                label: 'Total Animals',
                value: '$totalCount',
                icon: Icons.pets_outlined,
                accent:
                    AppColors.roleManager,
              ),

              const SizedBox(height: 10),

              _buildMobileStatCard(
                label: 'Healthy',
                value: '$healthyCount',
                icon: Icons
                    .check_circle_outline,
                accent: AppColors.primary,
              ),

              const SizedBox(height: 10),

              _buildMobileStatCard(
                label: 'Under Treatment',
                value: '$treatmentCount',
                icon: Icons
                    .medical_services_outlined,
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
        else
          StatCardRow(
            cards: [
              StatCard(
                label: 'Total Animals',
                value: '$totalCount',
                icon: Icons.pets_outlined,
                accent:
                    AppColors.roleManager,
              ),
              StatCard(
                label: 'Healthy',
                value: '$healthyCount',
                icon: Icons
                    .check_circle_outline,
                accent: AppColors.primary,
              ),
              StatCard(
                label: 'Under Treatment',
                value: '$treatmentCount',
                icon: Icons
                    .medical_services_outlined,
                accent: AppColors.warning,
              ),
              StatCard(
                label: 'Adopted',
                value: '$adoptedCount',
                icon: Icons.home_outlined,
                accent: AppColors.accent,
              ),
            ],
          ),

        const SizedBox(height: 20),

        // =====================================================================
        // SEARCH + FILTERS
        // =====================================================================

        Wrap(
          spacing: isMobile ? 8 : 12,
          runSpacing: isMobile ? 8 : 12,
          crossAxisAlignment:
              WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: isMobile
                  ? double.infinity
                  : 280,
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _search = value;
                  });
                },
                decoration:
                    const InputDecoration(
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                  ),
                  hintText:
                      'Search name, breed, or owner',
                  isDense: true,
                ),
              ),
            ),

            // ===============================================================
            // SPECIES FILTER
            // ===============================================================

            AppDropdown<PetSpecies?>(
              label:
                  _speciesFilter == null
                      ? 'Species'
                      : _speciesFilter ==
                              PetSpecies.dog
                          ? 'Dog'
                          : 'Cat',
              options: const [
                AppDropdownOption(
                  null,
                  'All species',
                ),
                AppDropdownOption(
                  PetSpecies.dog,
                  'Dog',
                ),
                AppDropdownOption(
                  PetSpecies.cat,
                  'Cat',
                ),
              ],
              onSelect: (value) {
                setState(() {
                  _speciesFilter = value;
                });
              },
            ),

            // ===============================================================
            // BREED FILTER
            // ===============================================================

            AppDropdown<String?>(
              label: _breedFilter ?? 'Breed',
              options: [
                const AppDropdownOption<
                    String?>(
                  null,
                  'All breeds',
                ),
                for (final breed
                    in _breedOptions)
                  AppDropdownOption<
                      String?>(
                    breed,
                    breed,
                  ),
              ],
              onSelect: (value) {
                setState(() {
                  _breedFilter = value;
                });
              },
            ),

            // ===============================================================
            // STATUS FILTER
            // ===============================================================

            AppDropdown<PetStatus?>(
              label:
                  _statusFilter == null
                      ? 'Status'
                      : _statusMeta(
                          _statusFilter!,
                        ).$1,
              options: [
                const AppDropdownOption(
                  null,
                  'All statuses',
                ),
                for (final status
                    in PetStatus.values)
                  AppDropdownOption(
                    status,
                    _statusMeta(status).$1,
                  ),
              ],
              onSelect: (value) {
                setState(() {
                  _statusFilter = value;
                });
              },
            ),

            // ===============================================================
            // SORT
            // ===============================================================

            AppDropdown<_AnimalSort>(
              label:
                  _sort ==
                          _AnimalSort.nameAZ
                      ? 'A–Z'
                      : 'Z–A',
              options: const [
                AppDropdownOption(
                  _AnimalSort.nameAZ,
                  'Name A–Z',
                ),
                AppDropdownOption(
                  _AnimalSort.nameZA,
                  'Name Z–A',
                ),
              ],
              onSelect: (value) {
                setState(() {
                  _sort = value;
                });
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        // =====================================================================
        // EMPTY / RECORDS
        // =====================================================================

        if (_pets.isEmpty)
          const Padding(
            padding:
                EdgeInsets.symmetric(
              vertical: 56,
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.pets_outlined,
                    size: 36,
                    color: AppColors
                        .mutedForeground,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No animals recorded yet',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_filtered.isEmpty)
          const Padding(
            padding:
                EdgeInsets.symmetric(
              vertical: 48,
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 32,
                    color: AppColors
                        .mutedForeground,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No animals match your filters.',
                    style: TextStyle(
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            gridDelegate:
                SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent:
                  isMobile ? 180 : 320,
              mainAxisExtent:
                  isMobile ? 155 : 175,
              crossAxisSpacing:
                  isMobile ? 10 : 16,
              mainAxisSpacing:
                  isMobile ? 10 : 16,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final pet = _filtered[index];

              final (
                statusLabel,
                statusColor,
              ) = _statusMeta(pet.status);

              return _Hoverable(
                builder: (
                  context,
                  isHovered,
                ) {
                  return InkWell(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                    onTap: () =>
                        _openDetailDialog(
                      pet,
                    ),
                    child: AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 150,
                      ),
                      padding: EdgeInsets.all(
                        isMobile ? 12 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        border: Border.all(
                          color: isHovered
                              ? AppColors.primary
                                  .withValues(
                                    alpha: 0.4,
                                  )
                              : AppColors.border,
                          width: isHovered
                              ? 1.5
                              : 1,
                        ),
                        boxShadow: isHovered
                            ? [
                                BoxShadow(
                                  color: AppColors
                                      .primary
                                      .withValues(
                                        alpha: 0.1,
                                      ),
                                  blurRadius: 10,
                                  offset:
                                      const Offset(
                                    0,
                                    3,
                                  ),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _speciesIcon(
                                  pet.species,
                                ),
                                size: isMobile
                                    ? 18
                                    : 20,
                                color: isHovered
                                    ? AppColors
                                        .primary
                                    : AppColors
                                        .mutedForeground,
                              ),

                              const SizedBox(
                                width: 8,
                              ),

                              Expanded(
                                child: Text(
                                  pet.petName,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      TextStyle(
                                    fontWeight:
                                        FontWeight
                                            .w700,
                                    fontSize:
                                        isMobile
                                            ? 13
                                            : 14,
                                    color: isHovered
                                        ? AppColors
                                            .primary
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            pet.breed ??
                                (pet.species ==
                                        PetSpecies
                                            .dog
                                    ? 'Dog'
                                    : 'Cat'),
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style: TextStyle(
                              fontSize: isMobile
                                  ? 11
                                  : 12.5,
                              color: AppColors
                                  .mutedForeground,
                            ),
                          ),

                          if ((pet.owner ?? '')
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(
                              height: 3,
                            ),
                            Text(
                              'Owner: ${pet.owner}',
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style: TextStyle(
                                fontSize:
                                    isMobile
                                        ? 10.5
                                        : 11.5,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),
                          ],

                          const Spacer(),

                          Align(
                            alignment:
                                Alignment
                                    .centerLeft,
                            child: Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration:
                                  BoxDecoration(
                                color: statusColor
                                    .withValues(
                                  alpha: isHovered
                                      ? 0.2
                                      : 0.12,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
                              child: Text(
                                statusLabel,
                                style:
                                    TextStyle(
                                  fontSize:
                                      isMobile
                                          ? 10
                                          : 12,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  color:
                                      statusColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  // ===========================================================================
  // MOBILE STAT CARD
  // ===========================================================================

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
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  accent.withValues(
                alpha: 0.1,
              ),
              borderRadius:
                  BorderRadius.circular(
                10,
              ),
            ),
            child: Icon(
              icon,
              size: 22,
              color: accent,
            ),
          ),

          const SizedBox(width: 14),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style:
                    const TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              Text(
                label,
                style:
                    const TextStyle(
                  fontSize: 13,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LATEST TREATMENT CARD
// =============================================================================
//
// Read-only summary for Manager.
//
// There is deliberately:
// - no InkWell
// - no chevron
// - no medical-history route
// - no treatment-detail route
// =============================================================================

class _LatestTreatmentCard
    extends StatelessWidget {
  final TreatmentRecord record;

  const _LatestTreatmentCard({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(
                  color: AppColors.primary
                      .withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    9,
                  ),
                ),
                child: const Icon(
                  Icons
                      .medical_services_outlined,
                  size: 17,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      record.treatName,
                      style:
                          const TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    Text(
                      _formatTreatmentDate(
                        record.recDate,
                      ),
                      style:
                          const TextStyle(
                        fontSize: 11.5,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          _TreatmentInfoRow(
            label: 'Performed by',
            value:
                record.performedByName,
          ),

          _TreatmentInfoRow(
            label: 'Recorded by',
            value:
                record.recordedByName,
          ),

          if (record.notes != null &&
              record.notes!
                  .trim()
                  .isNotEmpty)
            _TreatmentInfoRow(
              label: 'Notes',
              value:
                  record.notes!.trim(),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// TREATMENT INFO ROW
// =============================================================================

class _TreatmentInfoRow
    extends StatelessWidget {
  final String label;
  final String value;

  const _TreatmentInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize: 11.5,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontSize: 11.5,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HOVER
// =============================================================================

class _Hoverable extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    bool isHovered,
  ) builder;

  const _Hoverable({
    required this.builder,
  });

  @override
  State<_Hoverable> createState() =>
      _HoverableState();
}

class _HoverableState
    extends State<_Hoverable> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: widget.builder(
        context,
        _isHovered,
      ),
    );
  }
}

// =============================================================================
// DETAIL ROW
// =============================================================================

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 10,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style:
                  const TextStyle(
                fontSize: 12.5,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TREATMENT DATE
// =============================================================================

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

String _formatTreatmentDate(
  DateTime date,
) {
  return '${_monthAbbrev[date.month - 1]} '
      '${date.day}, ${date.year}';
}