import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../services/pet_service.dart';
import '../services/treatment_service.dart';
import '../state/data_bus.dart';

// =============================================================================
// MEDICAL RECORDS
// =============================================================================
//
// Existing behavior preserved:
// - all treatments load from TreatmentService
// - treatments are grouped by animal
// - animal cards open that animal's medical history
// - Log Treatment opens /medical-records/add
// - AppShell remains the page-level scroller
//
// NEW:
// - "Treatments Logged" summary card is interactive
// - clicking it opens a read-only modal with the 5 most recently RECORDED
//   treatments
// - closing the modal uses Navigator.pop(dialogContext) only
// - the modal does NOT change GoRouter location/history
//
// This keeps Close / Escape / Android back behavior isolated to the dialog.
// =============================================================================

class MedicalRecordsPage extends StatefulWidget {
  const MedicalRecordsPage({super.key});

  @override
  State<MedicalRecordsPage> createState() =>
      _MedicalRecordsPageState();
}

class _MedicalRecordsPageState extends State<MedicalRecordsPage>
    with DataBusRefreshMixin<MedicalRecordsPage> {
  final TreatmentService _treatmentService =
      TreatmentService();

  final PetService _petService =
      PetService();

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

  @override
  void onExternalDataChanged() =>
      _load(silent: true);

  Future<void> _load({
    bool silent = false,
  }) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _treatmentService.fetchTreatments(),
        _petService.fetchPets(),
      ]);

      if (!mounted) return;

      setState(() {
        _treatments =
            results[0] as List<TreatmentRecord>;

        _pets =
            results[1] as List<Pet>;

        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error =
              'Could not load medical records: $e';

          _loading = false;
        });
      }
    }
  }

  // ==========================================================================
  // GROUP TREATMENTS BY ANIMAL
  // ==========================================================================

  List<_AnimalMedicalSummary>
      get _animalRecords {
    final grouped =
        <String, List<TreatmentRecord>>{};

    for (final treatment in _treatments) {
      grouped
          .putIfAbsent(
            treatment.petId,
            () => [],
          )
          .add(treatment);
    }

    final summaries =
        <_AnimalMedicalSummary>[];

    for (final entry
        in grouped.entries) {
      final records = entry.value;

      records.sort((a, b) {
        final dateCompare =
            b.recDate.compareTo(
          a.recDate,
        );

        if (dateCompare != 0) {
          return dateCompare;
        }

        return b.loggedDate.compareTo(
          a.loggedDate,
        );
      });

      final latest = records.first;

      summaries.add(
        _AnimalMedicalSummary(
          petId: latest.petId,
          petName: latest.petName,
          species: latest.petSpecies,
          breed: latest.petBreed,
          treatmentCount:
              records.length,
          latestTreatment:
              latest.treatName,
          latestDate:
              latest.recDate,
        ),
      );
    }

    summaries.sort(
      (a, b) =>
          b.latestDate.compareTo(
        a.latestDate,
      ),
    );

    return summaries;
  }

  List<_AnimalMedicalSummary>
      get _filtered {
    final records = _animalRecords;

    if (_search.trim().isEmpty) {
      return records;
    }

    final query =
        _search.toLowerCase().trim();

    return records.where((record) {
      final name =
          record.petName.toLowerCase();

      final breed =
          record.breed?.toLowerCase() ??
              '';

      return name.contains(query) ||
          breed.contains(query);
    }).toList();
  }

  // ==========================================================================
  // LATEST 5 TREATMENTS
  // ==========================================================================

  List<TreatmentRecord>
      get _latestRecordedTreatments {
    final records =
        List<TreatmentRecord>.from(
      _treatments,
    );

    // "Latest added" means latest RECORDED in SIYAM, not necessarily the
    // latest administered date. This matters when an older treatment is
    // entered into the system later.
    records.sort((a, b) {
      final loggedCompare =
          b.loggedDate.compareTo(
        a.loggedDate,
      );

      if (loggedCompare != 0) {
        return loggedCompare;
      }

      return b.recDate.compareTo(
        a.recDate,
      );
    });

    return records.take(5).toList();
  }

  IconData _speciesIcon(
    PetSpecies species,
  ) {
    return species == PetSpecies.dog
        ? Icons.pets
        : Icons.pets_outlined;
  }

  // ==========================================================================
  // LATEST TREATMENT MODAL
  // ==========================================================================
  //
  // IMPORTANT NAVIGATION RULE:
  // This is an overlay, NOT a GoRouter page.
  //
  // Closing it calls Navigator.pop(dialogContext), which only dismisses the
  // dialog. It never calls context.go/context.push, so the current
  // /medical-records route stays exactly where it is.
  // ==========================================================================

  Future<void>
      _showLatestTreatments() async {
    final latest =
        _latestRecordedTreatments;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (
        dialogContext,
      ) {
        final screen =
            MediaQuery.sizeOf(
          dialogContext,
        );

        final dialogWidth =
            screen.width < 620
                ? screen.width - 32
                : 560.0;

        return Dialog(
          backgroundColor:
              Colors.white,
          surfaceTintColor:
              Colors.white,
          insetPadding:
              const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight:
                  screen.height * 0.82,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                // ============================================================
                // MODAL HEADER
                // ============================================================

                Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    20,
                    18,
                    12,
                    14,
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration:
                            BoxDecoration(
                          color: AppColors
                              .primary
                              .withValues(
                            alpha: 0.09,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            11,
                          ),
                        ),
                        alignment:
                            Alignment.center,
                        child: const Icon(
                          Icons
                              .medical_services_outlined,
                          size: 20,
                          color: AppColors
                              .primary,
                        ),
                      ),

                      const SizedBox(
                        width: 11,
                      ),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            const Text(
                              'Latest Treatments',
                              style:
                                  TextStyle(
                                fontSize:
                                    19,
                                fontWeight:
                                    FontWeight
                                        .w800,
                                color: AppColors
                                    .foreground,
                              ),
                            ),

                            const SizedBox(
                              height: 3,
                            ),

                            Text(
                              latest.length <
                                      5
                                  ? 'Most recently recorded treatments in SIYAM.'
                                  : '5 most recently recorded treatments in SIYAM.',
                              style:
                                  const TextStyle(
                                fontSize:
                                    11.8,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),
                          ],
                        ),
                      ),

                      IconButton(
                        tooltip: 'Close',
                        onPressed: () =>
                            Navigator.of(
                          dialogContext,
                        ).pop(),
                        icon: const Icon(
                          Icons.close,
                          size: 19,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ============================================================
                // MODAL CONTENT
                // ============================================================

                Flexible(
                  child:
                      SingleChildScrollView(
                    padding:
                        const EdgeInsets
                            .all(
                      16,
                    ),
                    child: latest.isEmpty
                        ? const Padding(
                            padding:
                                EdgeInsets
                                    .symmetric(
                              vertical:
                                  30,
                            ),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons
                                        .medical_services_outlined,
                                    size: 34,
                                    color: AppColors
                                        .mutedForeground,
                                  ),
                                  SizedBox(
                                    height: 9,
                                  ),
                                  Text(
                                    'No treatments logged yet',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0;
                                  i <
                                      latest
                                          .length;
                                  i++) ...[
                                _RecentTreatmentCard(
                                  record:
                                      latest[
                                          i],
                                  speciesIcon:
                                      _speciesIcon(
                                    latest[i]
                                        .petSpecies,
                                  ),
                                ),

                                if (i <
                                    latest.length -
                                        1)
                                  const SizedBox(
                                    height:
                                        10,
                                  ),
                              ],
                            ],
                          ),
                  ),
                ),

                const Divider(height: 1),

                // ============================================================
                // MODAL FOOTER
                // ============================================================

                Padding(
                  padding:
                      const EdgeInsets
                          .fromLTRB(
                    16,
                    10,
                    16,
                    12,
                  ),
                  child: LayoutBuilder(
                    builder: (
                      context,
                      constraints,
                    ) {
                      final compactFooter =
                          constraints.maxWidth <
                              360;

                      final closeButton =
                          TextButton(
                        onPressed: () =>
                            Navigator.of(
                          dialogContext,
                        ).pop(),
                        child: const Text(
                          'Close',
                        ),
                      );

                      if (compactFooter) {
                        return Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .stretch,
                          children: [
                            const Text(
                              'Close this window to continue viewing Medical Records.',
                              style:
                                  TextStyle(
                                fontSize:
                                    10.8,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),
                            const SizedBox(
                              height: 6,
                            ),
                            Align(
                              alignment:
                                  Alignment
                                      .centerRight,
                              child:
                                  closeButton,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Close this window to continue viewing Medical Records.',
                              style:
                                  TextStyle(
                                fontSize:
                                    10.8,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          closeButton,
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // PAGE
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign:
                  TextAlign.center,
              style: const TextStyle(
                color: AppColors
                    .mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              child:
                  const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // AppShell already handles the page-level scrolling.
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final isMobile =
            constraints.maxWidth <
                650;

        return Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ================================================================
            // HEADER
            // ================================================================

            if (isMobile)
              Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    'Medical Records',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),

                  const SizedBox(
                    height: 4,
                  ),

                  const Text(
                    'View each animal\'s treatment history.',
                    style:
                        TextStyle(
                      fontSize: 13,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),

                  const SizedBox(
                    height: 14,
                  ),

                  SizedBox(
                    width:
                        double.infinity,
                    child:
                        ElevatedButton
                            .icon(
                      onPressed:
                          _openTreatmentForm,
                      icon:
                          const Icon(
                        Icons.add,
                        size: 18,
                      ),
                      label:
                          const Text(
                        'Log Treatment',
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Medical Records',
                          style:
                              TextStyle(
                            fontSize:
                                24,
                            fontWeight:
                                FontWeight
                                    .w800,
                          ),
                        ),
                        SizedBox(
                          height: 4,
                        ),
                        Text(
                          'View each animal\'s treatment history.',
                          style:
                              TextStyle(
                            fontSize:
                                13,
                            color: AppColors
                                .mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed:
                        _openTreatmentForm,
                    icon: const Icon(
                      Icons.add,
                      size: 18,
                    ),
                    label: const Text(
                      'Log Treatment',
                    ),
                  ),
                ],
              ),

            const SizedBox(
              height: 20,
            ),

            // ================================================================
            // SUMMARY
            // ================================================================

            _SummaryBar(
              animalCount:
                  _animalRecords.length,
              treatmentCount:
                  _treatments.length,
              isMobile:
                  isMobile,
              onTreatmentsTap:
                  _showLatestTreatments,
            ),

            const SizedBox(
              height: 18,
            ),

            // ================================================================
            // SEARCH
            // ================================================================

            SizedBox(
              width: isMobile
                  ? double.infinity
                  : 340,
              child: TextField(
                onChanged: (
                  value,
                ) {
                  setState(() {
                    _search =
                        value;
                  });
                },
                decoration:
                    const InputDecoration(
                  prefixIcon:
                      Icon(
                    Icons.search,
                    size: 18,
                  ),
                  // Panel revision: keep the placeholder plain; no (...).
                  hintText:
                      'Search animals',
                  isDense: true,
                ),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            // ================================================================
            // CONTENT
            // ================================================================

            if (_treatments.isEmpty)
              const _EmptyMedicalRecords()
            else if (_filtered.isEmpty)
              const _EmptySearch()
            else
              _AnimalRecordsGrid(
                records:
                    _filtered,
                isMobile:
                    isMobile,
                iconForSpecies:
                    _speciesIcon,
                onOpen: (
                  record,
                ) {
                  context.go(
                    '/medical-records/pet/${record.petId}',
                  );
                },
              ),
          ],
        );
      },
    );
  }

  void _openTreatmentForm() {
    if (_pets.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Add an animal before logging a treatment.',
          ),
        ),
      );

      return;
    }

    final hasEligibleAnimal =
        _pets.any(
      (pet) =>
          pet.status !=
              PetStatus.adopted &&
          pet.status !=
              PetStatus.deceased,
    );

    if (!hasEligibleAnimal) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'No animals are currently eligible to receive treatment.',
          ),
        ),
      );

      return;
    }

    context.go(
      '/medical-records/add',
    );
  }
}

