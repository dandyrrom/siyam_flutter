// =============================================================================
// NON-WEB DONOR NOTIFICATION STORAGE
// =============================================================================
//
// Android and other non-web platforms do not have browser localStorage.
//
// This lightweight fallback keeps notification seen-state in memory during the
// current application session.
//
// It only affects the unread notification badge. Notification data itself
// continues to come from SIYAM's existing donation and impact data.
// =============================================================================

final Map<String, String> _memoryStorage = <String, String>{};

// Reads donor notification state from temporary memory storage.
String? getItem(String key) {
  return _memoryStorage[key];
}

// Saves donor notification state to temporary memory storage.
void setItem(
  String key,
  String value,
) {
  _memoryStorage[key] = value;
}
