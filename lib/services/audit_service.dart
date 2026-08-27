import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_entry.dart';
import 'backend.dart';

// =============================================================================
// AUDIT SERVICE
// =============================================================================
//
// Read-only Audit Trail service.
//
// Manager:
// - can request the complete audit data permitted by RLS.
//
// Staff:
// - the page supplies actorUserId + operational modules,
// - only their own permitted activity is requested,
// - change-detail JSON is not selected for the limited Staff view.
//
// The database trigger writes audit_log rows. Flutter only reads/presents them.
// =============================================================================

class AuditService {
  AuditService()
      : _client =
            kUseMock ? null : Supabase.instance.client;

  final SupabaseClient? _client;

  Future<List<AuditEntry>> fetchEntries({
    int limit = 500,
    String? actorUserId,
    List<String>? modules,
    bool includeChangeDetails = true,
  }) async {
    // Mock mode has no audit_log table. Return an empty trail so Audit /
    // My Activity pages still open without requiring Supabase.
    if (kUseMock || _client == null) {
      return const <AuditEntry>[];
    }

    final client = _client;

    // Always fetch before/after JSON internally so the service can resolve
    // human-readable entity context even for Staff My Activity.
    //
    // Staff still do NOT receive these maps in AuditEntry when
    // includeChangeDetails is false.
    const selectedColumns =
        'auditid, actor_user_id, module, action, '
        'entity_type, entity_id, entity_label, summary, '
        'old_values, new_values, createdat';

    var auditQuery =
        client
            .from('audit_log')
            .select(selectedColumns);

    final cleanActorId =
        actorUserId?.trim();

    if (cleanActorId != null &&
        cleanActorId.isNotEmpty) {
      auditQuery =
          auditQuery.eq(
        'actor_user_id',
        cleanActorId,
      );
    }

    if (modules != null &&
        modules.isNotEmpty) {
      auditQuery =
          auditQuery.inFilter(
        'module',
        modules,
      );
    }

    final results =
        await Future.wait<Object?>([
      auditQuery
          .order(
            'createdat',
            ascending: false,
          )
          .limit(limit),

      client
          .from('users')
          .select(
            'id, fname, lname, role',
          ),

      client
          .from('item')
          .select('id, name'),

      client
          .from('supplier')
          .select('id, name'),

      client
          .from('pet')
          .select('id, name'),

      client
          .from('purchase_item')
          .select('purchaseid, itemid'),

      client
          .from('treatment')
          .select('id, name, petid'),

      client
          .from('treatment_item')
          .select(
            'treatmentitemid, treatid, itemid, dispensed_qty, dispense_unit',
          ),

      client
          .from('units')
          .select('id, abbr_name'),
    ]);

    final auditRows =
        results[0] as List<dynamic>;

    final userRows =
        results[1] as List<dynamic>;

    final itemRows =
        results[2] as List<dynamic>;

    final supplierRows =
        results[3] as List<dynamic>;

    final petRows =
        results[4] as List<dynamic>;

    final purchaseItemRows =
        results[5] as List<dynamic>;

    final treatmentRows =
        results[6] as List<dynamic>;

    final treatmentItemRows =
        results[7] as List<dynamic>;

    final unitRows =
        results[8] as List<dynamic>;

    final users =
        <String, ({String name, String role})>{};

    for (final raw in userRows) {
      final row =
          Map<String, dynamic>.from(raw);

      final id =
          row['id'] as String;

      final first =
          (row['fname'] as String?) ?? '';

      final last =
          (row['lname'] as String?) ?? '';

      final name =
          '$first $last'.trim();

      users[id] = (
        name:
            name.isEmpty
                ? 'Unknown user'
                : name,
        role:
            ((row['role'] as Object?)
                        ?.toString() ??
                    '')
                .trim(),
      );
    }

    final items = <String, String>{
      for (final raw in itemRows)
        (raw['id'] as String):
            ((raw['name'] as String?) ??
                'Unknown item'),
    };

    // ==========================================================================
    // PURCHASE STOCK-IN ITEM LABELS
    // ==========================================================================
    //
    // The overall purchase audit is stored on the purchase record, while the
    // actual stocked item lines are stored in purchase_item.
    // Resolve those item names here so My Activity can show what was stocked.
    // ==========================================================================

    final purchaseItems =
        <String, List<String>>{};

    for (final raw in purchaseItemRows) {
      final row =
          Map<String, dynamic>.from(raw);

      final purchaseId =
          row['purchaseid'] as String?;

      final itemId =
          row['itemid'] as String?;

      if (purchaseId == null ||
          itemId == null) {
        continue;
      }

      final itemName =
          items[itemId] ?? 'Unknown item';

      final names =
          purchaseItems.putIfAbsent(
        purchaseId,
        () => <String>[],
      );

      if (!names.contains(itemName)) {
        names.add(itemName);
      }
    }

    for (final names
        in purchaseItems.values) {
      names.sort(
        (a, b) => a
            .toLowerCase()
            .compareTo(
              b.toLowerCase(),
            ),
      );
    }

    final suppliers = <String, String>{
      for (final raw in supplierRows)
        (raw['id'] as String):
            ((raw['name'] as String?) ??
                'Unknown supplier'),
    };

    final pets = <String, String>{
      for (final raw in petRows)
        (raw['id'] as String):
            ((raw['name'] as String?) ??
                'Unknown animal'),
    };

    // ==========================================================================
    // TREATMENT AUDIT CONTEXT
    // ==========================================================================
    //
    // Staff My Activity should answer:
    //
    //   Which animal?
    //   Which treatment?
    //   Which inventory item?
    //   How much was used?
    //
    // The raw audit row remains unchanged. These maps only enrich the
    // client-facing read-only presentation.
    // ==========================================================================

    final units = <String, String>{
      for (final raw in unitRows)
        (raw['id'] as String):
            ((raw['abbr_name'] as String?) ?? ''),
    };

    final treatments =
        <String, ({String name, String petName})>{};

    for (final raw in treatmentRows) {
      final row =
          Map<String, dynamic>.from(raw);

      final treatmentId =
          row['id'] as String;

      final petId =
          row['petid'] as String?;

      final treatmentName =
          ((row['name'] as String?) ?? '')
              .trim();

      treatments[treatmentId] = (
        name:
            treatmentName.isEmpty
                ? 'Treatment'
                : treatmentName,
        petName:
            petId == null
                ? 'Unknown animal'
                : (pets[petId] ??
                    'Unknown animal'),
      );
    }

    final treatmentItems =
        <String, String>{};

    for (final raw in treatmentItemRows) {
      final row =
          Map<String, dynamic>.from(raw);

      final treatmentItemId =
          row['treatmentitemid'] as String?;

      final treatmentId =
          row['treatid'] as String?;

      final itemId =
          row['itemid'] as String?;

      if (treatmentItemId == null ||
          treatmentId == null ||
          itemId == null) {
        continue;
      }

      final treatment =
          treatments[treatmentId];

      final treatmentName =
          treatment?.name ?? 'Treatment';

      final petName =
          treatment?.petName ??
              'Unknown animal';

      final itemName =
          items[itemId] ?? 'Unknown item';

      final qty =
          (row['dispensed_qty'] as num?)
                  ?.toDouble() ??
              0;

      final dispenseUnitId =
          row['dispense_unit'] as String?;

      final unitAbbr =
          dispenseUnitId == null
              ? ''
              : (units[dispenseUnitId] ?? '');

      final qtyLabel =
          _formatAuditQty(qty);

      final quantityText =
          unitAbbr.trim().isEmpty
              ? qtyLabel
              : '$qtyLabel $unitAbbr';

      treatmentItems[treatmentItemId] =
          'Animal: $petName · '
          'Treatment: $treatmentName · '
          'Item used: $itemName · '
          'Qty: $quantityText';
    }

    final entries =
        <AuditEntry>[];

    for (final raw in auditRows) {
      final row =
          Map<String, dynamic>.from(raw);

      final actorId =
          row['actor_user_id']
              as String?;

      final actor =
          actorId == null
              ? null
              : users[actorId];

      final internalOldValues =
          _jsonMap(
        row['old_values'],
      );

      final internalNewValues =
          _jsonMap(
        row['new_values'],
      );

      final entityType =
          (row['entity_type']
                  as String?) ??
              '';

      final entityId =
          row['entity_id']
              as String?;

      var entityLabel =
          row['entity_label']
              as String?;

      final resolvedEntityLabel =
          _resolveEntityLabel(
        entityType:
            entityType,
        entityId:
            entityId,
        oldValues:
            internalOldValues,
        newValues:
            internalNewValues,
        items:
            items,
        suppliers:
            suppliers,
        pets:
            pets,
        purchaseItems:
            purchaseItems,
        treatments:
            treatments,
        treatmentItems:
            treatmentItems,
        units:
            units,
      );

      if (entityType == 'purchase' ||
          entityType == 'treatment' ||
          entityType == 'treatment_item') {
        entityLabel =
            resolvedEntityLabel ??
                entityLabel;
      } else {
        entityLabel ??=
            resolvedEntityLabel;
      }

      var summary =
          (row['summary'] as String?) ??
              'System activity';

      summary =
          _enhanceSummary(
        summary,
        entityType,
        entityLabel,
      );

      entries.add(
        AuditEntry(
          auditId:
              row['auditid']
                  as String,
          actorUserId:
              actorId,
          actorName:
              actor?.name ??
                  'System',
          actorRole:
              _roleLabel(
            actor?.role ?? '',
          ),
          module:
              (row['module']
                      as String?) ??
                  'System',
          action:
              (row['action']
                      as String?) ??
                  'UPDATE',
          entityType:
              entityType,
          entityId:
              entityId,
          entityLabel:
              entityLabel,
          summary:
              summary,
          oldValues:
              includeChangeDetails
                  ? internalOldValues
                  : null,
          newValues:
              includeChangeDetails
                  ? internalNewValues
                  : null,
          createdAt:
              DateTime.parse(
            row['createdat']
                as String,
          ).toLocal(),
        ),
      );
    }

    return entries;
  }

