import 'dart:convert';

import 'package:web/web.dart' as web;

class DonorNotificationSeenStore {
  DonorNotificationSeenStore._();

  static const String _keyPrefix = 'siyam.donor_notifications.seen.v1.';

  static String _key(String donorId) => '$_keyPrefix$donorId';

  static Set<String> load(String donorId) {
    try {
      final raw = web.window.localStorage.getItem(
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

      final allIds = seen.toList();

      final bounded = allIds.length <= 500
          ? allIds
          : allIds.sublist(
              allIds.length - 500,
            );

      web.window.localStorage.setItem(
        _key(donorId),
        jsonEncode(bounded),
      );
    } catch (_) {}
  }
}
