import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../models/item_rop_settings.dart';
import '../models/primary_category.dart';
import '../models/subcategory.dart';
import '../models/unit.dart';
import '../services/catalog_service.dart';
import '../services/inventory_service.dart';
import '../services/settings_service.dart';
import '../services/rop_service.dart';

// =============================================================================
// MANAGER SETTINGS PAGE
// =============================================================================
//
// Handles:
//
// 1. Inventory alert thresholds
// 2. ROP system defaults
// 3. Item-specific ROP overrides
// 4. Category management
// 5. Unit management
//
// WBS 2.4 ROP Settings is implemented here.
// =============================================================================

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() =>
      _SettingsPageState();
}

class _SettingsPageState
    extends State<SettingsPage> {
  final SettingsService _service =
      SettingsService();

  final _formKey =
      GlobalKey<FormState>();

  // ===========================================================================
  // INVENTORY ALERT CONTROLLERS
  // ===========================================================================

  final _lowStockCtrl =
      TextEditingController();

  final _expiryDaysCtrl =
      TextEditingController();

  // ===========================================================================
  // ROP DEFAULT CONTROLLERS
  // ===========================================================================

  final _defaultLeadTimeCtrl =
      TextEditingController();

  final _defaultSafetyStockCtrl =
      TextEditingController();

  // These hold the SAVED values from Supabase.
  //
  // They are passed to the item override section so each item can show which
  // values it inherits when no custom override exists.
  int _defaultLeadTimeDays = 7;
  double _defaultSafetyStockQty = 0;

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lowStockCtrl.dispose();
    _expiryDaysCtrl.dispose();
    _defaultLeadTimeCtrl.dispose();
    _defaultSafetyStockCtrl.dispose();
    super.dispose();
  }

  // ===========================================================================
  // LOAD SYSTEM SETTINGS
  // ===========================================================================

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final settings =
          await _service.fetchSettings();

      if (!mounted) return;

      setState(() {
        _lowStockCtrl.text =
            formatQty(
          settings.lowStockThreshold,
        );

        _expiryDaysCtrl.text =
            settings.expirationWarningDays
                .toString();

        _defaultLeadTimeCtrl.text =
            settings.defaultLeadTimeDays
                .toString();

        _defaultSafetyStockCtrl.text =
            formatQty(
          settings.defaultSafetyStockQty,
        );

        _defaultLeadTimeDays =
            settings.defaultLeadTimeDays;

        _defaultSafetyStockQty =
            settings.defaultSafetyStockQty;

        _loading = false;
      });

      // Keep the existing global threshold synchronized with the value stored
      // in Supabase when the Settings page loads.
      lowStockPurchaseUnitThreshold =
          settings.lowStockThreshold;
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not load settings: $e';
        _loading = false;
      });
    }
  }

  // ===========================================================================
  // SAVE SYSTEM SETTINGS
  // ===========================================================================

  Future<void> _save() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final lowStock =
        double.parse(
      _lowStockCtrl.text.trim(),
    );

    final expiryDays =
        int.parse(
      _expiryDaysCtrl.text.trim(),
    );

    final leadTime =
        int.parse(
      _defaultLeadTimeCtrl.text.trim(),
    );

    final safetyStock =
        double.parse(
      _defaultSafetyStockCtrl.text.trim(),
    );

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(20),
        ),
        title: const Text(
          'Save settings?',
        ),
        content: const SizedBox(
          width: 420,
          child: Text(
            'This updates the app-wide inventory alert thresholds and '
            'the default Reorder Point settings used by items that do not '
            'have their own custom ROP settings.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(
              dialogContext,
            ).pop(false),
            child:
                const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(
              dialogContext,
            ).pop(true),
            child:
                const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) return;

    setState(
      () => _saving = true,
    );

    try {
      final settings =
          await _service.updateSettings(
        lowStockThreshold: lowStock,
        expirationWarningDays:
            expiryDays,
        defaultLeadTimeDays:
            leadTime,
        defaultSafetyStockQty:
            safetyStock,
      );

      lowStockPurchaseUnitThreshold =
          settings.lowStockThreshold;

      if (!mounted) return;

      setState(() {
        _defaultLeadTimeDays =
            settings.defaultLeadTimeDays;

        _defaultSafetyStockQty =
            settings.defaultSafetyStockQty;

        _defaultLeadTimeCtrl.text =
            settings.defaultLeadTimeDays
                .toString();

        _defaultSafetyStockCtrl.text =
            formatQty(
          settings.defaultSafetyStockQty,
        );
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Settings saved.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Could not save settings: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(
          () => _saving = false,
        );
      }
    }
  }

  // ===========================================================================
  // VALIDATION
  // ===========================================================================

  String? _positiveNumberValidator(
    String? value, {
    bool allowDecimal = true,
  }) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Required';
    }

    final parsed = allowDecimal
        ? double.tryParse(
            value.trim(),
          )
        : int.tryParse(
            value.trim(),
          );

    if (parsed == null) {
      return 'Enter a number';
    }

    if (parsed <= 0) {
      return 'Must be greater than 0';
    }

    return null;
  }

  String? _nonNegativeNumberValidator(
    String? value, {
    bool allowDecimal = true,
  }) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Required';
    }

    final parsed = allowDecimal
        ? double.tryParse(
            value.trim(),
          )
        : int.tryParse(
            value.trim(),
          );

    if (parsed == null) {
      return 'Enter a number';
    }

    if (parsed < 0) {
      return 'Cannot be negative';
    }

    return null;
  }

  // ===========================================================================
  // PAGE
  // ===========================================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return ConstrainedBox(
      constraints:
          const BoxConstraints(
        maxWidth: 900,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ===================================================================
          // PAGE HEADER
          // ===================================================================

          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Configure inventory alerts, reorder point settings, categories, and units.',
            style: TextStyle(
              color:
                  AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 20),

          // ===================================================================
          // INVENTORY ALERTS + ROP DEFAULTS
          // ===================================================================

          ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 700,
            ),
            child: _loading
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : _error != null
                    ? Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            _error!,
                            style:
                                const TextStyle(
                              color: AppColors
                                  .destructive,
                            ),
                          ),
                          const SizedBox(
                            height: 12,
                          ),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text(
                              'Retry',
                            ),
                          ),
                        ],
                      )
                    : Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets
                                .all(20),
                        decoration:
                            BoxDecoration(
                          color:
                              AppColors.card,
                          borderRadius:
                              BorderRadius
                                  .circular(16),
                          border:
                              Border.all(
                            color:
                                AppColors
                                    .border,
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,
                            children: [
                              // =================================================
                              // INVENTORY ALERTS
                              // =================================================

                              const Text(
                                'Inventory Alerts',
                                style:
                                    TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              const Text(
                                'Configure when inventory and expiry warnings appear.',
                                style:
                                    TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors
                                      .mutedForeground,
                                ),
                              ),
                              const SizedBox(
                                height: 16,
                              ),

                              TextFormField(
                                controller:
                                    _lowStockCtrl,
                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal: true,
                                ),
                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Low stock threshold',
                                  helperText:
                                      'Whole containers at or below this level are flagged as Low Stock.',
                                ),
                                validator:
                                    _positiveNumberValidator,
                              ),
                              const SizedBox(
                                height: 16,
                              ),

                              TextFormField(
                                controller:
                                    _expiryDaysCtrl,
                                keyboardType:
                                    TextInputType
                                        .number,
                                decoration:
                                    const InputDecoration(
                                  labelText:
                                      'Expiration warning window (days)',
                                  helperText:
                                      'Usable batches expiring within this many days are flagged as Expiring Soon.',
                                ),
                                validator: (v) =>
                                    _positiveNumberValidator(
                                  v,
                                  allowDecimal:
                                      false,
                                ),
                              ),

                              const SizedBox(
                                height: 24,
                              ),
                              const Divider(),
                              const SizedBox(
                                height: 20,
                              ),

                              // =================================================
                              // ROP DEFAULTS
                              // =================================================

                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration:
                                        BoxDecoration(
                                      color: AppColors
                                          .secondary,
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        12,
                                      ),
                                    ),
                                    alignment:
                                        Alignment
                                            .center,
                                    child:
                                        const Icon(
                                      Icons
                                          .trending_up_outlined,
                                      size: 20,
                                      color: AppColors
                                          .primary,
                                    ),
                                  ),
                                  const SizedBox(
                                    width: 12,
                                  ),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment
                                              .start,
                                      children: [
                                        Text(
                                          'Reorder Point Defaults',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight
                                                    .w700,
                                            fontSize:
                                                15,
                                          ),
                                        ),
                                        SizedBox(
                                          height: 2,
                                        ),
                                        Text(
                                          'Used when an item does not have its own ROP override.',
                                          style:
                                              TextStyle(
                                            fontSize:
                                                12.5,
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
                                height: 18,
                              ),

                              LayoutBuilder(
                                builder:
                                    (
                                  context,
                                  constraints,
                                ) {
                                  final isNarrow =
                                      constraints
                                              .maxWidth <
                                          520;

                                  final leadTime =
                                      TextFormField(
                                    controller:
                                        _defaultLeadTimeCtrl,
                                    keyboardType:
                                        TextInputType
                                            .number,
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'Default lead time',
                                      suffixText:
                                          'days',
                                      helperText:
                                          'Expected number of days before replenishment arrives.',
                                    ),
                                    validator: (v) =>
                                        _nonNegativeNumberValidator(
                                      v,
                                      allowDecimal:
                                          false,
                                    ),
                                  );

                                  final safety =
                                      TextFormField(
                                    controller:
                                        _defaultSafetyStockCtrl,
                                    keyboardType:
                                        const TextInputType
                                            .numberWithOptions(
                                      decimal:
                                          true,
                                    ),
                                    decoration:
                                        const InputDecoration(
                                      labelText:
                                          'Default safety stock',
                                      helperText:
                                          'Fallback buffer in each item\'s purchase unit.',
                                    ),
                                    validator: (v) =>
                                        _nonNegativeNumberValidator(
                                      v,
                                    ),
                                  );

                                  if (isNarrow) {
                                    return Column(
                                      children: [
                                        leadTime,
                                        const SizedBox(
                                          height:
                                              16,
                                        ),
                                        safety,
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
                                            leadTime,
                                      ),
                                      const SizedBox(
                                        width: 16,
                                      ),
                                      Expanded(
                                        child:
                                            safety,
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(
                                height: 16,
                              ),

                              Container(
                                width:
                                    double.infinity,
                                padding:
                                    const EdgeInsets
                                        .all(12),
                                decoration:
                                    BoxDecoration(
                                  color: AppColors
                                      .secondary,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    12,
                                  ),
                                ),
                                child: const Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Icon(
                                      Icons
                                          .info_outline,
                                      size: 17,
                                      color: AppColors
                                          .primary,
                                    ),
                                    SizedBox(
                                      width: 8,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'ROP = Average Daily Usage × Lead Time + Safety Stock. '
                                        'Average Daily Usage will be calculated from the last 30 days of recorded usage.',
                                        style:
                                            TextStyle(
                                          fontSize:
                                              12.5,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(
                                height: 20,
                              ),

                              Align(
                                alignment:
                                    Alignment
                                        .centerRight,
                                child:
                                    ElevatedButton.icon(
                                  onPressed:
                                      _saving
                                          ? null
                                          : _save,
                                  icon: _saving
                                      ? const SizedBox
                                          .shrink()
                                      : const Icon(
                                          Icons
                                              .save_outlined,
                                          size:
                                              17,
                                        ),
                                  label: _saving
                                      ? const SizedBox(
                                          height:
                                              16,
                                          width:
                                              16,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                          ),
                                        )
                                      : const Text(
                                          'Save Settings',
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),

          const SizedBox(height: 32),

          // ===================================================================
          // ITEM-SPECIFIC ROP OVERRIDES
          // ===================================================================

          const Text(
            'Item ROP Overrides',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Give individual items a different lead time or safety stock when the system defaults are not appropriate.',
            style: TextStyle(
              color:
                  AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 16),

          _RopOverridesSection(
            defaultLeadTimeDays:
                _defaultLeadTimeDays,
            defaultSafetyStockQty:
                _defaultSafetyStockQty,
          ),

          const SizedBox(height: 40),

          // ===================================================================
          // CATEGORY MANAGEMENT
          // ===================================================================

          const Text(
            'Category Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Expand a category to rename it, set its expiry requirement, and '
            'manage its subcategories.',
            style: TextStyle(
              color:
                  AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 20),

          const _CategoryManagementSection(),

          const SizedBox(height: 40),

          // ===================================================================
          // UNIT MANAGEMENT
          // ===================================================================

          const Text(
            'Unit Management',
            style: TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add, rename, or delete the purchase/package/dispense units used '
            'when stocking in items.',
            style: TextStyle(
              color:
                  AppColors.mutedForeground,
            ),
          ),
          const SizedBox(height: 20),

          const _UnitManagementSection(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// =============================================================================
// ITEM-SPECIFIC ROP OVERRIDES
// =============================================================================

class _RopOverridesSection extends StatefulWidget {
  final int defaultLeadTimeDays;
  final double defaultSafetyStockQty;

  const _RopOverridesSection({
    required this.defaultLeadTimeDays,
    required this.defaultSafetyStockQty,
  });

  @override
  State<_RopOverridesSection> createState() =>
      _RopOverridesSectionState();
}

class _RopOverridesSectionState extends State<_RopOverridesSection> {
  static const int _previewLimit = 5;

  final InventoryService _inventoryService = InventoryService();
  final RopService _ropService = RopService();

  bool _loading = true;
  String? _error;

  List<InventoryItem> _items = [];
  final Map<String, ItemRopSettings> _overrides = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  // ===========================================================================
  // LOAD ITEMS + OVERRIDES
  // ===========================================================================

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _inventoryService.fetchItems(),
        _ropService.fetchOverrides(),
      ]);

      final items = results[0] as List<InventoryItem>;
      final overrides = results[1] as List<ItemRopSettings>;

      items.sort(
        (a, b) => a.itemName.toLowerCase().compareTo(
              b.itemName.toLowerCase(),
            ),
      );

      if (!mounted) return;

      setState(() {
        _items = items;
        _overrides
          ..clear()
          ..addEntries(
            overrides.map(
              (ropOverride) => MapEntry(
                ropOverride.itemId,
                ropOverride,
              ),
            ),
          );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load ROP settings: $e';
        _loading = false;
      });
    }
  }

  // ===========================================================================
  // COMPACT PREVIEW
  // ===========================================================================
  //
  // Keep the Settings page short. Show only five items here, prioritizing
  // items that already have custom ROP overrides. The full list lives in the
  // searchable/filterable modal opened by See All.
  // ===========================================================================

  List<InventoryItem> get _previewItems {
    final items = [..._items];

    items.sort((a, b) {
      final aCustom = _overrides.containsKey(a.itemId);
      final bCustom = _overrides.containsKey(b.itemId);

      if (aCustom != bCustom) {
        return aCustom ? -1 : 1;
      }

      return a.itemName.toLowerCase().compareTo(
            b.itemName.toLowerCase(),
          );
    });

    return items.take(_previewLimit).toList();
  }

  // ===========================================================================
  // EDIT / CREATE OVERRIDE
  // ===========================================================================

  Future<void> _editOverride(InventoryItem item) async {
    final existing = _overrides[item.itemId];

    final result = await showDialog<(int, double)>(
      context: context,
      builder: (dialogContext) => _RopOverrideDialog(
        item: item,
        existing: existing,
        defaultLeadTimeDays: widget.defaultLeadTimeDays,
        defaultSafetyStockQty: widget.defaultSafetyStockQty,
      ),
    );

    if (result == null) return;

    try {
      final saved = await _ropService.saveOverride(
        itemId: item.itemId,
        leadTimeDays: result.$1,
        safetyStockQty: result.$2,
      );

      if (!mounted) return;

      setState(() {
        _overrides[item.itemId] = saved;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ROP settings saved for ${item.itemName}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await _showErrorDialog(
        context,
        title: 'Could not save ROP settings',
        error: e,
      );
    }
  }

  // ===========================================================================
  // RESET OVERRIDE
  // ===========================================================================

  Future<void> _resetOverride(InventoryItem item) async {
    final existing = _overrides[item.itemId];
    if (existing == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Reset to defaults?'),
        content: Text(
          '${item.itemName} will stop using its custom ROP settings and '
          'will use the system defaults instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _ropService.deleteOverride(item.itemId);

      if (!mounted) return;

      setState(() {
        _overrides.remove(item.itemId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${item.itemName} now uses the system ROP defaults.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await _showErrorDialog(
        context,
        title: 'Could not reset ROP settings',
        error: e,
      );
    }
  }

  // ===========================================================================
  // OPEN FULL ROP MANAGER
  // ===========================================================================

  Future<void> _openAllItems() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _RopOverridesDialog(
        items: _items,
        overrides: _overrides,
        defaultLeadTimeDays: widget.defaultLeadTimeDays,
        defaultSafetyStockQty: widget.defaultSafetyStockQty,
        onEdit: _editOverride,
        onReset: _resetOverride,
      ),
    );
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: AppColors.destructive),
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

    final previewItems = _previewItems;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===================================================================
          // COMPACT HEADER
          // ===================================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;

                final summary = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quick View',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_items.length} item${_items.length == 1 ? '' : 's'} • '
                      '${_overrides.length} custom override${_overrides.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                );

                final action = OutlinedButton.icon(
                  onPressed: _items.isEmpty ? null : _openAllItems,
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: Text(
                    _items.length > _previewLimit
                        ? 'See All (${_items.length})'
                        : 'Manage Items',
                  ),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      summary,
                      const SizedBox(height: 10),
                      action,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: summary),
                    const SizedBox(width: 16),
                    action,
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // ===================================================================
          // FIVE-ITEM PREVIEW
          // ===================================================================

          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(
                vertical: 36,
                horizontal: 20,
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 32,
                      color: AppColors.mutedForeground,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No inventory items available.',
                      style: TextStyle(
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: [
                for (var i = 0; i < previewItems.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _RopItemRow(
                    item: previewItems[i],
                    ropOverride: _overrides[previewItems[i].itemId],
                    defaultLeadTimeDays: widget.defaultLeadTimeDays,
                    defaultSafetyStockQty: widget.defaultSafetyStockQty,
                    onEdit: () => _editOverride(previewItems[i]),
                    onReset: () => _resetOverride(previewItems[i]),
                  ),
                ],
              ],
            ),

          if (_items.length > _previewLimit) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 11,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Showing $_previewLimit of ${_items.length} items. '
                      'Open the full list to search or filter.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _openAllItems,
                    child: const Text('See All'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// FULL ROP OVERRIDES MODAL
// =============================================================================

enum _RopListFilter {
  all,
  custom,
  defaults,
}

class _RopOverridesDialog extends StatefulWidget {
  final List<InventoryItem> items;
  final Map<String, ItemRopSettings> overrides;
  final int defaultLeadTimeDays;
  final double defaultSafetyStockQty;
  final Future<void> Function(InventoryItem item) onEdit;
  final Future<void> Function(InventoryItem item) onReset;

  const _RopOverridesDialog({
    required this.items,
    required this.overrides,
    required this.defaultLeadTimeDays,
    required this.defaultSafetyStockQty,
    required this.onEdit,
    required this.onReset,
  });

  @override
  State<_RopOverridesDialog> createState() => _RopOverridesDialogState();
}

class _RopOverridesDialogState extends State<_RopOverridesDialog> {
  final _searchCtrl = TextEditingController();

  String _search = '';
  _RopListFilter _filter = _RopListFilter.all;

  // Stronger neutral colors are used only inside this modal so the existing
  // Settings page design remains unchanged.
  static const Color _modalWhite = Colors.white;
  static const Color _surfaceSoft = Color(0xFFF8FAFC);
  static const Color _surfaceMuted = Color(0xFFF1F5F9);
  static const Color _textStrong = Color(0xFF0F172A);
  static const Color _textMuted = Color(0xFF475569);
  static const Color _borderStrong = Color(0xFFCBD5E1);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ===========================================================================
  // SEARCH RESET
  // ===========================================================================
  //
  // Keeps the search controller and the backing state synchronized.
  //
  // After an Edit/Reset action, the modal returns to the complete item list so
  // the manager does not remain trapped in the previous search result.
  // ===========================================================================

  void _clearSearch({bool resetFilter = false}) {
    _searchCtrl.clear();

    setState(() {
      _search = '';

      if (resetFilter) {
        _filter = _RopListFilter.all;
      }
    });
  }

  List<InventoryItem> get _filteredItems {
    final query = _search.trim().toLowerCase();

    final items = widget.items.where((item) {
      final hasOverride = widget.overrides.containsKey(item.itemId);

      final matchesFilter = switch (_filter) {
        _RopListFilter.all => true,
        _RopListFilter.custom => hasOverride,
        _RopListFilter.defaults => !hasOverride,
      };

      if (!matchesFilter) return false;
      if (query.isEmpty) return true;

      return item.itemName.toLowerCase().contains(query) ||
          item.itemCategory.toLowerCase().contains(query) ||
          item.purchaseUnitAbbr.toLowerCase().contains(query);
    }).toList();

    items.sort((a, b) {
      final aCustom = widget.overrides.containsKey(a.itemId);
      final bCustom = widget.overrides.containsKey(b.itemId);

      if (_filter == _RopListFilter.all && aCustom != bCustom) {
        return aCustom ? -1 : 1;
      }

      return a.itemName.toLowerCase().compareTo(
            b.itemName.toLowerCase(),
          );
    });

    return items;
  }

  Future<void> _edit(InventoryItem item) async {
    await widget.onEdit(item);

    if (!mounted) return;

    // Return to the complete list after editing an item that may have been
    // reached through search or a filter.
    _clearSearch(resetFilter: true);
  }

  Future<void> _reset(InventoryItem item) async {
    await widget.onReset(item);

    if (!mounted) return;

    // Same behavior as Edit: restore the full list after the action finishes.
    _clearSearch(resetFilter: true);
  }

  Widget _filterChip({
    required String label,
    required _RopListFilter value,
  }) {
    final selected = _filter == value;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.primary,
      backgroundColor: _modalWhite,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: selected ? AppColors.primary : _borderStrong,
        width: selected ? 1.4 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        color: selected ? Colors.white : _textMuted,
      ),
      onSelected: (_) => setState(() {
        _filter = value;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = screenHeight < 850 ? screenHeight * 0.86 : 720.0;
    final filteredItems = _filteredItems;

    return Dialog(
      backgroundColor: _modalWhite,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 20,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(
          color: _borderStrong,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 800,
        height: dialogHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // =================================================================
            // HEADER
            // =================================================================

            Container(
              width: double.infinity,
              color: AppColors.primary,
              padding: const EdgeInsets.fromLTRB(22, 18, 12, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Item ROP Overrides',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${widget.items.length} item${widget.items.length == 1 ? '' : 's'} • '
                          '${widget.overrides.length} custom override${widget.overrides.length == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // =================================================================
            // SEARCH + FILTERS
            // =================================================================

            Container(
              width: double.infinity,
              color: _surfaceSoft,
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 620;

                  final search = TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _textStrong,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: true,
                      fillColor: _modalWhite,
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 19,
                        color: _textMuted,
                      ),

                      // CLEAR SEARCH BUTTON:
                      // Only appears while text is actively filtering the list.
                      suffixIcon: _search.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: _clearSearch,
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: _textMuted,
                              ),
                            ),

                      hintText: 'Search item, category, or unit',
                      hintStyle: const TextStyle(
                        color: _textMuted,
                        fontSize: 13.5,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _borderStrong,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _borderStrong,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.6,
                        ),
                      ),
                    ),
                    onChanged: (value) => setState(() {
                      _search = value;
                    }),
                  );

                  final filters = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterChip(
                        label: 'All',
                        value: _RopListFilter.all,
                      ),
                      _filterChip(
                        label: 'Custom (${widget.overrides.length})',
                        value: _RopListFilter.custom,
                      ),
                      _filterChip(
                        label:
                            'Default (${widget.items.length - widget.overrides.length})',
                        value: _RopListFilter.defaults,
                      ),
                    ],
                  );

                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        search,
                        const SizedBox(height: 12),
                        filters,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: search),
                      const SizedBox(width: 16),
                      filters,
                    ],
                  );
                },
              ),
            ),

            const Divider(
              height: 1,
              color: _borderStrong,
            ),

            // =================================================================
            // FULL ITEM LIST
            // =================================================================

            Expanded(
              child: Container(
                color: _modalWhite,
                child: filteredItems.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 420),
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: _surfaceSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _borderStrong,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: _surfaceMuted,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.search_off,
                                    size: 25,
                                    color: _textMuted,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No matching items',
                                  style: TextStyle(
                                    color: _textStrong,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Try another search term or clear the active filter.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _textMuted,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                                if (_search.isNotEmpty ||
                                    _filter != _RopListFilter.all) ...[
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: () =>
                                        _clearSearch(resetFilter: true),
                                    icon: const Icon(
                                      Icons.filter_alt_off_outlined,
                                      size: 17,
                                    ),
                                    label: const Text('Clear Filters'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const Divider(
                          height: 1,
                          color: Color(0xFFE2E8F0),
                        ),
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];
                          final hasOverride =
                              widget.overrides.containsKey(item.itemId);

                          return Container(
                            decoration: BoxDecoration(
                              color: hasOverride
                                  ? AppColors.primary.withValues(alpha: 0.035)
                                  : _modalWhite,
                              border: Border(
                                left: BorderSide(
                                  color: hasOverride
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: _RopItemRow(
                              item: item,
                              ropOverride: widget.overrides[item.itemId],
                              defaultLeadTimeDays:
                                  widget.defaultLeadTimeDays,
                              defaultSafetyStockQty:
                                  widget.defaultSafetyStockQty,
                              onEdit: () => _edit(item),
                              onReset: () => _reset(item),
                            ),
                          );
                        },
                      ),
              ),
            ),

            const Divider(
              height: 1,
              color: _borderStrong,
            ),

            // =================================================================
            // FOOTER
            // =================================================================

            Container(
              color: _surfaceSoft,
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceMuted,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: _borderStrong,
                      ),
                    ),
                    child: Text(
                      'Showing ${filteredItems.length} of ${widget.items.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// ROP ITEM ROW
// =============================================================================

class _RopItemRow
    extends StatelessWidget {
  final InventoryItem item;
  final ItemRopSettings? ropOverride;

  final int defaultLeadTimeDays;
  final double defaultSafetyStockQty;

  final VoidCallback onEdit;
  final VoidCallback onReset;

  const _RopItemRow({
    required this.item,
    required this.ropOverride,
    required this.defaultLeadTimeDays,
    required this.defaultSafetyStockQty,
    required this.onEdit,
    required this.onReset,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final hasOverride =
        ropOverride != null;

    final leadTime =
        ropOverride?.leadTimeDays ??
            defaultLeadTimeDays;

    final safetyStock =
        ropOverride?.safetyStockQty ??
            defaultSafetyStockQty;

    final dayLabel =
        leadTime == 1
            ? 'day'
            : 'days';

    final unit =
        item.purchaseUnitAbbr
                .trim()
                .isEmpty
            ? 'purchase units'
            : item.purchaseUnitAbbr;

    Widget statusBadge() =>
        Container(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 9,
            vertical: 4,
          ),
          decoration:
              BoxDecoration(
            color: hasOverride
                ? AppColors.primary
                    .withValues(
                    alpha: 0.10,
                  )
                : AppColors.secondary,
            borderRadius:
                BorderRadius.circular(
              999,
            ),
          ),
          child: Text(
            hasOverride
                ? 'Custom'
                : 'Default',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight:
                  FontWeight.w600,
              color: hasOverride
                  ? AppColors.primary
                  : AppColors
                      .mutedForeground,
            ),
          ),
        );

    final details =
        '$leadTime $dayLabel lead time • '
        '${formatQty(safetyStock)} $unit safety stock';

    return LayoutBuilder(
      builder:
          (
        context,
        constraints,
      ) {
        final narrow =
            constraints.maxWidth <
                620;

        final information =
            Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    item.itemName,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight
                              .w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                statusBadge(),
              ],
            ),
            const SizedBox(
              height: 4,
            ),
            Text(
              item.itemCategory,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 12,
                color: AppColors
                    .mutedForeground,
              ),
            ),
            const SizedBox(
              height: 5,
            ),
            Text(
              details,
              style:
                  const TextStyle(
                fontSize: 12.5,
              ),
            ),
          ],
        );

        final actions =
            Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: Icon(
                hasOverride
                    ? Icons
                        .edit_outlined
                    : Icons
                        .add_outlined,
                size: 16,
              ),
              label: Text(
                hasOverride
                    ? 'Edit'
                    : 'Add Override',
              ),
            ),
            if (hasOverride)
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(
                  Icons
                      .settings_backup_restore,
                  size: 16,
                ),
                label:
                    const Text(
                  'Reset',
                ),
              ),
          ],
        );

        if (narrow) {
          return Padding(
            padding:
                const EdgeInsets
                    .all(16),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                information,
                const SizedBox(
                  height: 12,
                ),
                actions,
              ],
            ),
          );
        }

        return Padding(
          padding:
              const EdgeInsets
                  .symmetric(
            horizontal: 18,
            vertical: 14,
          ),
          child: Row(
            children: [
              Expanded(
                child:
                    information,
              ),
              const SizedBox(
                width: 20,
              ),
              actions,
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// ROP OVERRIDE DIALOG
// =============================================================================

class _RopOverrideDialog
    extends StatefulWidget {
  final InventoryItem item;
  final ItemRopSettings? existing;

  final int defaultLeadTimeDays;
  final double defaultSafetyStockQty;

  const _RopOverrideDialog({
    required this.item,
    required this.existing,
    required this.defaultLeadTimeDays,
    required this.defaultSafetyStockQty,
  });

  @override
  State<_RopOverrideDialog>
      createState() =>
          _RopOverrideDialogState();
}

class _RopOverrideDialogState
    extends State<_RopOverrideDialog> {
  final _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _leadTimeCtrl;

  late final TextEditingController
      _safetyStockCtrl;

  @override
  void initState() {
    super.initState();

    _leadTimeCtrl =
        TextEditingController(
      text:
          (widget.existing
                      ?.leadTimeDays ??
                  widget
                      .defaultLeadTimeDays)
              .toString(),
    );

    _safetyStockCtrl =
        TextEditingController(
      text: formatQty(
        widget.existing
                ?.safetyStockQty ??
            widget
                .defaultSafetyStockQty,
      ),
    );
  }

  @override
  void dispose() {
    _leadTimeCtrl.dispose();
    _safetyStockCtrl.dispose();
    super.dispose();
  }

  String? _validateLeadTime(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Required';
    }

    final parsed =
        int.tryParse(
      value.trim(),
    );

    if (parsed == null) {
      return 'Enter a whole number';
    }

    if (parsed < 0) {
      return 'Cannot be negative';
    }

    return null;
  }

  String? _validateSafetyStock(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Required';
    }

    final parsed =
        double.tryParse(
      value.trim(),
    );

    if (parsed == null) {
      return 'Enter a number';
    }

    if (!parsed.isFinite) {
      return 'Enter a valid number';
    }

    if (parsed < 0) {
      return 'Cannot be negative';
    }

    return null;
  }

  void _submit() {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final leadTime =
        int.parse(
      _leadTimeCtrl.text.trim(),
    );

    final safetyStock =
        double.parse(
      _safetyStockCtrl.text.trim(),
    );

    Navigator.of(context).pop(
      (
        leadTime,
        safetyStock,
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final unit =
        widget.item.purchaseUnitAbbr
                .trim()
                .isEmpty
            ? 'purchase units'
            : widget
                .item
                .purchaseUnitAbbr;

    final editing =
        widget.existing != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      title: Text(
        editing
            ? 'Edit ROP Override'
            : 'Add ROP Override',
      ),
      content: SizedBox(
        width: 430,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                widget.item.itemName,
                style:
                    const TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.item.itemCategory,
                style:
                    const TextStyle(
                  fontSize: 12.5,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
              const SizedBox(height: 18),

              TextFormField(
                controller:
                    _leadTimeCtrl,
                autofocus: true,
                keyboardType:
                    TextInputType.number,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Lead time',
                  suffixText:
                      'days',
                  helperText:
                      'Expected replenishment lead time for this item.',
                ),
                validator:
                    _validateLeadTime,
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller:
                    _safetyStockCtrl,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
                decoration:
                    InputDecoration(
                  labelText:
                      'Safety stock',
                  suffixText: unit,
                  helperText:
                      'Extra buffer kept above expected lead-time demand.',
                ),
                validator:
                    _validateSafetyStock,
                onFieldSubmitted:
                    (_) => _submit(),
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets
                        .all(12),
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.secondary,
                  borderRadius:
                      BorderRadius
                          .circular(12),
                ),
                child: Text(
                  editing
                      ? 'This item currently uses custom ROP settings.'
                      : 'System default: ${widget.defaultLeadTimeDays} '
                          '${widget.defaultLeadTimeDays == 1 ? 'day' : 'days'} '
                          'lead time and ${formatQty(widget.defaultSafetyStockQty)} '
                          '$unit safety stock.',
                  style:
                      const TextStyle(
                    fontSize: 12.5,
                    color: AppColors
                        .mutedForeground,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop(),
          child:
              const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(
            editing
                ? 'Save Changes'
                : 'Add Override',
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// CATEGORY MANAGEMENT
// =============================================================================

/// Manager-configurable expiry-date requirement per primary category and,
/// optionally, per subcategory.
///
/// Accordion layout: one collapsible card per primary category.
class _CategoryManagementSection
    extends StatefulWidget {
  const _CategoryManagementSection();

  @override
  State<_CategoryManagementSection>
      createState() =>
          _CategoryManagementSectionState();
}

class _CategoryManagementSectionState
    extends State<
        _CategoryManagementSection> {
  final CatalogService
      _catalogService =
      CatalogService();

  bool _loading = true;
  bool _savingChanges = false;
  String? _error;

  List<PrimaryCategory>
      _primaryCategories = [];

  List<Subcategory>
      _subcategories = [];

  final Map<String, bool>
      _pendingPrimary = {};

  final Map<String, bool?>
      _pendingSub = {};

  int get _pendingCount =>
      _pendingPrimary.length +
      _pendingSub.length;

  bool get _hasPendingChanges =>
      _pendingCount > 0;

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
      final results =
          await Future.wait([
        _catalogService
            .fetchPrimaryCategories(),
        _catalogService
            .fetchSubcategories(),
      ]);

      if (!mounted) return;

      setState(() {
        _primaryCategories =
            results[0]
                as List<
                    PrimaryCategory>;

        _subcategories =
            results[1]
                as List<Subcategory>;

        _pendingPrimary.clear();
        _pendingSub.clear();

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not load categories: $e';
        _loading = false;
      });
    }
  }

  Future<void> _refetch() async {
    final results =
        await Future.wait([
      _catalogService
          .fetchPrimaryCategories(),
      _catalogService
          .fetchSubcategories(),
    ]);

    if (!mounted) return;

    setState(() {
      _primaryCategories =
          results[0]
              as List<PrimaryCategory>;

      _subcategories =
          results[1]
              as List<Subcategory>;

      _pendingPrimary.removeWhere(
        (id, _) =>
            !_primaryCategories.any(
          (c) => c.id == id,
        ),
      );

      _pendingSub.removeWhere(
        (id, _) =>
            !_subcategories.any(
          (s) => s.id == id,
        ),
      );
    });
  }

  Future<void>
      _addPrimaryCategory() async {
    await _promptForName(
      context: context,
      title: 'Add Category',
      label: 'Category name',
      onSubmit: (name) =>
          _catalogService
              .createPrimaryCategory(
        name,
      ),
    );

    await _refetch();
  }

  Future<void> _addSubcategory(
    PrimaryCategory parent,
  ) async {
    await _promptForName(
      context: context,
      title:
          'Add Subcategory to ${parent.type}',
      label: 'Subcategory name',
      onSubmit: (name) =>
          _catalogService
              .createSubcategory(
        pCategoryId: parent.id,
        type: name,
      ),
    );

    await _refetch();
  }

  Future<void>
      _renamePrimaryCategory(
    PrimaryCategory category,
    String newName,
  ) async {
    await _catalogService
        .renamePrimaryCategory(
      id: category.id,
      type: newName,
    );

    await _refetch();
  }

  Future<void> _renameSubcategory(
    Subcategory sub,
    String newName,
  ) async {
    await _catalogService
        .renameSubcategory(
      id: sub.id,
      type: newName,
    );

    await _refetch();
  }

  Future<void>
      _deletePrimaryCategory(
    PrimaryCategory category,
  ) async {
    final confirmed =
        await _confirmDelete(
      context: context,
      title: 'Delete category?',
      message:
          'This will permanently delete "${category.type}" and its expiry setting. '
          'Any subcategories or items must be reassigned or removed first.',
    );

    if (!confirmed) return;

    try {
      await _catalogService
          .deletePrimaryCategory(
        category.id,
      );

      await _refetch();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '"${category.type}" deleted.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await _showErrorDialog(
        context,
        title:
            'Could not delete "${category.type}"',
        error: e,
      );
    }
  }

  Future<void> _deleteSubcategory(
    Subcategory sub,
  ) async {
    final confirmed =
        await _confirmDelete(
      context: context,
      title:
          'Delete subcategory?',
      message:
          'This will permanently delete "${sub.type}". Any items under it must be '
          'reassigned or removed first.',
    );

    if (!confirmed) return;

    try {
      await _catalogService
          .deleteSubcategory(
        sub.id,
      );

      await _refetch();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '"${sub.type}" deleted.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await _showErrorDialog(
        context,
        title:
            'Could not delete "${sub.type}"',
        error: e,
      );
    }
  }

  bool _effectivePrimary(
    PrimaryCategory c,
  ) =>
      _pendingPrimary[c.id] ??
      c.requiresExpiry;

  bool? _effectiveSub(
    Subcategory s,
  ) =>
      _pendingSub.containsKey(s.id)
          ? _pendingSub[s.id]
          : s.requiresExpiry;

  bool _resolvedSub(
    Subcategory s,
  ) {
    final raw =
        _effectiveSub(s);

    if (raw != null) {
      return raw;
    }

    final parent =
        _primaryCategories
            .firstWhere(
      (c) =>
          c.id ==
          s.pCategoryId,
    );

    return _effectivePrimary(
      parent,
    );
  }

  bool _isSubOverridden(
    Subcategory s,
  ) =>
      _effectiveSub(s) != null;

  void _stagePrimary(
    PrimaryCategory category,
    bool value,
  ) {
    setState(() {
      if (value ==
          category.requiresExpiry) {
        _pendingPrimary.remove(
          category.id,
        );
      } else {
        _pendingPrimary[
            category.id] = value;
      }
    });
  }

  void _stageSub(
    Subcategory sub,
    bool? value,
  ) {
    setState(() {
      if (value ==
          sub.requiresExpiry) {
        _pendingSub.remove(
          sub.id,
        );
      } else {
        _pendingSub[sub.id] =
            value;
      }
    });
  }

  void _discardChanges() {
    setState(() {
      _pendingPrimary.clear();
      _pendingSub.clear();
    });
  }

  String _label(
    bool? value,
  ) =>
      value == null
          ? 'Inherit'
          : value
              ? 'Required'
              : 'Not required';

  Future<void>
      _reviewAndSave() async {
    final primaryById = {
      for (final c
          in _primaryCategories)
        c.id: c,
    };

    final subById = {
      for (final s
          in _subcategories)
        s.id: s,
    };

    final changeLines = [
      for (final entry
          in _pendingPrimary.entries)
        '${primaryById[entry.key]!.type}: '
            '${_label(primaryById[entry.key]!.requiresExpiry)} → '
            '${_label(entry.value)}',
      for (final entry
          in _pendingSub.entries)
        '${primaryById[subById[entry.key]!.pCategoryId]?.type ?? 'Unknown'} '
            '> ${subById[entry.key]!.type}: '
            '${_label(subById[entry.key]!.requiresExpiry)} → '
            '${_label(entry.value)}',
    ];

    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) =>
          AlertDialog(
        title: const Text(
          'Confirm expiry-requirement changes',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                'This changes whether Stock In requires an expiry date for '
                '$_pendingCount categor${_pendingCount == 1 ? 'y' : 'ies'} below. '
                'It applies to every stock-in staff record from now on.',
                style:
                    const TextStyle(
                  color: AppColors
                      .mutedForeground,
                  fontSize: 13,
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxHeight: 260,
                ),
                child:
                    SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      for (final line
                          in changeLines)
                        Padding(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 4,
                          ),
                          child: Text(
                            line,
                            style:
                                const TextStyle(
                              fontSize:
                                  13.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(
              dialogContext,
            ).pop(false),
            child:
                const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(
              dialogContext,
            ).pop(true),
            child:
                const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(
      () => _savingChanges = true,
    );

    final errors =
        <String>[];

    for (final entry
        in _pendingPrimary.entries) {
      try {
        await _catalogService
            .setPrimaryCategoryRequiresExpiry(
          id: entry.key,
          requiresExpiry:
              entry.value,
        );
      } catch (e) {
        errors.add(
          '${primaryById[entry.key]?.type ?? entry.key}: $e',
        );
      }
    }

    for (final entry
        in _pendingSub.entries) {
      try {
        await _catalogService
            .setSubcategoryRequiresExpiry(
          id: entry.key,
          requiresExpiry:
              entry.value,
        );
      } catch (e) {
        errors.add(
          '${subById[entry.key]?.type ?? entry.key}: $e',
        );
      }
    }

    await _load();

    if (!mounted) return;

    setState(
      () => _savingChanges = false,
    );

    if (errors.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Category changes saved.',
          ),
        ),
      );
    } else {
      await _showErrorDialog(
        context,
        title:
            'Some changes could not be saved',
        error:
            '${errors.length} of $_pendingCount change(s) failed:',
        details: errors,
      );
    }
  }

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
      return Text(
        _error!,
        style: const TextStyle(
          color:
              AppColors.destructive,
        ),
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        if (_hasPendingChanges) ...[
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration:
                BoxDecoration(
              color:
                  AppColors.secondary,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              border: Border.all(
                color: AppColors.primary
                    .withValues(
                  alpha: 0.4,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_note,
                  size: 20,
                  color:
                      AppColors.primary,
                ),
                const SizedBox(
                  width: 8,
                ),
                Expanded(
                  child: Text(
                    '$_pendingCount unsaved change${_pendingCount == 1 ? '' : 's'} -- '
                    'review before this affects Stock In.',
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight
                              .w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      _savingChanges
                          ? null
                          : _discardChanges,
                  child: const Text(
                    'Discard',
                  ),
                ),
                const SizedBox(
                  width: 8,
                ),
                ElevatedButton(
                  onPressed:
                      _savingChanges
                          ? null
                          : _reviewAndSave,
                  child: _savingChanges
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                          ),
                        )
                      : const Text(
                          'Review',
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 16,
          ),
        ],

        Align(
          alignment:
              Alignment.centerRight,
          child:
              OutlinedButton.icon(
            onPressed:
                _savingChanges
                    ? null
                    : _addPrimaryCategory,
            icon: const Icon(
              Icons.add,
              size: 18,
            ),
            label:
                const Text(
              'Add Category',
            ),
          ),
        ),

        const SizedBox(height: 12),

        for (final category
            in _primaryCategories)
          Padding(
            key: ValueKey(
              category.id,
            ),
            padding:
                const EdgeInsets
                    .only(
              bottom: 12,
            ),
            child:
                _PrimaryCategoryCard(
              category: category,
              effectiveRequiresExpiry:
                  _effectivePrimary(
                category,
              ),
              isDirty:
                  _pendingPrimary
                      .containsKey(
                category.id,
              ),
              subcategories:
                  _subcategories
                      .where(
                        (s) =>
                            s.pCategoryId ==
                            category.id,
                      )
                      .toList(),
              effectiveSubValue:
                  _resolvedSub,
              isSubDirty: (s) =>
                  _pendingSub
                      .containsKey(
                s.id,
              ),
              isSubOverridden:
                  _isSubOverridden,
              onPrimaryChanged:
                  (v) =>
                      _stagePrimary(
                category,
                v,
              ),
              onSubChanged:
                  _stageSub,
              onResetSub: (s) =>
                  _stageSub(
                s,
                null,
              ),
              onRenamePrimary:
                  (name) =>
                      _renamePrimaryCategory(
                category,
                name,
              ),
              onDeletePrimary:
                  () =>
                      _deletePrimaryCategory(
                category,
              ),
              onAddSubcategory:
                  () =>
                      _addSubcategory(
                category,
              ),
              onRenameSub:
                  _renameSubcategory,
              onDeleteSub:
                  _deleteSubcategory,
            ),
          ),
      ],
    );
  }
}

// =============================================================================
// PRIMARY CATEGORY CARD
// =============================================================================

const int
    _kSubcategoryFilterThreshold =
    6;

class _PrimaryCategoryCard
    extends StatefulWidget {
  final PrimaryCategory category;
  final bool effectiveRequiresExpiry;
  final bool isDirty;

  final List<Subcategory>
      subcategories;

  final bool Function(
    Subcategory sub,
  ) effectiveSubValue;

  final bool Function(
    Subcategory sub,
  ) isSubDirty;

  final bool Function(
    Subcategory sub,
  ) isSubOverridden;

  final ValueChanged<bool>
      onPrimaryChanged;

  final void Function(
    Subcategory sub,
    bool? value,
  ) onSubChanged;

  final void Function(
    Subcategory sub,
  ) onResetSub;

  final Future<void> Function(
    String newName,
  ) onRenamePrimary;

  final VoidCallback
      onDeletePrimary;

  final VoidCallback
      onAddSubcategory;

  final Future<void> Function(
    Subcategory sub,
    String newName,
  ) onRenameSub;

  final void Function(
    Subcategory sub,
  ) onDeleteSub;

  const _PrimaryCategoryCard({
    required this.category,
    required this
        .effectiveRequiresExpiry,
    required this.isDirty,
    required this.subcategories,
    required this
        .effectiveSubValue,
    required this.isSubDirty,
    required this
        .isSubOverridden,
    required this
        .onPrimaryChanged,
    required this.onSubChanged,
    required this.onResetSub,
    required this
        .onRenamePrimary,
    required this
        .onDeletePrimary,
    required this
        .onAddSubcategory,
    required this.onRenameSub,
    required this.onDeleteSub,
  });

  @override
  State<_PrimaryCategoryCard>
      createState() =>
          _PrimaryCategoryCardState();
}

class _PrimaryCategoryCardState
    extends State<
        _PrimaryCategoryCard> {
  final _filterCtrl =
      TextEditingController();

  String _filter = '';

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  static Widget _dirtyDot() =>
      Container(
        width: 8,
        height: 8,
        margin:
            const EdgeInsets.only(
          right: 8,
        ),
        decoration:
            const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      );

  @override
  Widget build(
    BuildContext context,
  ) {
    final visibleSubs =
        _filter.isEmpty
            ? widget.subcategories
            : widget
                .subcategories
                .where(
                  (s) => s.type
                      .toLowerCase()
                      .contains(
                        _filter
                            .toLowerCase(),
                      ),
                )
                .toList();

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior:
          Clip.antiAlias,
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isDirty
              ? AppColors.primary
              : AppColors.border,
          width:
              widget.isDirty
                  ? 1.5
                  : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context)
            .copyWith(
          dividerColor:
              Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.only(
            left: 16,
            right: 8,
          ),
          title: Row(
            children: [
              if (widget.isDirty)
                _dirtyDot(),
              Expanded(
                child:
                    _EditableLabel(
                  value: widget
                      .category.type,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight
                            .w700,
                    fontSize: 15,
                  ),
                  onSave: widget
                      .onRenamePrimary,
                ),
              ),
              if (widget
                  .subcategories
                  .isNotEmpty)
                Padding(
                  padding:
                      const EdgeInsets
                          .only(
                    left: 8,
                  ),
                  child: Text(
                    '${widget.subcategories.length} sub'
                    '${widget.subcategories.length == 1 ? '' : 's'}',
                    style:
                        const TextStyle(
                      fontSize: 12,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(
                  Icons
                      .delete_outline,
                  size: 20,
                ),
                tooltip:
                    'Delete category',
                onPressed: widget
                    .onDeletePrimary,
              ),
            ],
          ),
          children: [
            SwitchListTile(
              title: const Text(
                'Requires expiry date',
                style: TextStyle(
                  fontSize: 13.5,
                ),
              ),
              subtitle:
                  const Text(
                'Applies to items filed directly under this category.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
              value: widget
                  .effectiveRequiresExpiry,
              onChanged: widget
                  .onPrimaryChanged,
              dense: true,
            ),

            if (widget
                    .subcategories
                    .length >
                _kSubcategoryFilterThreshold)
              Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  16,
                  0,
                  16,
                  8,
                ),
                child: TextField(
                  controller:
                      _filterCtrl,
                  decoration:
                      const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                    ),
                    hintText:
                        'Filter subcategories',
                  ),
                  onChanged: (v) =>
                      setState(
                    () => _filter = v,
                  ),
                ),
              ),

            for (final sub
                in visibleSubs)
              ListTile(
                key:
                    ValueKey(sub.id),
                contentPadding:
                    const EdgeInsets
                        .only(
                  left: 32,
                  right: 8,
                ),
                title: Row(
                  children: [
                    if (widget
                        .isSubDirty(
                      sub,
                    ))
                      _dirtyDot(),
                    Flexible(
                      child:
                          _EditableLabel(
                        value:
                            sub.type,
                        style:
                            const TextStyle(
                          fontSize:
                              13.5,
                        ),
                        onSave:
                            (name) =>
                                widget
                                    .onRenameSub(
                          sub,
                          name,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    if (widget
                        .isSubOverridden(
                      sub,
                    ))
                      IconButton(
                        icon:
                            const Icon(
                          Icons
                              .settings_backup_restore,
                          size: 18,
                        ),
                        tooltip:
                            'Reset to category default',
                        onPressed:
                            () => widget
                                .onResetSub(
                          sub,
                        ),
                      ),

                    SegmentedButton<
                        bool>(
                      style:
                          SegmentedButton
                              .styleFrom(
                        visualDensity:
                            VisualDensity
                                .compact,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal:
                              8,
                        ),
                      ),
                      segments:
                          const [
                        ButtonSegment(
                          value: true,
                          label: Text(
                            'Required',
                          ),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text(
                            'Not required',
                          ),
                        ),
                      ],
                      selected: {
                        widget
                            .effectiveSubValue(
                          sub,
                        ),
                      },
                      showSelectedIcon:
                          false,
                      onSelectionChanged:
                          (selection) =>
                              widget
                                  .onSubChanged(
                        sub,
                        selection.first,
                      ),
                    ),

                    IconButton(
                      icon:
                          const Icon(
                        Icons
                            .delete_outline,
                        size: 18,
                      ),
                      tooltip:
                          'Delete subcategory',
                      onPressed:
                          () => widget
                              .onDeleteSub(
                        sub,
                      ),
                    ),
                  ],
                ),
              ),

            if (visibleSubs.isEmpty &&
                widget
                    .subcategories
                    .isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  32,
                  0,
                  16,
                  12,
                ),
                child: Text(
                  'No subcategories match "$_filter".',
                  style:
                      const TextStyle(
                    color: AppColors
                        .mutedForeground,
                    fontSize: 13,
                  ),
                ),
              ),

            if (widget
                .subcategories
                .isEmpty)
              const Padding(
                padding:
                    EdgeInsets
                        .fromLTRB(
                  32,
                  0,
                  16,
                  12,
                ),
                child: Text(
                  'No subcategories yet.',
                  style:
                      TextStyle(
                    color: AppColors
                        .mutedForeground,
                    fontSize: 13,
                  ),
                ),
              ),

            ListTile(
              contentPadding:
                  const EdgeInsets
                      .only(
                left: 16,
                right: 16,
                bottom: 8,
              ),
              dense: true,
              leading:
                  const Icon(
                Icons.add,
                size: 18,
                color:
                    AppColors.primary,
              ),
              title: const Text(
                'Add Subcategory',
                style: TextStyle(
                  color:
                      AppColors.primary,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
              onTap: widget
                  .onAddSubcategory,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// UNIT MANAGEMENT
// =============================================================================

class _UnitManagementSection
    extends StatefulWidget {
  const _UnitManagementSection();

  @override
  State<_UnitManagementSection>
      createState() =>
          _UnitManagementSectionState();
}

class _UnitManagementSectionState
    extends State<
        _UnitManagementSection> {
  final CatalogService
      _catalogService =
      CatalogService();

  final _filterCtrl =
      TextEditingController();

  bool _loading = true;
  String? _error;

  List<Unit> _units = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final units =
          await _catalogService
              .fetchUnits();

      if (!mounted) return;

      setState(() {
        _units = units;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not load units: $e';
        _loading = false;
      });
    }
  }

  Future<void> _addUnit() async {
    await _promptForUnit(
      context: context,
      title: 'Add Unit',
      onSubmit: (
        name,
        abbr,
      ) =>
          _catalogService
              .createUnit(
        name: name,
        abbrName: abbr,
      ),
    );

    await _load();
  }

  Future<void> _editUnit(
    Unit unit,
  ) async {
    await _promptForUnit(
      context: context,
      title: 'Edit Unit',
      initialName: unit.name,
      initialAbbr:
          unit.abbrName,
      onSubmit: (
        name,
        abbr,
      ) =>
          _catalogService
              .renameUnit(
        id: unit.id,
        name: name,
        abbrName: abbr,
      ),
    );

    await _load();
  }

  Future<void> _deleteUnit(
    Unit unit,
  ) async {
    final confirmed =
        await _confirmDelete(
      context: context,
      title: 'Delete unit?',
      message:
          'This will permanently delete "${unit.name}".',
    );

    if (!confirmed) return;

    try {
      await _catalogService
          .deleteUnit(
        unit.id,
      );

      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '"${unit.name}" deleted.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      await _showErrorDialog(
        context,
        title:
            'Could not delete "${unit.name}"',
        error: e,
      );
    }
  }

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
      return Text(
        _error!,
        style: const TextStyle(
          color:
              AppColors.destructive,
        ),
      );
    }

    final query =
        _filter.trim().toLowerCase();

    final visible =
        query.isEmpty
            ? _units
            : _units
                .where(
                  (u) =>
                      u.name
                          .toLowerCase()
                          .contains(
                            query,
                          ) ||
                      u.abbrName
                          .toLowerCase()
                          .contains(
                            query,
                          ),
                )
                .toList();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SearchBar(
                controller:
                    _filterCtrl,
                hintText:
                    'Filter units',
                leading:
                    const Icon(
                  Icons.search,
                  size: 20,
                ),
                constraints:
                    const BoxConstraints(
                  minHeight: 44,
                  maxHeight: 44,
                ),
                onChanged: (v) =>
                    setState(
                  () => _filter = v,
                ),
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            FilledButton.icon(
              onPressed:
                  _addUnit,
              icon: const Icon(
                Icons.add,
                size: 18,
              ),
              label:
                  const Text(
                'Add Unit',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Card(
          margin: EdgeInsets.zero,
          clipBehavior:
              Clip.antiAlias,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            side:
                const BorderSide(
              color:
                  AppColors.border,
            ),
          ),
          child: Column(
            children: [
              ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxHeight: 420,
                ),
                child: visible.isEmpty
                    ? Padding(
                        padding:
                            const EdgeInsets
                                .all(
                          24,
                        ),
                        child: Text(
                          query.isEmpty
                              ? 'No units yet.'
                              : 'No units match "$_filter".',
                          style:
                              const TextStyle(
                            color: AppColors
                                .mutedForeground,
                            fontSize:
                                13,
                          ),
                        ),
                      )
                    : ListView
                        .separated(
                        shrinkWrap:
                            true,
                        padding:
                            EdgeInsets
                                .zero,
                        itemCount:
                            visible
                                .length,
                        separatorBuilder:
                            (
                          _,
                          __,
                        ) =>
                                const Divider(
                          height: 1,
                          indent: 16,
                        ),
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          final unit =
                              visible[
                                  index];

                          return ListTile(
                            key:
                                ValueKey(
                              unit.id,
                            ),
                            leading:
                                CircleAvatar(
                              backgroundColor:
                                  AppColors
                                      .secondary,
                              foregroundColor:
                                  AppColors
                                      .primary,
                              child: Text(
                                unit.abbrName
                                        .isNotEmpty
                                    ? unit.abbrName[
                                            0]
                                        .toUpperCase()
                                    : '?',
                                style:
                                    const TextStyle(
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ),
                            title: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    unit.name,
                                    overflow:
                                        TextOverflow
                                            .ellipsis,
                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Chip(
                                  label: Text(
                                    unit.abbrName,
                                  ),
                                  labelStyle:
                                      const TextStyle(
                                    fontSize:
                                        11.5,
                                  ),
                                  visualDensity:
                                      VisualDensity
                                          .compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize
                                          .shrinkWrap,
                                  padding:
                                      EdgeInsets
                                          .zero,
                                  labelPadding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal:
                                        8,
                                  ),
                                ),
                              ],
                            ),
                            trailing:
                                Row(
                              mainAxisSize:
                                  MainAxisSize
                                      .min,
                              children: [
                                IconButton(
                                  icon:
                                      const Icon(
                                    Icons
                                        .edit_outlined,
                                    size:
                                        19,
                                  ),
                                  tooltip:
                                      'Rename',
                                  onPressed:
                                      () =>
                                          _editUnit(
                                    unit,
                                  ),
                                ),
                                IconButton(
                                  icon:
                                      const Icon(
                                    Icons
                                        .delete_outline,
                                    size:
                                        20,
                                  ),
                                  tooltip:
                                      'Delete unit',
                                  onPressed:
                                      () =>
                                          _deleteUnit(
                                    unit,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),

              const Divider(
                height: 1,
              ),

              ListTile(
                dense: true,
                title: Text(
                  query.isEmpty
                      ? '${_units.length} unit${_units.length == 1 ? '' : 's'}'
                      : '${visible.length} of ${_units.length} units',
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// NAME DIALOG HELPER
// =============================================================================

Future<void> _promptForName({
  required BuildContext context,
  required String title,
  required String label,
  required Future<void> Function(
    String name,
  ) onSubmit,
}) async {
  final name =
      await showDialog<String>(
    context: context,
    builder: (dialogContext) =>
        _NameDialog(
      title: title,
      label: label,
    ),
  );

  if (name != null) {
    try {
      await onSubmit(name);
    } catch (e) {
      if (context.mounted) {
        await _showErrorDialog(
          context,
          title:
              'Could not create "$name"',
          error: e,
        );
      }
    }
  }
}

// =============================================================================
// UNIT DIALOG HELPER
// =============================================================================

Future<void> _promptForUnit({
  required BuildContext context,
  required String title,
  String? initialName,
  String? initialAbbr,
  required Future<void> Function(
    String name,
    String abbr,
  ) onSubmit,
}) async {
  final result =
      await showDialog<
          (String, String)>(
    context: context,
    builder: (dialogContext) =>
        _UnitDialog(
      title: title,
      initialName: initialName,
      initialAbbr: initialAbbr,
    ),
  );

  if (result != null) {
    try {
      await onSubmit(
        result.$1,
        result.$2,
      );
    } catch (e) {
      if (context.mounted) {
        await _showErrorDialog(
          context,
          title:
              'Could not save "${result.$1}"',
          error: e,
        );
      }
    }
  }
}

// =============================================================================
// NAME DIALOG
// =============================================================================

class _NameDialog
    extends StatefulWidget {
  final String title;
  final String label;

  const _NameDialog({
    required this.title,
    required this.label,
  });

  @override
  State<_NameDialog>
      createState() =>
          _NameDialogState();
}

class _NameDialogState
    extends State<_NameDialog> {
  final _ctrl =
      TextEditingController();

  final _formKey =
      GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!
        .validate()) {
      Navigator.of(context).pop(
        _ctrl.text.trim(),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      title:
          Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          decoration:
              InputDecoration(
            labelText:
                widget.label,
          ),
          validator: (v) =>
              v == null ||
                      v.trim().isEmpty
                  ? 'Required'
                  : null,
          onFieldSubmitted:
              (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop(),
          child:
              const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child:
              const Text('Create'),
        ),
      ],
    );
  }
}

// =============================================================================
// UNIT DIALOG
// =============================================================================

class _UnitDialog
    extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialAbbr;

  const _UnitDialog({
    required this.title,
    this.initialName,
    this.initialAbbr,
  });

  @override
  State<_UnitDialog>
      createState() =>
          _UnitDialogState();
}

class _UnitDialogState
    extends State<_UnitDialog> {
  late final _nameCtrl =
      TextEditingController(
    text:
        widget.initialName ?? '',
  );

  late final _abbrCtrl =
      TextEditingController(
    text:
        widget.initialAbbr ?? '',
  );

  final _formKey =
      GlobalKey<FormState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _abbrCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!
        .validate()) {
      Navigator.of(context).pop(
        (
          _nameCtrl.text.trim(),
          _abbrCtrl.text.trim(),
        ),
      );
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      title:
          Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            TextFormField(
              controller:
                  _nameCtrl,
              autofocus: true,
              decoration:
                  const InputDecoration(
                labelText:
                    'Unit name',
              ),
              validator: (v) =>
                  v == null ||
                          v
                              .trim()
                              .isEmpty
                      ? 'Required'
                      : null,
            ),

            const SizedBox(
              height: 12,
            ),

            TextFormField(
              controller:
                  _abbrCtrl,
              decoration:
                  const InputDecoration(
                labelText:
                    'Abbreviation',
              ),
              validator: (v) =>
                  v == null ||
                          v
                              .trim()
                              .isEmpty
                      ? 'Required'
                      : null,
              onFieldSubmitted:
                  (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context)
                  .pop(),
          child:
              const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(
            widget.initialName ==
                    null
                ? 'Create'
                : 'Save',
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// DELETE CONFIRMATION
// =============================================================================

Future<bool> _confirmDelete({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  final confirmed =
      await showDialog<bool>(
    context: context,
    builder: (dialogContext) =>
        AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(
            dialogContext,
          ).pop(false),
          child:
              const Text('Cancel'),
        ),
        ElevatedButton(
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                AppColors.destructive,
          ),
          onPressed: () =>
              Navigator.of(
            dialogContext,
          ).pop(true),
          child:
              const Text('Delete'),
        ),
      ],
    ),
  );

  return confirmed == true;
}

// =============================================================================
// ERROR DIALOG
// =============================================================================

Future<void> _showErrorDialog(
  BuildContext context, {
  required String title,
  required Object error,
  List<String>? details,
}) async {
  final blockingSubs =
      error is CategoryInUseException
          ? error
              .blockingSubcategoryNames
          : const <String>[];

  final blockingItems =
      error is CategoryInUseException
          ? error.blockingItemNames
          : const <String>[];

  await showDialog<void>(
    context: context,
    builder: (dialogContext) =>
        AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(20),
      ),
      title: Text(title),
      content: ConstrainedBox(
        constraints:
            const BoxConstraints(
          maxWidth: 420,
          maxHeight: 320,
        ),
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                error.toString(),
              ),

              if (blockingSubs
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 12,
                ),
                const Text(
                  'Subcategories still present:',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                for (final name
                    in blockingSubs)
                  Text('•  $name'),
              ],

              if (blockingItems
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 12,
                ),
                const Text(
                  'Items still assigned:',
                  style:
                      TextStyle(
                    fontWeight:
                        FontWeight
                            .w600,
                  ),
                ),
                const SizedBox(
                  height: 4,
                ),
                for (final name
                    in blockingItems)
                  Text('•  $name'),
              ],

              if (details != null &&
                  details
                      .isNotEmpty) ...[
                const SizedBox(
                  height: 12,
                ),
                for (final line
                    in details)
                  Text('•  $line'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () =>
              Navigator.of(
            dialogContext,
          ).pop(),
          child:
              const Text('OK'),
        ),
      ],
    ),
  );
}

// =============================================================================
// INLINE EDITABLE LABEL
// =============================================================================

class _EditableLabel
    extends StatefulWidget {
  final String value;
  final TextStyle? style;

  final Future<void> Function(
    String newValue,
  ) onSave;

  const _EditableLabel({
    required this.value,
    required this.onSave,
    this.style,
  });

  @override
  State<_EditableLabel>
      createState() =>
          _EditableLabelState();
}

class _EditableLabelState
    extends State<_EditableLabel> {
  bool _editing = false;
  bool _saving = false;

  late final
      TextEditingController _ctrl =
      TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(
    covariant _EditableLabel
        oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (!_editing &&
        oldWidget.value !=
            widget.value) {
      _ctrl.text =
          widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final newValue =
        _ctrl.text.trim();

    if (newValue.isEmpty ||
        newValue ==
            widget.value) {
      setState(() {
        _editing = false;
        _ctrl.text =
            widget.value;
      });

      return;
    }

    setState(
      () => _saving = true,
    );

    try {
      await widget.onSave(
        newValue,
      );

      if (!mounted) return;

      setState(() {
        _editing = false;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(
        () => _saving = false,
      );

      await _showErrorDialog(
        context,
        title:
            'Could not rename to "$newValue"',
        error: e,
      );
    }
  }

  void _cancel() {
    setState(() {
      _editing = false;
      _ctrl.text =
          widget.value;
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (!_editing) {
      return Row(
        children: [
          Flexible(
            child: Text(
              widget.value,
              style:
                  widget.style,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 15,
            ),
            tooltip: 'Rename',
            visualDensity:
                VisualDensity.compact,
            onPressed: () =>
                setState(
              () => _editing =
                  true,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style:
                widget.style,
            decoration:
                const InputDecoration(
              isDense: true,
            ),
            onSubmitted:
                (_) => _confirm(),
          ),
        ),

        if (_saving)
          const Padding(
            padding:
                EdgeInsets.symmetric(
              horizontal: 8,
            ),
            child: SizedBox(
              height: 16,
              width: 16,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
          )
        else ...[
          IconButton(
            icon: const Icon(
              Icons.check,
              size: 18,
              color:
                  AppColors.primary,
            ),
            tooltip: 'Save',
            visualDensity:
                VisualDensity.compact,
            onPressed: _confirm,
          ),
          IconButton(
            icon: const Icon(
              Icons.close,
              size: 18,
            ),
            tooltip: 'Cancel',
            visualDensity:
                VisualDensity.compact,
            onPressed: _cancel,
          ),
        ],
      ],
    );
  }
}