  Map<String, dynamic>? _jsonMap(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value
        is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(
        value,
      );
    }

    return null;
  }

  String? _resolveEntityLabel({
    required String entityType,
    required String? entityId,
    required Map<String, dynamic>?
        oldValues,
    required Map<String, dynamic>?
        newValues,
    required Map<String, String> items,
    required Map<String, String> suppliers,
    required Map<String, String> pets,
    required Map<String, List<String>>
        purchaseItems,
    required Map<
        String,
        ({String name, String petName})>
        treatments,
    required Map<String, String>
        treatmentItems,
    required Map<String, String> units,
  }) {
    if (entityType == 'purchase' &&
        entityId != null) {
      final stockedItems =
          purchaseItems[entityId];

      if (stockedItems != null &&
          stockedItems.isNotEmpty) {
        return stockedItems.join(', ');
      }
    }

    if (entityType == 'treatment' &&
        entityId != null) {
      final treatment =
          treatments[entityId];

      if (treatment != null) {
        return 'Animal: ${treatment.petName}';
      }
    }

    // Try the generic audit entity id directly against treatment_item PKs.
    // This does not depend on the exact entity_type text used by the trigger.
    if (entityId != null) {
      final context =
          treatmentItems[entityId];

      if (context != null &&
          context.trim().isNotEmpty) {
        return context;
      }
    }

    final data =
        newValues ?? oldValues;

    if (data == null) {
      return null;
    }

    // Live SIYAM treatment_item primary key.
    final treatmentItemId =
        data['treatmentitemid'] as String?;

    if (treatmentItemId != null) {
      final context =
          treatmentItems[treatmentItemId];

      if (context != null &&
          context.trim().isNotEmpty) {
        return context;
      }
    }

    // Fallback for audit rows where entity_id is missing or generic.
    // The audit payload still contains the real treatment/item relationship.
    final treatmentId =
        data['treatid'] as String?;

    final itemId =
        data['itemid'] as String?;

    if (treatmentId != null &&
        itemId != null) {
      final treatment =
          treatments[treatmentId];

      final treatmentName =
          treatment?.name ?? 'Treatment';

      final petName =
          treatment?.petName ??
              'Unknown animal';

      final itemName =
          items[itemId] ?? 'Unknown item';

      final qty =
          (data['dispensed_qty'] as num?)
                  ?.toDouble() ??
              0;

      final dispenseUnitId =
          data['dispense_unit'] as String?;

      final unitAbbr =
          dispenseUnitId == null
              ? ''
              : (units[dispenseUnitId] ?? '');

      final qtyLabel =
          _formatAuditQty(qty);

      final quantityText =
          unitAbbr.trim().isEmpty
              ? qtyLabel
              : '$qtyLabel $unitAbbr';

      return 'Animal: $petName · '
          'Treatment: $treatmentName · '
          'Item used: $itemName · '
          'Qty: $quantityText';
    }

    if (itemId != null &&
        items.containsKey(itemId)) {
      return items[itemId];
    }

    final suppId =
        data['suppid'] as String?;

    if (suppId != null &&
        suppliers.containsKey(
          suppId,
        )) {
      return suppliers[suppId];
    }

    final petId =
        data['petid'] as String?;

    if (petId != null &&
        pets.containsKey(petId)) {
      return pets[petId];
    }

    if (entityType == 'pet') {
      return (data['name']
                  as String?) ??
          (data['petname']
              as String?);
    }

    return (data['name']
                as String?) ??
        (data['type'] as String?) ??
        (data['abbr_name']
            as String?);
  }

  String _enhanceSummary(
    String summary,
    String entityType,
    String? label,
  ) {
    if (label == null ||
        label.trim().isEmpty) {
      return summary;
    }

    if (summary
        .toLowerCase()
        .contains(
          label.toLowerCase(),
        )) {
      return summary;
    }

    const addLabelFor = {
      'stock_out',
      'item_rop_settings',
    };

    if (!addLabelFor.contains(
      entityType,
    )) {
      return summary;
    }

    return '$summary — $label';
  }

  String _formatAuditQty(
    double value,
  ) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value
        .toStringAsFixed(3)
        .replaceFirst(
          RegExp(r'0+$'),
          '',
        )
        .replaceFirst(
          RegExp(r'\.$'),
          '',
        );
  }

  String _roleLabel(
    String raw,
  ) {
    final value =
        raw.trim().toLowerCase();

    if (value.isEmpty) {
      return 'System';
    }

    return '${value[0].toUpperCase()}'
        '${value.substring(1)}';
  }
}
