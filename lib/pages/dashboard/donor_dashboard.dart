import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../services/dashboard_service.dart';
import '../../state/auth_state.dart';
import '../../state/data_bus.dart';
import '../../widgets/stat_card.dart';

class DonorDashboard extends StatefulWidget {
  const DonorDashboard({super.key});

  @override
  State<DonorDashboard> createState() => _DonorDashboardState();
}

class _DonorDashboardState extends State<DonorDashboard>
    with DataBusRefreshMixin<DonorDashboard> {
  final DashboardService _service = DashboardService();

  DonorDashboardStats? _stats;
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
    final donorId = context.read<AuthController>().profile?.userId;
    if (donorId == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final stats = await _service.fetchDonorStats(donorId);
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
    final lastDonation = _stats?.lastDonation;
    final lastDonationLabel =
        lastDonation == null ? '—' : _formatDate(lastDonation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DashboardHeader(
          title: 'Donor Dashboard',
          subtitle: 'Thank you for supporting the sanctuary -- here\'s your impact so far.',
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
              label: 'Total Donations',
              value: _loading ? '—' : '${_stats!.totalDonations}',
              icon: Icons.favorite_outline,
              accent: AppColors.roleDonor,
            ),
            StatCard(
              label: 'Items Donated',
              value: _loading ? '—' : '${_stats!.itemsDonated}',
              icon: Icons.inventory_2_outlined,
              accent: AppColors.roleDonor,
            ),
            StatCard(
              label: 'Pending Submissions',
              value: _loading ? '—' : '${_stats!.pendingSubmissions}',
              icon: Icons.schedule_outlined,
              accent: AppColors.roleDonor,
            ),
            StatCard(
              label: 'Last Donation',
              value: _loading ? '—' : lastDonationLabel,
              icon: Icons.event_outlined,
              accent: AppColors.roleDonor,
            ),
          ]),
      ],
    );
  }
}

const _monthAbbrev = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime date) =>
    '${_monthAbbrev[date.month - 1]} ${date.day}, ${date.year}';
