import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../models/app_user.dart';
import '../models/donation.dart';
import '../models/inventory_item.dart';
import '../models/supplier.dart';
import '../services/auth_service.dart';
import '../services/donation_service.dart';
import '../services/inventory_service.dart';
import '../services/lookup_service.dart';
import '../services/supplier_service.dart';
import '../state/auth_state.dart';
import '../widgets/search_select_field.dart';

/// Strict TSS: the typed text must exactly match one of [options] --
/// there's no inline "add new" for category/UOM, so a value that isn't
/// already in the lookup table can't be saved.
String? _requireListMatch(String? v, List<String> options) {
  final value = v?.trim() ?? '';
  if (value.isEmpty) return 'Required';
  if (!options.contains(value)) return 'Select a value from the list';
  return null;
}

/// One "Item details" block's form state -- a Stock In Item submission can
/// cover several of these under one purchase_trans/donation (the flow's
/// "+ Add Item" UI), each becoming its own order_item/donation_item row.
class _StockInLineItem {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController categoryCtrl = TextEditingController();
  final TextEditingController qtyCtrl = TextEditingController();
  final TextEditingController unitCtrl = TextEditingController();
  final TextEditingController costCtrl = TextEditingController();

  /// Set when this line is restocking an existing item (arrived via the
  /// Inventory list's "Stock In" row action) -- name/category/unit are
  /// locked to that item rather than freely editable.
  InventoryItem? lockedItem;

  /// Set when the typed Name matches an existing item, so Save reuses it
  /// instead of creating a new `item` row.
  InventoryItem? matchedExistingItem;

  void dispose() {
    nameCtrl.dispose();
    categoryCtrl.dispose();
    qtyCtrl.dispose();
    unitCtrl.dispose();
    costCtrl.dispose();
  }
}

/// Staff-only "Stock In Item" page. Records the full stock-in: the
/// catalog entry (if new) for each item line, plus either a
/// purchase_trans/order_item batch or a donation/donation_item batch, and
/// increments stock once per item via that procurement call.
///
/// If [itemId] is provided (from the Inventory list's "Stock In" action),
/// the first line's Item details are pre-filled and locked to that
/// existing item -- this becomes a pure restock + procurement entry.
/// If [type] is provided (from the Inventory page's "New" menu), the
/// procurement type (purchased/donated) is preselected.
class AddItemPage extends StatefulWidget {
  final String? itemId;
  final String? type;
  const AddItemPage({super.key, this.itemId, this.type});

  @override
  State<AddItemPage> createState() => _AddItemPageState();
}

class _AddItemPageState extends State<AddItemPage> {
  final InventoryService _inventoryService = InventoryService();
  final SupplierService _supplierService = SupplierService();
  final DonationService _donationService = DonationService();
  final AuthService _authService = AuthService();
  final LookupService _lookupService = LookupService();

  final _formKey = GlobalKey<FormState>();
  final _receivedByCtrl = TextEditingController();

  bool _loading = true;
  String? _error;
  bool _saving = false;

  List<InventoryItem> _items = [];
  List<Supplier> _suppliers = [];
  List<AppUser> _donors = [];
  List<AppUser> _receivers = []; // staff + manager
  List<DonationSubmission> _linkableSubmissions = [];
  List<String> _categories = [];
  List<String> _uoms = [];

  final List<_StockInLineItem> _lines = [];

