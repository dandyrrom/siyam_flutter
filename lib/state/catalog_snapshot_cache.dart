import '../models/inventory_item.dart';
import '../models/replenishment_item.dart';
import 'page_snapshot_cache.dart';

/// Compatibility wrapper around [PageSnapshotCache] for inventory reads.
class CatalogSnapshotCache {
  CatalogSnapshotCache._();

  static final CatalogSnapshotCache instance = CatalogSnapshotCache._();

  List<InventoryItem>? get items =>
      PageSnapshotCache.instance.peekList<InventoryItem>(
        PageSnapshotCache.items,
      );

  List<ReplenishmentItem>? get replenishment =>
      PageSnapshotCache.instance.peekList<ReplenishmentItem>(
        PageSnapshotCache.replenishment,
      );

  Future<List<InventoryItem>> itemsOrFetch(
    Future<List<InventoryItem>> Function() loader,
  ) {
    return PageSnapshotCache.instance.coalesce(
      PageSnapshotCache.items,
      loader,
    );
  }

  Future<List<ReplenishmentItem>> replenishmentOrFetch(
    Future<List<ReplenishmentItem>> Function() loader,
  ) {
    return PageSnapshotCache.instance.coalesce(
      PageSnapshotCache.replenishment,
      loader,
    );
  }
}
