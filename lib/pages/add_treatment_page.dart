import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../models/pet.dart';
import '../models/treatment.dart';
import '../services/inventory_service.dart';
import '../services/pet_service.dart';
import '../services/treatment_service.dart';
import '../state/auth_state.dart';
import '../widgets/search_select_field.dart';

// =============================================================================
// ADD TREATMENT PAGE
// =============================================================================

class AddTreatmentPage extends StatefulWidget {
  final String? prefillItemId;
  final String? prefillQty;

  const AddTreatmentPage({
    super.key,
    this.prefillItemId,
    this.prefillQty,
  });

  @override
  State<AddTreatmentPage> createState() =>
      _AddTreatmentPageState();
}

// =============================================================================
// TREATMENT ITEM DRAFT
// =============================================================================
//
// A draft can exist without an inventory item.
//
// This is intentional:
// pressing "Add item" creates an EMPTY search field rather than automatically
// choosing the first inventory item.
// =============================================================================

class _TreatmentItemDraft {
  final int id;

  InventoryItem? item;
  double qty;

  _TreatmentItemDraft({
    required this.id,
    this.item,
    this.qty = 1,
  });
}

// =============================================================================
// PAGE STATE
// =============================================================================

class _AddTreatmentPageState
    extends State<AddTreatmentPage> {
  final TreatmentService _treatmentService =
      TreatmentService();

  final PetService _petService =
      PetService();

  final InventoryService _inventoryService =
      InventoryService();

  final _formKey =
      GlobalKey<FormState>();

  final _treatNameCtrl =
      TextEditingController();

  final _notesCtrl =
      TextEditingController();

  final _petCtrl =
      TextEditingController();

  final _administeredByCtrl =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;

  String? _error;

  List<Pet> _pets = [];
  List<InventoryItem> _items = [];

  Pet? _selectedPet;

  DateTime _dateAdministered =
      DateTime.now();

  final List<_TreatmentItemDraft>
      _itemDrafts = [];

  int _nextDraftId = 1;

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

  // ===========================================================================
  // ITEM -> TREATMENT INPUT
  // ===========================================================================

  TreatmentItemInput _inputFromItem(
    InventoryItem item, {
    required double qty,
  }) {
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
      doseUnitAbbr: doseUnitAbbr,
      deductible:
          item.stockOutIsDeductible,

      // Use current usable batch-aware stock.
      stockQty:
          item.hasPackageBreakdown
              ? item.currentPurchaseUnitEquivalent
              : item.currentUsableStockQty,

      packageQuantity:
          item.packageQuantity,

      packageStockQty:
          item.hasPackageBreakdown
              ? item.currentUsableStockQty
              : null,

      qty: qty,
    );
  }

  // ===========================================================================
  // LOAD
  // ===========================================================================

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final currentUser =
        context
            .read<AuthController>()
            .profile;

    try {
      final results =
          await Future.wait([
        _petService.fetchPets(),
        _inventoryService.fetchItems(),
      ]);

      if (!mounted) return;

      final pets =
          results[0] as List<Pet>;

      final items =
          results[1]
              as List<InventoryItem>;

      _itemDrafts.clear();

      // =======================================================================
      // OPTIONAL EXPLICIT INVENTORY PREFILL
      // =======================================================================
      //
      // If staff deliberately came from Inventory -> Treatment,
      // the selected inventory item may be prefilled.
      //
      // It is only allowed if usable stock still exists.
      // =======================================================================

      if (widget.prefillItemId != null) {
        InventoryItem? match;

        for (final item in items) {
          if (item.itemId ==
              widget.prefillItemId) {
            match = item;
            break;
          }
        }

        if (match != null &&
            match.currentUsableStockQty > 0) {
          final requestedQty =
              double.tryParse(
                    widget.prefillQty ?? '',
                  ) ??
                  1;

          final safeQty =
              requestedQty > 0
                  ? requestedQty
                  : 1.0;

          _itemDrafts.add(
            _TreatmentItemDraft(
              id: _nextDraftId++,
              item: match,
              qty: safeQty,
            ),
          );
        }
      }

      setState(() {
        _pets = pets;
        _items = items;

        _selectedPet =
            _pets.isEmpty
                ? null
                : _pets.first;

        _petCtrl.text =
            _selectedPet?.petName ?? '';

        _administeredByCtrl.text =
            currentUser?.fullName ?? '';

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not load form data: $e';

        _loading = false;
      });
    }
  }

  // ===========================================================================
  // ITEM AVAILABILITY
  // ===========================================================================

  Set<String> get _usedItemIds {
    return _itemDrafts
        .map(
          (draft) =>
              draft.item?.itemId,
        )
        .whereType<String>()
        .toSet();
  }

  bool get _hasEmptyDraft {
    return _itemDrafts.any(
      (draft) =>
          draft.item == null,
    );
  }

  bool get _hasUnusedInStockItems {
    final used =
        _usedItemIds;

    return _items.any(
      (item) =>
          item.currentUsableStockQty > 0 &&
          !used.contains(
            item.itemId,
          ),
    );
  }

  bool get _canAddItem {
    // Do not allow multiple blank rows at once.
    if (_hasEmptyDraft) {
      return false;
    }

    return _hasUnusedInStockItems;
  }

  // ===========================================================================
  // ADD EMPTY ITEM
  // ===========================================================================

  void _addItemRow() {
    if (_hasEmptyDraft) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Select or remove the current empty item before adding another.',
          ),
        ),
      );

      return;
    }

    if (!_hasUnusedInStockItems) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'No additional in-stock items are available.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _itemDrafts.add(
        _TreatmentItemDraft(
          id: _nextDraftId++,
        ),
      );
    });
  }

  // ===========================================================================
  // REMOVE ITEM
  // ===========================================================================

  void _removeItemRow(
    _TreatmentItemDraft draft,
  ) {
    setState(() {
      _itemDrafts.remove(
        draft,
      );
    });
  }

  // ===========================================================================
  // DATE
  // ===========================================================================

  Future<void>
      _pickDateAdministered() async {
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

  // ===========================================================================
  // NAVIGATION
  // ===========================================================================

  void _goBackToMedicalRecords() {
    // Keep this explicit route.
    //
    // It works whether the Add Treatment page was opened from:
    // - Medical Records
    // - Inventory -> Treatment
    // - browser navigation
    context.go(
      '/medical-records',
    );
  }

  // ===========================================================================
  // SAVE
  // ===========================================================================

  Future<void> _save() async {
    if (_saving) {
      return;
    }

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    if (_selectedPet == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Select a pet.',
          ),
        ),
      );

      return;
    }

    if (_itemDrafts.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Add at least one item used in the treatment.',
          ),
        ),
      );

      return;
    }

    if (_itemDrafts.any(
      (draft) =>
          draft.item == null,
    )) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Select an inventory item for every treatment row.',
          ),
        ),
      );

      return;
    }

    // Defensive duplicate check.
    final selectedIds =
        _itemDrafts
            .map(
              (draft) =>
                  draft.item!.itemId,
            )
            .toList();

    if (selectedIds.toSet().length !=
        selectedIds.length) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'The same inventory item cannot be added twice to one treatment.',
          ),
        ),
      );

      return;
    }

    final performedByUserId =
        context
            .read<AuthController>()
            .profile
            ?.userId;

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

    final treatmentItems =
        _itemDrafts
            .map(
              (draft) =>
                  _inputFromItem(
                draft.item!,
                qty:
                    draft.qty,
              ),
            )
            .toList();

    setState(() {
      _saving = true;
    });

    try {
      await _treatmentService
          .createTreatment(
        petId:
            _selectedPet!.petId,
        administeredByName:
            _administeredByCtrl
                .text
                .trim(),
        performedByUserId:
            performedByUserId,
        treatName:
            _treatNameCtrl
                .text
                .trim(),
        notes:
            _notesCtrl.text
                    .trim()
                    .isEmpty
                ? null
                : _notesCtrl.text
                    .trim(),
        dateAdministered:
            _dateAdministered,
        items:
            treatmentItems,
      );

      if (!mounted) return;

      _goBackToMedicalRecords();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not log treatment: $e',
          ),
        ),
      );
    }
  }

  // ===========================================================================
  // PAGE
  // ===========================================================================

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
      return Center(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Text(
              _error!,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    AppColors
                        .mutedForeground,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            OutlinedButton(
              onPressed:
                  _load,
              child:
                  const Text(
                'Retry',
              ),
            ),
          ],
        ),
      );
    }

    return ConstrainedBox(
      constraints:
          const BoxConstraints(
        maxWidth: 720,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ===================================================================
          // BACK
          // ===================================================================

          TextButton.icon(
            onPressed:
                _saving
                    ? null
                    : _goBackToMedicalRecords,
            icon:
                const Icon(
              Icons.arrow_back,
              size: 16,
            ),
            label:
                const Text(
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
            height: 8,
          ),

          // ===================================================================
          // HEADER
          // ===================================================================

          const Text(
            'Add Treatment',
            style:
                TextStyle(
              fontSize: 24,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 4,
          ),

          const Text(
            'Record treatment details and the inventory items used.',
            style:
                TextStyle(
              fontSize: 12.5,
              color:
                  AppColors
                      .mutedForeground,
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                // =============================================================
                // NAME + PET
                // =============================================================

                LayoutBuilder(
                  builder: (
                    context,
                    constraints,
                  ) {
                    final stacked =
                        constraints
                                .maxWidth <
                            520;

                    final treatmentField =
                        TextFormField(
                      controller:
                          _treatNameCtrl,
                      enabled:
                          !_saving,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Treatment name',
                      ),
                      validator: (
                        value,
                      ) {
                        if (value == null ||
                            value
                                .trim()
                                .isEmpty) {
                          return 'Required';
                        }

                        return null;
                      },
                    );

                    final petField =
                        _pets.isEmpty
                            ? const TextField(
                                enabled:
                                    false,
                                decoration:
                                    InputDecoration(
                                  labelText:
                                      'Pet (none available)',
                                ),
                              )
                            : SearchSelectField<
                                Pet>(
                                labelText:
                                    'Search pet',
                                controller:
                                    _petCtrl,
                                options:
                                    _pets,
                                displayStringForOption:
                                    (pet) =>
                                        pet.petName,
                                validator:
                                    (
                                  value,
                                ) {
                                  if (value ==
                                          null ||
                                      value
                                          .trim()
                                          .isEmpty) {
                                    return 'Required';
                                  }

                                  return null;
                                },
                                onSelected:
                                    (
                                  pet,
                                ) {
                                  setState(() {
                                    _selectedPet =
                                        pet;
                                  });
                                },
                              );

                    if (stacked) {
                      return Column(
                        children: [
                          treatmentField,

                          const SizedBox(
                            height: 12,
                          ),

                          petField,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          child:
                              treatmentField,
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child:
                              petField,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(
                  height: 12,
                ),

                TextFormField(
                  controller:
                      _notesCtrl,
                  enabled:
                      !_saving,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Notes (optional)',
                  ),
                  maxLines: 3,
                ),

                const SizedBox(
                  height: 24,
                ),

                // =============================================================
                // ITEMS HEADER
                // =============================================================

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
                            'Items Used',
                            style:
                                TextStyle(
                              fontSize:
                                  16,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),

                          SizedBox(
                            height: 3,
                          ),

                          Text(
                            'Search for an item used during treatment. '
                            'Out-of-stock items are not displayed.',
                            style:
                                TextStyle(
                              fontSize:
                                  11.5,
                              color:
                                  AppColors
                                      .mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    TextButton.icon(
                      onPressed:
                          !_saving &&
                                  _canAddItem
                              ? _addItemRow
                              : null,
                      icon:
                          const Icon(
                        Icons.add,
                        size: 16,
                      ),
                      label:
                          const Text(
                        'Add item',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                // =============================================================
                // EMPTY ITEM STATE
                // =============================================================

                if (_itemDrafts.isEmpty)
                  Container(
                    width:
                        double.infinity,
                    padding:
                        const EdgeInsets
                            .all(
                      16,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          AppColors
                              .muted
                              .withValues(
                        alpha:
                            0.35,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                      border:
                          Border.all(
                        color:
                            AppColors
                                .border,
                      ),
                    ),
                    child:
                        const Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Icon(
                          Icons.search,
                          size: 18,
                          color:
                              AppColors
                                  .mutedForeground,
                        ),

                        SizedBox(
                          width: 9,
                        ),

                        Expanded(
                          child: Text(
                            'Click “Add item” to search available inventory.',
                            style:
                                TextStyle(
                              fontSize:
                                  12.5,
                              color:
                                  AppColors
                                      .mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // =============================================================
                // ITEM ROWS
                // =============================================================

                for (final draft
                    in _itemDrafts)
                  _TreatmentItemDraftCard(
                    key:
                        ValueKey(
                      draft.id,
                    ),
                    draft:
                        draft,
                    items:
                        _items,
                    usedItemIds:
                        _usedItemIds
                            .where(
                              (id) =>
                                  id !=
                                  draft.item
                                      ?.itemId,
                            )
                            .toSet(),
                    enabled:
                        !_saving,
                    onRemove:
                        () =>
                            _removeItemRow(
                      draft,
                    ),
                    onItemSelected:
                        (
                      item,
                    ) {
                      setState(() {
                        draft.item =
                            item;

                        draft.qty =
                            1;
                      });
                    },
                    onItemCleared:
                        () {
                      setState(() {
                        draft.item =
                            null;

                        draft.qty =
                            1;
                      });
                    },
                    onQtyChanged:
                        (
                      qty,
                    ) {
                      draft.qty =
                          qty;
                    },
                  ),

                const SizedBox(
                  height: 20,
                ),

                // =============================================================
                // ADMINISTERED BY + DATE
                // =============================================================

                LayoutBuilder(
                  builder: (
                    context,
                    constraints,
                  ) {
                    final stacked =
                        constraints
                                .maxWidth <
                            520;

                    final administeredField =
                        TextFormField(
                      controller:
                          _administeredByCtrl,
                      enabled:
                          !_saving,
                      decoration:
                          const InputDecoration(
                        labelText:
                            'Administered by',
                      ),
                      validator: (
                        value,
                      ) {
                        if (value == null ||
                            value
                                .trim()
                                .isEmpty) {
                          return 'Required';
                        }

                        return null;
                      },
                    );

                    final dateField =
                        InkWell(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                      onTap:
                          _saving
                              ? null
                              : _pickDateAdministered,
                      child:
                          InputDecorator(
                        decoration:
                            const InputDecoration(
                          labelText:
                              'Date administered',
                        ),
                        child:
                            Text(
                          _formatDate(
                            _dateAdministered,
                          ),
                        ),
                      ),
                    );

                    if (stacked) {
                      return Column(
                        children: [
                          administeredField,

                          const SizedBox(
                            height: 12,
                          ),

                          dateField,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Expanded(
                          child:
                              administeredField,
                        ),

                        const SizedBox(
                          width: 12,
                        ),

                        Expanded(
                          child:
                              dateField,
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(
                  height: 28,
                ),

                // =============================================================
                // ACTIONS
                // =============================================================

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .end,
                  children: [
                    TextButton(
                      onPressed:
                          _saving
                              ? null
                              : _goBackToMedicalRecords,
                      child:
                          const Text(
                        'Cancel',
                      ),
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    ElevatedButton.icon(
                      onPressed:
                          _saving
                              ? null
                              : _save,
                      icon:
                          _saving
                              ? const SizedBox(
                                  width:
                                      16,
                                  height:
                                      16,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2,
                                    color:
                                        Colors
                                            .white,
                                  ),
                                )
                              : const Icon(
                                  Icons
                                      .save_outlined,
                                  size:
                                      17,
                                ),
                      label:
                          Text(
                        _saving
                            ? 'Saving'
                            : 'Save Treatment',
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TREATMENT ITEM CARD
// =============================================================================

class _TreatmentItemDraftCard
    extends StatefulWidget {
  final _TreatmentItemDraft draft;

  final List<InventoryItem> items;

  final Set<String> usedItemIds;

  final bool enabled;

  final VoidCallback onRemove;

  final ValueChanged<InventoryItem>
      onItemSelected;

  final VoidCallback onItemCleared;

  final ValueChanged<double>
      onQtyChanged;

  const _TreatmentItemDraftCard({
    super.key,
    required this.draft,
    required this.items,
    required this.usedItemIds,
    required this.enabled,
    required this.onRemove,
    required this.onItemSelected,
    required this.onItemCleared,
    required this.onQtyChanged,
  });

  @override
  State<_TreatmentItemDraftCard>
      createState() =>
          _TreatmentItemDraftCardState();
}

class _TreatmentItemDraftCardState
    extends State<_TreatmentItemDraftCard> {
  final _searchCtrl =
      TextEditingController();

  final _searchFocusNode =
      FocusNode();

  late final TextEditingController
      _qtyCtrl;

  @override
  void initState() {
    super.initState();

    final selected =
        widget.draft.item;

    if (selected != null) {
      _searchCtrl.text =
          _itemDisplayText(
        selected,
      );
    }

    _qtyCtrl =
        TextEditingController(
      text:
          formatQty(
        widget.draft.qty,
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _qtyCtrl.dispose();

    super.dispose();
  }

  // ===========================================================================
  // STOCK STATUS
  // ===========================================================================

  String _stockStatus(
    InventoryItem item,
  ) {
    switch (item.stockLevel) {
      case StockLevel.outOfStock:
        return 'OUT OF STOCK';

      case StockLevel.low:
        return 'LOW STOCK';

      case StockLevel.needsRestock:
        return 'RESTOCK SOON';

      case StockLevel.inStock:
        return '';
    }
  }

  String _itemDisplayText(
    InventoryItem item,
  ) {
    final status =
        _stockStatus(
      item,
    );

    final availability =
        '${formatQty(item.currentUsableStockQty)} '
        '${item.currentUsableStockUnit} available';

    if (status.isEmpty) {
      return '${item.itemName} · '
          '$availability';
    }

    return '${item.itemName} · '
        '$availability · '
        '$status';
  }

  String _stockSubtitle(
    InventoryItem item,
  ) {
    final status =
        _stockStatus(
      item,
    );

    final availability =
        '${formatQty(item.currentUsableStockQty)} '
        '${item.currentUsableStockUnit} available';

    if (status.isEmpty) {
      return availability;
    }

    return '$availability · $status';
  }

  // ===========================================================================
  // MAX DOSE
  // ===========================================================================

  double get _maxDoseQty {
    final item =
        widget.draft.item;

    if (item == null) {
      return 0;
    }

    if (!item.stockOutIsDeductible) {
      return double.infinity;
    }

    return item.currentUsableStockQty;
  }

  // ===========================================================================
  // CLEAR INVALID / MANUALLY EDITED SELECTION
  // ===========================================================================

  void _handleSearchTextChanged(
    String value,
  ) {
    final selected =
        widget.draft.item;

    if (selected == null) {
      return;
    }

    final expected =
        _itemDisplayText(
      selected,
    );

    // If staff manually changes the search text after selecting an item,
    // that old item must no longer remain selected internally.
    if (value.trim() !=
        expected.trim()) {
      widget.onItemCleared();

      _qtyCtrl.text =
          '1';

      if (mounted) {
        setState(() {});
      }
    }
  }

  // ===========================================================================
  // ITEM SEARCH
  // ===========================================================================

  Widget _buildItemSearch(
    List<InventoryItem>
        selectableItems,
  ) {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final fieldWidth =
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : 360.0;

        return RawAutocomplete<
            InventoryItem>(
          textEditingController:
              _searchCtrl,
          focusNode:
              _searchFocusNode,

          // Always display underneath this field.
          optionsViewOpenDirection:
              OptionsViewOpenDirection
                  .down,

          displayStringForOption:
              _itemDisplayText,

          optionsBuilder:
              (
            TextEditingValue value,
          ) {
            final query =
                value.text
                    .trim()
                    .toLowerCase();

            if (query.isEmpty) {
              return selectableItems;
            }

            return selectableItems
                .where(
              (item) {
                final searchable =
                    '${item.itemName} '
                    '${item.itemCategory} '
                    '${item.currentUsableStockUnit} '
                    '${_stockStatus(item)}'
                        .toLowerCase();

                return searchable
                    .contains(
                  query,
                );
              },
            );
          },

          onSelected:
              (
            item,
          ) {
            widget.onItemSelected(
              item,
            );

            final text =
                _itemDisplayText(
              item,
            );

            _searchCtrl.text =
                text;

            _searchCtrl.selection =
                TextSelection.collapsed(
              offset:
                  text.length,
            );

            _qtyCtrl.text =
                '1';

            if (mounted) {
              setState(() {});
            }
          },

          // ===================================================================
          // SEARCH FIELD
          // ===================================================================

          fieldViewBuilder:
              (
            context,
            controller,
            focusNode,
            onFieldSubmitted,
          ) {
            return TextFormField(
              controller:
                  controller,
              focusNode:
                  focusNode,
              enabled:
                  widget.enabled,
              decoration:
                  const InputDecoration(
                labelText:
                    'Search item',
                prefixIcon:
                    Icon(
                  Icons.search,
                  size: 18,
                ),
              ),
              onChanged:
                  _handleSearchTextChanged,
              validator:
                  (
                value,
              ) {
                final item =
                    widget
                        .draft
                        .item;

                if (item == null) {
                  return 'Select an item';
                }

                final expected =
                    _itemDisplayText(
                  item,
                );

                if ((value ?? '')
                        .trim() !=
                    expected.trim()) {
                  return 'Select an item from the list';
                }

                return null;
              },
            );
          },

          // ===================================================================
          // SEARCH RESULTS
          // ===================================================================
          //
          // Custom overlay prevents the first row from sitting underneath the
          // text field and gives every result a predictable full-height row.
          // ===================================================================

          optionsViewBuilder:
              (
            context,
            onSelected,
            options,
          ) {
            final list =
                options.toList();

            return Align(
              alignment:
                  Alignment.topLeft,
              child:
                  Transform.translate(
                // Important:
                // creates visible breathing room below the input.
                offset:
                    const Offset(
                  0,
                  8,
                ),
                child:
                    Material(
                  elevation: 8,
                  shadowColor:
                      Colors.black
                          .withValues(
                    alpha: 0.12,
                  ),
                  color:
                      AppColors.card,
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                  clipBehavior:
                      Clip.antiAlias,
                  child:
                      Container(
                    width:
                        fieldWidth,
                    constraints:
                        const BoxConstraints(
                      maxHeight:
                          260,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          AppColors.card,
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                      border:
                          Border.all(
                        color:
                            AppColors
                                .border,
                      ),
                    ),
                    child:
                        list.isEmpty
                            ? const Padding(
                                padding:
                                    EdgeInsets
                                        .all(
                                  16,
                                ),
                                child:
                                    Row(
                                  children: [
                                    Icon(
                                      Icons
                                          .search_off_outlined,
                                      size:
                                          18,
                                      color:
                                          AppColors
                                              .mutedForeground,
                                    ),
                                    SizedBox(
                                      width:
                                          8,
                                    ),
                                    Expanded(
                                      child:
                                          Text(
                                        'No matching in-stock items.',
                                        style:
                                            TextStyle(
                                          fontSize:
                                              12.5,
                                          color:
                                              AppColors
                                                  .mutedForeground,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView
                                .separated(
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  vertical:
                                      6,
                                ),
                                shrinkWrap:
                                    true,
                                itemCount:
                                    list.length,
                                separatorBuilder:
                                    (
                                  context,
                                  index,
                                ) =>
                                        const Divider(
                                  height:
                                      1,
                                ),
                                itemBuilder:
                                    (
                                  context,
                                  index,
                                ) {
                                  final item =
                                      list[
                                          index];

                                  final status =
                                      _stockStatus(
                                    item,
                                  );

                                  final warning =
                                      item.stockLevel ==
                                              StockLevel
                                                  .low ||
                                          item.stockLevel ==
                                              StockLevel
                                                  .needsRestock;

                                  return InkWell(
                                    onTap:
                                        () =>
                                            onSelected(
                                      item,
                                    ),
                                    child:
                                        SizedBox(
                                      height:
                                          58,
                                      child:
                                          Padding(
                                        padding:
                                            const EdgeInsets
                                                .symmetric(
                                          horizontal:
                                              14,
                                          vertical:
                                              8,
                                        ),
                                        child:
                                            Row(
                                          children: [
                                            Expanded(
                                              child:
                                                  Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .center,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment
                                                        .start,
                                                children: [
                                                  Text(
                                                    item.itemName,
                                                    maxLines:
                                                        1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                    style:
                                                        const TextStyle(
                                                      fontSize:
                                                          13,
                                                      fontWeight:
                                                          FontWeight
                                                              .w600,
                                                    ),
                                                  ),
                                                  const SizedBox(
                                                    height:
                                                        2,
                                                  ),
                                                  Text(
                                                    _stockSubtitle(
                                                      item,
                                                    ),
                                                    maxLines:
                                                        1,
                                                    overflow:
                                                        TextOverflow
                                                            .ellipsis,
                                                    style:
                                                        TextStyle(
                                                      fontSize:
                                                          11.3,
                                                      color:
                                                          warning
                                                              ? AppColors
                                                                  .warning
                                                              : AppColors
                                                                  .mutedForeground,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            if (status
                                                .isNotEmpty) ...[
                                              const SizedBox(
                                                width:
                                                    8,
                                              ),

                                              Container(
                                                padding:
                                                    const EdgeInsets
                                                        .symmetric(
                                                  horizontal:
                                                      7,
                                                  vertical:
                                                      3,
                                                ),
                                                decoration:
                                                    BoxDecoration(
                                                  color:
                                                      AppColors
                                                          .warning
                                                          .withValues(
                                                    alpha:
                                                        0.11,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                    999,
                                                  ),
                                                ),
                                                child:
                                                    Text(
                                                  status,
                                                  style:
                                                      const TextStyle(
                                                    fontSize:
                                                        8.5,
                                                    fontWeight:
                                                        FontWeight
                                                            .w800,
                                                    color:
                                                        AppColors
                                                            .warning,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // DOSE
  // ===========================================================================

  Widget _buildDoseField(
    InventoryItem? selectedItem,
  ) {
    final unit =
        selectedItem == null
            ? null
            : (
                selectedItem
                        .dispenseUnitAbbr ??
                    selectedItem
                        .packageUnitAbbr ??
                    selectedItem
                        .purchaseUnitAbbr
              );

    return TextFormField(
      controller:
          _qtyCtrl,
      enabled:
          widget.enabled &&
              selectedItem != null,
      keyboardType:
          const TextInputType
              .numberWithOptions(
        decimal: true,
      ),
      decoration:
          InputDecoration(
        labelText:
            unit == null
                ? 'Dose'
                : 'Dose ($unit)',
      ),
      onChanged:
          (
        value,
      ) {
        final qty =
            double.tryParse(
                  value,
                ) ??
                0;

        widget.onQtyChanged(
          qty,
        );
      },
      validator:
          (
        value,
      ) {
        if (selectedItem == null) {
          return null;
        }

        final qty =
            double.tryParse(
          value ?? '',
        );

        if (qty == null ||
            qty <= 0) {
          return 'Enter a valid quantity';
        }

        if (selectedItem
                .stockOutIsDeductible &&
            qty >
                _maxDoseQty) {
          return 'Only '
              '${formatQty(_maxDoseQty)} '
              'available';
        }

        return null;
      },
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final selectedItem =
        widget.draft.item;

    // ========================================================================
    // SELECTABLE INVENTORY
    // ========================================================================
    //
    // Rules:
    // - zero usable stock is hidden
    // - items already used in another row are hidden
    // - current row's own selected item remains available
    // ========================================================================

    final selectableItems =
        widget.items
            .where(
              (item) =>
                  item.currentUsableStockQty > 0 &&
                  (
                    selectedItem?.itemId ==
                            item.itemId ||
                        !widget
                            .usedItemIds
                            .contains(
                          item.itemId,
                        )
                  ),
            )
            .toList()
          ..sort(
            (a, b) =>
                a.itemName
                    .toLowerCase()
                    .compareTo(
                      b.itemName
                          .toLowerCase(),
                    ),
          );

    final isLowStock =
        selectedItem?.stockLevel ==
            StockLevel.low;

    final needsRestock =
        selectedItem?.stockLevel ==
            StockLevel
                .needsRestock;

    return Padding(
      padding:
          const EdgeInsets.only(
        top: 8,
        bottom: 8,
      ),
      child:
          Container(
        width:
            double.infinity,
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
          border:
              Border.all(
            color:
                AppColors.border,
          ),
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            // =================================================================
            // SEARCH + DOSE + REMOVE
            // =================================================================

            LayoutBuilder(
              builder: (
                context,
                constraints,
              ) {
                final stacked =
                    constraints
                            .maxWidth <
                        520;

                if (stacked) {
                  return Column(
                    children: [
                      _buildItemSearch(
                        selectableItems,
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Expanded(
                            child:
                                _buildDoseField(
                              selectedItem,
                            ),
                          ),

                          const SizedBox(
                            width: 6,
                          ),

                          IconButton(
                            tooltip:
                                'Remove item',
                            onPressed:
                                widget.enabled
                                    ? widget
                                        .onRemove
                                    : null,
                            icon:
                                const Icon(
                              Icons.close,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Expanded(
                      flex: 3,
                      child:
                          _buildItemSearch(
                        selectableItems,
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      flex: 2,
                      child:
                          _buildDoseField(
                        selectedItem,
                      ),
                    ),

                    const SizedBox(
                      width: 4,
                    ),

                    IconButton(
                      tooltip:
                          'Remove item',
                      onPressed:
                          widget.enabled
                              ? widget
                                  .onRemove
                              : null,
                      icon:
                          const Icon(
                        Icons.close,
                        size: 18,
                      ),
                    ),
                  ],
                );
              },
            ),

            // =================================================================
            // STOCK INFORMATION
            // =================================================================

            if (selectedItem !=
                null) ...[
              const SizedBox(
                height: 10,
              ),

              Container(
                width:
                    double.infinity,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 11,
                  vertical: 10,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      isLowStock ||
                              needsRestock
                          ? AppColors
                              .warning
                              .withValues(
                              alpha:
                                  0.08,
                            )
                          : AppColors
                              .muted
                              .withValues(
                              alpha:
                                  0.40,
                            ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                  border:
                      Border.all(
                    color:
                        isLowStock ||
                                needsRestock
                            ? AppColors
                                .warning
                                .withValues(
                                alpha:
                                    0.25,
                              )
                            : AppColors
                                .border,
                  ),
                ),
                child:
                    Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Icon(
                      isLowStock ||
                              needsRestock
                          ? Icons
                              .warning_amber_rounded
                          : Icons
                              .inventory_2_outlined,
                      size:
                          17,
                      color:
                          isLowStock ||
                                  needsRestock
                              ? AppColors
                                  .warning
                              : AppColors
                                  .mutedForeground,
                    ),

                    const SizedBox(
                      width:
                          8,
                    ),

                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            '${formatQty(selectedItem.currentUsableStockQty)} '
                            '${selectedItem.currentUsableStockUnit} available',
                            style:
                                const TextStyle(
                              fontSize:
                                  12.5,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),

                          const SizedBox(
                            height:
                                3,
                          ),

                          Text(
                            isLowStock
                                ? 'Low stock — use only the amount needed.'
                                : needsRestock
                                    ? 'Stock is getting low.'
                                    : 'Available for treatment.',
                            style:
                                TextStyle(
                              fontSize:
                                  11.5,
                              color:
                                  isLowStock ||
                                          needsRestock
                                      ? AppColors
                                          .warning
                                      : AppColors
                                          .mutedForeground,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (isLowStock ||
                        needsRestock) ...[
                      const SizedBox(
                        width:
                            8,
                      ),

                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              8,
                          vertical:
                              4,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              AppColors
                                  .warning
                                  .withValues(
                            alpha:
                                0.12,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            999,
                          ),
                        ),
                        child:
                            Text(
                          isLowStock
                              ? 'LOW STOCK'
                              : 'RESTOCK SOON',
                          style:
                              const TextStyle(
                            fontSize:
                                9.5,
                            fontWeight:
                                FontWeight
                                    .w800,
                            color:
                                AppColors
                                    .warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

  
            ],
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// DATE FORMAT
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
) {
  return '${_monthAbbrev[date.month - 1]} '
      '${date.day}, ${date.year}';
}