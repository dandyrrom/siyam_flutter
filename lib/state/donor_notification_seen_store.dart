import 'dart:convert';

import 'donor_notification_seen_store_stub.dart'
    if (dart.library.js_interop) 'donor_notification_seen_store_web.dart'
    as storage;

// =============================================================================
// DONOR NOTIFICATION SEEN STORE
// =============================================================================
//
// Donor notifications are derived from existing SIYAM donation/impact data and
// already have stable IDs such as:
//
//   approved:<submissionId>
//   received:<submissionId>
//   impact:<treatmentKey>
//
// This store remembers which of those IDs the donor has already viewed.
// Nothing is deleted from the notification list. The store only controls the
// bell's unread badge.
//
// Web:
// - Uses browser localStorage.
// - Seen state persists across browser refreshes.
//
// Android / other non-web platforms:
// - Uses a lightweight in-memory fallback.
// - Prevents browser-only APIs from being compiled into the Android APK.
//
// The key is scoped per donor account so different donors do not share
// notification read state.
// =============================================================================

class DonorNotificationSeenStore {
  DonorNotificationSeenStore._();

  static const String _keyPrefix = 'siyam.donor_notifications.seen.v1.';

  static String _key(String donorId) => '$_keyPrefix$donorId';

  static Set<String> load(String donorId) {
    try {
      final raw = storage.getItem(
        _key(donorId),
      );

      if (raw == null || raw.isEmpty) {
        return <String>{};
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return <String>{};
      }

      return decoded.whereType<String>().toSet();
    } catch (_) {
      // Storage failure must not prevent the notification bell from working.
      return <String>{};
    }
  }

  static void markSeen(
    String donorId,
    Iterable<String> notificationIds,
  ) {
    try {
      final seen = load(donorId);

      for (final id in notificationIds) {
        if (id.trim().isNotEmpty) {
          seen.add(id);
        }
      }

      // Keep local notification read-state bounded.
      final allIds = seen.toList();

      final bounded = allIds.length <= 500
          ? allIds
          : allIds.sublist(
              allIds.length - 500,
            );

      storage.setItem(
        _key(donorId),
        jsonEncode(bounded),
      );
    } catch (_) {
      // Read-state is only a UI convenience and must never block navigation.
    }
  }
}
