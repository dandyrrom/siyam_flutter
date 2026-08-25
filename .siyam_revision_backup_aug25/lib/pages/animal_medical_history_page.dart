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

// ============================================================================
// ANIMAL MEDICAL HISTORY PAGE
// ============================================================================

class AnimalMedicalHistoryPage extends StatefulWidget {
  final String petId;

  const AnimalMedicalHistoryPage({
    super.key,
    required this.petId,
  });

  @override
  State<AnimalMedicalHistoryPage> createState() =>
      _AnimalMedicalHistoryPageState();
}

class _AnimalMedicalHistoryPageState
    extends State<AnimalMedicalHistoryPage>
    with DataBusRefreshMixin<AnimalMedicalHistoryPage> {
  final TreatmentService _treatmentService =
      TreatmentService();

  final InventoryService _inventoryService =
      InventoryService();

  List<TreatmentRecord> _records = [];
  List<TreatmentItemUsed> _itemsUsed = [];
  List<InventoryItem> _inventoryItems = [];

  TreatmentRecord? _selectedTreatment;

  bool _loading = true;
  bool _detailLoading = false;
  bool _addingItem = false;

  String? _error;
  String? _detailError;

  // Prevents an older item request from overwriting a newer selection
  // when staff clicks different treatments quickly.
  int _detailRequestId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() {
    _load(silent: true);
  }

  // ==========================================================================
  // PAGE DATA
  // ==========================================================================

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
      // Start both requests together.
      final treatmentsFuture =
          _treatmentService.fetchTreatments();

      final inventoryFuture =
          _inventoryService.fetchItems();

      final treatments =
          await treatmentsFuture;

      List<InventoryItem> inventoryItems = [];

      try {
        inventoryItems =
            await inventoryFuture;
      } catch (_) {
        // Medical history can still be displayed even if
        // inventory items temporarily fail to load.
        inventoryItems = [];
      }

      final records = treatments
          .where(
            (treatment) =>
                treatment.petId == widget.petId,
          )
          .toList();

      // Newest administered treatment first.
      // loggedDate is used as a tie-breaker when treatment dates match.
      records.sort((a, b) {
        final dateCompare =
            b.recDate.compareTo(a.recDate);

        if (dateCompare != 0) {
          return dateCompare;
        }

        return b.loggedDate.compareTo(
          a.loggedDate,
        );
      });

      if (!mounted) return;

      if (records.isEmpty) {
        setState(() {
          _records = [];
          _selectedTreatment = null;
          _itemsUsed = [];
          _inventoryItems =
              inventoryItems;
          _loading = false;
          _error = null;
        });

        return;
      }

      // Preserve the currently selected treatment during refreshes.
      // Otherwise default to the newest treatment.
      final previousSelectedId =
          _selectedTreatment?.treatId;

      final selected =
          previousSelectedId == null
              ? records.first
              : records.firstWhere(
                  (record) =>
                      record.treatId ==
                      previousSelectedId,
                  orElse: () =>
                      records.first,
                );

      List<TreatmentItemUsed>
          selectedItems = [];

      String? detailError;

      try {
        selectedItems =
            await _treatmentService
                .fetchItemsUsed(
          selected.treatId,
        );
      } catch (_) {
        detailError =
            'Could not load items used for this treatment.';
      }

      if (!mounted) return;

      setState(() {
        _records = records;
        _inventoryItems =
            inventoryItems;

        _selectedTreatment =
            selected;

        _itemsUsed =
            selectedItems;

        _detailError =
            detailError;

        _loading = false;
        _detailLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error =
              'Could not load this animal\'s medical history.';
          _loading = false;
        });
      }
    }
  }

  // ==========================================================================
  // SELECT TREATMENT
  // ==========================================================================

  Future<void> _selectTreatment(
    TreatmentRecord treatment,
  ) async {
    // If already selected and loaded correctly,
    // there is nothing to fetch again.
    if (_selectedTreatment?.treatId ==
            treatment.treatId &&
        !_detailLoading &&
        _detailError == null) {
      return;
    }

    final requestId =
        ++_detailRequestId;

    setState(() {
      _selectedTreatment =
          treatment;

      _detailLoading = true;
      _detailError = null;
    });

    try {
      final items =
          await _treatmentService
              .fetchItemsUsed(
        treatment.treatId,
      );

      if (!mounted) return;

      // Ignore an old response if another treatment
      // was selected while this request was running.
      if (requestId !=
          _detailRequestId) {
        return;
      }

      if (_selectedTreatment?.treatId !=
          treatment.treatId) {
        return;
      }

      setState(() {
        _itemsUsed = items;
        _detailLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      if (requestId !=
          _detailRequestId) {
        return;
      }

      setState(() {
        _itemsUsed = [];
        _detailLoading = false;
        _detailError =
            'Could not load items used for this treatment.';
      });
    }
  }

  // ==========================================================================
  // REFRESH SELECTED TREATMENT ITEMS
  // ==========================================================================

  Future<void>
      _refreshSelectedItems() async {
    final treatment =
        _selectedTreatment;

    if (treatment == null) {
      return;
    }

    final requestId =
        ++_detailRequestId;

    setState(() {
      _detailLoading = true;
      _detailError = null;
    });

    try {
      final items =
          await _treatmentService
              .fetchItemsUsed(
        treatment.treatId,
      );

      if (!mounted) return;

      if (requestId !=
          _detailRequestId) {
        return;
      }

      if (_selectedTreatment?.treatId !=
          treatment.treatId) {
        return;
      }

      setState(() {
        _itemsUsed = items;
        _detailLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      if (requestId !=
          _detailRequestId) {
        return;
      }

      setState(() {
        _detailLoading = false;
        _detailError =
            'Could not load items used for this treatment.';
      });
    }
  }

  // ==========================================================================
  // ADD ITEM TO SELECTED TREATMENT
  // ==========================================================================

  Future<void>
      _openAddItemDialog() async {
    final treatment =
        _selectedTreatment;

    if (treatment == null) {
      return;
    }

    if (_inventoryItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'No inventory items are available to add.',
          ),
        ),
      );

      return;
    }

    final currentUser =
        context
            .read<AuthController>()
            .profile;

    final existingByItemId =
        <String,
            List<TreatmentItemUsed>>{};

    for (final item
        in _itemsUsed) {
      (
        existingByItemId[
                item.itemId] ??=
            []
      ).add(item);
    }

    final result =
        await showDialog<
            _AddTreatmentItemResult>(
      context: context,
      builder: (context) =>
          _AddTreatmentItemDialog(
        items:
            _inventoryItems,
        existingByItemId:
            existingByItemId,
        defaultAdministeredBy:
            currentUser?.fullName ??
                '',
      ),
    );

    if (result == null ||
        !mounted) {
      return;
    }

    final performedByUserId =
        currentUser?.userId;

    if (performedByUserId ==
        null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Could not identify the signed-in user.',
          ),
        ),
      );

      return;
    }

    // Store the treatment ID so the correct treatment receives the item,
    // even if UI state changes during the async operation.
    final targetTreatmentId =
        treatment.treatId;

    setState(() {
      _addingItem = true;
    });

    try {
      await _treatmentService
          .addTreatmentItem(
        treatId:
            targetTreatmentId,
        item: result.input,
        administeredByName:
            result.administeredBy,
        performedByUserId:
            performedByUserId,
        dateAdministered:
            result.dateAdministered,
      );

      if (!mounted) return;

      setState(() {
        _addingItem = false;
      });

      // Only refresh the panel if staff is still
      // viewing the same treatment.
      if (_selectedTreatment?.treatId ==
          targetTreatmentId) {
        await _refreshSelectedItems();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Item added to treatment.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _addingItem = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not add item: $e',
          ),
        ),
      );
    }
  }

  // ==========================================================================
  // HELPERS
  // ==========================================================================

  IconData _speciesIcon(
    PetSpecies species,
  ) {
    return species ==
            PetSpecies.dog
        ? Icons.pets
        : Icons.pets_outlined;
  }

  void _goBack() {
    context.go(
      '/medical-records',
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    if (_loading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return _PageError(
        message: _error!,
        onRetry: () => _load(),
        onBack: _goBack,
      );
    }

    if (_records.isEmpty) {
      return _NoMedicalHistory(
        onBack: _goBack,
      );
    }

    final firstRecord =
        _records.first;

    final species =
        firstRecord.petSpecies ==
                PetSpecies.dog
            ? 'Dog'
            : 'Cat';

    final breed =
        firstRecord.petBreed
            ?.trim();

    final animalDescription =
        breed == null ||
                breed.isEmpty
            ? species
            : '$species · $breed';

    // AppShell already handles overall page scrolling.
    // Do not add another page-level SingleChildScrollView here.
    return Center(
      child: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 1120,
        ),
        child: LayoutBuilder(
          builder: (
            context,
            constraints,
          ) {
            final stacked =
                constraints.maxWidth <
                    900;

            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ============================================================
                // BACK
                // ============================================================
                TextButton.icon(
                  onPressed: _goBack,
                  icon: const Icon(
                    Icons.arrow_back,
                    size: 16,
                  ),
                  label: const Text(
                    'Back to Medical Records',
                  ),
                  style:
                      TextButton.styleFrom(
                    foregroundColor:
                        AppColors
                            .mutedForeground,
                  ),
                ),

                const SizedBox(
                    height: 8),

                // ============================================================
                // ANIMAL HEADER
                // ============================================================
                _AnimalHeaderCard(
                  record:
                      firstRecord,
                  animalDescription:
                      animalDescription,
                  treatmentCount:
                      _records.length,
                  speciesIcon:
                      _speciesIcon(
                    firstRecord
                        .petSpecies,
                  ),
                  compact: stacked,
                ),

                const SizedBox(
                    height: 20),

                // ============================================================
                // MASTER / DETAIL
                // ============================================================
                if (stacked)
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,
                    children: [
                      _TreatmentHistoryPanel(
                        records:
                            _records,
                        selectedTreatmentId:
                            _selectedTreatment
                                ?.treatId,
                        onSelected:
                            _selectTreatment,
                      ),

                      const SizedBox(
                          height: 18),

                      _TreatmentDetailPanel(
                        record:
                            _selectedTreatment!,
                        itemsUsed:
                            _itemsUsed,
                        loading:
                            _detailLoading,
                        error:
                            _detailError,
                        addingItem:
                            _addingItem,
                        canAddItem:
                            _inventoryItems
                                .isNotEmpty,
                        onRetry:
                            _refreshSelectedItems,
                        onAddItem:
                            _openAddItemDialog,
                      ),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      // Treatment history gets less space.
                      Expanded(
                        flex: 4,
                        child:
                            _TreatmentHistoryPanel(
                          records:
                              _records,
                          selectedTreatmentId:
                              _selectedTreatment
                                  ?.treatId,
                          onSelected:
                              _selectTreatment,
                        ),
                      ),

                      const SizedBox(
                          width: 18),

                      // Details receive more space.
                      Expanded(
                        flex: 7,
                        child:
                            _TreatmentDetailPanel(
                          record:
                              _selectedTreatment!,
                          itemsUsed:
                              _itemsUsed,
                          loading:
                              _detailLoading,
                          error:
                              _detailError,
                          addingItem:
                              _addingItem,
                          canAddItem:
                              _inventoryItems
                                  .isNotEmpty,
                          onRetry:
                              _refreshSelectedItems,
                          onAddItem:
                              _openAddItemDialog,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(
                    height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ============================================================================
// ANIMAL HEADER
// ============================================================================

class _AnimalHeaderCard
    extends StatelessWidget {
  final TreatmentRecord record;
  final String animalDescription;
  final int treatmentCount;
  final IconData speciesIcon;
  final bool compact;

  const _AnimalHeaderCard({
    required this.record,
    required this.animalDescription,
    required this.treatmentCount,
    required this.speciesIcon,
    required this.compact,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final avatar =
        Container(
      width: 56,
      height: 56,
      decoration:
          BoxDecoration(
        color: AppColors.primary
            .withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          15,
        ),
      ),
      child: Icon(
        speciesIcon,
        size: 25,
        color:
            AppColors.primary,
      ),
    );

    final details = Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          record.petName,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 21,
            fontWeight:
                FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          animalDescription,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColors
                .mutedForeground,
          ),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: compact
          ? Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Row(
                  children: [
                    avatar,
                    const SizedBox(
                        width: 14),
                    Expanded(
                      child: details,
                    ),
                  ],
                ),

                const SizedBox(
                    height: 13),

                _TreatmentCountBadge(
                  count:
                      treatmentCount,
                ),
              ],
            )
          : Row(
              children: [
                avatar,

                const SizedBox(
                    width: 15),

                Expanded(
                  child: details,
                ),

                const SizedBox(
                    width: 16),

                _TreatmentCountBadge(
                  count:
                      treatmentCount,
                ),
              ],
            ),
    );
  }
}

class _TreatmentCountBadge
    extends StatelessWidget {
  final int count;

  const _TreatmentCountBadge({
    required this.count,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: AppColors.primary
            .withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          999,
        ),
      ),
      child: Text(
        '$count ${count == 1 ? 'treatment' : 'treatments'}',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight:
              FontWeight.w600,
          color:
              AppColors.primary,
        ),
      ),
    );
  }
}

// ============================================================================
// LEFT: TREATMENT HISTORY
// ============================================================================

class _TreatmentHistoryPanel
    extends StatelessWidget {
  final List<TreatmentRecord>
      records;

  final String?
      selectedTreatmentId;

  final Future<void> Function(
    TreatmentRecord treatment,
  ) onSelected;

  const _TreatmentHistoryPanel({
    required this.records,
    required this.selectedTreatmentId,
    required this.onSelected,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Treatment History',
          style: TextStyle(
            fontSize: 17,
            fontWeight:
                FontWeight.w700,
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          'Select a treatment to view its details.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors
                .mutedForeground,
          ),
        ),

        const SizedBox(height: 14),

        for (var i = 0;
            i < records.length;
            i++) ...[
          _TreatmentHistoryCard(
            record:
                records[i],
            selected:
                records[i]
                        .treatId ==
                    selectedTreatmentId,
            onTap: () {
              onSelected(
                records[i],
              );
            },
          ),

          if (i <
              records.length - 1)
            const SizedBox(
                height: 10),
        ],
      ],
    );
  }
}

