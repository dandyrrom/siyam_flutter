import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../models/qty_unit.dart';
import '../models/stock_out.dart';
import '../services/inventory_service.dart';
import 'app_dropdown.dart';
import 'search_select_field.dart';

// ============================================================================
// DISPENSE UNIT HELPERS
// ============================================================================

bool _hasPackageUnit(InventoryItem item) {
  return item.packageUnitId != null &&
      item.packageUnitAbbr != null &&
      item.packageQuantity != null &&
      item.packageQuantity! > 0;
}

QtyUnit _defaultDispenseUnit(InventoryItem item) {
  return _hasPackageUnit(item)
      ? QtyUnit.packageUnit
      : QtyUnit.purchaseUnit;
}

String _dispenseUnitAbbr(InventoryItem item, QtyUnit qtyUnit) {
  return qtyUnit == QtyUnit.packageUnit
      ? (item.packageUnitAbbr ?? item.purchaseUnitAbbr)
      : item.purchaseUnitAbbr;
}

// ============================================================================
// EXPIRY HELPERS
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

String _formatDate(DateTime date) {
  return '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
}

// ============================================================================
// REASON-AWARE STOCK HELPERS
// ============================================================================
//
// IMPORTANT:
//
// Normal dispense:
//   currentUsableStockQty
//
// Expired removal:
//   expiredBatchStockQty
//
// Both quantities are already expressed in the item's canonical unit:
//
// package breakdown exists:
//   kg / ml / tablet / etc.
//
// no package breakdown:
//   bag / piece / bottle / etc.
//
// This makes the dialog match SupabaseInventoryService FEFO rules.
// ============================================================================

bool _isExpiredRemoval(String reason) {
  return reason == 'Expired';
}

double _canonicalAvailable(
  InventoryItem item,
  String reason,
) {
  if (_isExpiredRemoval(reason)) {
    return item.hasBatchHistory
        ? item.expiredBatchStockQty
        : 0;
  }

  return item.currentUsableStockQty;
}

/// Returns reason-aware available stock in the unit selected by staff.
///
/// Example:
///
/// usable = 25 kg
/// 1 bag = 10 kg
///
/// selected kg:
///   25 kg
///
/// selected bag:
///   2.5 bag equivalent
///
/// If Dispense Type = Expired and expired stock = 5 kg:
///
/// selected kg:
///   5 kg
///
/// selected bag:
///   0.5 bag equivalent
double _availableForUnit(
  InventoryItem item,
  QtyUnit qtyUnit,
  String reason,
) {
  final canonicalAvailable = _canonicalAvailable(item, reason);

  if (!_hasPackageUnit(item)) {
    return canonicalAvailable;
  }

  if (qtyUnit == QtyUnit.packageUnit) {
    return canonicalAvailable;
  }

  return canonicalAvailable / item.packageQuantity!;
}

double _purchaseEquivalent(
  InventoryItem item,
  String reason,
) {
  if (!_hasPackageUnit(item)) {
    return _canonicalAvailable(item, reason);
  }

  return _canonicalAvailable(item, reason) /
      item.packageQuantity!;
}

// ============================================================================
// DISPENSE DIALOG
// ============================================================================
//
// STAFF-FACING TERMINOLOGY:
//
// Stock Out      -> Dispense
// Stock Out Unit -> Dispense Unit
// Reason         -> Dispense Type
//
// INTERNAL BACKEND NAMES REMAIN UNCHANGED:
//
// showStockOutDialog()
// service.stockOut()
// StockOutReason
//
// This avoids unnecessary changes to the tested backend.
// ============================================================================

