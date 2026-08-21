param(
    [string]$ProjectRoot = "."
)

$ErrorActionPreference = "Stop"

function Normalize-Lf([string]$text) {
    return $text.Replace("`r`n", "`n")
}

function Replace-Exact(
    [string]$text,
    [string]$old,
    [string]$new,
    [string]$label
) {
    $count = ($text.Split([string[]]@($old), [System.StringSplitOptions]::None).Count - 1)

    if ($count -ne 1) {
        throw "Treatment-stock fix stopped: expected exactly 1 match for '$label', found $count. No files were written."
    }

    return $text.Replace($old, $new)
}

$branch = (git -C $ProjectRoot branch --show-current).Trim()
if ($branch -ne "vernon") {
    throw "Treatment-stock fix stopped: current branch is '$branch'. Switch to 'vernon' first."
}

$targets = @(
    "lib/pages/add_treatment_page.dart",
    "lib/pages/animal_medical_history_page.dart",
    "lib/widgets/stock_out_dialog.dart",
    "lib/services/supabase/supabase_treatment_service.dart"
)

$updates = @{}

foreach ($relativePath in $targets) {
    $fullPath = Join-Path $ProjectRoot $relativePath

    if (-not (Test-Path $fullPath)) {
        throw "Treatment-stock fix stopped: missing file $relativePath. No files were written."
    }

    $updates[$relativePath] = Normalize-Lf (Get-Content -Raw -Path $fullPath)
}

# =============================================================================
# 1. ADD TREATMENT PAGE
# =============================================================================

$oldInputStock = @'
      deductible: item.stockOutIsDeductible,
      stockQty: item.stockQty,
      packageQuantity: item.packageQuantity,
      packageStockQty: item.packageStockQty,
      qty: qty,
'@

$newInputStock = @'
      deductible: item.stockOutIsDeductible,
      // Use CURRENT USABLE stock, not legacy aggregate stock.
      // Expired, quarantined and depleted batches are already excluded.
      stockQty: item.hasPackageBreakdown
          ? item.currentPurchaseUnitEquivalent
          : item.currentUsableStockQty,
      packageQuantity: item.packageQuantity,
      packageStockQty:
          item.hasPackageBreakdown ? item.currentUsableStockQty : null,
      qty: qty,
'@

$updates["lib/pages/add_treatment_page.dart"] = Replace-Exact `
    $updates["lib/pages/add_treatment_page.dart"] `
    $oldInputStock `
    $newInputStock `
    "Add Treatment current usable stock input"

$oldPrefill = @'
        if (match != null) {
          final qty = double.tryParse(widget.prefillQty ?? '') ?? 1;
          _itemRows.add(_inputFromItem(match, qty: qty));
        }
'@

$newPrefill = @'
        if (match != null && match.currentUsableStockQty > 0) {
          final qty = double.tryParse(widget.prefillQty ?? '') ?? 1;
          _itemRows.add(_inputFromItem(match, qty: qty));
        }
'@

$updates["lib/pages/add_treatment_page.dart"] = Replace-Exact `
    $updates["lib/pages/add_treatment_page.dart"] `
    $oldPrefill `
    $newPrefill `
    "Add Treatment prefill out-of-stock guard"

$oldAddRow = @'
  void _addItemRow() {
    final available = _items.where((i) => !_itemRows.any((r) => r.itemId == i.itemId)).toList();
    if (available.isEmpty) return;
    setState(() => _itemRows.add(_inputFromItem(available.first)));
  }
'@

$newAddRow = @'
  void _addItemRow() {
    final available = _items
        .where(
          (i) =>
              i.currentUsableStockQty > 0 &&
              !_itemRows.any((r) => r.itemId == i.itemId),
        )
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No in-stock inventory items are available.'),
        ),
      );
      return;
    }

    setState(() => _itemRows.add(_inputFromItem(available.first)));
  }
'@

$updates["lib/pages/add_treatment_page.dart"] = Replace-Exact `
    $updates["lib/pages/add_treatment_page.dart"] `
    $oldAddRow `
    $newAddRow `
    "Add Treatment in-stock Add Item guard"

$oldAddButton = @'
                      onPressed: _items.isEmpty ? null : _addItemRow,
'@

