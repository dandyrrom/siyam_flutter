import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../models/supplier.dart';
import '../services/supplier_service.dart';
import '../state/data_bus.dart';
import '../widgets/stat_card.dart';

// The SuppliersPage widget displays a list of suppliers and their details.
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

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Optional field
    }

    // Check if it contains only digits
    if (!RegExp(r'^\d+$').hasMatch(value.trim())) {
      return 'Only numbers are allowed';
    }

    // Must be exactly 11 digits
    if (value.trim().length != 11) {
      return 'Phone number must be exactly 11 digits';
    }

    return null;
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

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

  // Custom elevated button with hover effect
  Widget _buildElevatedButton({
    required VoidCallback? onPressed,
    required Widget child,
    bool isLoading = false,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return _Hoverable(
      builder: (context, isHovered) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: foregroundColor ?? Colors.white,
          elevation: isHovered ? 8 : 2,
          shadowColor: Colors.black.withValues(alpha: isHovered ? 0.3 : 0.1),
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
  }

  // Custom text button with hover effect
  Widget _buildTextButton({
    required VoidCallback? onPressed,
    required Widget child,
    Color? foregroundColor,
  }) {
    return _Hoverable(
      builder: (context, isHovered) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: (foregroundColor ?? AppColors.mutedForeground)
              .withValues(alpha: isHovered ? 0.85 : 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: child,
      ),
    );
  }

  // Custom icon button with hover effect
  Widget _buildIconButton({
    required VoidCallback? onPressed,
    required IconData icon,
    Color? color,
    bool? disabled,
  }) {
    return _Hoverable(
      builder: (context, isHovered) => IconButton(
        icon: Icon(icon),
        onPressed: disabled == true ? null : onPressed,
        color: isHovered && disabled != true
            ? (color ?? AppColors.mutedForeground).withValues(alpha: 0.7)
            : color ?? AppColors.mutedForeground,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
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
    return _Hoverable(
      builder: (context, isHovered) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isHovered
                ? (backgroundColor ?? AppColors.primary).withValues(alpha: 0.85)
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
  }

  // Build supplier card with hover effect
  Widget _buildSupplierCard(Supplier supplier) {
    final orders = _ordersFor(supplier.suppId);

    return _Hoverable(
      builder: (context, isHovered) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetailDialog(supplier),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isHovered
                ? AppColors.card.withValues(alpha: 0.95)
                : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isHovered
                  ? AppColors.roleManager.withValues(alpha: 0.3)
                  : AppColors.border,
              width: isHovered ? 1.5 : 1,
            ),
            boxShadow: isHovered
                ? [
                    BoxShadow(
                      color: AppColors.roleManager.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isHovered
                          ? AppColors.roleManager.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.local_shipping_outlined,
                      size: 20,
                      color: isHovered
                          ? AppColors.roleManager
                          : AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(supplier.suppName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isHovered ? AppColors.roleManager : null,
                        )),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (supplier.contactNum != null)
                Text(supplier.contactNum!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: isHovered
                            ? AppColors.mutedForeground.withValues(alpha: 0.8)
                            : AppColors.mutedForeground)),
              if (supplier.address != null)
                Text(supplier.address!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: TextStyle(
                        fontSize: 12.5,
                        color: isHovered
                            ? AppColors.mutedForeground.withValues(alpha: 0.8)
                            : AppColors.mutedForeground)),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${orders.length} orders',
                      style: TextStyle(
                          fontSize: 12,
                          color: isHovered
                              ? AppColors.mutedForeground.withValues(alpha: 0.7)
                              : AppColors.mutedForeground)),
                  Text(
                      orders.isEmpty
                          ? 'No orders yet'
                          : 'Last: ${_formatDate(orders.first.receivedDate)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: isHovered
                              ? AppColors.mutedForeground.withValues(alpha: 0.7)
                              : AppColors.mutedForeground)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSupplierFormDialog({Supplier? supplier}) async {
    final isEdit = supplier != null;
    final nameCtrl = TextEditingController(text: supplier?.suppName ?? '');
    final contactCtrl = TextEditingController(text: supplier?.contactNum ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
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
                onPressed:
                    saving ? null : () => Navigator.of(builderContext).pop(),
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
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'Contact number (optional)',
                        hintText: '09XXXXXXXXX',
                        helperText: 'Enter exactly 11 digits',
                        counterText: '',
                      ),
                      validator: _validatePhoneNumber,
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
              onPressed:
                  saving ? null : () => Navigator.of(builderContext).pop(),
              child: const Text('Cancel'),
            ),
            _buildElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        // Get phone number - should already be clean digits only
                        final cleanPhone = contactCtrl.text.trim().isEmpty
                            ? null
                            : contactCtrl.text.trim();

                        if (isEdit) {
                          await _service.updateSupplier(
                            suppId: supplier.suppId,
                            suppName: nameCtrl.text.trim(),
                            contactNum: cleanPhone,
                            address: addressCtrl.text.trim().isEmpty
                                ? null
                                : addressCtrl.text.trim(),
                          );
                        } else {
                          await _service.createSupplier(
                            suppName: nameCtrl.text.trim(),
                            contactNum: cleanPhone,
                            address: addressCtrl.text.trim().isEmpty
                                ? null
                                : addressCtrl.text.trim(),
                          );
                        }

                        // Close the dialog
                        if (builderContext.mounted) {
                          Navigator.of(builderContext).pop();
                        }

                        // Wait for dialog to close
                        await Future.delayed(const Duration(milliseconds: 100));

                        // Use State.mounted to check if page is still mounted
                        if (!mounted) return;
                        _showSuccessSnackBar(
                          isEdit
                              ? '${nameCtrl.text.trim()} updated successfully'
                              : '${nameCtrl.text.trim()} added successfully',
                        );

                        // Refresh the data
                        await _load();
                      } catch (e) {
                        if (!builderContext.mounted) return;
                        setDialogState(() => saving = false);
                        // Use builderContext for error since dialog is still open
                        if (builderContext.mounted) {
                          ScaffoldMessenger.of(builderContext).clearSnackBars();
                          ScaffoldMessenger.of(builderContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not ${isEdit ? 'update' : 'add'} supplier: $e',
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
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

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.local_shipping_outlined,
                size: 20, color: AppColors.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(supplier.suppName, overflow: TextOverflow.ellipsis),
            ),
            _buildIconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
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
              Navigator.of(dialogContext).pop();
              _openSupplierFormDialog(supplier: supplier);
            },
            icon: Icons.edit_outlined,
            label: 'Edit Supplier',
          ),
        ],
      ),
    );
  }

  // Build the main UI of the SuppliersPage
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
              return _buildSupplierCard(supplier);
            },
          ),
      ],
    );
  }
}

/// Small reusable widget that tracks its own hover state.
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

// Helper widget to display a label-value pair in the supplier detail dialog
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  // Build the row with a fixed width for the label and flexible width for the value
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

// Helper function to format DateTime to a readable string
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

// Formats a DateTime object into a string like "Jan 1, 2024"
String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