// =============================================================================
// ANIMAL MEDICAL SUMMARY MODEL
// =============================================================================

class _AnimalMedicalSummary {
  final String petId;
  final String petName;
  final PetSpecies species;
  final String? breed;
  final int treatmentCount;
  final String latestTreatment;
  final DateTime latestDate;

  const _AnimalMedicalSummary({
    required this.petId,
    required this.petName,
    required this.species,
    required this.breed,
    required this.treatmentCount,
    required this.latestTreatment,
    required this.latestDate,
  });
}

// =============================================================================
// SUMMARY
// =============================================================================

class _SummaryBar
    extends StatelessWidget {
  final int animalCount;
  final int treatmentCount;
  final bool isMobile;
  final VoidCallback
      onTreatmentsTap;

  const _SummaryBar({
    required this.animalCount,
    required this.treatmentCount,
    required this.isMobile,
    required this.onTreatmentsTap,
  });

  @override
  Widget build(BuildContext context) {
    final animals =
        _SummaryItem(
      icon:
          Icons.pets_outlined,
      value:
          animalCount.toString(),
      label:
          'Animals with Records',
    );

    final treatments =
        _SummaryItem(
      icon: Icons
          .medical_services_outlined,
      value: treatmentCount
          .toString(),
      label:
          'Treatments Logged',
      helper:
          'View latest treatments',
      onTap:
          onTreatmentsTap,
    );

    if (isMobile) {
      return Column(
        children: [
          animals,
          const SizedBox(
            height: 10,
          ),
          treatments,
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: animals,
        ),
        const SizedBox(
          width: 12,
        ),
        Expanded(
          child: treatments,
        ),
      ],
    );
  }
}

