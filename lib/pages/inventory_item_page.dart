import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../models/primary_category.dart';
import '../models/replenishment_item.dart';
import '../models/qty_unit.dart';
import '../models/stock_movement.dart';
import '../models/unit.dart';
import '../services/catalog_service.dart';
import '../services/inventory_service.dart';
import '../services/replenishment_service.dart';
import '../state/auth_state.dart';
import '../state/data_bus.dart';
import '../widgets/search_select_field.dart';
import '../widgets/stock_out_dialog.dart';

class InventoryItemPage extends StatefulWidget {
  final String itemId;

  const InventoryItemPage({
    super.key,
    required this.itemId,
  });

  @override
  State<InventoryItemPage> createState() => _InventoryItemPageState();
}

class _InventoryItemPageState extends State<InventoryItemPage>
    with DataBusRefreshMixin<InventoryItemPage> {
  final InventoryService _service = InventoryService();
  final CatalogService _catalogService = CatalogService();
  final ReplenishmentService _replenishmentService =
      ReplenishmentService();

  InventoryItem? _item;
  ReplenishmentItem? _replenishment;
  List<StockMovement> _history = [];
  List<PrimaryCategory> _primaryCategories = [];
  List<Unit> _units = [];

  bool _loading = true;
  bool _notFound = false;

  // ===========================================================================
  // CURRENT STOCK DISPLAY
  // ===========================================================================

  bool _hasPackageBreakdown(InventoryItem item) {
    return item.packageQuantity != null &&
        item.packageQuantity! > 0 &&
        item.packageUnitAbbr != null &&
        item.packageUnitAbbr!.trim().isNotEmpty;
  }

  double _currentStockQty(InventoryItem item) {
    return item.currentUsableStockQty;
  }

  String _currentStockUnit(InventoryItem item) {
    return item.currentUsableStockUnit;
  }

  double? _purchaseUnitEquivalent(InventoryItem item) {
    if (!item.hasPackageBreakdown) {
      return null;
    }

    return item.currentPurchaseUnitEquivalent;
  }

  String? _packageConversionLabel(InventoryItem item) {
    if (!_hasPackageBreakdown(item)) return null;

    return '1 ${item.purchaseUnitAbbr} = '
        '${formatQty(item.packageQuantity!)} ${item.packageUnitAbbr}';
  }

  // ===========================================================================
  // STOCK LEVEL
  // ===========================================================================

  StockLevel _stockLevelFor(InventoryItem item) {
    if (item.isOutOfStock) {
      return StockLevel.outOfStock;
    }

    if (item.currentPurchaseUnitEquivalent <=
        lowStockPurchaseUnitThreshold) {
      return StockLevel.low;
    }

    if (_replenishment != null) {
      return StockLevel.needsRestock;
    }

    return StockLevel.inStock;
  }

  (String, Color) _stockLevelMeta(StockLevel level) {
    switch (level) {
      case StockLevel.inStock:
        return ('In Stock', AppColors.stockInStock);

      case StockLevel.needsRestock:
        return ('Needs Restock', AppColors.stockNeedsRestock);

      case StockLevel.low:
        return ('Low Stock', AppColors.stockLow);

      case StockLevel.outOfStock:
        return ('Out of Stock', AppColors.stockOut);
    }
  }

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
        _notFound = false;
      });
    }

    try {
      final results = await Future.wait([
        _service.fetchItem(widget.itemId),
        _service.fetchStockHistory(widget.itemId),
        _catalogService.fetchPrimaryCategories(),
        _catalogService.fetchUnits(),
        _replenishmentService.fetchReplenishmentItems(),
      ]);

      if (!mounted) return;

      final item = results[0] as InventoryItem?;
      final replenishmentRows =
          results[4] as List<ReplenishmentItem>;

      ReplenishmentItem? replenishment;

      if (item != null) {
        for (final row in replenishmentRows) {
          if (row.item.itemId == item.itemId) {
            replenishment = row;
            break;
          }
        }
      }

      setState(() {
        _item = item;
        _replenishment = replenishment;
        _history = results[1] as List<StockMovement>;
        _primaryCategories = results[2] as List<PrimaryCategory>;
        _units = results[3] as List<Unit>;
        _notFound = item == null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _notFound = true;
          _loading = false;
        });
      }
    }
  }

  Future<void> _editField({
    required String label,
    required String currentValue,
    required Future<void> Function(String) onSave,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Edit $label'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              Navigator.of(context).pop();

              try {
                await onSave(controller.text.trim());
                _load();
              } catch (e) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not update: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  /// Category/unit are catalog lookups, not free-text values.
  Future<void> _editPickerField<T extends Object>({
    required String label,
    required List<T> options,
    required String Function(T) displayStringForOption,
    required Future<void> Function(T) onSave,
  }) async {
    T? selected;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text('Edit $label'),
        content: Form(
          key: formKey,
          child: SearchSelectField<T>(
            labelText: label,
            options: options,
            displayStringForOption: displayStringForOption,
            validator: (v) => selected == null ? 'Required' : null,
            onSelected: (v) => selected = v,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              Navigator.of(context).pop();

              try {
                await onSave(selected as T);
                _load();
              } catch (e) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Could not update: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _openStockOutDialog() async {
    final item = _item;
    if (item == null) return;

    final result = await showStockOutDialog(
      context,
      service: _service,
      recordedByUserId: context.read<AuthController>().profile!.userId,
      item: item,
    );

    if (!mounted) return;

    if (result != null) {
      final (usedItem, qty) = result;

      context.push(
        '/medical-records/add?itemId=${usedItem.itemId}&qty=$qty',
      );

      return;
    }

    _load();
  }

  // ===========================================================================
  // BACK NAVIGATION
  // ===========================================================================

  bool get _openedFromPurchases {
    final from = GoRouterState.of(context)
        .uri
        .queryParameters['from'];

    return from == 'purchase-orders';
  }

  void _goBack() {
    if (_openedFromPurchases) {
      context.go('/purchase-orders');
      return;
    }

    context.go('/inventory');
  }

  String get _backLabel => _openedFromPurchases
      ? 'Back to Ordering'
      : 'Back to Inventory';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_notFound || _item == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: AppColors.mutedForeground,
            ),
            const SizedBox(height: 12),
            const Text(
              'Item not found',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _goBack,
              child: Text(_backLabel),
            ),
          ],
        ),
      );
    }

    final item = _item!;
    final stockLevel = _stockLevelFor(item);

    final (stockLevelLabel, stockLevelColor) =
        _stockLevelMeta(stockLevel);

    final currentStockQty =
        _currentStockQty(item);

    final currentStockUnit =
        _currentStockUnit(item);

    final equivalent =
        _purchaseUnitEquivalent(item);

    final conversionLabel =
        _packageConversionLabel(item);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 720,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: _goBack,
            icon: const Icon(
              Icons.arrow_back,
              size: 16,
            ),
            label: Text(
              _backLabel,
            ),
            style: TextButton.styleFrom(
              foregroundColor:
                  AppColors.mutedForeground,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: stockLevelColor
                      .withValues(
                    alpha: 0.12,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                ),
                child: Text(
                  stockLevelLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w700,
                    color: stockLevelColor,
                  ),
                ),
              ),
              const SizedBox(
                height: 8,
              ),
              Text(
                item.itemName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 20,
          ),

          // ===============================================================
          // STOCK ACTIONS
          // ===============================================================

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.push(
                      '/inventory/add?itemId=${item.itemId}',
                    );
                  },
                  icon: const Icon(
                    Icons.arrow_upward,
                    size: 16,
                    color:
                        AppColors.roleManager,
                  ),
                  label: const Text(
                    'Goods Received',
                  ),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: ElevatedButton.icon(
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        AppColors.destructive,
                  ),
                  onPressed:
                      _openStockOutDialog,
                  icon: const Icon(
                    Icons.arrow_downward,
                    size: 16,
                  ),
                  label: const Text(
                    'Dispense',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 24,
          ),

          // ===============================================================
          // ITEM DETAILS
          // ===============================================================

          _FieldRow(
            label: 'Item ID',
            value: item.displayId,
          ),

          const SizedBox(
            height: 16,
          ),

          _FieldRow(
            label: 'Name',
            value: item.itemName,
            onEdit: () => _editField(
              label: 'Name',
              currentValue:
                  item.itemName,
              onSave: (v) =>
                  _service.updateDetails(
                itemId: item.itemId,
                itemName: v,
              ),
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Row(
            children: [
              Expanded(
                child: _FieldRow(
                  label: 'Category',
                  value:
                      item.itemCategory,
                  onEdit: () =>
                      _editPickerField<
                          PrimaryCategory>(
                    label: 'Category',
                    options:
                        _primaryCategories,
                    displayStringForOption:
                        (c) => c.type,
                    onSave: (c) =>
                        _service
                            .updateDetails(
                      itemId:
                          item.itemId,
                      pCategoryId: c.id,
                    ),
                  ),
                ),
              ),
              const SizedBox(
                width: 16,
              ),
              Expanded(
                child: _FieldRow(
                  label: 'Purchase Unit',
                  value: item.itemUom,
                  onEdit: () =>
                      _editPickerField<
                          Unit>(
                    label:
                        'Purchase Unit',
                    options: _units,
                    displayStringForOption:
                        (u) => u.name,
                    onSave: (u) =>
                        _service
                            .updateDetails(
                      itemId:
                          item.itemId,
                      purchaseUnitId:
                          u.id,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          Row(
            children: [
              Expanded(
                child: _FieldRow(
                  label: 'Package Unit',
                  value:
                      item.packageUnitAbbr ??
                          '—',
                ),
              ),
              const SizedBox(
                width: 16,
              ),
              Expanded(
                child: _FieldRow(
                  label:
                      'Package Quantity',
                  value:
                      item.packageQuantity ==
                              null
                          ? '—'
                          : formatQty(
                              item.packageQuantity!,
                            ),
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 16,
          ),

          _FieldRow(
            label: 'Dispense Unit',
            value:
                item.dispenseUnitAbbr ??
                    '—',
          ),

          const SizedBox(
            height: 16,
          ),

          // ===============================================================
          // STOCK COUNT MODE
          // ===============================================================

          if (item.packageUnitAbbr !=
              null) ...[
            _FieldRow(
              label:
                  'Stock Count Mode',
              value: item.effectiveCountMode ==
                      StockCountMode
                          .packageUnit
                  ? 'By package unit (${item.packageUnitAbbr})'
                  : 'By purchase unit (${item.purchaseUnitAbbr})',
              onEdit: () =>
                  _editPickerField<
                      StockCountMode>(
                label:
                    'Stock Count Mode',
                options:
                    StockCountMode.values,
                displayStringForOption:
                    (m) {
                  return m ==
                          StockCountMode
                              .packageUnit
                      ? 'By package unit (${item.packageUnitAbbr})'
                      : 'By purchase unit (${item.purchaseUnitAbbr})';
                },
                onSave: (m) =>
                    _service
                        .updateDetails(
                  itemId: item.itemId,
                  stockCountMode: m,
                ),
              ),
            ),
            const SizedBox(
              height: 16,
            ),
          ],

          // ===============================================================
          // CURRENT STOCK
          // ===============================================================

          if (_hasPackageBreakdown(
            item,
          ))
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Expanded(
                  child:
                      _StockStatCard(
                    label:
                        'Current Stock',
                    qty:
                        currentStockQty,
                    unit:
                        currentStockUnit,
                  ),
                ),
                const SizedBox(
                  width: 16,
                ),
                Expanded(
                  child:
                      _StockStatCard(
                    label:
                        'Equivalent',
                    qty:
                        equivalent ?? 0,
                    unit: item
                        .purchaseUnitAbbr,
                  ),
                ),
              ],
            )
          else
            _StockStatCard(
              label: 'Current Stock',
              qty: currentStockQty,
              unit: currentStockUnit,
            ),

          if (conversionLabel !=
              null) ...[
            const SizedBox(
              height: 8,
            ),
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 14,
                  color: AppColors
                      .mutedForeground,
                ),
                const SizedBox(
                  width: 6,
                ),
                Text(
                  conversionLabel,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(
            height: 24,
          ),

          // ===============================================================
          // STOCK HISTORY
          // ===============================================================

          const Text(
            'Stock History',
            style: TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(
            height: 12,
          ),

          if (_history.isEmpty)
            const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 8,
              ),
              child: Text(
                'No stock movements yet.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            )
          else
            Container(
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
              child: Column(
                children: [
                  for (var i = 0;
                      i < _history.length;
                      i++) ...[
                    if (i > 0)
                      const Divider(
                        height: 1,
                      ),
                    _StockHistoryRow(
                      movement:
                          _history[i],
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// STOCK HISTORY ROW
// =============================================================================

class _StockHistoryRow extends StatelessWidget {
  final StockMovement movement;

  const _StockHistoryRow({
    required this.movement,
  });

  @override
  Widget build(BuildContext context) {
    final isLoggedTreatment =
        movement.typeLabel ==
            'Logged Treatment';

    final isIn =
        movement.direction ==
            StockDirection.stockIn;

    final color = isLoggedTreatment
        ? AppColors.primary
        : isIn
            ? AppColors.roleManager
            : AppColors.destructive;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            isLoggedTreatment
                ? Icons
                    .medical_services_outlined
                : isIn
                    ? Icons.arrow_upward
                    : Icons.arrow_downward,
            size: 16,
            color: color,
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  movement.typeLabel,
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  _formatDate(
                    movement.date,
                  ),
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

          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  isLoggedTreatment
                      ? '${formatQty(movement.qty)} ${movement.unitAbbr}'
                      : '${isIn ? '+' : '-'}${formatQty(movement.qty)} '
                          '${movement.unitAbbr}',
                  style: TextStyle(
                    fontWeight:
                        FontWeight.w600,
                    color: color,
                  ),
                ),
                if (isLoggedTreatment)
                  const Text(
                    'No stock deduction',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.end,
              children: [
                if (movement
                        .treatmentId !=
                    null)
                  InkWell(
                    onTap: () {
                      context.push(
                        '/medical-records/${movement.treatmentId}',
                      );
                    },
                    child: Text(
                      movement
                              .treatmentName ??
                          '',
                      textAlign:
                          TextAlign.end,
                      style:
                          const TextStyle(
                        fontSize: 12.5,
                        color:
                            AppColors.primary,
                        fontWeight:
                            FontWeight.w600,
                        decoration:
                            TextDecoration
                                .underline,
                      ),
                    ),
                  ),
                Text(
                  'by ${movement.recordedByName}',
                  textAlign:
                      TextAlign.end,
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
) {
  return '${_monthAbbrev[date.month - 1]} '
      '${date.day}, ${date.year}';
}

// =============================================================================
// FIELD LABEL
// =============================================================================

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(
    this.text,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 6,
      ),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight:
              FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors
              .mutedForeground,
        ),
      ),
    );
  }
}

// =============================================================================
// FIELD ROW
// =============================================================================

class _FieldRow extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onEdit;

  const _FieldRow({
    required this.label,
    required this.value,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          label,
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
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
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
              if (onEdit != null)
                IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 15,
                    color: AppColors
                        .mutedForeground,
                  ),
                  onPressed: onEdit,
                  splashRadius: 18,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// STOCK STAT CARD
// =============================================================================

class _StockStatCard extends StatelessWidget {
  final String label;
  final double qty;
  final String unit;

  const _StockStatCard({
    required this.label,
    required this.qty,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          label,
        ),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
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
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Text(
                formatQty(
                  qty,
                ),
                style:
                    const TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
              const SizedBox(
                width: 6,
              ),
              Text(
                unit,
                style:
                    const TextStyle(
                  color: AppColors
                      .mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}