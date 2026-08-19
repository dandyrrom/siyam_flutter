import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/validators.dart';
import '../models/supplier.dart';
import '../services/supplier_service.dart';
import '../state/data_bus.dart';
import '../widgets/stat_card.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage>
    with DataBusRefreshMixin<SuppliersPage> {
  final SupplierService _service = SupplierService();

  List<Supplier> _suppliers = [];
  List<PurchaseOrder> _allOrders = [];

  bool _loading = true;
  String? _error;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  // ===========================================================================
  // LOAD
  // ===========================================================================

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

  // ===========================================================================
  // SUPPLIER NAME NORMALIZATION / DUPLICATE VALIDATION
  // ===========================================================================

  String _cleanSupplierName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  String _supplierNameKey(String value) {
    return _cleanSupplierName(value).toLowerCase();
  }

  String? _validateSupplierName(
    String? value, {
    Supplier? editingSupplier,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }

    final targetKey = _supplierNameKey(value);

    final duplicate = _suppliers.any(
      (existing) =>
          existing.suppId != editingSupplier?.suppId &&
          _supplierNameKey(existing.suppName) == targetKey,
    );

    if (duplicate) {
      return 'A supplier with this name already exists';
    }

    return null;
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '');
  }

  // ===========================================================================
  // FILTERING
  // ===========================================================================

  List<Supplier> get _filtered {
    if (_search.trim().isEmpty) {
      return _suppliers;
    }

    final q = _search.trim().toLowerCase();

    return _suppliers.where((supplier) {
      return supplier.suppName.toLowerCase().contains(q) ||
          (supplier.address ?? '').toLowerCase().contains(q) ||
          (supplier.contactNum ?? '').toLowerCase().contains(q) ||
          (supplier.contactTel ?? '').toLowerCase().contains(q);
    }).toList();
  }

  List<PurchaseOrder> _ordersFor(String suppId) {
    return _allOrders
        .where((order) => order.suppId == suppId)
        .toList();
  }

  // ===========================================================================
  // SUCCESS MESSAGE
  // ===========================================================================

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ===========================================================================
  // ADD / EDIT SUPPLIER
  // ===========================================================================
  //
  // PANEL REQUIREMENT:
  // The Edit Supplier modal must remain within a controlled/fixed size.
  //
  // Desktop:
  // 420px wide, 390px content height.
  //
  // Smaller screens:
  // Width/height adapts to the available viewport and the form scrolls inside
  // the dialog rather than extending the entire modal.
  // ===========================================================================

  Future<void> _openSupplierFormDialog({
    Supplier? supplier,
  }) async {
    final isEdit = supplier != null;

    final nameCtrl = TextEditingController(
      text: supplier?.suppName ?? '',
    );

    final contactCtrl = TextEditingController(
      text: supplier?.contactNum ?? '',
    );

    final contactTelCtrl = TextEditingController(
      text: supplier?.contactTel ?? '',
    );

    final addressCtrl = TextEditingController(
      text: supplier?.address ?? '',
    );

    final formKey = GlobalKey<FormState>();

    var saving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (
            builderContext,
            setDialogState,
          ) {
            final screen = MediaQuery.sizeOf(builderContext);

            final contentWidth =
                screen.width < 520
                    ? screen.width - 96
                    : 420.0;

            final contentHeight =
                screen.height < 700
                    ? screen.height * 0.52
                    : 390.0;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                isEdit
                    ? 'Edit Supplier'
                    : 'Add Supplier',
              ),

              // ===============================================================
              // FIXED / CONTROLLED FORM AREA
              // ===============================================================

              content: SizedBox(
                width: contentWidth,
                height: contentHeight,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // =====================================================
                        // SUPPLIER NAME
                        // =====================================================

                        TextFormField(
                          controller: nameCtrl,
                          autofocus: !isEdit,
                          decoration: const InputDecoration(
                            labelText: 'Supplier name',
                          ),
                          validator: (value) =>
                              _validateSupplierName(
                            value,
                            editingSupplier: supplier,
                          ),
                        ),

                        const SizedBox(height: 12),

                        // =====================================================
                        // MOBILE NUMBER
                        // =====================================================

                        TextFormField(
                          controller: contactCtrl,
                          keyboardType: TextInputType.phone,
                          inputFormatters: phoneInputFormatters,
                          maxLength: 11,
                          decoration: const InputDecoration(
                            labelText:
                                'Contact number (optional)',
                            hintText: '09XXXXXXXXX',
                            helperText:
                                'Enter exactly 11 digits, starting with 09',
                            counterText: '',
                          ),
                          validator: validatePhoneNumber,
                        ),

                        const SizedBox(height: 12),

                        // =====================================================
                        // TELEPHONE
                        // =====================================================

                        TextFormField(
                          controller: contactTelCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText:
                                'Contact tel (optional)',
                            hintText: 'Landline number',
                          ),
                        ),

                        const SizedBox(height: 12),

                        // =====================================================
                        // ADDRESS
                        // =====================================================

                        TextFormField(
                          controller: addressCtrl,
                          minLines: 2,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText:
                                'Address (optional)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () {
                          Navigator.of(
                            builderContext,
                          ).pop();
                        },
                  child: const Text('Cancel'),
                ),

                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            return;
                          }

                          setDialogState(
                            () => saving = true,
                          );

                          final cleanName =
                              _cleanSupplierName(
                            nameCtrl.text,
                          );

                          final cleanPhone =
                              contactCtrl.text.trim().isEmpty
                                  ? null
                                  : contactCtrl.text.trim();

                          final cleanTel =
                              contactTelCtrl.text.trim().isEmpty
                                  ? null
                                  : contactTelCtrl.text.trim();

                          final cleanAddress =
                              addressCtrl.text.trim().isEmpty
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

                            if (!builderContext.mounted) {
                              return;
                            }

                            Navigator.of(builderContext).pop();

                            if (!mounted) return;

                            _showSuccessSnackBar(
                              isEdit
                                  ? '$cleanName updated successfully'
                                  : '$cleanName added successfully',
                            );

                            await _load();
                          } catch (e) {
                            if (!builderContext.mounted) {
                              return;
                            }

                            setDialogState(
                              () => saving = false,
                            );

                            ScaffoldMessenger.of(
                              builderContext,
                            ).clearSnackBars();

                            ScaffoldMessenger.of(
                              builderContext,
                            ).showSnackBar(
                              SnackBar(
                                content: Text(
                                  _cleanError(e),
                                ),
                                backgroundColor:
                                    AppColors.destructive,
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
                      : Text(
                          isEdit
                              ? 'Save Changes'
                              : 'Add Supplier',
                        ),
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

  // ===========================================================================
  // SUPPLIER FULL DETAILS
  // ===========================================================================

  Future<void> _openDetailDialog(
    Supplier supplier,
  ) async {
    final orders = _ordersFor(supplier.suppId);

    // =========================================================================
    // STAFF
    // =========================================================================
    //
    // Supplier does not currently have a direct "assigned staff" foreign key.
    //
    // Therefore we do NOT invent one.
    //
    // Staff is derived from the real PURCHASE.recordedby → USERS relationship
    // that already produces PurchaseOrder.buyerName.
    // =========================================================================

    final staffNames = orders
        .map((order) => order.buyerName.trim())
        .where(
          (name) =>
              name.isNotEmpty &&
              name != 'Unknown user',
        )
        .toSet()
        .toList()
      ..sort();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final screen = MediaQuery.sizeOf(dialogContext);

        final contentWidth =
            screen.width < 520
                ? screen.width - 96
                : 460.0;

        final maxContentHeight =
            screen.height < 700
                ? screen.height * 0.55
                : 470.0;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(supplier.suppName),
          content: SizedBox(
            width: contentWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxContentHeight,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    // =========================================================
                    // SUPPLIER INFORMATION
                    // =========================================================

                    _DetailRow(
                      label: 'Contact number',
                      value:
                          supplier.contactNum ?? '—',
                    ),

                    _DetailRow(
                      label: 'Contact tel',
                      value:
                          supplier.contactTel ?? '—',
                    ),

                    _DetailRow(
                      label: 'Address',
                      value:
                          supplier.address ?? '—',
                    ),

                    _DetailRow(
                      label: 'Total Orders',
                      value: '${orders.length}',
                    ),

                    _DetailRow(
                      label: 'Last Order',
                      value: orders.isEmpty
                          ? '—'
                          : _formatDate(
                              orders.first.receivedDate,
                            ),
                    ),

                    // =========================================================
                    // PANEL REQUIREMENT: STAFF
                    // =========================================================

                    _DetailRow(
                      label: 'Staff',
                      value: staffNames.isEmpty
                          ? '—'
                          : staffNames.join(', '),
                    ),

                    const SizedBox(height: 6),
                    const Divider(),
                    const SizedBox(height: 10),

                    // =========================================================
                    // PURCHASE HISTORY
                    // =========================================================

                    const Text(
                      'Purchase History',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    if (orders.isEmpty)
                      const Text(
                        'No purchase orders yet.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color:
                              AppColors.mutedForeground,
                        ),
                      )
                    else
                      for (var i = 0;
                          i < orders.length;
                          i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 18,
                            color: AppColors.border,
                          ),
                        _PurchaseHistoryRow(
                          order: orders[i],
                        ),
                      ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),

            TextButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop();

                _openSupplierFormDialog(
                  supplier: supplier,
                );
              },
              icon: const Icon(
                Icons.edit_outlined,
                size: 16,
              ),
              label: const Text('Edit Supplier'),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // PAGE
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final bool isMobile =
        MediaQuery.sizeOf(context).width < 600;

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.mutedForeground,
              ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // =====================================================================
        // HEADER
        // =====================================================================

        if (isMobile)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Suppliers',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _openSupplierFormDialog(),
                  icon: const Icon(
                    Icons.add,
                    size: 18,
                  ),
                  label: const Text(
                    'Add Supplier',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Suppliers',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              ElevatedButton.icon(
                onPressed: () =>
                    _openSupplierFormDialog(),
                icon: const Icon(
                  Icons.add,
                  size: 18,
                ),
                label: const Text(
                  'Add Supplier',
                ),
              ),
            ],
          ),

        const SizedBox(height: 2),

        Text(
          '${_suppliers.length} suppliers',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.mutedForeground,
          ),
        ),

        const SizedBox(height: 20),

        // =====================================================================
        // STAT CARDS
        // =====================================================================

        if (isMobile)
          Column(
            children: [
              _buildMobileStatCard(
                label: 'Total Suppliers',
                value: '${_suppliers.length}',
                icon:
                    Icons.local_shipping_outlined,
                accent: AppColors.roleManager,
              ),

              const SizedBox(height: 10),

              _buildMobileStatCard(
                label: 'Total Purchase Orders',
                value: '${_allOrders.length}',
                icon: Icons.receipt_long_outlined,
                accent: AppColors.roleManager,
              ),
            ],
          )
        else
          StatCardRow(
            cards: [
              StatCard(
                label: 'Total Suppliers',
                value: '${_suppliers.length}',
                icon:
                    Icons.local_shipping_outlined,
                accent: AppColors.roleManager,
              ),
              StatCard(
                label: 'Total Purchase Orders',
                value: '${_allOrders.length}',
                icon: Icons.receipt_long_outlined,
                accent: AppColors.roleManager,
              ),
            ],
          ),

        const SizedBox(height: 20),

        // =====================================================================
        // SEARCH
        // =====================================================================

        SizedBox(
          width: isMobile
              ? double.infinity
              : 280,
          child: TextField(
            onChanged: (value) {
              setState(() {
                _search = value;
              });
            },
            decoration: const InputDecoration(
              prefixIcon: Icon(
                Icons.search,
                size: 18,
              ),
              hintText: 'Search suppliers',
              isDense: true,
            ),
          ),
        ),

        const SizedBox(height: 20),

        // =====================================================================
        // EMPTY STATES / SUPPLIER GRID
        // =====================================================================

        if (_suppliers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 56,
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.local_shipping_outlined,
                    size: 36,
                    color:
                        AppColors.mutedForeground,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'No suppliers yet',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(
              vertical: 48,
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 32,
                    color:
                        AppColors.mutedForeground,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No suppliers match your search.',
                    style: TextStyle(
                      color:
                          AppColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics:
                const NeverScrollableScrollPhysics(),
            gridDelegate:
                SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent:
                  isMobile ? 280 : 320,
              mainAxisExtent:
                  isMobile ? 180 : 165,
              crossAxisSpacing:
                  isMobile ? 10 : 16,
              mainAxisSpacing:
                  isMobile ? 10 : 16,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final supplier =
                  _filtered[index];

              final orders =
                  _ordersFor(supplier.suppId);

              return _Hoverable(
                builder: (
                  context,
                  isHovered,
                ) {
                  return InkWell(
                    borderRadius:
                        BorderRadius.circular(16),
                    onTap: () =>
                        _openDetailDialog(
                      supplier,
                    ),
                    child: AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 150,
                      ),
                      padding: EdgeInsets.all(
                        isMobile ? 14 : 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                        border: Border.all(
                          color: isHovered
                              ? AppColors.roleManager
                                  .withValues(
                                    alpha: 0.4,
                                  )
                              : AppColors.border,
                          width:
                              isHovered ? 1.5 : 1,
                        ),
                        boxShadow: isHovered
                            ? [
                                BoxShadow(
                                  color: AppColors
                                      .roleManager
                                      .withValues(
                                        alpha: 0.1,
                                      ),
                                  blurRadius: 10,
                                  offset:
                                      const Offset(
                                    0,
                                    3,
                                  ),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            supplier.suppName,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight:
                                  FontWeight.w700,
                              fontSize:
                                  isMobile ? 14 : 15,
                              color: isHovered
                                  ? AppColors
                                      .roleManager
                                  : null,
                            ),
                          ),

                          const SizedBox(height: 6),

                          if (supplier.contactNum != null)
                            Text(
                              supplier.contactNum!,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize:
                                    isMobile
                                        ? 11
                                        : 12.5,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),

                          if (supplier.contactTel != null)
                            Text(
                              supplier.contactTel!,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize:
                                    isMobile
                                        ? 11
                                        : 12.5,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),

                          if (supplier.address != null)
                            Text(
                              supplier.address!,
                              overflow:
                                  TextOverflow.ellipsis,
                              maxLines: 2,
                              style: TextStyle(
                                fontSize:
                                    isMobile
                                        ? 11
                                        : 12.5,
                                color: AppColors
                                    .mutedForeground,
                              ),
                            ),

                          const Spacer(),

                          Row(
                            children: [
                              Text(
                                '${orders.length} orders',
                                style: TextStyle(
                                  fontSize:
                                      isMobile
                                          ? 11
                                          : 12,
                                  color: AppColors
                                      .mutedForeground,
                                ),
                              ),

                              const Spacer(),

                              Flexible(
                                child: Text(
                                  orders.isEmpty
                                      ? 'No orders yet'
                                      : 'Last: ${_formatDate(orders.first.receivedDate)}',
                                  overflow:
                                      TextOverflow.ellipsis,
                                  textAlign:
                                      TextAlign.end,
                                  style: TextStyle(
                                    fontSize:
                                        isMobile
                                            ? 11
                                            : 12,
                                    color: AppColors
                                        .mutedForeground,
                                  ),
                                ),
                              ),
                            ],
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

  // ===========================================================================
  // MOBILE STAT CARD
  // ===========================================================================

  Widget _buildMobileStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding:
                const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: accent.withValues(
                alpha: 0.1,
              ),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 22,
              color: accent,
            ),
          ),

          const SizedBox(width: 14),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
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
                  color:
                      AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PURCHASE HISTORY ROW
// =============================================================================

class _PurchaseHistoryRow extends StatelessWidget {
  final PurchaseOrder order;

  const _PurchaseHistoryRow({
    required this.order,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.receipt_long_outlined,
          size: 16,
          color: AppColors.mutedForeground,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                _formatDate(
                  order.receivedDate,
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                'Staff: ${order.buyerName}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color:
                      AppColors.mutedForeground,
                ),
              ),

              if (order.receivedBy.trim().isNotEmpty)
                Text(
                  'Received by: ${order.receivedBy}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color:
                        AppColors.mutedForeground,
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
// HOVER
// =============================================================================

class _Hoverable extends StatefulWidget {
  final Widget Function(
    BuildContext context,
    bool isHovered,
  ) builder;

  const _Hoverable({
    required this.builder,
  });

  @override
  State<_Hoverable> createState() =>
      _HoverableState();
}

class _HoverableState extends State<_Hoverable> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHovered = true;
        });
      },
      onExit: (_) {
        setState(() {
          _isHovered = false;
        });
      },
      child: widget.builder(
        context,
        _isHovered,
      ),
    );
  }
}

// =============================================================================
// DETAIL ROW
// =============================================================================

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
      padding:
          const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color:
                    AppColors.mutedForeground,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
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

String _formatDate(DateTime date) {
  return '${_monthAbbrev[date.month - 1]} '
      '${date.day}, ${date.year}';
}