// ============================================================================
// LEFT: INDIVIDUAL TREATMENT CARD
// ============================================================================

class _TreatmentHistoryCard
    extends StatefulWidget {
  final TreatmentRecord record;
  final bool selected;
  final VoidCallback onTap;

  const _TreatmentHistoryCard({
    required this.record,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_TreatmentHistoryCard>
      createState() =>
          _TreatmentHistoryCardState();
}

class _TreatmentHistoryCardState
    extends State<_TreatmentHistoryCard> {
  bool _hovering = false;

  @override
  Widget build(
    BuildContext context,
  ) {
    final record =
        widget.record;

    final backgroundColor =
        widget.selected
            ? AppColors.primary
                .withValues(
                alpha: 0.08,
              )
            : _hovering
                ? AppColors.muted
                : AppColors.card;

    final borderColor =
        widget.selected
            ? AppColors.primary
                .withValues(
                alpha: 0.45,
              )
            : AppColors.border;

    return MouseRegion(
      cursor:
          SystemMouseCursors.click,
      onEnter: (_) {
        if (!mounted) return;

        setState(() {
          _hovering = true;
        });
      },
      onExit: (_) {
        if (!mounted) return;

        setState(() {
          _hovering = false;
        });
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap:
              widget.onTap,
          hoverColor:
              Colors.transparent,
          borderRadius:
              BorderRadius.circular(
            15,
          ),
          child: AnimatedContainer(
            duration:
                const Duration(
              milliseconds: 130,
            ),
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(
              14,
            ),
            decoration:
                BoxDecoration(
              color:
                  backgroundColor,
              borderRadius:
                  BorderRadius
                      .circular(
                15,
              ),
              border: Border.all(
                color:
                    borderColor,
                width: widget.selected
                    ? 1.4
                    : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration:
                      BoxDecoration(
                    color: widget
                            .selected
                        ? AppColors
                            .primary
                            .withValues(
                              alpha:
                                  0.12,
                            )
                        : AppColors
                            .muted,
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                  ),
                  child: Icon(
                    Icons
                        .medical_services_outlined,
                    size: 17,
                    color: widget
                            .selected
                        ? AppColors
                            .primary
                        : AppColors
                            .mutedForeground,
                  ),
                ),

                const SizedBox(
                    width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        record
                            .treatName,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 14,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),

                      const SizedBox(
                          height: 3),

                      Text(
                        _formatDate(
                          record
                              .recDate,
                        ),
                        style:
                            const TextStyle(
                          fontSize:
                              11.5,
                          color: AppColors
                              .mutedForeground,
                        ),
                      ),

                      const SizedBox(
                          height: 6),

                      Text(
                        record
                                .performedByName
                                .trim()
                                .isEmpty
                            ? 'Performed by not specified'
                            : 'Performed by ${record.performedByName}',
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
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

                if (widget.selected)
                  const Padding(
                    padding:
                        EdgeInsets.only(
                      top: 8,
                    ),
                    child: Icon(
                      Icons
                          .check_circle,
                      size: 17,
                      color:
                          AppColors
                              .primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// RIGHT: TREATMENT DETAIL
// ============================================================================

class _TreatmentDetailPanel
    extends StatelessWidget {
  final TreatmentRecord record;

  final List<TreatmentItemUsed>
      itemsUsed;

  final bool loading;
  final bool addingItem;
  final bool canAddItem;

  final String? error;

  final VoidCallback onRetry;
  final VoidCallback onAddItem;

  const _TreatmentDetailPanel({
    required this.record,
    required this.itemsUsed,
    required this.loading,
    required this.error,
    required this.addingItem,
    required this.canAddItem,
    required this.onRetry,
    required this.onAddItem,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ================================================================
          // DETAIL HEADER
          // ================================================================
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color: AppColors.primary
                      .withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons
                      .medical_services_outlined,
                  size: 20,
                  color:
                      AppColors.primary,
                ),
              ),

              const SizedBox(
                  width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      record
                          .treatName,
                      style:
                          const TextStyle(
                        fontSize: 19,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),

                    const SizedBox(
                        height: 3),

                    Text(
                      'Administered ${_formatDate(record.recDate)}',
                      style:
                          const TextStyle(
                        fontSize: 12,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 20),

          // ================================================================
          // TREATMENT INFORMATION
          // ================================================================
          LayoutBuilder(
            builder: (
              context,
              constraints,
            ) {
              final stacked =
                  constraints.maxWidth <
                      560;

              if (stacked) {
                return Column(
                  children: [
                    _FieldBlock(
                      label:
                          'Performed by',
                      value: record
                              .performedByName
                              .trim()
                              .isEmpty
                          ? 'Not specified'
                          : record
                              .performedByName,
                    ),

                    const SizedBox(
                        height: 12),

                    _FieldBlock(
                      label:
                          'Date administered',
                      value:
                          _formatDate(
                        record
                            .recDate,
                      ),
                    ),

                    const SizedBox(
                        height: 12),

                    _FieldBlock(
                      label:
                          'Recorded by',
                      value: record
                          .recordedByName,
                    ),

                    const SizedBox(
                        height: 12),

                    _FieldBlock(
                      label:
                          'Recorded date',
                      value:
                          _formatDate(
                        record
                            .loggedDate,
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Expanded(
                        child:
                            _FieldBlock(
                          label:
                              'Performed by',
                          value: record
                                  .performedByName
                                  .trim()
                                  .isEmpty
                              ? 'Not specified'
                              : record
                                  .performedByName,
                        ),
                      ),

                      const SizedBox(
                          width: 12),

                      Expanded(
                        child:
                            _FieldBlock(
                          label:
                              'Date administered',
                          value:
                              _formatDate(
                            record
                                .recDate,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 12),

                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Expanded(
                        child:
                            _FieldBlock(
                          label:
                              'Recorded by',
                          value: record
                              .recordedByName,
                        ),
                      ),

                      const SizedBox(
                          width: 12),

                      Expanded(
                        child:
                            _FieldBlock(
                          label:
                              'Recorded date',
                          value:
                              _formatDate(
                            record
                                .loggedDate,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          if (record.notes != null &&
              record.notes!
                  .trim()
                  .isNotEmpty) ...[
            const SizedBox(height: 12),

            _FieldBlock(
              label: 'Notes',
              value:
                  record.notes!.trim(),
            ),
          ],

          const SizedBox(
              height: 22),

          const Divider(height: 1),

          const SizedBox(
              height: 18),

          // ================================================================
          // ITEMS USED HEADER
          // ================================================================
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Items Used',
                      style:
                          TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                    SizedBox(
                        height: 2),
                    Text(
                      'Medicine and supplies logged under this treatment.',
                      style:
                          TextStyle(
                        fontSize: 11.5,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                  width: 10),

              TextButton.icon(
                onPressed:
                    addingItem ||
                            !canAddItem
                        ? null
                        : onAddItem,
                icon: addingItem
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                        ),
                      )
                    : const Icon(
                        Icons.add,
                        size: 16,
                      ),
                label: const Text(
                  'Add Item',
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 12),

          // ================================================================
          // ITEMS USED CONTENT
          // ================================================================
          if (loading)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 28,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            _DetailError(
              message: error!,
              onRetry: onRetry,
            )
          else if (itemsUsed.isEmpty)
            const _NoItemsUsed()
          else
            _ItemsUsedList(
              items:
                  itemsUsed,
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// FIELD BLOCK
// ============================================================================

class _FieldBlock
    extends StatelessWidget {
  final String label;
  final String value;

  const _FieldBlock({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight:
                FontWeight.w700,
            letterSpacing: 0.7,
            color: AppColors
                .mutedForeground,
          ),
        ),

        const SizedBox(height: 6),

        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 10,
          ),
          decoration:
              BoxDecoration(
            color: AppColors.muted
                .withValues(
              alpha: 0.55,
            ),
            borderRadius:
                BorderRadius.circular(
              11,
            ),
            border: Border.all(
              color:
                  AppColors.border,
            ),
          ),
          child: Text(
            value,
            style:
                const TextStyle(
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ITEMS USED
// ============================================================================

class _ItemsUsedList
    extends StatelessWidget {
  final List<TreatmentItemUsed>
      items;

  const _ItemsUsedList({
    required this.items,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(13),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          for (var i = 0;
              i < items.length;
              i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
              ),

            _TreatmentItemRow(
              item: items[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _TreatmentItemRow
    extends StatelessWidget {
  final TreatmentItemUsed item;

  const _TreatmentItemRow({
    required this.item,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
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
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(
                  color: AppColors.primary
                      .withValues(
                    alpha: 0.07,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    9,
                  ),
                ),
                child: const Icon(
                  Icons
                      .medication_outlined,
                  size: 16,
                  color:
                      AppColors.primary,
                ),
              ),

              const SizedBox(
                  width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      item.itemName,
                      style:
                          const TextStyle(
                        fontSize: 13,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),

                    const SizedBox(
                        height: 2),

                    Text(
                      'Given by ${item.givenBy}',
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

              const SizedBox(
                  width: 10),

              Text(
                '${formatQty(item.dispensedQty)} '
                '${item.dispenseUnitAbbr}',
                style:
                    const TextStyle(
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(
              height: 9),

          Padding(
            padding:
                const EdgeInsets.only(
              left: 42,
            ),
            child: Wrap(
              spacing: 14,
              runSpacing: 5,
              children: [
                _SmallMeta(
                  icon: Icons
                      .calendar_today_outlined,
                  text:
                      'Given ${_formatDate(item.consumedDate)}',
                ),

                _SmallMeta(
                  icon: Icons
                      .edit_note_outlined,
                  text:
                      'Recorded by ${item.recordedByName} · '
                      '${_formatDate(item.recordedDate)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallMeta
    extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallMeta({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: AppColors
              .mutedForeground,
        ),

        const SizedBox(width: 4),

        Text(
          text,
          style:
              const TextStyle(
            fontSize: 11,
            color: AppColors
                .mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _NoItemsUsed
    extends StatelessWidget {
  const _NoItemsUsed();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 22,
      ),
      decoration:
          BoxDecoration(
        color: AppColors.muted
            .withValues(
          alpha: 0.35,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Column(
        children: [
          Icon(
            Icons
                .medication_outlined,
            size: 24,
            color: AppColors
                .mutedForeground,
          ),
          SizedBox(height: 7),
          Text(
            'No items logged',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'No inventory items have been recorded for this treatment.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColors
                  .mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR / EMPTY STATES
// ============================================================================

class _DetailError
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DetailError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color: AppColors.muted,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize: 12,
              color: AppColors
                  .mutedForeground,
            ),
          ),

          const SizedBox(
              height: 8),

          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh,
              size: 15,
            ),
            label:
                const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _PageError
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  const _PageError({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            size: 40,
            color: AppColors
                .mutedForeground,
          ),

          const SizedBox(height: 12),

          Text(
            message,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color: AppColors
                  .mutedForeground,
            ),
          ),

          const SizedBox(height: 14),

          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(
              Icons.refresh,
              size: 16,
            ),
            label:
                const Text('Retry'),
          ),

          const SizedBox(height: 6),

          TextButton(
            onPressed: onBack,
            child: const Text(
              'Back to Medical Records',
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMedicalHistory
    extends StatelessWidget {
  final VoidCallback onBack;

  const _NoMedicalHistory({
    required this.onBack,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          const Icon(
            Icons
                .medical_services_outlined,
            size: 40,
            color: AppColors
                .mutedForeground,
          ),

          const SizedBox(height: 12),

          const Text(
            'No medical history found',
            style: TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(height: 4),

          const Text(
            'No treatments have been recorded for this animal.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors
                  .mutedForeground,
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: onBack,
            child: const Text(
              'Back to Medical Records',
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ADD TREATMENT ITEM RESULT
// ============================================================================

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

// ============================================================================
// ADD ITEM DIALOG
// ============================================================================

class _AddTreatmentItemDialog
    extends StatefulWidget {
  final List<InventoryItem> items;

  final Map<
      String,
      List<TreatmentItemUsed>>
      existingByItemId;

  final String
      defaultAdministeredBy;

  const _AddTreatmentItemDialog({
    required this.items,
    required this.existingByItemId,
    required this.defaultAdministeredBy,
  });

  @override
  State<_AddTreatmentItemDialog>
      createState() =>
          _AddTreatmentItemDialogState();
}

class _AddTreatmentItemDialogState
    extends State<_AddTreatmentItemDialog> {
      
  final _formKey =
      GlobalKey<FormState>();

  final _itemCtrl =
      TextEditingController();

  final _qtyCtrl =
      TextEditingController(
    text: '1',
  );

  late final TextEditingController
      _administeredByCtrl =
      TextEditingController(
    text:
        widget.defaultAdministeredBy,
  );

  DateTime _dateAdministered =
      DateTime.now();

  InventoryItem? _selectedItem;
List<InventoryItem> get _availableItems {
  final items = widget.items
      .where(
        (item) => item.currentUsableStockQty > 0,
      )
      .toList();

  items.sort(
    (a, b) => a.itemName
        .toLowerCase()
        .compareTo(
          b.itemName.toLowerCase(),
        ),
  );

  return items;
}

String _itemDisplayText(
  InventoryItem item,
) {
  String warning = '';

  if (item.stockLevel == StockLevel.low) {
    warning = ' · LOW STOCK';
  } else if (
      item.stockLevel ==
      StockLevel.needsRestock) {
    warning = ' · RESTOCK SOON';
  }

  return '${item.itemName} · '
      '${formatQty(item.currentUsableStockQty)} '
      '${item.currentUsableStockUnit} remaining'
      '$warning';
}

// ==========================================================================
// CLEAR ITEM SEARCH
// ==========================================================================

void _clearItemSelection() {
  setState(() {
    _selectedItem = null;
    _itemCtrl.clear();
    _qtyCtrl.text = '1';
  });

  FocusScope.of(context).unfocus();
}

@override
void dispose() {
    _itemCtrl.dispose();
    _qtyCtrl.dispose();
    _administeredByCtrl.dispose();

    super.dispose();
  }

  // ==========================================================================
  // BUILD INPUT
  // ==========================================================================

  TreatmentItemInput _inputFromItem(
    InventoryItem item,
    double qty,
  ) {
    final doseUnitId =
        item.dispenseUnitId ??
            item.packageUnitId ??
            item.purchaseUnitId;

    final doseUnitAbbr =
        item.dispenseUnitAbbr ??
            item.packageUnitAbbr ??
            item.purchaseUnitAbbr;

    return TreatmentItemInput(
      itemId: item.itemId,
      itemName: item.itemName,
      doseUnitId: doseUnitId,
      doseUnitAbbr:
          doseUnitAbbr,
      deductible:
          item.stockOutIsDeductible,
      stockQty:
          item.stockQty,
      packageQuantity:
          item.packageQuantity,
      packageStockQty:
          item.packageStockQty,
      qty: qty,
    );
  }

  // ==========================================================================
  // MAX DOSE
  // ==========================================================================

 double get _maxDoseQty {
  final item = _selectedItem;

  if (item == null ||
      !item.stockOutIsDeductible) {
    return double.infinity;
  }

  return item.currentUsableStockQty;
}
  // ==========================================================================
  // DATE
  // ==========================================================================

  Future<void> _pickDate() async {
    final picked =
        await showDatePicker(
      context: context,
      initialDate:
          _dateAdministered,
      firstDate:
          DateTime(2000),
      lastDate:
          DateTime.now(),
    );

    if (picked != null &&
        mounted) {
      setState(() {
        _dateAdministered =
            picked;
      });
    }
  }

  // ==========================================================================
  // SUBMIT
  // ==========================================================================

  void _submit() {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final item =
        _selectedItem;

    if (item == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('Select an item.'),
        ),
      );

      return;
    }

    final qty =
        double.tryParse(
              _qtyCtrl.text,
            ) ??
            0;

    Navigator.of(context).pop(
      _AddTreatmentItemResult(
        input:
            _inputFromItem(
          item,
          qty,
        ),
        administeredBy:
            _administeredByCtrl
                .text
                .trim(),
        dateAdministered:
            _dateAdministered,
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final item =
        _selectedItem;

   final priorDoses =
    item == null
        ? null
        : widget.existingByItemId[item.itemId];

    final mostRecentDose =
        priorDoses == null ||
                priorDoses.isEmpty
            ? null
            : priorDoses.reduce(
                (a, b) => a
                        .consumedDate
                        .isAfter(
                      b.consumedDate,
                    )
                    ? a
                    : b,
              );

    final doseUnitAbbr =
        item?.dispenseUnitAbbr ??
            item?.packageUnitAbbr ??
            item?.purchaseUnitAbbr;

    return AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      title: const Text(
        'Add Item to Treatment',
      ),
      content: SizedBox(
        width: 420,

        // Dialog can scroll independently if the screen is small.
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
        SearchSelectField<InventoryItem>(
  labelText:
      'Item',
  controller:
      _itemCtrl,

  // Only items with available stock are shown.
  options:
      _availableItems,

  // Shows remaining stock and stock warning.
  displayStringForOption:
      _itemDisplayText,

  validator: (value) =>
      value == null ||
              value
                  .trim()
                  .isEmpty
          ? 'Required'
          : null,

  onSelected:
      (picked) {
    setState(() {
      _selectedItem =
          picked;

      _qtyCtrl.text =
          '1';
    });
  },
),

const SizedBox(
  height: 5,
),

const SizedBox(
  height: 5,
),

Row(
  children: [
    const Expanded(
      child: Text(
        'Items with available stocks are the only ones displayed.',
        style: TextStyle(
          fontSize: 11.5,
          color:
              AppColors.mutedForeground,
        ),
      ),
    ),

    TextButton.icon(
      onPressed:
          _itemCtrl.text.trim().isEmpty &&
                  _selectedItem == null
              ? null
              : _clearItemSelection,
      icon: const Icon(
        Icons.close,
        size: 14,
      ),
      label: const Text(
        'Clear',
      ),
      style: TextButton.styleFrom(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 4,
        ),
        visualDensity:
            VisualDensity.compact,
      ),
    ),
  ],
),
                if (mostRecentDose !=
                    null) ...[
                  const SizedBox(
                      height: 7),

                  Text(
                    'Already given ${priorDoses!.length} '
                    '${priorDoses.length == 1 ? 'time' : 'times'} in this treatment. '
                    'Most recent: ${formatQty(mostRecentDose.dispensedQty)} '
                    '${mostRecentDose.dispenseUnitAbbr} on '
                    '${_formatDate(mostRecentDose.consumedDate)}. '
                    'This will be logged as an additional dose.',
                    style:
                        const TextStyle(
                      fontSize: 11.5,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),
                ],

                const SizedBox(
                    height: 14),

           TextFormField(
  controller:
      _qtyCtrl,

  autovalidateMode:
      AutovalidateMode.onUserInteraction,

  keyboardType:
      const TextInputType
          .numberWithOptions(
    decimal: true,
  ),

  decoration:
      InputDecoration(
    labelText:
        doseUnitAbbr == null
            ? 'Dose'
            : 'Dose ($doseUnitAbbr)',
  ),

  validator:
      (value) {
    final number =
        double.tryParse(
      value ?? '',
    );

    if (number == null ||
        number <= 0) {
      return 'Enter a valid quantity';
    }

    if (_selectedItem != null &&
        _selectedItem!
            .stockOutIsDeductible &&
        number > _maxDoseQty) {
      return 'Only ${formatQty(_maxDoseQty)} '
          '${_selectedItem!.currentUsableStockUnit} remaining';
    }

    return null;
  },
),

             if (item != null) ...[
  const SizedBox(
    height: 7,
  ),

  Row(
    crossAxisAlignment:
        CrossAxisAlignment.start,
    children: [
      Icon(
        item.stockLevel ==
                    StockLevel.low ||
                item.stockLevel ==
                    StockLevel.needsRestock
            ? Icons.warning_amber_rounded
            : Icons.inventory_2_outlined,
        size: 14,
        color:
            item.stockLevel ==
                        StockLevel.low ||
                    item.stockLevel ==
                        StockLevel.needsRestock
                ? AppColors.warning
                : AppColors
                    .mutedForeground,
      ),

      const SizedBox(
        width: 6,
      ),

      Expanded(
        child: Text(
          item.stockLevel ==
                  StockLevel.low
              ? '${formatQty(item.currentUsableStockQty)} '
                  '${item.currentUsableStockUnit} remaining · LOW STOCK'
              : item.stockLevel ==
                      StockLevel.needsRestock
                  ? '${formatQty(item.currentUsableStockQty)} '
                      '${item.currentUsableStockUnit} remaining · RESTOCK SOON'
                  : '${formatQty(item.currentUsableStockQty)} '
                      '${item.currentUsableStockUnit} remaining',
          style: TextStyle(
            fontSize: 11.5,
            color:
                item.stockLevel ==
                            StockLevel.low ||
                        item.stockLevel ==
                            StockLevel.needsRestock
                    ? AppColors.warning
                    : AppColors
                        .mutedForeground,
          ),
        ),
      ),
    ],
  ),
],

                const SizedBox(
                    height: 14),

                TextFormField(
                  controller:
                      _administeredByCtrl,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Administered by',
                  ),
                  validator:
                      (value) =>
                          value ==
                                      null ||
                                  value
                                      .trim()
                                      .isEmpty
                              ? 'Required'
                              : null,
                ),

                const SizedBox(
                    height: 14),

                InkWell(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                  onTap:
                      _pickDate,
                  child:
                      InputDecorator(
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Date administered',
                    ),
                    child: Text(
                      _formatDate(
                        _dateAdministered,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context)
                .pop();
          },
          child:
              const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed: _submit,
          child:
              const Text('Add'),
        ),
      ],
    );
  }
}

// ============================================================================
// DATE FORMAT
// ============================================================================

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
) {
  return '${_monthAbbrev[date.month - 1]} '
      '${date.day}, ${date.year}';
}