$newAddButton = @'
                      onPressed: _items.any(
                        (item) =>
                            item.currentUsableStockQty > 0 &&
                            !_itemRows.any((row) => row.itemId == item.itemId),
                      )
                          ? _addItemRow
                          : null,
'@

$updates["lib/pages/add_treatment_page.dart"] = Replace-Exact `
    $updates["lib/pages/add_treatment_page.dart"] `
    $oldAddButton `
    $newAddButton `
    "Add Treatment Add Item button availability"

$oldOptions = @'
                  options: items
                      .where((i) => i.itemId == row.itemId || !usedItemIds.contains(i.itemId))
                      .map((i) => AppDropdownOption(i.itemId, i.itemName))
                      .toList(),
'@

$newOptions = @'
                  options: items
                      .where(
                        (i) =>
                            i.currentUsableStockQty > 0 &&
                            (i.itemId == row.itemId ||
                                !usedItemIds.contains(i.itemId)),
                      )
                      .map(
                        (i) => AppDropdownOption(
                          i.itemId,
                          '${i.itemName} · ${formatQty(i.currentUsableStockQty)} '
                          '${i.currentUsableStockUnit} available',
                        ),
                      )
                      .toList(),
'@

$updates["lib/pages/add_treatment_page.dart"] = Replace-Exact `
    $updates["lib/pages/add_treatment_page.dart"] `
    $oldOptions `
    $newOptions `
    "Add Treatment item dropdown in-stock filter"

# =============================================================================
# 2. EXISTING TREATMENT -> ADD ITEM
# =============================================================================

$oldInventoryEmptyCheck = @'
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
'@

$newInventoryEmptyCheck = @'
    final usableInventoryItems = _inventoryItems
        .where(
          (item) => item.currentUsableStockQty > 0,
        )
        .toList();

    if (usableInventoryItems.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'No in-stock inventory items are available to add.',
          ),
        ),
      );

      return;
    }

    final currentUser =
'@

$updates["lib/pages/animal_medical_history_page.dart"] = Replace-Exact `
    $updates["lib/pages/animal_medical_history_page.dart"] `
    $oldInventoryEmptyCheck `
    $newInventoryEmptyCheck `
    "Existing treatment in-stock list"

$oldDialogItems = @'
        items:
            _inventoryItems,
'@

$newDialogItems = @'
        items:
            usableInventoryItems,
'@

$updates["lib/pages/animal_medical_history_page.dart"] = Replace-Exact `
    $updates["lib/pages/animal_medical_history_page.dart"] `
    $oldDialogItems `
    $newDialogItems `
    "Existing treatment filtered dialog items"

# Two canAddItem occurrences, so handle separately with direct count check.
$oldCanAdd = @'
                        canAddItem:
                            _inventoryItems
                                .isNotEmpty,
'@
$countCanAdd = ($updates["lib/pages/animal_medical_history_page.dart"].Split(
    [string[]]@($oldCanAdd),
    [System.StringSplitOptions]::None
).Count - 1)

if ($countCanAdd -ne 2) {
    throw "Treatment-stock fix stopped: expected exactly 2 canAddItem blocks, found $countCanAdd. No files were written."
}

$newCanAdd = @'
                        canAddItem:
                            _inventoryItems.any(
                          (item) =>
                              item.currentUsableStockQty > 0,
                        ),
'@

$updates["lib/pages/animal_medical_history_page.dart"] =
    $updates["lib/pages/animal_medical_history_page.dart"].Replace(
        $oldCanAdd,
        $newCanAdd
    )

$oldExistingInput = @'
      deductible:
          item.stockOutIsDeductible,
      stockQty:
          item.stockQty,
      packageQuantity:
          item.packageQuantity,
      packageStockQty:
          item.packageStockQty,
      qty: qty,
'@

$newExistingInput = @'
      deductible:
          item.stockOutIsDeductible,
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
'@

$updates["lib/pages/animal_medical_history_page.dart"] = Replace-Exact `
    $updates["lib/pages/animal_medical_history_page.dart"] `
    $oldExistingInput `
    $newExistingInput `
    "Existing treatment current usable stock input"

$oldMaxDose = @'
    final packageQuantity =
        item.packageQuantity;

    if (packageQuantity ==
        null) {
      return item.stockQty;
    }

    return item.packageStockQty ??
        item.stockQty *
            packageQuantity;
'@

$newMaxDose = @'
    return item.currentUsableStockQty;
'@

