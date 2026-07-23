import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/dashboard_service.dart';
import '../../state/data_bus.dart';
import '../../widgets/stat_card.dart';

class StaffDashboard extends StatefulWidget {
  const StaffDashboard({super.key});

  @override
  State<StaffDashboard> createState() => _StaffDashboardState();
}

class _StaffDashboardState extends State<StaffDashboard>
    with DataBusRefreshMixin<StaffDashboard> {
  final DashboardService _service = DashboardService();

  StaffDashboardStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void onExternalDataChanged() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final stats = await _service.fetchStaffStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      if (!silent) {
        setState(() {
          _error = 'Could not load dashboard: $e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardHeader(
          title: 'Staff Dashboard',
          subtitle: 'Your day-to-day: inventory, medical care, and donations.',
        ),
        if (_error != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_error!, style: const TextStyle(color: AppColors.destructive)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else
          StatCardRow(cards: [
            StatCard(
              label: 'Out of Stock Items',
              value: _loading ? '—' : '${_stats!.outOfStockItems}',
              icon: Icons.inventory_2_outlined,
              accent: AppColors.roleStaff,
            ),
            StatCard(
              label: 'Animals Under Treatment',
              value: _loading ? '—' : '${_stats!.animalsUnderTreatment}',
              icon: Icons.medical_services_outlined,
              accent: AppColors.roleStaff,
            ),
            StatCard(
              label: 'Donations This Week',
              value: _loading ? '—' : '${_stats!.donationsThisWeek}',
              icon: Icons.volunteer_activism_outlined,
              accent: AppColors.roleStaff,
            ),
            StatCard(
              label: 'Pending Submissions',
              value: _loading ? '—' : '${_stats!.pendingSubmissions}',
              icon: Icons.schedule_outlined,
              accent: AppColors.roleStaff,
            ),
          ]),
      ],
    );
  }
}
