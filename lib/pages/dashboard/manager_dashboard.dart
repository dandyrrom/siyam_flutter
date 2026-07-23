import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../services/dashboard_service.dart';
import '../../state/data_bus.dart';
import '../../widgets/stat_card.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard>
    with DataBusRefreshMixin<ManagerDashboard> {
  final DashboardService _service = DashboardService();

  ManagerDashboardStats? _stats;
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
      final stats = await _service.fetchManagerStats();
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
          title: 'Manager Dashboard',
          subtitle: 'Sanctuary-wide overview: animals, suppliers, and audit activity.',
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
              label: 'Total Animals',
              value: _loading ? '—' : '${_stats!.totalAnimals}',
              icon: Icons.pets_outlined,
              accent: AppColors.roleManager,
            ),
            StatCard(
              label: 'Suppliers',
              value: _loading ? '—' : '${_stats!.totalSuppliers}',
              icon: Icons.local_shipping_outlined,
              accent: AppColors.roleManager,
            ),
            StatCard(
              label: 'Pending Submissions',
              value: _loading ? '—' : '${_stats!.pendingSubmissions}',
              icon: Icons.fact_check_outlined,
              accent: AppColors.roleManager,
            ),
            StatCard(
              label: 'Staff Accounts',
              value: _loading ? '—' : '${_stats!.staffAccounts}',
              icon: Icons.badge_outlined,
              accent: AppColors.roleManager,
            ),
          ]),
      ],
    );
  }
}
