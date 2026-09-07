class DonorNotificationSeenStore {
  DonorNotificationSeenStore._();

  static final Map<String, Set<String>> _seenByDonor = <String, Set<String>>{};

  static Set<String> load(
    String donorId,
  ) {
    return Set<String>.from(
      _seenByDonor[donorId] ?? const <String>{},
    );
  }

  static void markSeen(
    String donorId,
    Iterable<String> notificationIds,
  ) {
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

    _seenByDonor[donorId] = bounded.toSet();
  }
}
