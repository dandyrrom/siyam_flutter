import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../models/inventory_item.dart';
import '../models/primary_category.dart';
import '../models/subcategory.dart';
import '../services/catalog_service.dart';
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
          const SizedBox(height: 28),
          const Text(
            'Category Management',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add, rename, or delete primary categories and subcategories, and '
            'choose which ones require an expiry date at Stock In.',
            style: TextStyle(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          const _CategoryExpirySection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

/// Manager-configurable expiry-date requirement per primary category and,
/// optionally, per subcategory (overriding the parent). See
/// updated_db.md's PRIMARY_CATEGORY/SUBCATEGORY `requires_expiry` and
/// AddItemPage's `_resolveExpiryRequired`, which reads these values.
class _CategoryExpirySection extends StatefulWidget {
  const _CategoryExpirySection();

  @override
  State<_CategoryExpirySection> createState() => _CategoryExpirySectionState();
}

class _CategoryExpirySectionState extends State<_CategoryExpirySection> {
  final CatalogService _catalogService = CatalogService();

  bool _loading = true;
  bool _savingChanges = false;
  String? _error;
  List<PrimaryCategory> _primaryCategories = [];
  List<Subcategory> _subcategories = [];

  /// Staged edits, not yet written to the catalog service -- keyed by
  /// category/subcategory id. A Switch/SegmentedButton tap only updates
  /// these maps; nothing is persisted until the manager reviews the exact
  /// diff in [_reviewAndSave] and confirms. This changes a Stock In
  /// validation rule for every future stock-in of that category, so a
  /// stray click shouldn't be able to apply it silently.
  final Map<String, bool> _pendingPrimary = {};
  final Map<String, bool?> _pendingSub = {};

  int get _pendingCount => _pendingPrimary.length + _pendingSub.length;
  bool get _hasPendingChanges => _pendingCount > 0;

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
        _catalogService.fetchPrimaryCategories(),
        _catalogService.fetchSubcategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _primaryCategories = results[0] as List<PrimaryCategory>;
        _subcategories = results[1] as List<Subcategory>;
        _pendingPrimary.clear();
        _pendingSub.clear();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load categories: $e';
        _loading = false;
      });
    }
  }

  /// Re-fetches catalog data after an add/rename/delete without touching
  /// [_pendingPrimary]/[_pendingSub] -- unlike [_load], which is only meant
  /// for the initial load and the post-save reset. A manager who's mid-way
  /// through staging expiry-requirement edits shouldn't have that work
  /// silently wiped out because they also renamed an unrelated category;
  /// only entries whose category/subcategory no longer exists (deleted) are
  /// dropped.
  Future<void> _refetch() async {
    final results = await Future.wait([
      _catalogService.fetchPrimaryCategories(),
      _catalogService.fetchSubcategories(),
    ]);
    if (!mounted) return;
    setState(() {
      _primaryCategories = results[0] as List<PrimaryCategory>;
      _subcategories = results[1] as List<Subcategory>;
      _pendingPrimary.removeWhere((id, _) => !_primaryCategories.any((c) => c.id == id));
      _pendingSub.removeWhere((id, _) => !_subcategories.any((s) => s.id == id));
    });
  }

  Future<void> _addPrimaryCategory() async {
    await _promptForName(
      context: context,
      title: 'Add Category',
      label: 'Category name',
      onSubmit: (name) => _catalogService.createPrimaryCategory(name),
    );
    await _refetch();
  }

  Future<void> _addSubcategory(PrimaryCategory parent) async {
    await _promptForName(
      context: context,
      title: 'Add Subcategory to ${parent.type}',
      label: 'Subcategory name',
      onSubmit: (name) =>
          _catalogService.createSubcategory(pCategoryId: parent.id, type: name),
    );
    await _refetch();
  }

  Future<void> _renamePrimaryCategory(PrimaryCategory category, String newName) async {
    await _catalogService.renamePrimaryCategory(id: category.id, type: newName);
    await _refetch();
  }

  Future<void> _renameSubcategory(Subcategory sub, String newName) async {
    await _catalogService.renameSubcategory(id: sub.id, type: newName);
    await _refetch();
  }

  Future<void> _deletePrimaryCategory(PrimaryCategory category) async {
    final confirmed = await _confirmDelete(
      context: context,
      title: 'Delete category?',
      message: 'This will permanently delete "${category.type}" and its expiry setting. '
          'Any subcategories or items must be reassigned or removed first.',
    );
    if (!confirmed) return;
    try {
      await _catalogService.deletePrimaryCategory(category.id);
      await _refetch();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${category.type}" deleted.')));
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        context,
        title: 'Could not delete "${category.type}"',
        error: e,
      );
    }
  }

  Future<void> _deleteSubcategory(Subcategory sub) async {
    final confirmed = await _confirmDelete(
      context: context,
      title: 'Delete subcategory?',
      message: 'This will permanently delete "${sub.type}". Any items under it must be '
          'reassigned or removed first.',
    );
    if (!confirmed) return;
    try {
      await _catalogService.deleteSubcategory(sub.id);
      await _refetch();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('"${sub.type}" deleted.')));
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        context,
        title: 'Could not delete "${sub.type}"',
        error: e,
      );
    }
  }

  bool _effectivePrimary(PrimaryCategory c) => _pendingPrimary[c.id] ?? c.requiresExpiry;

  bool? _effectiveSub(Subcategory s) =>
      _pendingSub.containsKey(s.id) ? _pendingSub[s.id] : s.requiresExpiry;

  /// Stages a primary category's toggle. Setting it back to its saved
  /// value clears the pending entry rather than staging a no-op change.
  void _stagePrimary(PrimaryCategory category, bool value) {
    setState(() {
      if (value == category.requiresExpiry) {
        _pendingPrimary.remove(category.id);
      } else {
        _pendingPrimary[category.id] = value;
      }
    });
  }

  void _stageSub(Subcategory sub, bool? value) {
    setState(() {
      if (value == sub.requiresExpiry) {
        _pendingSub.remove(sub.id);
      } else {
        _pendingSub[sub.id] = value;
      }
    });
  }

  void _discardChanges() => setState(() {
        _pendingPrimary.clear();
        _pendingSub.clear();
      });

  String _label(bool? v) => v == null ? 'Inherit' : (v ? 'Required' : 'Not required');

  Future<void> _reviewAndSave() async {
    final primaryById = {for (final c in _primaryCategories) c.id: c};
    final subById = {for (final s in _subcategories) s.id: s};

    final changeLines = [
      for (final entry in _pendingPrimary.entries)
        '${primaryById[entry.key]!.type}: '
            '${_label(primaryById[entry.key]!.requiresExpiry)} → ${_label(entry.value)}',
      for (final entry in _pendingSub.entries)
        '${primaryById[subById[entry.key]!.pCategoryId]?.type ?? 'Unknown'} '
            '> ${subById[entry.key]!.type}: '
            '${_label(subById[entry.key]!.requiresExpiry)} → ${_label(entry.value)}',
    ];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm expiry-requirement changes'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This changes whether Stock In requires an expiry date for '
                '$_pendingCount categor${_pendingCount == 1 ? 'y' : 'ies'} below. '
                'It applies to every stock-in staff record from now on.',
                style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in changeLines)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(line, style: const TextStyle(fontSize: 13.5)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _savingChanges = true);
    final errors = <String>[];
    for (final entry in _pendingPrimary.entries) {
      try {
        await _catalogService.setPrimaryCategoryRequiresExpiry(
            id: entry.key, requiresExpiry: entry.value);
      } catch (e) {
        errors.add('${primaryById[entry.key]?.type ?? entry.key}: $e');
      }
    }
    for (final entry in _pendingSub.entries) {
      try {
        await _catalogService.setSubcategoryRequiresExpiry(
            id: entry.key, requiresExpiry: entry.value);
      } catch (e) {
        errors.add('${subById[entry.key]?.type ?? entry.key}: $e');
      }
    }
    await _load();
    if (!mounted) return;
    setState(() => _savingChanges = false);
    if (errors.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Category changes saved.')));
    } else {
      await _showErrorDialog(
        context,
        title: 'Some changes could not be saved',
        error: '${errors.length} of $_pendingCount change(s) failed:',
        details: errors,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Text(_error!, style: const TextStyle(color: AppColors.destructive));
    }
    return Column(
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton.icon(
            onPressed: _savingChanges ? null : _addPrimaryCategory,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Category'),
          ),
        ),
        const SizedBox(height: 12),
        if (_hasPendingChanges) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$_pendingCount unsaved change${_pendingCount == 1 ? '' : 's'} -- '
                    'review before this affects Stock In.',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
                TextButton(
                  onPressed: _savingChanges ? null : _discardChanges,
                  child: const Text('Discard'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _savingChanges ? null : _reviewAndSave,
                  child: _savingChanges
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Review'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        for (final category in _primaryCategories)
          Padding(
            key: ValueKey(category.id),
            padding: const EdgeInsets.only(bottom: 12),
            child: _PrimaryCategoryCard(
              category: category,
              effectiveRequiresExpiry: _effectivePrimary(category),
              isDirty: _pendingPrimary.containsKey(category.id),
              subcategories:
                  _subcategories.where((s) => s.pCategoryId == category.id).toList(),
              effectiveSubValue: _effectiveSub,
              isSubDirty: (s) => _pendingSub.containsKey(s.id),
              onPrimaryChanged: (v) => _stagePrimary(category, v),
              onSubChanged: _stageSub,
              onRenamePrimary: (name) => _renamePrimaryCategory(category, name),
              onDeletePrimary: () => _deletePrimaryCategory(category),
              onAddSubcategory: () => _addSubcategory(category),
              onRenameSub: _renameSubcategory,
              onDeleteSub: _deleteSubcategory,
            ),
          ),
      ],
    );
  }
}

