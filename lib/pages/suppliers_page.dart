import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/validators.dart';
import '../models/supplier.dart';
import '../services/supplier_service.dart';
import '../state/data_bus.dart';
import '../widgets/app_dropdown.dart';
import '../widgets/stat_card.dart';

const Color _supplierModalSurface = Color(0xFFFFFFFF);
const Color _supplierModalSoft = Color(0xFFF7F7F5);
const Color _supplierModalBorder = Color(0xFFE7E5E1);

// =============================================================================
// SUPPLIER LIST SORT / FILTER
// =============================================================================
//
// These only affect presentation of the already-loaded supplier list.
// No supplier, purchase, or Supabase data is modified.
// =============================================================================

enum _SupplierSortOption {
  nameAZ,
  nameZA,
  mostOrders,
  leastOrders,
  latestOrder,
}

enum _SupplierOrderFilter {
  all,
  withOrders,
  noOrders,
}

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage>
    with DataBusRefreshMixin<SuppliersPage> {
  final SupplierService _service = SupplierService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Supplier> _suppliers = [];
  List<PurchaseOrder> _allOrders = [];

  bool _loading = true;
  String? _error;
  String _search = '';
  _SupplierSortOption _sortOption = _SupplierSortOption.nameAZ;
  _SupplierOrderFilter _orderFilter = _SupplierOrderFilter.all;
  bool _supplierDetailDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _service.fetchSuppliers(),
        _service.fetchAllPurchaseOrders(),
      ]);

      if (!mounted) return;

      setState(() {
        _suppliers = results[0] as List<Supplier>;
        _allOrders = results[1] as List<PurchaseOrder>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'Could not load suppliers: $e';
          _loading = false;
        });
      }
    }
  }

  String _cleanSupplierName(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');

  String _supplierNameKey(String value) =>
      _cleanSupplierName(value).toLowerCase();

  String? _validateSupplierName(
    String? value, {
    Supplier? editingSupplier,
  }) {
    if (value == null || value.trim().isEmpty) return 'Required';

    final targetKey = _supplierNameKey(value);
    final duplicate = _suppliers.any(
      (existing) =>
          existing.suppId != editingSupplier?.suppId &&
          _supplierNameKey(existing.suppName) == targetKey,
    );

    return duplicate ? 'A supplier with this name already exists' : null;
  }

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  List<PurchaseOrder> _ordersFor(String suppId) => _allOrders
      .where((order) => order.suppId == suppId)
      .toList();

  int _orderCountFor(Supplier supplier) => _allOrders
      .where((order) => order.suppId == supplier.suppId)
      .length;

  DateTime? _latestOrderDateFor(Supplier supplier) {
    DateTime? latest;
    for (final order in _allOrders) {
      if (order.suppId != supplier.suppId) continue;
      if (latest == null || order.receivedDate.isAfter(latest)) {
        latest = order.receivedDate;
      }
    }
    return latest;
  }

  Supplier? _supplierForOrder(PurchaseOrder order) {
    for (final supplier in _suppliers) {
      if (supplier.suppId == order.suppId) return supplier;
    }
    return null;
  }

  bool get _hasActiveListFilter =>
      _search.trim().isNotEmpty || _orderFilter != _SupplierOrderFilter.all;

  bool get _hasNonDefaultControls =>
      _hasActiveListFilter || _sortOption != _SupplierSortOption.nameAZ;

  List<Supplier> get _filtered {
    final query = _search.trim().toLowerCase();

    final rows = _suppliers.where((supplier) {
      final matchesSearch = query.isEmpty ||
          supplier.suppName.toLowerCase().contains(query) ||
          (supplier.address ?? '').toLowerCase().contains(query) ||
          (supplier.contactNum ?? '').toLowerCase().contains(query) ||
          (supplier.contactTel ?? '').toLowerCase().contains(query);

      if (!matchesSearch) return false;

      final count = _orderCountFor(supplier);
      switch (_orderFilter) {
        case _SupplierOrderFilter.all:
          return true;
        case _SupplierOrderFilter.withOrders:
          return count > 0;
        case _SupplierOrderFilter.noOrders:
          return count == 0;
      }
    }).toList();

    int byName(Supplier a, Supplier b) =>
        a.suppName.toLowerCase().compareTo(b.suppName.toLowerCase());

    rows.sort((a, b) {
      switch (_sortOption) {
        case _SupplierSortOption.nameAZ:
          return byName(a, b);
        case _SupplierSortOption.nameZA:
          return byName(b, a);
        case _SupplierSortOption.mostOrders:
          final c = _orderCountFor(b).compareTo(_orderCountFor(a));
          return c != 0 ? c : byName(a, b);
        case _SupplierSortOption.leastOrders:
          final c = _orderCountFor(a).compareTo(_orderCountFor(b));
          return c != 0 ? c : byName(a, b);
        case _SupplierSortOption.latestOrder:
          final aDate = _latestOrderDateFor(a);
          final bDate = _latestOrderDateFor(b);
          if (aDate == null && bDate == null) return byName(a, b);
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          final c = bDate.compareTo(aDate);
          return c != 0 ? c : byName(a, b);
      }
    });

    return rows;
  }

  String get _supplierCountLabel => _hasActiveListFilter
      ? 'Showing ${_filtered.length} of ${_suppliers.length} suppliers'
      : '${_suppliers.length} suppliers';

  String _sortOptionLabel(_SupplierSortOption option) {
    switch (option) {
      case _SupplierSortOption.nameAZ:
        return 'A–Z';
      case _SupplierSortOption.nameZA:
        return 'Z–A';
      case _SupplierSortOption.mostOrders:
        return 'Most Orders';
      case _SupplierSortOption.leastOrders:
        return 'Least Orders';
      case _SupplierSortOption.latestOrder:
        return 'Latest Order';
    }
  }

  String _orderFilterLabel(_SupplierOrderFilter filter) {
    switch (filter) {
      case _SupplierOrderFilter.all:
        return 'All Suppliers';
      case _SupplierOrderFilter.withOrders:
        return 'With Orders';
      case _SupplierOrderFilter.noOrders:
        return 'No Orders Yet';
    }
  }

  void _resetSupplierControls() {
    _searchCtrl.clear();
    setState(() {
      _search = '';
      _sortOption = _SupplierSortOption.nameAZ;
      _orderFilter = _SupplierOrderFilter.all;
    });
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.sageGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _openSupplierFormDialog({Supplier? supplier}) async {
    final isEdit = supplier != null;
    final nameCtrl = TextEditingController(text: supplier?.suppName ?? '');
    final contactCtrl = TextEditingController(text: supplier?.contactNum ?? '');
    final contactTelCtrl = TextEditingController(text: supplier?.contactTel ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            final screen = MediaQuery.sizeOf(builderContext);
            final contentWidth = screen.width < 520 ? screen.width - 96 : 420.0;
            final contentHeight = screen.height < 700 ? screen.height * 0.52 : 390.0;

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(isEdit ? 'Edit Supplier' : 'Add Supplier'),
              content: SizedBox(
                width: contentWidth,
                height: contentHeight,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          autofocus: !isEdit,
                          decoration: const InputDecoration(labelText: 'Supplier name'),
                          validator: (value) => _validateSupplierName(
                            value,
                            editingSupplier: supplier,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contactCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: phoneInputFormatters,
                          maxLength: 11,
                          decoration: const InputDecoration(
                            labelText: 'Contact number (optional)',
                            hintText: '09XXXXXXXXX',
                            helperText: 'Enter exactly 11 digits, starting with 09',
                            counterText: '',
                          ),
                          validator: validatePhoneNumber,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: contactTelCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Contact tel (optional)',
                            hintText: 'Landline number',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressCtrl,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Address (optional)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(builderContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => saving = true);

                          final cleanName = _cleanSupplierName(nameCtrl.text);
                          final cleanPhone = contactCtrl.text.trim().isEmpty
                              ? null
                              : contactCtrl.text.trim();
                          final cleanTel = contactTelCtrl.text.trim().isEmpty
                              ? null
                              : contactTelCtrl.text.trim();
                          final cleanAddress = addressCtrl.text.trim().isEmpty
                              ? null
                              : addressCtrl.text.trim();

                          try {
                            if (isEdit) {
                              await _service.updateSupplier(
                                suppId: supplier!.suppId,
                                suppName: cleanName,
                                contactNum: cleanPhone,
                                contactTel: cleanTel,
                                address: cleanAddress,
                              );
                            } else {
                              await _service.createSupplier(
                                suppName: cleanName,
                                contactNum: cleanPhone,
                                contactTel: cleanTel,
                                address: cleanAddress,
                              );
                            }

                            if (!builderContext.mounted) return;
                            Navigator.of(builderContext).pop();
                            if (!mounted) return;

                            _showSuccessSnackBar(
                              isEdit
                                  ? '$cleanName updated successfully'
                                  : '$cleanName added successfully',
                            );
                            await _load();
                          } catch (e) {
                            if (!builderContext.mounted) return;
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(builderContext).clearSnackBars();
                            ScaffoldMessenger.of(builderContext).showSnackBar(
                              SnackBar(
                                content: Text(_cleanError(e)),
                                backgroundColor: AppColors.destructive,
                              ),
                            );
                          }
                        },
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEdit ? 'Save Changes' : 'Add Supplier'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    contactCtrl.dispose();
    contactTelCtrl.dispose();
    addressCtrl.dispose();
  }

  Future<void> _openSupplierDirectoryDialog() async {
    final directory = List<Supplier>.from(_suppliers)
      ..sort((a, b) => a.suppName.toLowerCase().compareTo(b.suppName.toLowerCase()));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screen = MediaQuery.sizeOf(dialogContext);
        final width = screen.width < 600 ? screen.width - 32 : 560.0;
        final height = screen.height < 720 ? screen.height * 0.78 : 600.0;

        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              children: [
                _DirectoryDialogHeader(
                  icon: Icons.local_shipping_outlined,
                  title: 'Supplier Directory',
                  subtitle: '${directory.length} supplier${directory.length == 1 ? '' : 's'}',
                  onClose: () => Navigator.of(dialogContext).pop(),
                ),
                const Divider(height: 1),
                Expanded(
                  child: directory.isEmpty
                      ? const Center(
                          child: Text(
                            'No suppliers yet.',
                            style: TextStyle(color: AppColors.mutedForeground),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: directory.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final supplier = directory[index];
                            final orders = _ordersFor(supplier.suppId);
                            return _DirectorySupplierRow(
                              supplier: supplier,
                              orderCount: orders.length,
                              onTap: () {
                                Navigator.of(dialogContext).pop();
                                Future<void>.delayed(Duration.zero, () {
                                  if (mounted) _openDetailDialog(supplier);
                                });
                              },
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

  // ===========================================================================
  // TOTAL PURCHASE ORDERS CARD
  // ===========================================================================
  //
  // Suppliers is a Manager page while Ordering is Staff-only.
  // Therefore this card opens a read-only purchase overview here instead of
  // routing the Manager into the Staff Ordering module.
  // ===========================================================================

  Future<void> _openPurchaseOrdersDirectoryDialog() async {
    final orders = List<PurchaseOrder>.from(_allOrders)
      ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screen = MediaQuery.sizeOf(dialogContext);
        final width = screen.width < 700 ? screen.width - 32 : 650.0;
        final height = screen.height < 720 ? screen.height * 0.78 : 620.0;

        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: SizedBox(
            width: width,
            height: height,
            child: Column(
              children: [
                _DirectoryDialogHeader(
                  icon: Icons.receipt_long_outlined,
                  title: 'Purchase Orders',
                  subtitle: '${orders.length} recorded purchase ${orders.length == 1 ? 'order' : 'orders'}',
                  onClose: () => Navigator.of(dialogContext).pop(),
                ),
                const Divider(height: 1),
                Expanded(
                  child: orders.isEmpty
                      ? const Center(
                          child: Text(
                            'No purchase orders yet.',
                            style: TextStyle(color: AppColors.mutedForeground),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            final supplier = _supplierForOrder(order);
                            return _DirectoryPurchaseRow(
                              order: order,
                              canOpenSupplier: supplier != null,
                              onTap: supplier == null
                                  ? null
                                  : () {
                                      Navigator.of(dialogContext).pop();
                                      Future<void>.delayed(Duration.zero, () {
                                        if (mounted) _openDetailDialog(supplier);
                                      });
                                    },
                            );
                          },
                        ),
                ),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Select a purchase row to open that supplier’s details.',
                      style: TextStyle(fontSize: 10.8, color: AppColors.mutedForeground),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_SupplierPurchaseDetails> _loadSupplierPurchaseDetails(
    List<PurchaseOrder> orders,
  ) async {
    final itemsByOrder = <String, List<OrderLineItem>>{};

    if (orders.isEmpty) {
      return const _SupplierPurchaseDetails(
        itemsByOrder: <String, List<OrderLineItem>>{},
        purchasedItems: <_PurchasedItemSummary>[],
      );
    }

    final itemLists = await Future.wait(
      orders.map((order) => _service.fetchOrderItems(order.purId)),
    );

    for (var i = 0; i < orders.length; i++) {
      itemsByOrder[orders[i].purId] = itemLists[i];
    }

    final purchasedItemMap = <String, _PurchasedItemSummary>{};

    for (final order in orders) {
      final items = itemsByOrder[order.purId] ?? const <OrderLineItem>[];
      for (final item in items) {
        final key = '${item.itemId}|${item.itemUom}';
        final existing = purchasedItemMap[key];

        if (existing == null) {
          purchasedItemMap[key] = _PurchasedItemSummary(
            itemName: item.itemName,
            itemUom: item.itemUom,
            totalQty: item.qty,
            orderCount: 1,
          );
        } else {
          purchasedItemMap[key] = _PurchasedItemSummary(
            itemName: existing.itemName,
            itemUom: existing.itemUom,
            totalQty: existing.totalQty + item.qty,
            orderCount: existing.orderCount + 1,
          );
        }
      }
    }

    final purchasedItems = purchasedItemMap.values.toList()
      ..sort(
        (a, b) => a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()),
      );

    return _SupplierPurchaseDetails(
      itemsByOrder: itemsByOrder,
      purchasedItems: purchasedItems,
    );
  }

  Future<void> _openDetailDialog(Supplier supplier) async {
    if (_supplierDetailDialogOpen) return;
    _supplierDetailDialogOpen = true;

    final orders = _ordersFor(supplier.suppId)
      ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));

    final purchaseDetailsFuture = _loadSupplierPurchaseDetails(orders);

    final staffNames = orders
        .map((order) => order.buyerName.trim())
        .where((name) => name.isNotEmpty && name != 'Unknown user')
        .toSet()
        .toList()
      ..sort();

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final screen = MediaQuery.sizeOf(dialogContext);
          final contentWidth = screen.width < 600 ? screen.width - 64 : 540.0;
          final maxContentHeight = screen.height < 700 ? screen.height * 0.64 : 570.0;

          return AlertDialog(
            backgroundColor: _supplierModalSurface,
            surfaceTintColor: Colors.transparent,
            elevation: 10,
            insetPadding: const EdgeInsets.all(20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: _supplierModalBorder),
            ),
            titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 14),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.sageGreen.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    size: 21,
                    color: AppColors.sageGreen,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        supplier.suppName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.foreground,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Supplier details',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: contentWidth,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxContentHeight),
                child: FutureBuilder<_SupplierPurchaseDetails>(
                  future: purchaseDetailsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 230,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text(
                                'Loading supplier details...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return SizedBox(
                        height: 230,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 34,
                                color: AppColors.destructive,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Could not load purchased items.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _cleanError(snapshot.error!),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final purchaseDetails = snapshot.data ??
                        const _SupplierPurchaseDetails(
                          itemsByOrder: <String, List<OrderLineItem>>{},
                          purchasedItems: <_PurchasedItemSummary>[],
                        );

                    final itemsByOrder = purchaseDetails.itemsByOrder;
                    final purchasedItems = purchaseDetails.purchasedItems;

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 15, 16, 7),
                            decoration: BoxDecoration(
                              color: _supplierModalSoft,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _supplierModalBorder),
                            ),
                            child: Column(
                              children: [
                                _DetailRow(
                                  label: 'Contact number',
                                  value: supplier.contactNum ?? '—',
                                ),
                                _DetailRow(
                                  label: 'Contact tel',
                                  value: supplier.contactTel ?? '—',
                                ),
                                _DetailRow(
                                  label: 'Address',
                                  value: supplier.address ?? '—',
                                ),
                                _DetailRow(
                                  label: 'Total Orders',
                                  value: '${orders.length}',
                                ),
                                _DetailRow(
                                  label: 'Last Order',
                                  value: orders.isEmpty
                                      ? '—'
                                      : _formatDate(orders.first.receivedDate),
                                ),
                                _DetailRow(
                                  label: 'Staff',
                                  value: staffNames.isEmpty ? '—' : staffNames.join(', '),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),
                          const _SupplierSectionHeader(
                            icon: Icons.inventory_2_outlined,
                            title: 'Items Purchased',
                            subtitle:
                                'Actual items recorded in purchase orders from this supplier.',
                          ),
                          const SizedBox(height: 11),
                          if (purchasedItems.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
                              decoration: BoxDecoration(
                                color: _supplierModalSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _supplierModalBorder),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 16,
                                    color: AppColors.mutedForeground,
                                  ),
                                  SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'No purchased items recorded yet.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: AppColors.mutedForeground,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _supplierModalBorder),
                              ),
                              child: Column(
                                children: [
                                  for (var i = 0; i < purchasedItems.length; i++) ...[
                                    if (i > 0)
                                      const Divider(
                                        height: 1,
                                        color: _supplierModalBorder,
                                      ),
                                    _PurchasedItemRow(item: purchasedItems[i]),
                                  ],
                                ],
                              ),
                            ),
                          const SizedBox(height: 24),
                          const Divider(height: 1, color: _supplierModalBorder),
                          const SizedBox(height: 20),
                          const _SupplierSectionHeader(
                            icon: Icons.receipt_long_outlined,
                            title: 'Purchase History',
                            subtitle:
                                'Items are shown under the purchase order where they were recorded.',
                          ),
                          const SizedBox(height: 12),
                          if (orders.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _supplierModalSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _supplierModalBorder),
                              ),
                              child: const Text(
                                'No purchase orders yet.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                            )
                          else
                            for (var i = 0; i < orders.length; i++) ...[
                              if (i > 0) const SizedBox(height: 10),
                              _PurchaseHistoryRow(
                                order: orders[i],
                                items: itemsByOrder[orders[i].purId] ??
                                    const <OrderLineItem>[],
                              ),
                            ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.mutedForeground,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _openSupplierFormDialog(supplier: supplier);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sageGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text(
                  'Edit Supplier',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          );
        },
      );
    } finally {
      _supplierDetailDialogOpen = false;
    }
  }

  Widget _buildListControls() {
    final isMobile =
        MediaQuery.sizeOf(context).width < 600;

    return Wrap(
      spacing: isMobile ? 8 : 12,
      runSpacing: isMobile ? 8 : 12,
      crossAxisAlignment:
          WrapCrossAlignment.center,
      children: [
        // =====================================================================
        // SEARCH
        // =====================================================================

        SizedBox(
          width: isMobile
              ? double.infinity
              : 280,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (value) {
              setState(() {
                _search = value;
              });
            },
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
              ),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        _searchCtrl.clear();

                        setState(() {
                          _search = '';
                        });
                      },
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                      ),
                    ),
              hintText: 'Search suppliers',
              isDense: true,
            ),
          ),
        ),

        // =====================================================================
        // SORT
        // =====================================================================
        //
        // Uses the exact same shared dropdown component as Animal Records.
        // This keeps the trigger, rounded border, caret, popup card, shadow,
        // spacing, and anchored menu behavior consistent across the app.
        // =====================================================================

        AppDropdown<_SupplierSortOption>(
          label: _sortOptionLabel(
            _sortOption,
          ),
          options: const [
            AppDropdownOption(
              _SupplierSortOption.nameAZ,
              'Name A–Z',
            ),
            AppDropdownOption(
              _SupplierSortOption.nameZA,
              'Name Z–A',
            ),
            AppDropdownOption(
              _SupplierSortOption.mostOrders,
              'Most Orders',
            ),
            AppDropdownOption(
              _SupplierSortOption.leastOrders,
              'Least Orders',
            ),
            AppDropdownOption(
              _SupplierSortOption.latestOrder,
              'Latest Order',
            ),
          ],
          onSelect: (value) {
            setState(() {
              _sortOption = value;
            });
          },
        ),

        // =====================================================================
        // ORDER FILTER
        // =====================================================================

        AppDropdown<_SupplierOrderFilter>(
          label: _orderFilterLabel(
            _orderFilter,
          ),
          options: const [
            AppDropdownOption(
              _SupplierOrderFilter.all,
              'All Suppliers',
            ),
            AppDropdownOption(
              _SupplierOrderFilter.withOrders,
              'With Orders',
            ),
            AppDropdownOption(
              _SupplierOrderFilter.noOrders,
              'No Orders Yet',
            ),
          ],
          onSelect: (value) {
            setState(() {
              _orderFilter = value;
            });
          },
        ),

        // =====================================================================
        // RESET
        // =====================================================================

        if (_hasNonDefaultControls)
          TextButton.icon(
            onPressed:
                _resetSupplierControls,
            icon: const Icon(
              Icons.filter_alt_off_outlined,
              size: 16,
            ),
            label: const Text(
              'Reset',
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final visibleSuppliers = _filtered;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suppliers',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openSupplierFormDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Supplier'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Suppliers',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _openSupplierFormDialog(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Supplier'),
              ),
            ],
          ),
        const SizedBox(height: 2),
        Text(
          _supplierCountLabel,
          style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 20),

        if (isMobile)
          Column(
            children: [
              _buildMobileStatCard(
                label: 'Total Suppliers',
                value: '${_suppliers.length}',
                icon: Icons.local_shipping_outlined,
                accent: AppColors.roleManager,
              ),
              const SizedBox(height: 10),
              _buildMobileStatCard(
                label: 'Total Purchase Orders',
                value: '${_allOrders.length}',
                icon: Icons.receipt_long_outlined,
                accent: AppColors.roleManager,
                onTap: _openPurchaseOrdersDirectoryDialog,
              ),
            ],
          )
        else
          StatCardRow(
            cards: [
              StatCard(
                label: 'Total Suppliers',
                value: '${_suppliers.length}',
                icon: Icons.local_shipping_outlined,
                accent: AppColors.roleManager,
              ),
              StatCard(
                label: 'Total Purchase Orders',
                value: '${_allOrders.length}',
                icon: Icons.receipt_long_outlined,
                accent: AppColors.roleManager,
                onTap: _openPurchaseOrdersDirectoryDialog,
                tooltip: 'View recorded purchase orders',
              ),
            ],
          ),

        const SizedBox(height: 20),
        _buildListControls(),
        const SizedBox(height: 20),

        if (_suppliers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 36,
                    color: AppColors.mutedForeground,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No suppliers yet',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          )
        else if (visibleSuppliers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.search_off,
                    size: 32,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'No suppliers match your search or filter.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.mutedForeground),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _resetSupplierControls,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isMobile ? 300 : 330,
              mainAxisExtent: isMobile ? 186 : 175,
              crossAxisSpacing: isMobile ? 10 : 16,
              mainAxisSpacing: isMobile ? 10 : 16,
            ),
            itemCount: visibleSuppliers.length,
            itemBuilder: (context, index) {
              final supplier = visibleSuppliers[index];
              final orders = _ordersFor(supplier.suppId)
                ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));

              return _Hoverable(
                builder: (context, isHovered) {
                  return InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _openDetailDialog(supplier),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: EdgeInsets.all(isMobile ? 14 : 16),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isHovered
                              ? AppColors.roleManager.withValues(alpha: 0.45)
                              : AppColors.border,
                          width: isHovered ? 1.5 : 1,
                        ),
                        boxShadow: isHovered
                            ? [
                                BoxShadow(
                                  color: AppColors.roleManager.withValues(alpha: 0.10),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  supplier.suppName,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: isMobile ? 14 : 15,
                                    color: isHovered ? AppColors.roleManager : null,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: isHovered
                                    ? AppColors.roleManager
                                    : AppColors.mutedForeground,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (supplier.contactNum != null)
                            Text(
                              supplier.contactNum!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12.5,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          if (supplier.contactTel != null)
                            Text(
                              supplier.contactTel!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12.5,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          if (supplier.address != null)
                            Text(
                              supplier.address!,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize: isMobile ? 11 : 12.5,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                '${orders.length} order${orders.length == 1 ? '' : 's'}',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
                              const Spacer(),
                              Flexible(
                                child: Text(
                                  orders.isEmpty
                                      ? 'No orders yet'
                                      : 'Last: ${_formatDate(_latestOrderDateFor(supplier)!)}',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 7),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'View details',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isHovered
                                    ? AppColors.roleManager
                                    : AppColors.mutedForeground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
      ],
    );
  }

  Widget _buildMobileStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
    VoidCallback? onTap,
  }) {
    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 22, color: accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    'View details',
                    style: TextStyle(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: AppColors.mutedForeground,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }

}

// =============================================================================
// SUPPLIER PURCHASE DETAILS
// =============================================================================

class _SupplierPurchaseDetails {
  final Map<String, List<OrderLineItem>> itemsByOrder;
  final List<_PurchasedItemSummary> purchasedItems;

  const _SupplierPurchaseDetails({
    required this.itemsByOrder,
    required this.purchasedItems,
  });
}

class _PurchasedItemSummary {
  final String itemName;
  final String itemUom;
  final double totalQty;
  final int orderCount;

  const _PurchasedItemSummary({
    required this.itemName,
    required this.itemUom,
    required this.totalQty,
    required this.orderCount,
  });
}

class _DirectoryDialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const _DirectoryDialogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.sageGreen.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: AppColors.sageGreen),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 19),
          ),
        ],
      ),
    );
  }
}

