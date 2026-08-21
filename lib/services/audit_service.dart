import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/audit_entry.dart';

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
  final SupabaseClient _client =
      Supabase.instance.client;

  Future<List<AuditEntry>> fetchEntries({
    int limit = 500,
    String? actorUserId,
    List<String>? modules,
    bool includeChangeDetails = true,
  }) async {
    final selectedColumns =
        includeChangeDetails
            ? 'auditid, actor_user_id, module, action, '
                'entity_type, entity_id, entity_label, summary, '
                'old_values, new_values, createdat'
            : 'auditid, actor_user_id, module, action, '
                'entity_type, entity_id, entity_label, summary, '
                'createdat';

    var auditQuery =
        _client
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

      _client
          .from('users')
          .select(
            'id, fname, lname, role',
          ),

      _client
          .from('item')
          .select('id, name'),

      _client
          .from('supplier')
          .select('id, name'),

      _client
          .from('pet')
          .select('id, name'),
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

      final oldValues =
          _jsonMap(
        row['old_values'],
      );

      final newValues =
          _jsonMap(
        row['new_values'],
      );

      final entityType =
          (row['entity_type']
                  as String?) ??
              '';

      var entityLabel =
          row['entity_label']
              as String?;

      entityLabel ??=
          _resolveEntityLabel(
        entityType:
            entityType,
        oldValues:
            oldValues,
        newValues:
            newValues,
        items:
            items,
        suppliers:
            suppliers,
        pets:
            pets,
      );

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
              row['entity_id']
                  as String?,
          entityLabel:
              entityLabel,
          summary:
              summary,
          oldValues:
              oldValues,
          newValues:
              newValues,
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
    required Map<String, dynamic>?
        oldValues,
    required Map<String, dynamic>?
        newValues,
    required Map<String, String> items,
    required Map<String, String> suppliers,
    required Map<String, String> pets,
  }) {
    final data =
        newValues ?? oldValues;

    if (data == null) {
      return null;
    }

    final itemId =
        data['itemid'] as String?;

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
      'purchase',
      'stock_out',
      'treatment_item',
      'item_rop_settings',
    };

    if (!addLabelFor.contains(
      entityType,
    )) {
      return summary;
    }

    return '$summary — $label';
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
