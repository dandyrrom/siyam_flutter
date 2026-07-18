import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard_service.dart';

/// Supabase-backed dashboard aggregates. Counts are derived from small
/// filtered selects (the data volume here is modest).
class SupabaseDashboardService implements DashboardService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<int> _count(String table) async {
    final rows = await _client.from(table).select('id');
    return rows.length;
  }

  @override
  Future<ManagerDashboardStats> fetchManagerStats() async {
    final pets = await _count('pet');
    final suppliers = await _count('supplier');
    final pending = await _client.from('submission').select('id').eq('status', 'pending');
    final staff = await _client.from('users').select('id').eq('role', 'staff');
    return ManagerDashboardStats(
      totalAnimals: pets,
      totalSuppliers: suppliers,
      pendingSubmissions: pending.length,
      staffAccounts: staff.length,
    );
  }

  @override
  Future<StaffDashboardStats> fetchStaffStats() async {
    final weekAgo =
        DateTime.now().toUtc().subtract(const Duration(days: 7));
    final outOfStock =
        await _client.from('item').select('id').lte('purchase_stocks', 0);
    final underTreatment = await _client
        .from('pet')
        .select('id')
        .eq('status', 'under_treatment');
    final donationsThisWeek = await _client
        .from('donation')
        .select('id')
        .gte('receiveddate', weekAgo.toIso8601String());
    final pending =
        await _client.from('submission').select('id').eq('status', 'pending');
    return StaffDashboardStats(
      outOfStockItems: outOfStock.length,
      animalsUnderTreatment: underTreatment.length,
      donationsThisWeek: donationsThisWeek.length,
      pendingSubmissions: pending.length,
    );
  }

  @override
  Future<DonorDashboardStats> fetchDonorStats(String donorId) async {
    final donations = await _client
        .from('donation')
        .select('id, receiveddate')
        .eq('donorid', donorId)
        .order('receiveddate', ascending: false);

    final itemRows = await _client
        .from('donation_item')
        .select('qty, donation!inner(donorid)')
        .eq('donation.donorid', donorId);
    var itemsDonated = 0;
    for (final r in itemRows) {
      itemsDonated += ((r['qty'] as num?)?.toDouble() ?? 0).round();
    }

    final pending = await _client
        .from('submission')
        .select('id')
        .eq('donorid', donorId)
        .eq('status', 'pending');

    return DonorDashboardStats(
      totalDonations: donations.length,
      itemsDonated: itemsDonated,
      pendingSubmissions: pending.length,
      lastDonation: donations.isEmpty
          ? null
          : DateTime.parse(donations.first['receiveddate'] as String),
    );
  }
}
