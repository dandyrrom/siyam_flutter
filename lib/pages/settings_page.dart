import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../services/settings_service.dart';

/// Manager Settings Tab -- app-wide alert thresholds (see updated_db.md's
/// SYSTEM_SETTINGS). Reorder Point with Safety Stock and per-item overrides
/// are intentionally out of scope for this increment -- see
/// KNOWN_LIMITATIONS.md.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _service = SettingsService();
  final _formKey = GlobalKey<FormState>();
  final _lowStockCtrl = TextEditingController();
  final _expiryDaysCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _lowStockCtrl.dispose();
    _expiryDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final settings = await _service.fetchSettings();
      if (!mounted) return;
      setState(() {
        _lowStockCtrl.text = formatQty(settings.lowStockThreshold);
        _expiryDaysCtrl.text = settings.expirationWarningDays.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load settings: $e';
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final settings = await _service.updateSettings(
        lowStockThreshold: double.parse(_lowStockCtrl.text.trim()),
        expirationWarningDays: int.parse(_expiryDaysCtrl.text.trim()),
      );
      lowStockPurchaseUnitThreshold = settings.lowStockThreshold;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not save settings: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _positiveNumberValidator(String? v, {bool allowDecimal = true}) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final parsed = allowDecimal ? double.tryParse(v.trim()) : int.tryParse(v.trim());
    if (parsed == null) return 'Enter a number';
    if (parsed <= 0) return 'Must be greater than 0';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Configure app-wide alert thresholds.',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.destructive))
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Inventory Alerts',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lowStockCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Low stock threshold',
                        helperText: 'Whole containers at or below which an item is '
                            'flagged as Low Stock.',
                      ),
                      validator: _positiveNumberValidator,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _expiryDaysCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Expiration warning window (days)',
                        helperText: 'Items with a stock batch expiring within this '
                            'many days are flagged as Expiring Soon.',
                      ),
                      validator: (v) => _positiveNumberValidator(v, allowDecimal: false),
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Save Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
