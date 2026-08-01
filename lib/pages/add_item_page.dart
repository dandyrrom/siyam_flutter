import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../models/donation.dart';
import '../models/inventory_item.dart';
import '../models/primary_category.dart';
import '../models/qty_unit.dart';
import '../models/subcategory.dart';
import '../models/supplier.dart';
import '../models/unit.dart';
import '../services/auth_service.dart';
import '../services/catalog_service.dart';
import '../services/donation_service.dart';
import '../services/inventory_service.dart';
import '../services/supplier_service.dart';
import '../state/auth_state.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/search_select_field.dart';

/// One "Item details" block's form state -- a Stock In Item submission can
/// cover several of these under one purchase/donation (the flow's
/// "+ Add Item" UI), each becoming its own purchase_item/donation_item row.
class _StockInLineItem {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController pCategoryCtrl = TextEditingController();
  final TextEditingController sCategoryCtrl = TextEditingController();
  final TextEditingController purchaseUnitCtrl = TextEditingController();
  final TextEditingController packageUnitCtrl = TextEditingController();
  final TextEditingController packageQuantityCtrl = TextEditingController();
  final TextEditingController dispenseUnitCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController costCtrl = TextEditingController();

  /// Set when this line is restocking an existing item (arrived via the
  /// Inventory list's "Stock In" row action) -- catalog fields are locked
  /// to that item rather than freely editable.
  InventoryItem? lockedItem;

  /// Set when the typed Name matches an existing item, so Save reuses it
  /// instead of creating a new `item` row. Treated the same as [lockedItem]
  /// for display purposes -- an existing item's catalog attributes aren't
  /// re-specified here.
  InventoryItem? matchedExistingItem;

  bool get isExistingItem => lockedItem != null || matchedExistingItem != null;
  InventoryItem? get existingItem => lockedItem ?? matchedExistingItem;

  PrimaryCategory? selectedPCategory;
  Subcategory? selectedSCategory;
  Unit? selectedPurchaseUnit;
  Unit? selectedPackageUnit;
  Unit? selectedDispenseUnit;

  /// Which unit [qtyCtrl]/[costCtrl] are entered in for this stock-in line.
  /// Only ever [QtyUnit.packageUnit] when the target item actually has a
  /// package breakdown -- see [hasPackageBreakdown].
  QtyUnit qtyUnit = QtyUnit.purchaseUnit;
  DateTime? expiryDate;

  /// Whether the target item (existing or being created here) has a
  /// package_unit/package_quantity breakdown -- gates the unit selector.
  bool get hasPackageBreakdown =>
      existingItem != null ? existingItem!.packageUnitId != null : selectedPackageUnit != null;

  /// Primary/sub category ids for the target item, existing or new.
  String? get pCategoryId => existingItem?.pCategoryId ?? selectedPCategory?.id;
  String? get sCategoryId => existingItem?.sCategoryId ?? selectedSCategory?.id;

  void dispose() {
    nameCtrl.dispose();
    pCategoryCtrl.dispose();
    sCategoryCtrl.dispose();
    purchaseUnitCtrl.dispose();
    packageUnitCtrl.dispose();
    packageQuantityCtrl.dispose();
    dispenseUnitCtrl.dispose();
    qtyCtrl.dispose();
    costCtrl.dispose();
  }
}

/// Resolves whether an expiry date is required for a line: the subcategory's
/// own override if it has one, else its parent primary category's setting
/// (manager-configurable, see updated_db.md's PRIMARY_CATEGORY/SUBCATEGORY
/// `requires_expiry`). Defaults to false if the category can't be found.
bool _resolveExpiryRequired(
  _StockInLineItem line,
  List<PrimaryCategory> primaryCategories,
  List<Subcategory> subcategories,
) {
  if (line.sCategoryId != null) {
    final sub = subcategories.where((s) => s.id == line.sCategoryId);
    if (sub.isNotEmpty && sub.first.requiresExpiry != null) {
      return sub.first.requiresExpiry!;
    }
  }
  final primary = primaryCategories.where((c) => c.id == line.pCategoryId);
  return primary.isEmpty ? false : primary.first.requiresExpiry;
}

