// =============================================================================
// AUDIT ENTRY
// =============================================================================
//
// One Manager-facing action recorded by the centralized Supabase audit_log.
// =============================================================================

class AuditEntry {
  final String auditId;
  final String? actorUserId;
  final String actorName;
  final String actorRole;

  final String module;
  final String action;

  final String entityType;
  final String? entityId;
  final String? entityLabel;

  final String summary;

  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;

  final DateTime createdAt;

  const AuditEntry({
    required this.auditId,
    required this.actorUserId,
    required this.actorName,
    required this.actorRole,
    required this.module,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.entityLabel,
    required this.summary,
    required this.oldValues,
    required this.newValues,
    required this.createdAt,
  });

  bool get isCreate => action == 'CREATE';
  bool get isUpdate => action == 'UPDATE';
  bool get isDelete => action == 'DELETE';

  // -------------------------------------------------------------------------
  // BUSINESS CONTEXT HELPERS
  // -------------------------------------------------------------------------
  //
  // The Audit Trail actor is the authenticated account that performed/recorded
  // the action in SIYAM. Some records also contain a different person who
  // physically received stock on-site. Keep those concepts separate.
  // -------------------------------------------------------------------------

  Map<String, dynamic>? get latestValues =>
      newValues ?? oldValues;

  String? get receivedBy {
    final value = latestValues?['receivedby'];

    if (value == null) return null;

    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  bool get hasDifferentReceiver =>
      receivedBy != null &&
      receivedBy!.toLowerCase() != actorName.toLowerCase();
}
