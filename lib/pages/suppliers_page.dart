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

  List<Supplier> get _filtered {
    if (_search.isEmpty) return _suppliers;
    final q = _search.toLowerCase();
    return _suppliers.where((s) => s.suppName.toLowerCase().contains(q)).toList();
  }

  List<PurchaseOrder> _ordersFor(String suppId) =>
      _allOrders.where((o) => o.suppId == suppId).toList();

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
        backgroundColor: Colors.green,
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

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEdit ? 'Edit Supplier' : 'Add Supplier'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    autofocus: !isEdit,
                    decoration: const InputDecoration(labelText: 'Supplier name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Address (optional)'),
                  ),
                ],
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
                      try {
                        final cleanPhone = contactCtrl.text.trim().isEmpty
                            ? null
                            : contactCtrl.text.trim();
                        final cleanTel = contactTelCtrl.text.trim().isEmpty
                            ? null
                            : contactTelCtrl.text.trim();

                        if (isEdit) {
                          await _service.updateSupplier(
                            suppId: supplier.suppId,
                            suppName: nameCtrl.text.trim(),
                            contactNum: cleanPhone,
                            contactTel: cleanTel,
                            address: addressCtrl.text.trim().isEmpty
                                ? null
                                : addressCtrl.text.trim(),
                          );
                        } else {
                          await _service.createSupplier(
                            suppName: nameCtrl.text.trim(),
                            contactNum: cleanPhone,
                            contactTel: cleanTel,
                            address: addressCtrl.text.trim().isEmpty
                                ? null
                                : addressCtrl.text.trim(),
                          );
                        }

                        if (builderContext.mounted) {
                          Navigator.of(builderContext).pop();
                        }

                        if (!mounted) return;
                        _showSuccessSnackBar(
                          isEdit
                              ? '${nameCtrl.text.trim()} updated successfully'
                              : '${nameCtrl.text.trim()} added successfully',
                        );
                        await _load();
                      } catch (e) {
                        if (!builderContext.mounted) return;
                        setDialogState(() => saving = false);
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
                    },
              child: Text(isEdit ? 'Save Changes' : 'Add Supplier'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    contactCtrl.dispose();
    contactTelCtrl.dispose();
    addressCtrl.dispose();
  }

  Future<void> _openDetailDialog(Supplier supplier) async {
    final orders = _ordersFor(supplier.suppId);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(supplier.suppName),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DetailRow(label: 'Contact number', value: supplier.contactNum ?? '—'),
                _DetailRow(label: 'Contact tel', value: supplier.contactTel ?? '—'),
                _DetailRow(label: 'Address', value: supplier.address ?? '—'),
                _DetailRow(label: 'Total Orders', value: '${orders.length}'),
                _DetailRow(
                  label: 'Last Order',
                  value: orders.isEmpty ? '—' : _formatDate(orders.first.receivedDate),
                ),
                const SizedBox(height: 12),
                const Text('Purchase History',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 8),
                if (orders.isEmpty)
                  const Text('No purchase orders yet.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground))
                else
                  for (final order in orders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text(_formatDate(order.receivedDate))),
                          Text(order.buyerName,
                              style: const TextStyle(
                                  fontSize: 12.5, color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openSupplierFormDialog(supplier: supplier);
            },
            child: const Text('Edit Supplier'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // MOBILE DETECTION: Check if screen width is less than 600px
    // ============================================================
    final bool isMobile = MediaQuery.of(context).size.width < 600;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ============================================================
        // HEADER: Stacked on mobile, Row on web
        // ============================================================
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Suppliers',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
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
            : Row(
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
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
        const SizedBox(height: 20),

        // ============================================================
        // STAT CARDS: Stacked on mobile, Row on web
        // ============================================================
        isMobile
            ? Column(
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
                  ),
                ],
              )
            : StatCardRow(cards: [
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

        // ============================================================
        // SEARCH: Full width on mobile
        // ============================================================
        SizedBox(
          width: isMobile ? double.infinity : 280,
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

        // ============================================================
        // EMPTY STATES OR GRID
        // ============================================================
        if (_suppliers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 56),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 36, color: AppColors.mutedForeground),
                  SizedBox(height: 10),
                  Text('No suppliers yet', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  Icon(Icons.search_off, size: 32, color: AppColors.mutedForeground),
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
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: isMobile ? 280 : 320,
              mainAxisExtent: isMobile ? 180 : 165,
              crossAxisSpacing: isMobile ? 10 : 16,
              mainAxisSpacing: isMobile ? 10 : 16,
            ),
            itemCount: _filtered.length,
            itemBuilder: (context, index) {
              final supplier = _filtered[index];
              final orders = _ordersFor(supplier.suppId);
              return _Hoverable(
                builder: (context, isHovered) => InkWell(
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
                            ? AppColors.roleManager.withValues(alpha: 0.4)
                            : AppColors.border,
                        width: isHovered ? 1.5 : 1,
                      ),
                      boxShadow: isHovered
                          ? [
                              BoxShadow(
                                color: AppColors.roleManager.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(supplier.suppName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isMobile ? 14 : 15,
                              color: isHovered ? AppColors.roleManager : null,
                            )),
                        const SizedBox(height: 6),
                        if (supplier.contactNum != null)
                          Text(supplier.contactNum!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: isMobile ? 11 : 12.5,
                                  color: AppColors.mutedForeground)),
                        if (supplier.contactTel != null)
                          Text(supplier.contactTel!,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: isMobile ? 11 : 12.5,
                                  color: AppColors.mutedForeground)),
                        if (supplier.address != null)
                          Text(supplier.address!,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                              style: TextStyle(
                                  fontSize: isMobile ? 11 : 12.5,
                                  color: AppColors.mutedForeground)),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${orders.length} orders',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: isMobile ? 11 : 12,
                                    color: AppColors.mutedForeground)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                  orders.isEmpty
                                      ? 'No orders yet'
                                      : 'Last: ${_formatDate(orders.first.receivedDate)}',
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                      fontSize: isMobile ? 11 : 12,
                                      color: AppColors.mutedForeground)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // ============================================================
  // MOBILE STAT CARD
  // ============================================================
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
        borderRadius: BorderRadius.circular(12),
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
          Column(
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
            ],
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
                style: const TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';