/// Staff-only "Stock In Item" page. Records the full stock-in: the catalog
/// entry (if new) for each item line, plus either a purchase/purchase_item
/// batch or a donation/donation_item batch, and increments stock once per
/// item via that procurement call.
///
/// If [itemId] is provided (from the Inventory list's "Stock In" action),
/// the first line's Item details are pre-filled and locked to that
/// existing item -- this becomes a pure restock + procurement entry.
/// If [type] is provided (from the Inventory page's "New" menu), the
/// procurement type (purchased/donated) is preselected.
class AddItemPage extends StatefulWidget {
  final String? itemId;
  final String? type;
  final String? subId;
  const AddItemPage({super.key, this.itemId, this.type, this.subId});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final InventoryService _inventoryService = InventoryService();
  final SupplierService _supplierService = SupplierService();
  final DonationService _donationService = DonationService();
  final AuthService _authService = AuthService();
  final CatalogService _catalogService = CatalogService();

  final _formKey = GlobalKey<FormState>();
  final _receivedByCtrl = TextEditingController();
  final _donorNameCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  bool _saving = false;

  List<InventoryItem> _items = [];
  List<Supplier> _suppliers = [];
  List<AppUser> _receivers = []; // staff + manager
  List<DonationSubmission> _linkableSubmissions = [];
  List<PrimaryCategory> _primaryCategories = [];
  List<Subcategory> _subcategories = [];
  List<Unit> _units = [];

  final List<_StockInLineItem> _lines = [];