/// Prompts for a single required name via a dialog, then calls [onSubmit]
/// with the trimmed value. Errors from [onSubmit] are surfaced as a snackbar
/// rather than left silently swallowed.
Future<void> _promptForName({
  required BuildContext context,
  required String title,
  required String label,
  required Future<void> Function(String name) onSubmit,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (dialogContext) => _NameDialog(title: title, label: label),
  );
  if (name != null) {
    try {
      await onSubmit(name);
    } catch (e) {
      if (context.mounted) {
        await _showErrorDialog(context, title: 'Could not create "$name"', error: e);
      }
    }
  }
}

/// Dialog content for [_promptForName]. Deliberately its own StatefulWidget
/// (rather than a bare controller local to the calling function) so the
/// TextEditingController's lifecycle is owned by this State and disposed in
/// its own `dispose()` -- disposing it manually right after `showDialog`
/// resolves races the route's closing transition: the TextFormField can
/// still be mounted mid-animation when the pop future completes, and
/// touching a controller already disposed at that point crashes with
/// "A TextEditingController was used after being disposed."
class _NameDialog extends StatefulWidget {
  final String title;
  final String label;

  const _NameDialog({required this.title, required this.label});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  final _ctrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_ctrl.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: widget.label),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

/// Standard destructive-action confirmation, matching
/// InventoryItemPage's `_confirmDelete` (rounded dialog, red "Delete"
/// button) so delete looks and behaves the same everywhere in the app.
Future<bool> _confirmDelete({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.destructive),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Modal error acknowledgement -- a snackbar disappears on its own and can
/// be missed, which isn't acceptable for "why didn't my delete/rename/add
/// work" failures. Requires an explicit OK to dismiss, and if [error] is a
/// [CategoryInUseException], lists the actual blocking subcategories/items
/// by name rather than just a count. [details] adds extra bullet lines for
/// callers that already have their own list of per-item failure messages
/// (e.g. a batch save).
Future<void> _showErrorDialog(
  BuildContext context, {
  required String title,
  required Object error,
  List<String>? details,
}) async {
  final blockingSubs =
      error is CategoryInUseException ? error.blockingSubcategoryNames : const <String>[];
  final blockingItems =
      error is CategoryInUseException ? error.blockingItemNames : const <String>[];

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error.toString()),
              if (blockingSubs.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Subcategories still present:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                for (final name in blockingSubs) Text('•  $name'),
              ],
              if (blockingItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('Items still assigned:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                for (final name in blockingItems) Text('•  $name'),
              ],
              if (details != null && details.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final line in details) Text('•  $line'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

/// Collapsible per-primary-category card. Collapsed by default so a
/// category with many subcategories (Medical has ~17 in the DAS Stock In/
/// Out CSVs -- see updated_db.md's SUBCATEGORY note) doesn't force the whole
/// Settings page into one long scroll; expanding reveals its subcategories,
/// with an inline filter once there are enough to be worth searching rather
/// than scanning.
class _PrimaryCategoryCard extends StatefulWidget {
  final PrimaryCategory category;
  final bool effectiveRequiresExpiry;
  final bool isDirty;
  final List<Subcategory> subcategories;
  final bool? Function(Subcategory sub) effectiveSubValue;
  final bool Function(Subcategory sub) isSubDirty;
  final ValueChanged<bool> onPrimaryChanged;
  final void Function(Subcategory sub, bool? value) onSubChanged;
  final Future<void> Function(String newName) onRenamePrimary;
  final VoidCallback onDeletePrimary;
  final VoidCallback onAddSubcategory;
  final Future<void> Function(Subcategory sub, String newName) onRenameSub;
  final void Function(Subcategory sub) onDeleteSub;

  const _PrimaryCategoryCard({
    required this.category,
    required this.effectiveRequiresExpiry,
    required this.isDirty,
    required this.subcategories,
    required this.effectiveSubValue,
    required this.isSubDirty,
    required this.onPrimaryChanged,
    required this.onSubChanged,
    required this.onRenamePrimary,
    required this.onDeletePrimary,
    required this.onAddSubcategory,
    required this.onRenameSub,
    required this.onDeleteSub,
  });

  @override
  State<_PrimaryCategoryCard> createState() => _PrimaryCategoryCardState();
}

/// Above this many subcategories, an inline filter field is worth the extra
/// row -- below it, scanning a short list is faster than typing.
const int _kSubcategoryFilterThreshold = 6;

class _PrimaryCategoryCardState extends State<_PrimaryCategoryCard> {
  bool _expanded = false;
  final _filterCtrl = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  static Widget _dirtyDot() => Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 8),
        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
      );

  @override
  Widget build(BuildContext context) {
    final visibleSubs = _filter.isEmpty
        ? widget.subcategories
        : widget.subcategories
            .where((s) => s.type.toLowerCase().contains(_filter.toLowerCase()))
            .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDirty ? AppColors.primary : AppColors.border,
          width: widget.isDirty ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                tooltip: _expanded ? 'Collapse' : 'Expand',
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              if (widget.isDirty) _dirtyDot(),
              Expanded(
                child: _EditableLabel(
                  value: widget.category.type,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  onSave: widget.onRenamePrimary,
                ),
              ),
              if (widget.subcategories.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text('${widget.subcategories.length} sub'
                      '${widget.subcategories.length == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 12, color: AppColors.mutedForeground)),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                tooltip: 'Delete category',
                visualDensity: VisualDensity.compact,
                onPressed: widget.onDeletePrimary,
              ),
            ],
          ),
          if (_expanded) ...[
            const Divider(height: 24),
            // Expiry requirement lives inside the expanded body, not the
            // collapsed header -- it's a setting you go looking for, not
            // identity info you need at a glance, so it doesn't need to
            // compete with the name/count/delete row for space. Label
            // indented to line up with the category name above it; switch
            // pushed to the far right to line up with the delete icon.
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 40),
                    child: Text('Requires expiry date',
                        style: TextStyle(fontSize: 13, color: AppColors.mutedForeground)),
                  ),
                  const Spacer(),
                  Switch(
                      value: widget.effectiveRequiresExpiry, onChanged: widget.onPrimaryChanged),
                ],
              ),
            ),
            if (widget.subcategories.length > _kSubcategoryFilterThreshold) ...[
              TextField(
                controller: _filterCtrl,
                decoration: const InputDecoration(
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Filter subcategories',
                ),
                onChanged: (v) => setState(() => _filter = v),
              ),
              const SizedBox(height: 12),
            ],
            for (final sub in visibleSubs)
              Padding(
                key: ValueKey(sub.id),
                padding: const EdgeInsets.only(left: 40, bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (widget.isSubDirty(sub)) _dirtyDot(),
                        Expanded(
                          child: _EditableLabel(
                            value: sub.type,
                            style: const TextStyle(fontSize: 13.5),
                            onSave: (name) => widget.onRenameSub(sub, name),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          tooltip: 'Delete subcategory',
                          visualDensity: VisualDensity.compact,
                          onPressed: () => widget.onDeleteSub(sub),
                        ),
                      ],
                    ),
                    // Own line, and horizontally scrollable as a last
                    // resort -- three segments ("Inherit"/"Required"/"Not
                    // required") don't shrink below their text width, so on
                    // a narrow window this is the fallback that guarantees
                    // no RenderFlex overflow instead of clipping content.
                    Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SegmentedButton<bool?>(
                          style: SegmentedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          segments: const [
                            ButtonSegment(value: null, label: Text('Inherit')),
                            ButtonSegment(value: true, label: Text('Required')),
                            ButtonSegment(value: false, label: Text('Not required')),
                          ],
                          selected: {widget.effectiveSubValue(sub)},
                          showSelectedIcon: false,
                          onSelectionChanged: (selection) =>
                              widget.onSubChanged(sub, selection.first),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (visibleSubs.isEmpty && widget.subcategories.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No subcategories match "$_filter".',
                    style: const TextStyle(color: AppColors.mutedForeground, fontSize: 13)),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onAddSubcategory,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Subcategory'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inline rename affordance: a label with a pencil icon that swaps to a
/// text field with explicit confirm/cancel icons. Deliberately not
/// auto-save-on-blur -- clicking away to edit something else shouldn't be
/// able to silently commit a half-typed rename.
class _EditableLabel extends StatefulWidget {
  final String value;
  final TextStyle? style;
  final Future<void> Function(String newValue) onSave;

  const _EditableLabel({required this.value, required this.onSave, this.style});

  @override
  State<_EditableLabel> createState() => _EditableLabelState();
}

class _EditableLabelState extends State<_EditableLabel> {
  bool _editing = false;
  bool _saving = false;
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(covariant _EditableLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_editing && oldWidget.value != widget.value) {
      _ctrl.text = widget.value;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final newValue = _ctrl.text.trim();
    if (newValue.isEmpty || newValue == widget.value) {
      setState(() {
        _editing = false;
        _ctrl.text = widget.value;
      });
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(newValue);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      await _showErrorDialog(context, title: 'Could not rename to "$newValue"', error: e);
    }
  }

  void _cancel() => setState(() {
        _editing = false;
        _ctrl.text = widget.value;
      });

  @override
  Widget build(BuildContext context) {
    if (!_editing) {
      return Row(
        children: [
          Flexible(child: Text(widget.value, style: widget.style)),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 15),
            tooltip: 'Rename',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _editing = true),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _ctrl,
            autofocus: true,
            style: widget.style,
            decoration: const InputDecoration(isDense: true),
            onSubmitted: (_) => _confirm(),
          ),
        ),
        if (_saving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
                height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          IconButton(
            icon: const Icon(Icons.check, size: 18, color: AppColors.primary),
            tooltip: 'Save',
            visualDensity: VisualDensity.compact,
            onPressed: _confirm,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Cancel',
            visualDensity: VisualDensity.compact,
            onPressed: _cancel,
          ),
        ],
      ],
    );
  }
}