class _DirectorySupplierRow extends StatelessWidget {
  final Supplier supplier;
  final int orderCount;
  final VoidCallback onTap;

  const _DirectorySupplierRow({
    required this.supplier,
    required this.orderCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _supplierModalSoft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _supplierModalBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.sageGreen.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  size: 18,
                  color: AppColors.sageGreen,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplier.suppName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      supplier.address ?? 'No address recorded',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$orderCount order${orderCount == 1 ? '' : 's'}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectoryPurchaseRow extends StatelessWidget {
  final PurchaseOrder order;
  final bool canOpenSupplier;
  final VoidCallback? onTap;

  const _DirectoryPurchaseRow({
    required this.order,
    required this.canOpenSupplier,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _supplierModalSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _supplierModalBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.sageGreen.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 18,
              color: AppColors.sageGreen,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.suppName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(order.receivedDate),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Recorded by: ${order.buyerName}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.mutedForeground,
                      ),
                    ),
                    if (order.receivedBy.trim().isNotEmpty)
                      Text(
                        'Received by: ${order.receivedBy}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canOpenSupplier) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mutedForeground,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(12),
        child: content,
      ),
    );
  }
}

class _SupplierSectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SupplierSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.sageGreen.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: AppColors.sageGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: AppColors.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PurchasedItemRow extends StatelessWidget {
  final _PurchasedItemSummary item;