  String? _procurementType; // 'purchased' | 'donated'
  Supplier? _selectedSupplier;
  DonationType? _donationType;
  DonationSubmission? _selectedSubmission;
  AppUser? _selectedReceiver;
  DateTime _dateReceived = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.type == 'donated') _procurementType = 'donated';
    if (widget.type == 'purchased') _procurementType = 'purchased';
    _load();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _receivedByCtrl.dispose();
    _donorNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _inventoryService.fetchItems(),
        _supplierService.fetchSuppliers(),
        _authService.fetchUsersByRole([AppRole.staff, AppRole.manager]),
        _donationService.fetchLinkableSubmissions(),
        _catalogService.fetchPrimaryCategories(),
        _catalogService.fetchSubcategories(),
        _catalogService.fetchUnits(),
      ]);
      if (!mounted) return;

      final items = results[0] as List<InventoryItem>;
      InventoryItem? locked;
      if (widget.itemId != null) {
        locked = items.where((i) => i.itemId == widget.itemId).cast<InventoryItem?>().firstWhere(
              (i) => i != null,
              orElse: () => null,
            );
        locked ??= await _inventoryService.fetchItem(widget.itemId!);
      }

      final receivers = results[2] as List<AppUser>;

      final firstLine = _StockInLineItem();
      if (locked != null) {
        firstLine.lockedItem = locked;
        firstLine.matchedExistingItem = locked;
        firstLine.nameCtrl.text = locked.itemName;
      }

      final linkableSubmissions = results[3] as List<DonationSubmission>;
      DonationSubmission? preselectedSubmission;
      if (widget.subId != null) {
        preselectedSubmission = linkableSubmissions
            .where((s) => s.subId == widget.subId)
            .cast<DonationSubmission?>()
            .firstWhere((s) => s != null, orElse: () => null);
      }

      setState(() {
        _items = items;
        _suppliers = results[1] as List<Supplier>;
        _receivers = receivers;
        _linkableSubmissions = linkableSubmissions;
        _primaryCategories = results[4] as List<PrimaryCategory>;
        _subcategories = results[5] as List<Subcategory>;
        _units = results[6] as List<Unit>;
        if (preselectedSubmission != null) {
          _selectedSubmission = preselectedSubmission;
          _donorNameCtrl.text = preselectedSubmission.donorName;
          _donationType = DonationType.dropOff;
        }
        _lines
          ..clear()
          ..add(firstLine);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load form data: $e';
        _loading = false;
      });
    }
  }

  void _addLine() => setState(() => _lines.add(_StockInLineItem()));

  void _removeLine(_StockInLineItem line) {
    line.dispose();
    setState(() => _lines.remove(line));
  }

  /// Fills "Received by" with the logged-in user's first name -- for staff
  /// recording a stock-in they physically received themselves, rather than
  /// on someone else's behalf.
  void _useMyNameAsReceiver() {
    final profile = context.read<AuthController>().profile;
    if (profile == null) return;
    setState(() {
      _receivedByCtrl.text = profile.firstName;
      _selectedReceiver = profile;
    });
  }

  Future<void> _pickDateReceived() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateReceived,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateReceived = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final isPurchased = _procurementType == 'purchased';

    if (isPurchased && _selectedSupplier == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a supplier.')));
      return;
    }
    if (_selectedReceiver == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select who received the stock.')));
      return;
    }
    for (final line in _lines) {
      if (!line.isExistingItem &&
          (line.selectedPCategory == null || line.selectedPurchaseUnit == null)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Every new item needs a category and a purchase unit.')));
        return;
      }
      if (!line.isExistingItem &&
          line.selectedPackageUnit != null &&
          double.tryParse(line.packageQuantityCtrl.text.trim()) == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Enter how many package units per purchase unit.')));
        return;
      }
      final expiryRequired =
          _resolveExpiryRequired(line, _primaryCategories, _subcategories);
      if (expiryRequired && line.expiryDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${line.nameCtrl.text.trim().isEmpty ? 'This item' : line.nameCtrl.text.trim()} needs an expiry date.')));
        return;
      }
    }

    setState(() => _saving = true);
    final currentUserId = context.read<AuthController>().profile!.userId;
    try {
      final resolvedItemIds = <String>[];
      for (final line in _lines) {
        if (line.existingItem != null) {
          resolvedItemIds.add(line.existingItem!.itemId);
          continue;
        }
        final newItem = await _inventoryService.createItem(
          itemName: line.nameCtrl.text.trim(),
          pCategoryId: line.selectedPCategory!.id,
          sCategoryId: line.selectedSCategory?.id,
          purchaseUnitId: line.selectedPurchaseUnit!.id,
          packageUnitId: line.selectedPackageUnit?.id,
          packageQuantity: line.selectedPackageUnit == null
              ? null
              : double.parse(line.packageQuantityCtrl.text.trim()),
          dispenseUnitId: (line.selectedDispenseUnit ?? line.selectedPackageUnit)?.id,
        );
        resolvedItemIds.add(newItem.itemId);
      }

      if (isPurchased) {
        final items = [
          for (var i = 0; i < _lines.length; i++)
            OrderItemInput(
              itemId: resolvedItemIds[i],
              itemName: _lines[i].nameCtrl.text.trim(),
              itemUom: _lines[i].existingItem?.itemUom ?? _lines[i].purchaseUnitCtrl.text.trim(),
              qty: double.parse(_lines[i].qtyCtrl.text.trim()),
              unitCost: double.parse(_lines[i].costCtrl.text.trim()),
              qtyUnit: _lines[i].qtyUnit,
              expiryDate: _lines[i].expiryDate,
            ),
        ];
        await _supplierService.createPurchaseOrder(
          suppId: _selectedSupplier!.suppId,
          recordedByUserId: currentUserId,
          receivedBy: _receivedByCtrl.text.trim(),
          items: items,
          receivedDate: _dateReceived,
        );
      } else {
        final items = [
          for (var i = 0; i < _lines.length; i++)
            DonationItemInput(
              itemId: resolvedItemIds[i],
              itemName: _lines[i].nameCtrl.text.trim(),
              itemUom: _lines[i].existingItem?.itemUom ?? _lines[i].purchaseUnitCtrl.text.trim(),
              qty: double.parse(_lines[i].qtyCtrl.text.trim()),
              qtyUnit: _lines[i].qtyUnit,
              expiryDate: _lines[i].expiryDate,
            ),
        ];
        if (_selectedSubmission != null) {
          await _donationService.approveSubmission(
            subId: _selectedSubmission!.subId,
            donorId: _selectedSubmission!.donorId,
            updatedByUserId: currentUserId,
            receivedBy: _receivedByCtrl.text.trim(),
            items: items,
            type: _donationType!,
            receivedDate: _dateReceived,
          );
        } else {
          await _donationService.recordDirectDonation(
            donorName: _donorNameCtrl.text.trim().isEmpty ? null : _donorNameCtrl.text.trim(),
            recordedByUserId: currentUserId,
            receivedBy: _receivedByCtrl.text.trim(),
            items: items,
            type: _donationType!,
            receivedDate: _dateReceived,
          );
        }
      }

      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save item: $e')));
    }
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

    final isPurchased = _procurementType == 'purchased';
    final isDonated = _procurementType == 'donated';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('Back to Inventory'),
            style: TextButton.styleFrom(foregroundColor: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          const Text('Stock In Item',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(isPurchased
                    ? 'Purchase details'
                    : isDonated
                        ? 'Donation details'
                        : 'Procurement details'),
                Row(
                  children: [
                    Expanded(
                      child: AppDropdownField<String>(
                        label: 'Type *',
                        initialValue: _procurementType,
                        placeholder: 'Select type',
                        options: const [
                          AppDropdownOption('purchased', 'Purchased'),
                          AppDropdownOption('donated', 'Donated'),
                        ],
                        validator: (v) => v == null ? 'Required' : null,
                        onChanged: (v) => setState(() => _procurementType = v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: isPurchased
                          ? SearchSelectField<Supplier>(
                              labelText: 'Supplier *',
                              options: _suppliers,
                              displayStringForOption: (s) => s.suppName,
                              initialText: _selectedSupplier?.suppName,
                              onSelected: (s) => setState(() => _selectedSupplier = s),
                            )
                          : isDonated
                              ? AppDropdownField<DonationType>(
                                  label: 'Donation Type *',
                                  initialValue: _donationType,
                                  placeholder: 'Select donation type',
                                  options: const [
                                    AppDropdownOption(DonationType.walkIn, 'Walk-in'),
                                    AppDropdownOption(DonationType.dropOff, 'Dropped-off'),
                                  ],
                                  validator: (v) => v == null ? 'Required' : null,
                                  onChanged: (v) => setState(() => _donationType = v),
                                )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ),
                if (isDonated && _donationType == DonationType.dropOff) ...[
                  const SizedBox(height: 12),
                  _selectedSubmission == null
                      ? SearchSelectField<DonationSubmission>(
                          labelText: 'Submission ID *',
                          options: _linkableSubmissions,
                          displayStringForOption: (s) =>
                              '${s.subId} — ${s.donorName} — '
                              '${_formatDate(s.dateReceived!)}',
                          validator: (v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                          onSelected: (s) => setState(() {
                            _selectedSubmission = s;
                            _donorNameCtrl.text = s.donorName;
                          }),
                        )
                      : InputDecorator(
                          decoration: const InputDecoration(labelText: 'Submission ID *'),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(_selectedSubmission!.subId,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setState(() {
                                  _selectedSubmission = null;
                                  _donorNameCtrl.clear();
                                }),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 14,
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 12),
                  InputDecorator(
                    decoration: const InputDecoration(labelText: 'Donor'),
                    child: Text(
                      _selectedSubmission?.donorName ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                if (isDonated && _donationType == DonationType.walkIn) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _donorNameCtrl,
                    decoration: const InputDecoration(labelText: 'Donated by (optional)'),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDateReceived,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Date received'),
                          child: Text(_formatDate(_dateReceived)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SearchSelectField<AppUser>(
                            labelText: 'Received By *',
                            controller: _receivedByCtrl,
                            options: _receivers,
                            displayStringForOption: (u) => u.fullName,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? 'Required' : null,
                            onSelected: (u) => setState(() => _selectedReceiver = u),
                          ),
                          TextButton(
                            onPressed: _useMyNameAsReceiver,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              alignment: Alignment.centerLeft,
                            ),
                            child: const Text('I received this', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                for (final line in _lines)
                  _ItemDetailsBlock(
                    key: ValueKey(line),
                    line: line,
                    allItems: _items,
                    primaryCategories: _primaryCategories,
                    subcategories: _subcategories,
                    units: _units,
                    isPurchased: isPurchased,
                    showRemove: _lines.length > 1,
                    onRemove: () => _removeLine(line),
                    onChanged: () => setState(() {}),
                  ),
                if (widget.itemId == null)
                  TextButton.icon(
                    onPressed: _addLine,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Item'),
                  ),

                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => context.pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemDetailsBlock extends StatelessWidget {
  final _StockInLineItem line;
  final List<InventoryItem> allItems;
  final List<PrimaryCategory> primaryCategories;
  final List<Subcategory> subcategories;
  final List<Unit> units;
  final bool isPurchased;
  final bool showRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemDetailsBlock({
    super.key,
    required this.line,
    required this.allItems,
    required this.primaryCategories,
    required this.subcategories,
    required this.units,
    required this.isPurchased,
    required this.showRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final existing = line.existingItem;
    final subcategoryOptions = line.selectedPCategory == null
        ? subcategories
        : subcategories.where((s) => s.pCategoryId == line.selectedPCategory!.id).toList();
    final expiryRequired = _resolveExpiryRequired(line, primaryCategories, subcategories);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Item details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              if (showRemove)
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.close, size: 18),
                  splashRadius: 16,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (existing != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(existing.itemName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${existing.itemCategory} · ${existing.itemUom}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
                  Text('Current: ${formatQty(existing.stockQty)} ${existing.itemUom}',
                      style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            )
          else ...[
            SearchSelectField<InventoryItem>(
              labelText: 'Name',
              controller: line.nameCtrl,
              options: allItems,
              displayStringForOption: (i) => i.itemName,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              onTextChanged: (text) {
                final match = allItems
                    .where((i) => i.itemName.toLowerCase() == text.trim().toLowerCase());
                line.matchedExistingItem = match.isEmpty ? null : match.first;
                onChanged();
              },
              onSelected: (item) {
                line.matchedExistingItem = item;
                onChanged();
              },
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SearchSelectField<PrimaryCategory>(
                    labelText: 'Category',
                    controller: line.pCategoryCtrl,
                    options: primaryCategories,
                    displayStringForOption: (c) => c.type,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    onSelected: (c) {
                      line.selectedPCategory = c;
                      line.selectedSCategory = null;
                      line.sCategoryCtrl.clear();
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SearchSelectField<Subcategory>(
                    labelText: 'Subcategory (optional)',
                    controller: line.sCategoryCtrl,
                    options: subcategoryOptions,
                    displayStringForOption: (s) => s.type,
                    onSelected: (s) {
                      line.selectedSCategory = s;
                      if (line.selectedPCategory == null) {
                        final parent = primaryCategories
                            .where((c) => c.id == s.pCategoryId);
                        if (parent.isNotEmpty) {
                          line.selectedPCategory = parent.first;
                          line.pCategoryCtrl.text = parent.first.type;
                        }
                      }
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SearchSelectField<Unit>(
              labelText: 'Purchase unit (the container bought, e.g. box, bottle)',
              controller: line.purchaseUnitCtrl,
              options: units,
              displayStringForOption: (u) => u.name,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              onSelected: (u) {
                line.selectedPurchaseUnit = u;
                onChanged();
              },
            ),
            const SizedBox(height: 4),
            const Text(
              'Leave package unit blank for items with no breakdown (e.g. a mop) -- '
              'they stock out one purchase unit at a time.',
              style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SearchSelectField<Unit>(
                    labelText: 'Package unit (optional)',
                    controller: line.packageUnitCtrl,
                    options: units,
                    displayStringForOption: (u) => u.name,
                    onSelected: (u) {
                      line.selectedPackageUnit = u;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: line.packageQuantityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Package qty per purchase unit'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SearchSelectField<Unit>(
              labelText: 'Dispense unit (optional -- unit doses are recorded in)',
              controller: line.dispenseUnitCtrl,
              options: units,
              displayStringForOption: (u) => u.name,
              onSelected: (u) {
                line.selectedDispenseUnit = u;
                onChanged();
              },
            ),
          ],
          if (line.hasPackageBreakdown) ...[
            const SizedBox(height: 12),
            const Text('Stock in by', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Purchase unit (${_purchaseUnitLabel(line, existing)})'),
                  selected: line.qtyUnit == QtyUnit.purchaseUnit,
                  onSelected: (_) {
                    line.qtyUnit = QtyUnit.purchaseUnit;
                    onChanged();
                  },
                ),
                ChoiceChip(
                  label: Text('Package unit (${_packageUnitLabel(line, existing)})'),
                  selected: line.qtyUnit == QtyUnit.packageUnit,
                  onSelected: (_) {
                    line.qtyUnit = QtyUnit.packageUnit;
                    onChanged();
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: line.qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Quantity (${line.qtyUnit == QtyUnit.packageUnit ? _packageUnitLabel(line, existing) : _purchaseUnitLabel(line, existing)})'),
            validator: (v) {
              final n = double.tryParse(v ?? '');
              if (n == null || n <= 0) return 'Enter a quantity greater than 0';
              return null;
            },
          ),
          if (isPurchased) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: line.costCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Cost per ${line.qtyUnit == QtyUnit.packageUnit ? _packageUnitLabel(line, existing) : _purchaseUnitLabel(line, existing)}'),
              validator: (v) {
                if (!isPurchased) return null;
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0) return 'Enter a valid unit cost';
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: line.expiryDate ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                line.expiryDate = picked;
                onChanged();
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Expiry date${expiryRequired ? ' *' : ' (optional)'}',
                errorText: expiryRequired && line.expiryDate == null
                    ? 'Required for this category'
                    : null,
              ),
              child: Text(line.expiryDate == null
                  ? 'Select a date'
                  : _formatDate(line.expiryDate!)),
            ),
          ),
        ],
      ),
    );
  }
}

String _purchaseUnitLabel(_StockInLineItem line, InventoryItem? existing) =>
    existing?.purchaseUnitAbbr ?? line.selectedPurchaseUnit?.name ?? line.purchaseUnitCtrl.text;

String _packageUnitLabel(_StockInLineItem line, InventoryItem? existing) =>
    existing?.packageUnitAbbr ?? line.selectedPackageUnit?.name ?? line.packageUnitCtrl.text;

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
    );
  }
}

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