  String _procurementType = 'purchased'; // 'purchased' | 'donated'
  String _donationMode = 'walkin'; // 'walkin' | 'submission'
  Supplier? _selectedSupplier;
  AppUser? _selectedDonor;
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
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final currentUser = context.read<AuthController>().profile;
    try {
      final results = await Future.wait([
        _inventoryService.fetchItems(),
        _supplierService.fetchSuppliers(),
        _authService.fetchUsersByRole([AppRole.donor]),
        _authService.fetchUsersByRole([AppRole.staff, AppRole.manager]),
        _donationService.fetchLinkableSubmissions(),
        _lookupService.fetchCategories(),
        _lookupService.fetchUoms(),
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

      final receivers = results[3] as List<AppUser>;
      final defaultReceiver = currentUser == null
          ? null
          : receivers.where((u) => u.userId == currentUser.userId).cast<AppUser?>().firstWhere(
                (u) => u != null,
                orElse: () => currentUser,
              );

      final firstLine = _StockInLineItem();
      if (locked != null) {
        firstLine.lockedItem = locked;
        firstLine.matchedExistingItem = locked;
        firstLine.nameCtrl.text = locked.itemName;
        firstLine.categoryCtrl.text = locked.itemCategory;
        firstLine.unitCtrl.text = locked.itemUom;
      }

      setState(() {
        _items = items;
        _suppliers = results[1] as List<Supplier>;
        _donors = results[2] as List<AppUser>;
        _receivers = receivers;
        _linkableSubmissions = results[4] as List<DonationSubmission>;
        _categories = results[5] as List<String>;
        _uoms = results[6] as List<String>;
        _selectedReceiver = defaultReceiver;
        _receivedByCtrl.text = defaultReceiver?.fullName ?? '';
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

  List<String> get _categoryOptions => _categories;

  List<String> get _uomOptions => _uoms;

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
    if (!isPurchased && _donationMode == 'walkin' && _selectedDonor == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a donor.')));
      return;
    }
    if (!isPurchased && _donationMode == 'submission' && _selectedSubmission == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select a submission to link.')));
      return;
    }
    if (_selectedReceiver == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select who received the stock.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final resolvedItemIds = <String>[];
      for (final line in _lines) {
        String itemId;
        if (line.lockedItem != null) {
          itemId = line.lockedItem!.itemId;
        } else if (line.matchedExistingItem != null) {
          itemId = line.matchedExistingItem!.itemId;
        } else {
          final newItem = await _inventoryService.createItem(
            itemName: line.nameCtrl.text.trim(),
            itemCategory: line.categoryCtrl.text.trim(),
            itemUom: line.unitCtrl.text.trim(),
          );
          itemId = newItem.itemId;
        }
        resolvedItemIds.add(itemId);
      }

      if (isPurchased) {
        final items = [
          for (var i = 0; i < _lines.length; i++)
            OrderItemInput(
              itemId: resolvedItemIds[i],
              itemName: _lines[i].nameCtrl.text.trim(),
              itemUom: _lines[i].unitCtrl.text.trim(),
              qty: int.parse(_lines[i].qtyCtrl.text.trim()),
              unitCost: double.parse(_lines[i].costCtrl.text.trim()),
            ),
        ];
        await _supplierService.createPurchaseOrder(
          suppId: _selectedSupplier!.suppId,
          userId: _selectedReceiver!.userId,
          items: items,
          rcvdOn: _dateReceived,
        );
      } else {
        final items = [
          for (var i = 0; i < _lines.length; i++)
            DonationItemInput(
              itemId: resolvedItemIds[i],
              itemName: _lines[i].nameCtrl.text.trim(),
              itemUom: _lines[i].unitCtrl.text.trim(),
              qty: int.parse(_lines[i].qtyCtrl.text.trim()),
            ),
        ];
        if (_donationMode == 'submission') {
          await _donationService.approveSubmission(
            subId: _selectedSubmission!.subId,
            donorId: _selectedSubmission!.donorId,
            revById: _selectedReceiver!.userId,
            items: items,
          );
        } else {
          await _donationService.recordDirectDonation(
            donorId: _selectedDonor!.userId,
            rcvdById: _selectedReceiver!.userId,
            items: items,
            rcvdOn: _dateReceived,
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
                _SectionLabel(isPurchased ? 'Purchase details' : 'Donation details'),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _procurementType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: const [
                          DropdownMenuItem(value: 'purchased', child: Text('Purchased')),
                          DropdownMenuItem(value: 'donated', child: Text('Donated')),
                        ],
                        onChanged: (v) => setState(() => _procurementType = v ?? 'purchased'),
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
                if (!isPurchased) ...[
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'walkin', label: Text('Walk-in donation')),
                      ButtonSegment(value: 'submission', label: Text('Link to submission')),
                    ],
                    selected: {_donationMode},
                    onSelectionChanged: (s) => setState(() => _donationMode = s.first),
                  ),
                  const SizedBox(height: 12),
                  if (_donationMode == 'submission')
                    _selectedSubmission == null
                        ? SearchSelectField<DonationSubmission>(
                            labelText: 'Submission',
                            options: _linkableSubmissions,
                            displayStringForOption: (s) =>
                                '${s.donorName} — ${_formatDate(s.dateSub)}',
                            validator: (v) =>
                                _selectedSubmission == null ? 'Required' : null,
                            onSelected: (s) => setState(() => _selectedSubmission = s),
                          )
                        : Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('Donor: ${_selectedSubmission!.donorName}',
                                      style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  onPressed: () => setState(() => _selectedSubmission = null),
                                ),
                              ],
                            ),
                          )
                  else
                    SearchSelectField<AppUser>(
                      labelText: 'Donor',
                      options: _donors,
                      displayStringForOption: (u) => u.fullName,
                      initialText: _selectedDonor?.fullName,
                      onSelected: (u) => setState(() => _selectedDonor = u),
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
                      child: SearchSelectField<AppUser>(
                        labelText: 'Received by',
                        controller: _receivedByCtrl,
                        options: _receivers,
                        displayStringForOption: (u) => u.fullName,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        onSelected: (u) => setState(() => _selectedReceiver = u),
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
                    categoryOptions: _categoryOptions,
                    uomOptions: _uomOptions,
                    isPurchased: isPurchased,
                    showRemove: _lines.length > 1,
                    onRemove: () => _removeLine(line),
                    onChanged: () => setState(() {}),
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
  final List<String> categoryOptions;
  final List<String> uomOptions;
  final bool isPurchased;
  final bool showRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemDetailsBlock({
    super.key,
    required this.line,
    required this.allItems,
    required this.categoryOptions,
    required this.uomOptions,
    required this.isPurchased,
    required this.showRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locked = line.lockedItem != null;

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
          if (locked)
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
                        Text(line.lockedItem!.itemName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text('${line.lockedItem!.itemCategory} · ${line.lockedItem!.itemUom}',
                            style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
                  Text('Current: ${formatQty(line.lockedItem!.stockQty)} ${line.lockedItem!.itemUom}',
                      style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SearchSelectField<InventoryItem>(
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
                      line.categoryCtrl.text = item.itemCategory;
                      line.unitCtrl.text = item.itemUom;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SearchSelectField<String>(
                    labelText: 'Category',
                    controller: line.categoryCtrl,
                    options: categoryOptions,
                    displayStringForOption: (c) => c,
                    onSelected: (_) {},
                    validator: (v) => _requireListMatch(v, categoryOptions),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: line.qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) return 'Enter a quantity greater than 0';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: locked
                    ? TextFormField(
                        controller: line.unitCtrl,
                        enabled: false,
                        decoration: const InputDecoration(labelText: 'Unit'),
                      )
                    : SearchSelectField<String>(
                        labelText: 'Unit',
                        controller: line.unitCtrl,
                        options: uomOptions,
                        displayStringForOption: (u) => u,
                        onSelected: (_) {},
                        validator: (v) => _requireListMatch(v, uomOptions),
                      ),
              ),
            ],
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
