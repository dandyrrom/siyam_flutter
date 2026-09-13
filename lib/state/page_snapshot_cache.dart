import '../models/donation.dart';
import '../models/inventory_item.dart';
import '../models/pet.dart';
import '../models/replenishment_item.dart';
import '../models/supplier.dart';
import '../models/treatment.dart';

/// App-wide last-known snapshots and in-flight fetch coalescing.
///
/// Used to:
/// - reuse one in-flight request when several screens ask for the same data;
/// - keep the last successful result so a revisited tab can paint immediately
///   while a background refresh runs;
/// - drop stale snapshots when another session changes the same data.
class PageSnapshotCache {
  PageSnapshotCache._();

  static final PageSnapshotCache instance = PageSnapshotCache._();

  static const items = 'inventory.items';
  static const replenishment = 'inventory.replenishment';
  static const pets = 'pets';
  static const suppliers = 'suppliers';
  static const purchaseOrders = 'purchase.orders';
  static const treatments = 'treatments';
  static const submissions = 'donations.submissions';
  static const donorSubmissionsPrefix = 'donations.submissions.';
  static const settings = 'system.settings';
  static const primaryCategories = 'catalog.primaryCategories';
  static const subcategories = 'catalog.subcategories';
  static const units = 'catalog.units';
  static const managerStats = 'dashboard.managerStats';
  static const staffStats = 'dashboard.staffStats';
  static const donorStatsPrefix = 'dashboard.donorStats.';
  static const donorImpactPrefix = 'donor.impact.';
  static const donorHistoryPrefix = 'donor.history.';
  static const auditManager = 'audit.manager';
  static const auditStaffPrefix = 'audit.staff.';
  static const notifications = 'notifications.staff';
  static const donorNotificationsPrefix = 'notifications.donor.';
  static const followUps = 'medical.followUps';
  static const managerReports = 'reports.manager';
  static const staffReports = 'reports.staff';
  static const medicalPage = 'medical.page';
  static const purchaseTrans = 'purchase.transactions';
  static const orderingPage = 'ordering.page';

  final Map<String, Object?> _snapshots = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  int _generation = 0;

  T? peek<T>(String key) {
    final value = _snapshots[key];
    if (value is T) return value;
    return null;
  }

  List<T>? peekList<T>(String key) {
    final value = _snapshots[key];
    if (value is List<T>) return value;
    if (value is List) {
      final out = <T>[];
      for (final item in value) {
        if (item is! T) return null;
        out.add(item);
      }
      return out;
    }
    return null;
  }

  void put<T>(String key, T value) {
    _snapshots[key] = value;
  }

  void invalidateAll() {
    _generation++;
    _snapshots.clear();
  }

  void invalidateMatching(bool Function(String key) test) {
    _generation++;
    _snapshots.removeWhere((key, _) => test(key));
  }

  InventoryItem? itemById(String itemId) {
    final single = peek<InventoryItem>('inventory.item.$itemId');
    if (single != null) return single;

    final list = peekList<InventoryItem>(items);
    if (list == null) return null;
    for (final item in list) {
      if (item.itemId == itemId) return item;
    }
    return null;
  }

  ReplenishmentItem? replenishmentByItemId(String itemId) {
    final list = peekList<ReplenishmentItem>(replenishment);
    if (list == null) return null;
    for (final row in list) {
      if (row.item.itemId == itemId) return row;
    }
    return null;
  }

  Pet? petById(String petId) {
    final list = peekList<Pet>(pets);
    if (list == null) return null;
    for (final pet in list) {
      if (pet.petId == petId) return pet;
    }
    return null;
  }

  List<TreatmentRecord> treatmentsForPet(String petId) {
    final list = peekList<TreatmentRecord>(treatments);
    if (list == null) return const [];
    return list.where((row) => row.petId == petId).toList();
  }

  TreatmentRecord? treatmentById(String treatId) {
    final list = peekList<TreatmentRecord>(treatments);
    if (list == null) return null;
    for (final row in list) {
      if (row.treatId == treatId) return row;
    }
    return null;
  }

  DonationSubmission? submissionById(String subId) {
    final single = peek<DonationSubmission>('donations.submission.$subId');
    if (single != null) return single;

    final all = peekList<DonationSubmission>(submissions);
    if (all != null) {
      for (final row in all) {
        if (row.subId == subId) return row;
      }
    }

    for (final entry in _snapshots.entries) {
      if (!entry.key.startsWith(donorSubmissionsPrefix)) continue;
      final rows = entry.value;
      if (rows is! List) continue;
      for (final row in rows) {
        if (row is DonationSubmission && row.subId == subId) return row;
      }
    }

    return null;
  }

  PurchaseOrder? purchaseOrderById(String purId) {
    final single = peek<PurchaseOrder>('purchase.order.$purId');
    if (single != null) return single;

    final list = peekList<PurchaseOrder>(purchaseOrders);
    if (list == null) return null;
    for (final order in list) {
      if (order.purId == purId) return order;
    }
    return null;
  }

  Future<T> coalesce<T>(
    String key,
    Future<T> Function() loader,
  ) {
    final existing = _inFlight[key];
    if (existing != null) {
      return existing as Future<T>;
    }

    final generation = _generation;
    final future = loader().then((value) {
      if (generation == _generation) {
        _snapshots[key] = value;
      }
      return value;
    }).whenComplete(() {
      _inFlight.remove(key);
    });

    _inFlight[key] = future;
    return future;
  }
}
