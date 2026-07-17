import '../mock/mock_database.dart';
import '../models/app_user.dart';
import '../models/pet.dart';
import 'backend.dart';

/// Aggregate counts for the Manager dashboard.
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
/// computed against a threshold. This uses `purchase_stocks = 0` (out of
/// stock) instead, which is derivable from the schema as-is.
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

/// Data-access interface for dashboard aggregates. The factory resolves to
/// the mock or Supabase implementation based on [kUseMock], chosen at build
/// time.
abstract interface class DashboardService {
  factory DashboardService() => kUseMock
      ? MockDashboardService()
      : throw UnimplementedError('Supabase DashboardService not implemented yet');

  Future<ManagerDashboardStats> fetchManagerStats();
  Future<StaffDashboardStats> fetchStaffStats();
  Future<DonorDashboardStats> fetchDonorStats(String donorId);
}

class MockDashboardService implements DashboardService {
  final MockDatabase _db = MockDatabase.instance;

  @override
  Future<ManagerDashboardStats> fetchManagerStats() async {
    return ManagerDashboardStats(
      totalAnimals: _db.pets.length,
      totalSuppliers: _db.suppliers.length,
      pendingSubmissions: _db.submissions.where((s) => s.status == 'pending').length,
      staffAccounts: _db.users.where((u) => u.role == AppRole.staff).length,
    );
  }

  @override
  Future<StaffDashboardStats> fetchStaffStats() async {
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    return StaffDashboardStats(
      outOfStockItems: _db.items.where((i) => i.purchaseStocks <= 0).length,
      animalsUnderTreatment:
          _db.pets.where((p) => p.status == PetStatus.underTreatment).length,
      donationsThisWeek:
          _db.donations.where((d) => d.receivedDate.isAfter(weekAgo)).length,
      pendingSubmissions: _db.submissions.where((s) => s.status == 'pending').length,
    );
  }

  @override
  Future<DonorDashboardStats> fetchDonorStats(String donorId) async {
    final donations = _db.donations.where((d) => d.donorId == donorId).toList()
      ..sort((a, b) => b.receivedDate.compareTo(a.receivedDate));

    final donationIds = donations.map((d) => d.id).toSet();
    var itemsDonated = 0;
    for (final row in _db.donationItems) {
      if (donationIds.contains(row.donId)) itemsDonated += row.qty.round();
    }

    final pendingCount = _db.submissions
        .where((s) => s.donorId == donorId && s.status == 'pending')
        .length;

    return DonorDashboardStats(
      totalDonations: donations.length,
      itemsDonated: itemsDonated,
      pendingSubmissions: pendingCount,
      lastDonation: donations.isEmpty ? null : donations.first.receivedDate,
    );
  }
}