  const _PurchasedItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final unit = item.itemUom.trim();
    final qtyText = unit.isEmpty
        ? _formatQuantity(item.totalQty)
        : '${_formatQuantity(item.totalQty)} $unit';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.sageGreen.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 14, color: AppColors.sageGreen),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.orderCount == 1
                      ? 'Purchased in 1 order'
                      : 'Purchased across ${item.orderCount} orders',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            qtyText,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseHistoryRow extends StatelessWidget {
  final PurchaseOrder order;
  final List<OrderLineItem> items;

  const _PurchaseHistoryRow({
    required this.order,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _supplierModalSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _supplierModalBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _supplierModalBorder),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 15,
              color: AppColors.mutedForeground,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(order.receivedDate),
                  style: const TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Staff: ${order.buyerName}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.mutedForeground,
                  ),
                ),
                if (order.receivedBy.trim().isNotEmpty)
                  Text(
                    'Received by: ${order.receivedBy}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.mutedForeground,
                    ),
                  ),
                const SizedBox(height: 9),
                if (items.isEmpty)
                  const Text(
                    'No items recorded for this order.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontStyle: FontStyle.italic,
                      color: AppColors.mutedForeground,
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      for (final item in items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: SizedBox(
                                  width: 4,
                                  height: 4,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: AppColors.sageGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  item.itemName,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                item.itemUom.trim().isEmpty
                                    ? _formatQuantity(item.qty)
                                    : '${_formatQuantity(item.qty)} ${item.itemUom}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
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

class _Hoverable extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovered) builder;

  const _Hoverable({required this.builder});

  @override
  State<_Hoverable> createState() => _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.builder(context, _isHovered),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: AppColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatQuantity(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

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

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