$updates["lib/pages/animal_medical_history_page.dart"] = Replace-Exact `
    $updates["lib/pages/animal_medical_history_page.dart"] `
    $oldMaxDose `
    $newMaxDose `
    "Existing treatment current usable max dose"

$oldExistingOptions = @'
                  options:
                      widget.items,
'@

$newExistingOptions = @'
                  options:
                      widget.items
                          .where(
                            (item) =>
                                item.currentUsableStockQty > 0,
                          )
                          .toList(),
'@

$updates["lib/pages/animal_medical_history_page.dart"] = Replace-Exact `
    $updates["lib/pages/animal_medical_history_page.dart"] `
    $oldExistingOptions `
    $newExistingOptions `
    "Existing treatment item picker in-stock filter"

# =============================================================================
# 3. DISPENSE DIALOG -> TREATMENT
# =============================================================================

$oldTreatmentProceed = @'
                        if (reason == 'Treatment') {
                          Navigator.of(dialogContext).pop(
                            (
                              target,
                              1.0,
                            ),
                          );

                          return;
                        }
'@

$newTreatmentProceed = @'
                        if (reason == 'Treatment') {
                          if (target.currentUsableStockQty <= 0) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${target.itemName} is out of stock and cannot '
                                  'be used for a treatment.',
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.of(dialogContext).pop(
                            (
                              target,
                              1.0,
                            ),
                          );

                          return;
                        }
'@

$updates["lib/widgets/stock_out_dialog.dart"] = Replace-Exact `
    $updates["lib/widgets/stock_out_dialog.dart"] `
    $oldTreatmentProceed `
    $newTreatmentProceed `
    "Dispense Treatment out-of-stock guard"

# =============================================================================
# 4. SUPABASE SERVICE-LEVEL GUARD
#    Prevent stale/bypassed UI from creating treatment usage for no stock.
#    Pre-validates BEFORE inserting the treatment parent or treatment_item.
# =============================================================================

$oldImports = @'
import '../../models/pet.dart';
import '../../models/treatment.dart';
'@

$newImports = @'
import '../../models/inventory_item.dart';
import '../../models/pet.dart';
import '../../models/treatment.dart';
'@

$updates["lib/services/supabase/supabase_treatment_service.dart"] = Replace-Exact `
    $updates["lib/services/supabase/supabase_treatment_service.dart"] `
    $oldImports `
    $newImports `
    "Supabase treatment InventoryItem import"