Future<(InventoryItem, double)?> showStockOutDialog(
  BuildContext context, {
  required InventoryService service,
  required String recordedByUserId,
  InventoryItem? item,
  List<InventoryItem> items = const [],
}) {
  final qtyCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  String reason = 'Waste';
  InventoryItem? selectedItem = item;

  QtyUnit selectedQtyUnit = item == null
      ? QtyUnit.purchaseUnit
      : _defaultDispenseUnit(item);

  bool isSubmitting = false;

  return showDialog<(InventoryItem, double)?>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final target = selectedItem;

          final hasPackageUnit =
              target != null && _hasPackageUnit(target);

          final expiredRemoval = _isExpiredRemoval(reason);

          final selectedUnitAbbr = target == null
              ? ''
              : _dispenseUnitAbbr(
                  target,
                  selectedQtyUnit,
                );

          final availableInSelectedUnit = target == null
              ? 0.0
              : _availableForUnit(
                  target,
                  selectedQtyUnit,
                  reason,
                );

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),

            // ==================================================================
            // TITLE
            // ==================================================================

            title: const Row(
              children: [
                Icon(
                  Icons.arrow_downward,
                  size: 18,
                  color: AppColors.destructive,
                ),
                SizedBox(width: 8),
                Text('Dispense Item'),
              ],
            ),

            // ==================================================================
            // FORM
            // ==================================================================

            content: SizedBox(
              width: 430,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================================
                    // ITEM PICKER
                    // ==========================================================

                    if (item == null) ...[
                      SearchSelectField<InventoryItem>(
                        labelText: 'Item',
                        options: items,
                        displayStringForOption: (inventoryItem) =>
                            inventoryItem.itemName,
                        validator: (_) =>
                            selectedItem == null ? 'Required' : null,

                        onSelected: (picked) {
                          setDialogState(() {
                            selectedItem = picked;
                            selectedQtyUnit =
                                _defaultDispenseUnit(picked);
                            qtyCtrl.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ==========================================================
                    // SELECTED ITEM SUMMARY
                    // ==========================================================

                    if (target != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              target.itemName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 6),

                            // ==================================================
                            // REASON-AWARE AVAILABLE STOCK
                            // ==================================================
                            //
                            // Waste / Adjustment:
                            //   shows usable stock only
                            //
                            // Expired:
                            //   shows expired stock only
                            // ==================================================

                            if (hasPackageUnit) ...[
                              Text(
                                expiredRemoval
                                    ? 'Expired stock available: '
                                        '${formatQty(_canonicalAvailable(target, reason))} '
                                        '${target.packageUnitAbbr}'
                                    : 'Available stock: '
                                        '${formatQty(_canonicalAvailable(target, reason))} '
                                        '${target.packageUnitAbbr}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: expiredRemoval
                                      ? AppColors.destructive
                                      : AppColors.foreground,
                                ),
                              ),

                              const SizedBox(height: 2),

                              Text(
                                'Equivalent: '
                                '${formatQty(_purchaseEquivalent(target, reason))} '
                                '${target.purchaseUnitAbbr}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.mutedForeground,
                                ),
                              ),

                              const SizedBox(height: 2),

                              Text(
                                '1 ${target.purchaseUnitAbbr} = '
                                '${formatQty(target.packageQuantity!)} '
                                '${target.packageUnitAbbr}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ] else
                              Text(
                                expiredRemoval
                                    ? 'Expired stock available: '
                                        '${formatQty(_canonicalAvailable(target, reason))} '
                                        '${target.purchaseUnitAbbr}'
                                    : 'Available stock: '
                                        '${formatQty(_canonicalAvailable(target, reason))} '
                                        '${target.purchaseUnitAbbr}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: expiredRemoval
                                      ? AppColors.destructive
                                      : AppColors.foreground,
                                ),
                              ),

                            // ==================================================
                            // EXPIRED REMOVAL NOTICE
                            // ==================================================

                            if (expiredRemoval) ...[
                              const SizedBox(height: 8),

                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 14,
                                    color: AppColors.destructive,
                                  ),
                                  SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Only expired batches will be removed. '
                                      'Usable stock will not be affected.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.destructive,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // ==================================================
                            // EXPIRED STOCK WARNING DURING NORMAL DISPENSE
                            // ==================================================

                            if (!expiredRemoval &&
                                target.hasExpiredStock) ...[
                              const SizedBox(height: 8),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    size: 14,
                                    color: AppColors.destructive,
                                  ),
                                  const SizedBox(width: 5),

                                  Expanded(
                                    child: Text(
                                      '${formatQty(target.expiredBatchStockQty)} '
                                      '${target.currentUsableStockUnit} expired '
                                      'stock is excluded from available stock. '
                                      'Choose "Expired" under Dispense Type '
                                      'to remove it.',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.destructive,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],

                            // ==================================================
                            // NEXT FEFO EXPIRY
                            // ==================================================

                            if (!expiredRemoval &&
                                target.nearestExpiryDate != null) ...[
                              const SizedBox(height: 8),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.schedule_outlined,
                                    size: 14,
                                    color: target.isExpiringSoon
                                        ? AppColors.warning
                                        : AppColors.mutedForeground,
                                  ),

                                  const SizedBox(width: 5),

                                  Expanded(
                                    child: Text(
                                      target.expiresToday
                                          ? 'Next batch expires today '
                                              '(${_formatDate(target.nearestExpiryDate!)}).'
                                          : 'Next batch expires '
                                              '${_formatDate(target.nearestExpiryDate!)}'
                                              '${target.daysUntilNearestExpiry != null ? ' · ${target.daysUntilNearestExpiry} days left' : ''}.',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: target.isExpiringSoon
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                        color: target.isExpiringSoon
                                            ? AppColors.warning
                                            : AppColors.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                    // ==========================================================
                    // NON-TREATMENT DISPENSE FIELDS
                    // ==========================================================

                    if (reason != 'Treatment') ...[
                      const SizedBox(height: 16),

                      // ========================================================
                      // QUANTITY
                      // ========================================================

                      TextFormField(
                        controller: qtyCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        autofocus: item != null,
                        decoration: InputDecoration(
                          labelText: target == null
                              ? 'Quantity'
                              : 'Quantity ($selectedUnitAbbr)',
                        ),

                        // ======================================================
                        // REASON-AWARE QUANTITY VALIDATION
                        // ======================================================

                        validator: (value) {
                          final qty = double.tryParse(value ?? '');

                          if (qty == null || qty <= 0) {
                            return 'Enter a quantity greater than 0';
                          }

                          final currentItem = selectedItem;
                          if (currentItem == null) return null;

                          final available = _availableForUnit(
                            currentItem,
                            selectedQtyUnit,
                            reason,
                          );

                          if (qty > available) {
                            final stockLabel = expiredRemoval
                                ? 'expired stock'
                                : 'usable stock';

                            return 'Only '
                                '${formatQty(available)} '
                                '${_dispenseUnitAbbr(currentItem, selectedQtyUnit)} '
                                '${selectedQtyUnit == QtyUnit.purchaseUnit && _hasPackageUnit(currentItem) ? 'equivalent ' : ''}'
                                '$stockLabel available';
                          }

                          // ====================================================
                          // PURCHASE -> PACKAGE CROSS-CHECK
                          // ====================================================

                          if (selectedQtyUnit == QtyUnit.purchaseUnit &&
                              _hasPackageUnit(currentItem)) {
                            final requiredPackageQty =
                                qty * currentItem.packageQuantity!;

                            final availablePackageQty =
                                _canonicalAvailable(
                              currentItem,
                              reason,
                            );

                            if (requiredPackageQty >
                                availablePackageQty) {
                              return '${formatQty(qty)} '
                                  '${currentItem.purchaseUnitAbbr} requires '
                                  '${formatQty(requiredPackageQty)} '
                                  '${currentItem.packageUnitAbbr}, but only '
                                  '${formatQty(availablePackageQty)} '
                                  '${currentItem.packageUnitAbbr} is available';
                            }
                          }

                          return null;
                        },
                      ),

                      // ========================================================
                      // DISPENSE UNIT
                      // ========================================================

                      if (hasPackageUnit) ...[
                        const SizedBox(height: 12),

                        AppDropdownField<QtyUnit>(
                          key: ValueKey(
                            '${target!.itemId}-${selectedQtyUnit.name}',
                          ),
                          label: 'Dispense Unit',
                          initialValue: selectedQtyUnit,
                          options: [
                            AppDropdownOption<QtyUnit>(
                              QtyUnit.packageUnit,
                              target.packageUnitAbbr!,
                            ),
                            AppDropdownOption<QtyUnit>(
                              QtyUnit.purchaseUnit,
                              target.purchaseUnitAbbr,
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedQtyUnit = value;

                              // Prevent old numeric input from silently changing
                              // meaning when unit changes.
                              qtyCtrl.clear();
                            });
                          },
                        ),

                        const SizedBox(height: 8),

                        // ======================================================
                        // UNIT HELPER
                        // ======================================================

                        Text(
                          selectedQtyUnit == QtyUnit.packageUnit
                              ? 'Dispense in ${target.packageUnitAbbr}. '
                                  '1 ${target.purchaseUnitAbbr} = '
                                  '${formatQty(target.packageQuantity!)} '
                                  '${target.packageUnitAbbr}.'
                              : 'Dispensing 1 ${target.purchaseUnitAbbr} '
                                  'uses ${formatQty(target.packageQuantity!)} '
                                  '${target.packageUnitAbbr}.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.mutedForeground,
                          ),
                        ),
                      ],

                      // ========================================================
                      // AVAILABLE IN SELECTED UNIT
                      // ========================================================

                      if (target != null) ...[
                        const SizedBox(height: 8),

                        Row(
                          children: [
                            Icon(
                              expiredRemoval
                                  ? Icons.error_outline
                                  : Icons.inventory_2_outlined,
                              size: 14,
                              color: expiredRemoval
                                  ? AppColors.destructive
                                  : AppColors.mutedForeground,
                            ),

                            const SizedBox(width: 5),

                            Expanded(
                              child: Text(
                                '${expiredRemoval ? 'Expired stock' : 'Available'} '
                                'in selected unit: '
                                '${formatQty(availableInSelectedUnit)} '
                                '$selectedUnitAbbr'
                                '${selectedQtyUnit == QtyUnit.purchaseUnit && hasPackageUnit ? ' equivalent' : ''}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: expiredRemoval
                                      ? AppColors.destructive
                                      : AppColors.mutedForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],

                    const SizedBox(height: 14),

                    // ==========================================================
                    // DISPENSE TYPE
                    // ==========================================================

                    AppDropdownField<String>(
                      label: 'Dispense Type',
                      initialValue: reason,
                      options: const [
                        AppDropdownOption(
                          'Waste',
                          'Waste',
                        ),
                        AppDropdownOption(
                          'Expired',
                          'Expired',
                        ),
                        AppDropdownOption(
                          'Adjustment',
                          'Adjustment',
                        ),
                        AppDropdownOption(
                          'Treatment',
                          'Treatment',
                        ),
                      ],

                      // ========================================================
                      // TYPE CHANGED
                      // ========================================================

                      onChanged: (value) {
                        setDialogState(() {
                          reason = value;

                          // The available stock pool changes when switching:
                          //
                          // Normal -> usable stock
                          // Expired -> expired stock
                          // Treatment -> separate treatment workflow
                          //
                          // Clear the old quantity so it cannot accidentally
                          // carry across to another stock pool.
                          qtyCtrl.clear();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // ==================================================================
            // ACTIONS
            // ==================================================================

            actions: [
              TextButton(
                onPressed: isSubmitting
                    ? null
                    : () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.destructive,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        // ======================================================
                        // VALIDATE
                        // ======================================================

                        if (!formKey.currentState!.validate()) return;

                        final target = selectedItem;
                        if (target == null) return;

                        // ======================================================
                        // TREATMENT
                        // ======================================================
                        //
                        // Treatment continues through the Medical Treatment
                        // workflow and does not directly call stockOut here.
                        // ======================================================

                        if (reason == 'Treatment') {
                          Navigator.of(dialogContext).pop(
                            (
                              target,
                              1.0,
                            ),
                          );

                          return;
                        }

                        final qty = double.parse(qtyCtrl.text);

                        setDialogState(() {
                          isSubmitting = true;
                        });

                        try {
                          // ====================================================
                          // EXISTING BACKEND STOCK OUT
                          // ====================================================
                          //
                          // SupabaseInventoryService now handles:
                          //
                          // Waste / Adjustment:
                          //   usable FEFO batches only
                          //
                          // Expired:
                          //   expired batches only
                          //
                          // Staff-entered qty + qtyUnit remain unchanged.
                          // ====================================================

                          await service.stockOut(
                            itemId: target.itemId,
                            qty: qty,
                            qtyUnit: selectedQtyUnit,
                            reason: stockOutReasonFromString(
                              reason.toLowerCase(),
                            ),
                            recordedByUserId: recordedByUserId,
                          );

                          if (!dialogContext.mounted) return;

                          // ====================================================
                          // SUCCESS
                          // ====================================================

                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                reason == 'Expired'
                                    ? 'Expired stock removed: '
                                        '${formatQty(qty)} '
                                        '${_dispenseUnitAbbr(target, selectedQtyUnit)}.'
                                    : 'Dispense recorded: '
                                        '${formatQty(qty)} '
                                        '${_dispenseUnitAbbr(target, selectedQtyUnit)}.',
                              ),
                            ),
                          );

                          Navigator.of(dialogContext).pop();
                        } catch (e) {
                          if (!dialogContext.mounted) return;

                          setDialogState(() {
                            isSubmitting = false;
                          });

                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                            ),
                          );
                        }
                      },

                // ==============================================================
                // SUBMIT LABEL
                // ==============================================================

                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        reason == 'Treatment'
                            ? 'Proceed'
                            : reason == 'Expired'
                                ? 'Remove Expired Stock'
                                : 'Record Dispense',
                      ),
              ),
            ],
          );
        },
      );
    },
  ).whenComplete(() {
    qtyCtrl.dispose();
  });
}