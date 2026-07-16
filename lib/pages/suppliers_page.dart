import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/supplier.dart';
import '../services/supplier_service.dart';
import '../widgets/stat_card.dart';

class SuppliersPage extends StatefulWidget {
  const SuppliersPage({super.key});

  @override
  State<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends State<SuppliersPage> {
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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
      setState(() {
        _error = 'Could not load suppliers: $e';
        _loading = false;
      });
    }
  }

  List<Supplier> get _filtered {
    if (_search.isEmpty) return _suppliers;
    final q = _search.toLowerCase();
    return _suppliers.where((s) => s.suppName.toLowerCase().contains(q)).toList();
  }

  List<PurchaseOrder> _ordersFor(String suppId) =>
      _allOrders.where((o) => o.suppId == suppId).toList();

  Future<void> _openAddSupplierDialog() async {
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
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
              Navigator.of(context).pop();
              try {
                await _service.createSupplier(
                  suppName: nameCtrl.text.trim(),
                  contactNum: contactCtrl.text.trim().isEmpty ? null : contactCtrl.text.trim(),
                  address: addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
                );
                _load();
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
  }

  Future<void> _openDetailDialog(Supplier supplier) async {
    final orders = _ordersFor(supplier.suppId);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(supplier.suppName),
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
              onPressed: _openAddSupplierDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Supplier'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text('${_suppliers.length} suppliers',
            style: const TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
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
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 6),
                      if (supplier.contactNum != null)
                        Text(supplier.contactNum!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.mutedForeground)),
                      if (supplier.address != null)
                        Text(supplier.address!,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12.5, color: AppColors.mutedForeground)),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${orders.length} orders',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.mutedForeground)),
                          Text(
                              orders.isEmpty
                                  ? 'No orders yet'
                                  : 'Last: ${_formatDate(orders.first.receivedDate)}',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.mutedForeground)),
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