$oldHelperAnchor = @'
  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select('id, abbr_name');
    return {
      for (final r in rows) r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

'@

$newHelperAnchor = @'
  Future<Map<String, String>> _unitAbbrMap() async {
    final rows = await _client.from('units').select('id, abbr_name');
    return {
      for (final r in rows) r['id'] as String: (r['abbr_name'] as String?) ?? '',
    };
  }

  // ==========================================================================
  // TREATMENT STOCK VALIDATION
  // ==========================================================================
  //
  // UI filtering is helpful, but stock can change after the page loads.
  // Always re-read inventory immediately before writing treatment records.
  //
  Future<InventoryItem> _validateTreatmentStock(
    TreatmentItemInput input,
  ) async {
    if (input.qty <= 0) {
      throw Exception('Treatment quantity must be greater than 0.');
    }

    final item = await _inventoryService.fetchItem(input.itemId);

    if (item == null) {
      throw Exception('${input.itemName} is no longer available in inventory.');
    }

    final available = item.currentUsableStockQty;

    if (available <= 0) {
      throw Exception(
        '${item.itemName} is out of stock and cannot be used for a treatment.',
      );
    }

    // When SIYAM knows the dispense/package conversion, requested treatment
    // quantity and currentUsableStockQty are in the same canonical unit.
    if (item.stockOutIsDeductible && input.qty > available) {
      throw Exception(
        'Not enough usable stock for ${item.itemName}. Only '
        '${formatQty(available)} ${item.currentUsableStockUnit} available.',
      );
    }

    return item;
  }

'@

$updates["lib/services/supabase/supabase_treatment_service.dart"] = Replace-Exact `
    $updates["lib/services/supabase/supabase_treatment_service.dart"] `
    $oldHelperAnchor `
    $newHelperAnchor `
    "Supabase treatment stock validation helper"

$oldCreateStart = @'
  }) async {
    final consumedDate = (dateAdministered ?? DateTime.now()).toUtc();

    final treatment = await _client
'@

$newCreateStart = @'
  }) async {
    final consumedDate = (dateAdministered ?? DateTime.now()).toUtc();

    // Validate every requested item BEFORE creating the treatment record.
    // This prevents an out-of-stock item from leaving behind a false
    // treatment/treatment_item row when FEFO deduction rejects it.
    final validatedItems =
        <(TreatmentItemInput, InventoryItem)>[];

    for (final row in items) {
      if (row.qty <= 0) continue;

      final inventoryItem =
          await _validateTreatmentStock(row);

      validatedItems.add(
        (row, inventoryItem),
      );
    }

    if (validatedItems.isEmpty) {
      throw Exception(
        'Add at least one in-stock inventory item to the treatment.',
      );
    }

    final treatment = await _client
'@

$updates["lib/services/supabase/supabase_treatment_service.dart"] = Replace-Exact `
    $updates["lib/services/supabase/supabase_treatment_service.dart"] `
    $oldCreateStart `
    $newCreateStart `
    "Supabase createTreatment prevalidation"

$oldCreateLoop = @'
    for (final row in items) {
      if (row.qty <= 0) continue;
      final item = await _inventoryService.fetchItem(row.itemId);
      if (item == null) continue;

      await _client.from('treatment_item').insert({
        'treatid': treatId,
        'itemid': row.itemId,
        'dispensed_qty': row.qty,
        'dispense_unit': row.doseUnitId,
        'consumeddate': consumedDate.toIso8601String(),
        'givenby': administeredByName,
        'recordedby': performedByUserId,
      });

      await applyTreatmentDeduction(_inventoryService, item, row.qty);
    }
'@

$newCreateLoop = @'
    for (final validated in validatedItems) {
      final row = validated.$1;
      final item = validated.$2;

      await _client.from('treatment_item').insert({
        'treatid': treatId,
        'itemid': row.itemId,
        'dispensed_qty': row.qty,
        'dispense_unit': row.doseUnitId,
        'consumeddate': consumedDate.toIso8601String(),
        'givenby': administeredByName,
        'recordedby': performedByUserId,
      });

      await applyTreatmentDeduction(_inventoryService, item, row.qty);
    }
'@

$updates["lib/services/supabase/supabase_treatment_service.dart"] = Replace-Exact `
    $updates["lib/services/supabase/supabase_treatment_service.dart"] `
    $oldCreateLoop `
    $newCreateLoop `
    "Supabase createTreatment validated loop"

$oldAddItemValidation = @'
    if (item.qty <= 0) return;
    final invItem = await _inventoryService.fetchItem(item.itemId);
    if (invItem == null) throw Exception('Item not found');

    final consumedDate = (dateAdministered ?? DateTime.now()).toUtc();
'@

$newAddItemValidation = @'
    if (item.qty <= 0) {
      throw Exception('Treatment quantity must be greater than 0.');
    }

    // Re-check live usable stock before inserting the treatment_item row.
    final invItem = await _validateTreatmentStock(item);

    final consumedDate = (dateAdministered ?? DateTime.now()).toUtc();
'@

$updates["lib/services/supabase/supabase_treatment_service.dart"] = Replace-Exact `
    $updates["lib/services/supabase/supabase_treatment_service.dart"] `
    $oldAddItemValidation `
    $newAddItemValidation `
    "Supabase addTreatmentItem prevalidation"

# =============================================================================
# WRITE ONLY AFTER ALL CHECKS PASS
# =============================================================================

foreach ($relativePath in $targets) {
    $fullPath = Join-Path $ProjectRoot $relativePath
    [System.IO.File]::WriteAllText(
        (Resolve-Path $fullPath),
        $updates[$relativePath],
        (New-Object System.Text.UTF8Encoding($false))
    )
}

Write-Host ""
Write-Host "Treatment stock guard applied successfully." -ForegroundColor Green
Write-Host ""
Write-Host "What is now blocked:"
Write-Host "  - Out-of-stock items in Add Treatment"
Write-Host "  - Out-of-stock items when adding an item to an existing treatment"
Write-Host "  - Out-of-stock Treatment flow from the Dispense dialog"
Write-Host "  - Stale/bypassed UI requests at Supabase service level"
Write-Host ""
Write-Host "Run git diff and test before committing."