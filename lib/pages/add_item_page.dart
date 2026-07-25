import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/donation.dart';
import '../models/inventory_item.dart';
import '../models/primary_category.dart';
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

  Future<void> _openAddSupplierDialog() async {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<Supplier>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Supplier'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Supplier name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: contactCtrl,
                  decoration: const InputDecoration(labelText: 'Contact number (optional)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address (optional)'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              try {
                final supplier = await _supplierService.createSupplier(
                  suppName: nameCtrl.text.trim(),
                  contactNum: contactCtrl.text.trim().isEmpty ? null : contactCtrl.text.trim(),
                  address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                );
                if (!context.mounted) return;
                Navigator.of(context).pop(supplier);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Could not add supplier: $e')));
              }
            },
            child: const Text('Add Supplier'),
          ),
        ],
      ),
    );

    if (created != null) {
      setState(() {
        _suppliers = [..._suppliers, created];
        _selectedSupplier = created;
      });
    }
  }

  /// Generic "type a name, add it" dialog used for creating a new category
  /// or unit inline, mirroring [_openAddSupplierDialog].
  Future<String?> _promptForText(String title, String label) async {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: ctrl,
            autofocus: true,
            decoration: InputDecoration(labelText: label),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(context).pop(ctrl.text.trim());
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPrimaryCategory(_StockInLineItem line) async {
    Navigator.of(context).maybePop();
    final name = await _promptForText('Add Category', 'Category name');
    if (name == null) return;
    final created = await _catalogService.createPrimaryCategory(name);
    if (!mounted) return;
    setState(() {
      _primaryCategories = [..._primaryCategories, created];
      line.selectedPCategory = created;
      line.pCategoryCtrl.text = created.type;
      line.selectedSCategory = null;
      line.sCategoryCtrl.clear();
    });
  }

  Future<void> _addSubcategory(_StockInLineItem line) async {
    Navigator.of(context).maybePop();
    if (line.selectedPCategory == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a category first.')));
      return;
    }
    final name = await _promptForText('Add Subcategory', 'Subcategory name');
    if (name == null) return;
    final created = await _catalogService.createSubcategory(
      pCategoryId: line.selectedPCategory!.id,
      type: name,
    );
    if (!mounted) return;
    setState(() {
      _subcategories = [..._subcategories, created];
      line.selectedSCategory = created;
      line.sCategoryCtrl.text = created.type;
    });
  }

  Future<void> _addUnit(
    _StockInLineItem line,
    TextEditingController targetCtrl,
    void Function(Unit) assign,
  ) async {
    Navigator.of(context).maybePop();
    final name = await _promptForText('Add Unit', 'Unit name (e.g. Milliliter, Tablet, Box)');
    if (name == null) return;
    final created = await _catalogService.createUnit(name);
    if (!mounted) return;
    setState(() {
      _units = [..._units, created];
      assign(created);
      targetCtrl.text = created.name;
    });
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
            ),
        ];
        if (_selectedSubmission != null) {
          await _donationService.approveSubmission(
            subId: _selectedSubmission!.subId,
            donorId: _selectedSubmission!.donorId,
            updatedByUserId: currentUserId,
            receivedBy: _receivedByCtrl.text.trim(),
            items: items,
            receivedDate: _dateReceived,
          );
        } else {
          await _donationService.recordDirectDonation(
            donorName: _donorNameCtrl.text.trim().isEmpty ? null : _donorNameCtrl.text.trim(),
            recordedByUserId: currentUserId,
            receivedBy: _receivedByCtrl.text.trim(),
            items: items,
            receivedDate: _dateReceived,
          );
        }
      }

      if (!mounted) return;
      context.go('/inventory');
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
            onPressed: () => context.go('/inventory'),
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
                        label: 'Type',
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
                              labelText: 'Supplier',
                              options: _suppliers,
                              displayStringForOption: (s) => s.suppName,
                              initialText: _selectedSupplier?.suppName,
                              onAddNew: () {
                                Navigator.of(context).maybePop();
                                _openAddSupplierDialog();
                              },
                              onSelected: (s) => setState(() => _selectedSupplier = s),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
                if (isDonated) ...[
                  const SizedBox(height: 12),
                  _selectedSubmission == null
                      ? SearchSelectField<DonationSubmission>(
                          labelText: 'Link to submission (optional)',
                          options: _linkableSubmissions,
                          displayStringForOption: (s) =>
                              '${s.subId} — ${s.donorName} — '
                              '${_formatDate(s.dateReceived!)}',
                          onSelected: (s) => setState(() {
                            _selectedSubmission = s;
                            _donorNameCtrl.text = s.donorName;
                          }),
                        )
                      : InputDecorator(
                          decoration:
                              const InputDecoration(labelText: 'Link to submission (optional)'),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                              ),
                            ],
                          ),
                        ),
                  if (_selectedSubmission == null) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Leave the submission link blank for a donor who isn\'t registered in '
                      'SIYAM -- type their name below for your records only.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.mutedForeground),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _donorNameCtrl,
                    readOnly: _selectedSubmission != null,
                    decoration: const InputDecoration(
                        labelText: 'Donor name (optional, for documentation only)'),
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
                            labelText: 'Received by',
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
                    onAddPrimaryCategory: () => _addPrimaryCategory(line),
                    onAddSubcategory: () => _addSubcategory(line),
                    onAddPurchaseUnit: () => _addUnit(
                        line, line.purchaseUnitCtrl, (u) => line.selectedPurchaseUnit = u),
                    onAddPackageUnit: () => _addUnit(
                        line, line.packageUnitCtrl, (u) => line.selectedPackageUnit = u),
                    onAddDispenseUnit: () => _addUnit(
                        line, line.dispenseUnitCtrl, (u) => line.selectedDispenseUnit = u),
                  ),
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
                      onPressed: _saving ? null : () => context.go('/inventory'),
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
  final VoidCallback onAddPrimaryCategory;
  final VoidCallback onAddSubcategory;
  final VoidCallback onAddPurchaseUnit;
  final VoidCallback onAddPackageUnit;
  final VoidCallback onAddDispenseUnit;

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
    required this.onAddPrimaryCategory,
    required this.onAddSubcategory,
    required this.onAddPurchaseUnit,
    required this.onAddPackageUnit,
    required this.onAddDispenseUnit,
  });

  @override
  Widget build(BuildContext context) {
    final existing = line.existingItem;
    final subcategoryOptions = line.selectedPCategory == null
        ? const <Subcategory>[]
        : subcategories.where((s) => s.pCategoryId == line.selectedPCategory!.id).toList();

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
                    onAddNew: onAddPrimaryCategory,
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
                    onAddNew: onAddSubcategory,
                    onSelected: (s) {
                      line.selectedSCategory = s;
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
              onAddNew: onAddPurchaseUnit,
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
                    onAddNew: onAddPackageUnit,
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
              onAddNew: onAddDispenseUnit,
              onSelected: (u) {
                line.selectedDispenseUnit = u;
                onChanged();
              },
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: line.qtyCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText:
                    'Quantity${existing == null ? '' : ' (${existing.itemUom})'}'),
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
              decoration: const InputDecoration(labelText: 'Cost'),
              validator: (v) {
                if (!isPurchased) return null;
                final n = double.tryParse(v ?? '');
                if (n == null || n < 0) return 'Enter a valid unit cost';
                return null;
              },
            ),
          ],
        ],
      ),
    );
  }
}

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
