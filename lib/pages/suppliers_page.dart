import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/supplier.dart';
import '../services/supplier_service.dart';
import '../state/data_bus.dart';
import '../widgets/app_dropdown.dart';
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

  // Track if the widget is mounted and safe for state updates
  bool _isMounted = false;

  @override
  void initState() {
    super.initState();
    _isMounted = true;
    // Use WidgetsBinding to ensure the widget is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isMounted) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _isMounted = false;
    super.dispose();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  // Safe state update method
  void _safeSetState(VoidCallback fn) {
    if (_isMounted && mounted) {
      setState(fn);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!_isMounted || !mounted) return;

    if (!silent) {
      _safeSetState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final results = await Future.wait([
        _service.fetchSuppliers(),
        _service.fetchAllPurchaseOrders(),
      ]);
      if (!_isMounted || !mounted) return;
      _safeSetState(() {
        _suppliers = results[0] as List<Supplier>;
        _allOrders = results[1] as List<PurchaseOrder>;
        _loading = false;
      });
    } catch (e) {
      if (!_isMounted || !mounted) return;
      if (!silent) {
        _safeSetState(() {
          _error = 'Could not load suppliers: $e';
          _loading = false;
        });
      }
    }
  }

  List<Supplier> get _filtered {
    if (_search.isEmpty) return _suppliers;
    final q = _search.toLowerCase();
    return _suppliers
        .where((s) => s.suppName.toLowerCase().contains(q))
        .toList();
  }

  List<PurchaseOrder> _ordersFor(String suppId) =>
      _allOrders.where((o) => o.suppId == suppId).toList();

  void _showSuccessSnackBar(BuildContext context, String message) {
    if (!_isMounted || !mounted) return;

    try {
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
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          width: 500,
        ),
      );
    } catch (e) {
      debugPrint('Failed to show success snackbar: $e');
    }
  }

  void _showErrorSnackBar(BuildContext context, String message) {
    if (!_isMounted || !mounted) return;

    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Flexible(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          width: 500,
        ),
      );
    } catch (e) {
      debugPrint('Failed to show error snackbar: $e');
    }
  }

  // Custom elevated button with hover effect
  Widget _buildElevatedButton({
    required VoidCallback? onPressed,
    required Widget child,
    bool isLoading = false,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isHovered
                  ? (backgroundColor ?? AppColors.primary)
                      .withValues(alpha: 0.85)
                  : backgroundColor ?? AppColors.primary,
              foregroundColor: foregroundColor ?? Colors.white,
              elevation: isHovered ? 8 : 2,
              shadowColor:
                  Colors.black.withValues(alpha: isHovered ? 0.3 : 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : child,
          ),
        );
      },
    );
  }

  // Custom text button with hover effect
  Widget _buildTextButton({
    required VoidCallback? onPressed,
    required Widget child,
    Color? foregroundColor,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: isHovered
                  ? (foregroundColor ?? AppColors.mutedForeground)
                      .withValues(alpha: 0.7)
                  : foregroundColor ?? AppColors.mutedForeground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: child,
          ),
        );
      },
    );
  }

  // Custom icon button with hover effect
  Widget _buildIconButton({
    required VoidCallback? onPressed,
    required IconData icon,
    Color? color,
    bool? disabled,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: IconButton(
            icon: Icon(icon),
            onPressed: disabled == true ? null : onPressed,
            color: isHovered && disabled != true
                ? (color ?? AppColors.mutedForeground).withValues(alpha: 0.7)
                : color ?? AppColors.mutedForeground,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        );
      },
    );
  }

  // Custom action button with hover effect (for Edit/Update buttons)
  Widget _buildActionButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isHovered
                    ? (backgroundColor ?? AppColors.primary)
                        .withValues(alpha: 0.85)
                    : backgroundColor ?? AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                boxShadow: isHovered
                    ? [
                        BoxShadow(
                          color: (backgroundColor ?? AppColors.primary)
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 18, color: foregroundColor ?? Colors.white),
                  const SizedBox(width: 8),
                  Text(label,
                      style: TextStyle(color: foregroundColor ?? Colors.white)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openSupplierFormDialog({Supplier? supplier}) async {
    final isEdit = supplier != null;
    final nameCtrl = TextEditingController(text: supplier?.suppName ?? '');
    final contactCtrl = TextEditingController(text: supplier?.contactNum ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    // Store the current context for snackbar display
    final currentContext = context;

    await showDialog(
      context: currentContext,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(
                isEdit ? Icons.edit_outlined : Icons.add,
                size: 20,
                color: AppColors.mutedForeground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(isEdit ? 'Edit Supplier' : 'Add Supplier'),
              ),
              _buildIconButton(
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                icon: Icons.close,
                color: AppColors.mutedForeground,
                disabled: saving,
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      autofocus: !isEdit,
                      decoration:
                          const InputDecoration(labelText: 'Supplier name *'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: contactCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                          labelText: 'Contact number (optional)'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: addressCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Address (optional)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            _buildTextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            _buildElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        if (isEdit) {
                          await _service.updateSupplier(
                            suppId: supplier.suppId,
                            suppName: nameCtrl.text.trim(),
                            contactNum: contactCtrl.text.trim().isEmpty
                                ? null
                                : contactCtrl.text.trim(),
                            address: addressCtrl.text.trim().isEmpty
                                ? null
                                : addressCtrl.text.trim(),
                          );
                        } else {
                          await _service.createSupplier(
                            suppName: nameCtrl.text.trim(),
                            contactNum: contactCtrl.text.trim().isEmpty
                                ? null
                                : contactCtrl.text.trim(),
                            address: addressCtrl.text.trim().isEmpty
                                ? null
                                : addressCtrl.text.trim(),
                          );
                        }

                        // Close the dialog
                        if (!context.mounted) return;
                        Navigator.of(context).pop();

                        // Show snackbar after dialog is closed
                        await Future.delayed(const Duration(milliseconds: 100));

                        if (!_isMounted || !mounted) return;
                        _showSuccessSnackBar(
                          currentContext,
                          isEdit
                              ? '${nameCtrl.text.trim()} updated successfully'
                              : '${nameCtrl.text.trim()} added successfully',
                        );

                        // Refresh the data
                        await _load();
                      } catch (e) {
                        if (!context.mounted) return;
                        setDialogState(() => saving = false);
                        _showErrorSnackBar(
                          currentContext,
                          'Could not ${isEdit ? 'update' : 'add'} supplier: $e',
                        );
                      }
                    },
              child: Text(isEdit ? 'Save Changes' : 'Add Supplier'),
              isLoading: saving,
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    contactCtrl.dispose();
    addressCtrl.dispose();
  }

  Future<void> _openDetailDialog(Supplier supplier) async {
    final orders = _ordersFor(supplier.suppId);
    final currentContext = context;

    await showDialog(
      context: currentContext,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.local_shipping_outlined,
                size: 20, color: AppColors.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(supplier.suppName, overflow: TextOverflow.ellipsis),
            ),
            _buildIconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Icons.close,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Contact', value: supplier.contactNum ?? '—'),
                _DetailRow(label: 'Address', value: supplier.address ?? '—'),
                _DetailRow(label: 'Total Orders', value: '${orders.length}'),
                _DetailRow(
                  label: 'Last Order',
                  value: orders.isEmpty
                      ? '—'
                      : _formatDate(orders.first.receivedDate),
                ),
                const SizedBox(height: 12),
                const Text('Purchase History',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 8),
                if (orders.isEmpty)
                  const Text('No purchase orders yet.',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.mutedForeground))
                else
                  for (final order in orders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(_formatDate(order.receivedDate))),
                          Text(order.buyerName,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          _buildActionButton(
            onTap: () {
              Navigator.of(context).pop();
              _openSupplierFormDialog(supplier: supplier);
            },
            icon: Icons.edit_outlined,
            label: 'Edit Supplier',
          ),
        ],
      ),
    );
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
            Text(_error!,
                style: const TextStyle(color: AppColors.mutedForeground)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text('Suppliers',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            ElevatedButton.icon(
              onPressed: () => _openSupplierFormDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Supplier'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('${_suppliers.length} suppliers',
            style: const TextStyle(
                fontSize: 13, color: AppColors.mutedForeground)),
        const SizedBox(height: 20),
        StatCardRow(cards: [
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
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(
          width: 280,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Search suppliers…',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (_suppliers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 36, color: AppColors.mutedForeground),
                  SizedBox(height: 10),
                  Text('No suppliers yet',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          )
        else if (_filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off,
                      size: 32, color: AppColors.mutedForeground),
                  SizedBox(height: 8),
                  Text('No suppliers match your search.',
                      style: TextStyle(color: AppColors.mutedForeground)),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 165,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final supplier = _filtered[index];
              final orders = _ordersFor(supplier.suppId);
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openDetailDialog(supplier),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(supplier.suppName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 6),
                      if (supplier.contactNum != null)
                        Text(supplier.contactNum!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.mutedForeground)),
                      if (supplier.address != null)
                        Text(supplier.address!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.mutedForeground)),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${orders.length} orders',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground)),
                          Text(
                              orders.isEmpty
                                  ? 'No orders yet'
                                  : 'Last: ${_formatDate(orders.first.receivedDate)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedForeground)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColors.mutedForeground)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
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
