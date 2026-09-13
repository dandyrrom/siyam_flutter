import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/backend.dart';
import 'data_bus.dart';
import 'page_snapshot_cache.dart';

/// Listens to Postgres changes for every table SIYAM reads and pushes those
/// updates into the existing silent-refresh path.
///
/// Same-session writes still ping [DataChangeBus] directly. This covers the
/// other-user case: another Staff/Manager/Donor changes data, open screens
/// refresh without a manual reload.
class AppRealtimeSync {
  AppRealtimeSync._();

  static final AppRealtimeSync instance = AppRealtimeSync._();

  static const Duration _debounce = Duration(milliseconds: 250);

  static const List<String> _tables = [
    'users',
    'primary_category',
    'subcategory',
    'units',
    'item',
    'system_settings',
    'item_rop_settings',
    'pet',
    'supplier',
    'purchase',
    'purchase_item',
    'treatment',
    'treatment_item',
    'treatment_occurrence',
    'submission',
    'donation',
    'donation_item',
    'stock_out',
    'inventory_batch',
    'batch_transaction_log',
    'audit_log',
  ];

  RealtimeChannel? _channel;
  Timer? _debounceTimer;
  bool _started = false;

  void start() {
    if (kUseMock || _started) {
      return;
    }

    _started = true;

    var channel = Supabase.instance.client.channel('siyam-realtime');

    for (final table in _tables) {
      channel = channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: (_) => _scheduleRefresh(),
      );
    }

    _channel = channel.subscribe();
  }

  void stop() {
    _debounceTimer?.cancel();
    _debounceTimer = null;

    final channel = _channel;
    _channel = null;
    _started = false;

    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }

    PageSnapshotCache.instance.invalidateAll();
  }

  void _scheduleRefresh() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, _applyRefresh);
  }

  void _applyRefresh() {
    DataChangeBus.instance.ping();

    assert(() {
      debugPrint('[SIYAM] Realtime: applied remote data change');
      return true;
    }());
  }
}