class _SummaryItem
    extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final String? helper;
  final VoidCallback? onTap;

  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
    this.helper,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content =
        Container(
      width: double.infinity,
      constraints:
          const BoxConstraints(
        minHeight: 82,
      ),
      padding:
          const EdgeInsets
              .symmetric(
        horizontal: 18,
        vertical: 15,
      ),
      decoration:
          BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color:
              AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration:
                BoxDecoration(
              color: AppColors
                  .primary
                  .withValues(
                alpha: 0.08,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                11,
              ),
            ),
            child: Icon(
              icon,
              size: 19,
              color:
                  AppColors.primary,
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 19,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
                Text(
                  label,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
                if (helper !=
                    null) ...[
                  const SizedBox(
                    height: 2,
                  ),
                  Text(
                    helper!,
                    style:
                        TextStyle(
                      fontSize: 10.5,
                      fontWeight: onTap ==
                              null
                          ? FontWeight
                              .w400
                          : FontWeight
                              .w600,
                      color: onTap ==
                              null
                          ? AppColors
                              .mutedForeground
                          : AppColors
                              .primary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (onTap != null)
            const Icon(
              Icons
                  .chevron_right,
              size: 18,
              color: AppColors
                  .primary,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        onTap: onTap,
        hoverColor: AppColors
            .primary
            .withValues(
          alpha: 0.035,
        ),
        child: content,
      ),
    );
  }
}

// =============================================================================
// RECENT TREATMENT MODAL CARD
// =============================================================================

class _RecentTreatmentCard
    extends StatelessWidget {
  final TreatmentRecord record;
  final IconData speciesIcon;

  const _RecentTreatmentCard({
    required this.record,
    required this.speciesIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color:
            AppColors.card,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border: Border.all(
          color:
              AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment
                .start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(
                  color: AppColors
                      .primary
                      .withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                ),
                alignment:
                    Alignment.center,
                child: Icon(
                  speciesIcon,
                  size: 18,
                  color:
                      AppColors.primary,
                ),
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      record
                          .treatName,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 13.5,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      record.petName,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 11.7,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Text(
                _formatDate(
                  record.recDate,
                ),
                style:
                    const TextStyle(
                  fontSize: 11,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 11,
          ),

          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              _TreatmentMeta(
                icon: Icons
                    .person_outline,
                text:
                    'Performed by ${record.performedByName.trim().isEmpty ? 'Not specified' : record.performedByName}',
              ),
              _TreatmentMeta(
                icon: Icons
                    .edit_note_outlined,
                text:
                    'Recorded by ${record.recordedByName}',
              ),
              _TreatmentMeta(
                icon: Icons
                    .schedule_outlined,
                text:
                    'Recorded ${_formatDateTime(record.loggedDate)}',
              ),
            ],
          ),

          if (record.notes !=
                  null &&
              record.notes!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(
              height: 9,
            ),
            Text(
              record.notes!
                  .trim(),
              maxLines: 2,
              overflow:
                  TextOverflow
                      .ellipsis,
              style:
                  const TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TreatmentMeta
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TreatmentMeta({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color:
              AppColors
                  .mutedForeground,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style:
              const TextStyle(
            fontSize: 10.8,
            color: AppColors
                .mutedForeground,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// RECORD GRID
// =============================================================================

class _AnimalRecordsGrid
    extends StatelessWidget {
  final List<
          _AnimalMedicalSummary>
      records;

  final bool isMobile;

  final IconData Function(
    PetSpecies species,
  ) iconForSpecies;

  final void Function(
    _AnimalMedicalSummary
        record,
  ) onOpen;

  const _AnimalRecordsGrid({
    required this.records,
    required this.isMobile,
    required this.iconForSpecies,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          for (final record
              in records) ...[
            _AnimalMedicalCard(
              record: record,
              speciesIcon:
                  iconForSpecies(
                record.species,
              ),
              onTap: () =>
                  onOpen(record),
            ),

            const SizedBox(
              height: 12,
            ),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final width =
            constraints.maxWidth;

        final columns =
            width >= 1100
                ? 3
                : 2;

        const spacing = 14.0;

        final cardWidth =
            (width -
                    spacing *
                        (columns -
                            1)) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final record
                in records)
              SizedBox(
                width:
                    cardWidth,
                height: 184,
                child:
                    _AnimalMedicalCard(
                  record: record,
                  speciesIcon:
                      iconForSpecies(
                    record
                        .species,
                  ),
                  onTap: () =>
                      onOpen(
                    record,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// ANIMAL CARD
// =============================================================================

class _AnimalMedicalCard
    extends StatefulWidget {
  final _AnimalMedicalSummary
      record;

  final IconData speciesIcon;
  final VoidCallback onTap;

  const _AnimalMedicalCard({
    required this.record,
    required this.speciesIcon,
    required this.onTap,
  });

  @override
  State<_AnimalMedicalCard>
      createState() =>
          _AnimalMedicalCardState();
}

class _AnimalMedicalCardState
    extends State<
        _AnimalMedicalCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final record =
        widget.record;

    final speciesText =
        record.species ==
                PetSpecies.dog
            ? 'Dog'
            : 'Cat';

    final animalInfo =
        record.breed == null ||
                record.breed!
                    .trim()
                    .isEmpty
            ? speciesText
            : '$speciesText · ${record.breed}';

    return MouseRegion(
      cursor:
          SystemMouseCursors
              .click,
      onEnter: (_) {
        setState(() {
          _hovering = true;
        });
      },
      onExit: (_) {
        setState(() {
          _hovering = false;
        });
      },
      child: Material(
        color:
            Colors.transparent,
        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          onTap: widget.onTap,
          hoverColor:
              Colors.transparent,
          child:
              AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 140,
            ),
            width:
                double.infinity,
            height:
                double.infinity,
            padding:
                const EdgeInsets.all(
              17,
            ),
            decoration:
                BoxDecoration(
              color: _hovering
                  ? AppColors.muted
                  : AppColors.card,
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              border: Border.all(
                color:
                    AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration:
                          BoxDecoration(
                        color: AppColors
                            .primary
                            .withValues(
                          alpha: 0.08,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          11,
                        ),
                      ),
                      child: Icon(
                        widget
                            .speciesIcon,
                        size: 20,
                        color: AppColors
                            .primary,
                      ),
                    ),

                    const SizedBox(
                      width: 11,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            record
                                .petName,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize:
                                  15,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),

                          const SizedBox(
                            height: 2,
                          ),

                          Text(
                            animalInfo,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              fontSize:
                                  12,
                              color: AppColors
                                  .mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Icon(
                      Icons
                          .chevron_right,
                      size: 19,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ],
                ),

                const SizedBox(
                  height: 16,
                ),

                Text(
                  '${record.treatmentCount} '
                  '${record.treatmentCount == 1 ? 'treatment' : 'treatments'} recorded',
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                const Text(
                  'LATEST TREATMENT',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight:
                        FontWeight
                            .w700,
                    letterSpacing: 0.7,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .end,
                  children: [
                    Expanded(
                      child: Text(
                        record
                            .latestTreatment,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 13,
                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Text(
                      _formatDate(
                        record
                            .latestDate,
                      ),
                      style:
                          const TextStyle(
                        fontSize:
                            11.5,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// EMPTY STATES
// =============================================================================

class _EmptyMedicalRecords
    extends StatelessWidget {
  const _EmptyMedicalRecords();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        vertical: 56,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons
                  .medical_services_outlined,
              size: 38,
              color: AppColors
                  .mutedForeground,
            ),
            SizedBox(height: 10),
            Text(
              'No medical records yet',
              style: TextStyle(
                fontWeight:
                    FontWeight
                        .w600,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Logged treatments will appear under each animal.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySearch
    extends StatelessWidget {
  const _EmptySearch();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        vertical: 48,
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 34,
              color: AppColors
                  .mutedForeground,
            ),
            SizedBox(height: 8),
            Text(
              'No animals match your search.',
              style: TextStyle(
                color: AppColors
                    .mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DATE
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

String _formatDate(
  DateTime date,
) =>
    '${_monthAbbrev[date.month - 1]} '
    '${date.day}, ${date.year}';

String _formatDateTime(
  DateTime date,
) {
  final local =
      date.toLocal();

  final hour =
      local.hour == 0
          ? 12
          : local.hour > 12
              ? local.hour - 12
              : local.hour;

  final minute =
      local.minute
          .toString()
          .padLeft(
            2,
            '0',
          );

  final period =
      local.hour >= 12
          ? 'PM'
          : 'AM';

  return '${_monthAbbrev[local.month - 1]} '
      '${local.day}, ${local.year} · '
      '$hour:$minute $period';
}
