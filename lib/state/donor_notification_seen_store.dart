import 'dart:convert';

import 'package:web/web.dart' as web;

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
// The SIYAM project is currently a Flutter Web port and already depends on the
// `web` package, so browser localStorage gives us persistence across refreshes
// without adding a new database table or changing the existing donation schema.
// The key is scoped per donor account so two donors using the same browser do
// not share read state.
// =============================================================================

class DonorNotificationSeenStore {
  DonorNotificationSeenStore._();

  static const String _keyPrefix =
      'siyam.donor_notifications.seen.v1.';

  static String _key(String donorId) =>
      '$_keyPrefix$donorId';

  static Set<String> load(String donorId) {
    try {
      final raw =
          web.window.localStorage.getItem(
        _key(donorId),
      );

      if (raw == null || raw.isEmpty) {
        return <String>{};
      }

      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return <String>{};
      }

      return decoded
          .whereType<String>()
          .toSet();
    } catch (_) {
      // Storage can be unavailable in restricted/private browser contexts.
      // The bell should still work; only persistence is skipped.
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

      // Keep storage bounded. Linked insertion order is retained by the set
      // created from the decoded JSON list, so the newest additions remain at
      // the end and are kept when trimming is ever necessary.
      final allIds = seen.toList();
      final bounded = allIds.length <= 500
          ? allIds
          : allIds.sublist(allIds.length - 500);

      web.window.localStorage.setItem(
        _key(donorId),
        jsonEncode(bounded),
      );
    } catch (_) {
      // Read state is a UI convenience. A storage failure must never block the
      // donor from opening or navigating through notifications.
    }
  }
}
