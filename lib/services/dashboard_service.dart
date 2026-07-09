import 'package:supabase_flutter/supabase_flutter.dart';

/// Aggregate counts for the Manager dashboard.
///
/// Note: `supplier` has no "active/inactive" status column in the schema,
/// so this is a total supplier count, not an "active suppliers" count.
class ManagerDashboardStats {
  final int totalAnimals;
  final int totalSuppliers;
  final int pendingSubmissions;
  final int staffAccounts;

  const ManagerDashboardStats({
    required this.totalAnimals,
    required this.totalSuppliers,
    required this.pendingSubmissions,
    required this.staffAccounts,
  });
}

/// Aggregate counts for the Staff dashboard.
///
/// Note: `item` has no reorder-point column, so "low stock" can't be
/// computed against a threshold. This uses `stockqty = 0` (out of stock)
/// instead, which is derivable from the schema as-is.
class StaffDashboardStats {
  final int outOfStockItems;
  final int animalsUnderTreatment;
  final int donationsThisWeek;
  final int pendingSubmissions;

  const StaffDashboardStats({
    required this.outOfStockItems,
    required this.animalsUnderTreatment,
    required this.donationsThisWeek,
    required this.pendingSubmissions,
  });
}

/// Aggregate stats for the signed-in donor.
///
/// Note: there's no schema link from a donation's items to a specific
/// animal, so "Animals Helped" can't be derived; this reports the
/// donor's own pending submissions instead.
class DonorDashboardStats {
  final int totalDonations;
  final int itemsDonated;
  final int pendingSubmissions;
  final DateTime? lastDonation;

  const DonorDashboardStats({
    required this.totalDonations,
    required this.itemsDonated,
    required this.pendingSubmissions,
    this.lastDonation,
  });
}

class DashboardService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<int> _count(
    String table, {
    String column = '*',
    String? eqColumn,
    Object? eqValue,
    String? gteColumn,
    DateTime? gteValue,
  }) async {
    var query = _client.from(table).select(column);
    if (eqColumn != null) query = query.eq(eqColumn, eqValue as Object);
    if (gteColumn != null) {
      query = query.gte(gteColumn, gteValue!.toIso8601String());
    }
    final res = await query.count(CountOption.exact);
    return res.count;
  }

  Future<ManagerDashboardStats> fetchManagerStats() async {
    final results = await Future.wait([
      _count('pet'),
      _count('supplier'),
      _count('submission', eqColumn: 'status', eqValue: 'pending'),
      _count('users', eqColumn: 'role', eqValue: 'staff'),
    ]);
    return ManagerDashboardStats(
      totalAnimals: results[0],
      totalSuppliers: results[1],
      pendingSubmissions: results[2],
      staffAccounts: results[3],
    );
  }

  Future<StaffDashboardStats> fetchStaffStats() async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final results = await Future.wait([
      _count('item', eqColumn: 'stockqty', eqValue: 0),
      _count('pet', eqColumn: 'status', eqValue: 'under_treatment'),
      _count('donation', gteColumn: 'transdate', gteValue: weekAgo),
      _count('submission', eqColumn: 'status', eqValue: 'pending'),
    ]);
    return StaffDashboardStats(
      outOfStockItems: results[0],
      animalsUnderTreatment: results[1],
      donationsThisWeek: results[2],
      pendingSubmissions: results[3],
    );
  }

  Future<DonorDashboardStats> fetchDonorStats(String donorId) async {
    final donationCount = await _count('donation', eqColumn: 'donorid', eqValue: donorId);

    final donationRows = await _client
        .from('donation')
        .select('donid, transdate')
        .eq('donorid', donorId)
        .order('transdate', ascending: false);
    final donationIds =
        donationRows.map((r) => r['donid'] as String).toList();

    int itemsDonated = 0;
    if (donationIds.isNotEmpty) {
      final itemRows = await _client
          .from('donation_item')
          .select('qty')
          .inFilter('donid', donationIds);
      for (final r in (itemRows as List)) {
        itemsDonated += (r as Map<String, dynamic>)['qty'] as int;
      }
    }

    final lastDonation = donationRows.isEmpty
        ? null
        : DateTime.tryParse(donationRows.first['transdate'] as String);

    // "Pending submissions" = this donor's submissions still awaiting
    // review, not yet converted into a donation.
    final pendingOnly = await _client
        .from('submission')
        .select('subid')
        .eq('donorid', donorId)
        .eq('status', 'pending')
        .count(CountOption.exact);

    return DonorDashboardStats(
      totalDonations: donationCount,
      itemsDonated: itemsDonated,
      pendingSubmissions: pendingOnly.count,
      lastDonation: lastDonation,
    );
  }
}
