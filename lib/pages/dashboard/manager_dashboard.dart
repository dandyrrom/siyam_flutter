import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../widgets/stat_card.dart';

class ManagerDashboard extends StatelessWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardHeader(
          title: 'Manager Dashboard',
          subtitle: 'Sanctuary-wide overview: animals, suppliers, and audit activity.',
        ),
        StatCardRow(cards: [
          StatCard(
            label: 'Total Animals',
            value: '—',
            icon: Icons.pets_outlined,
            accent: AppColors.roleManager,
          ),
          StatCard(
            label: 'Active Suppliers',
            value: '—',
            icon: Icons.local_shipping_outlined,
            accent: AppColors.roleManager,
          ),
          StatCard(
            label: 'Pending Submissions',
            value: '—',
            icon: Icons.fact_check_outlined,
            accent: AppColors.roleManager,
          ),
          StatCard(
            label: 'Staff Accounts',
            value: '—',
            icon: Icons.badge_outlined,
            accent: AppColors.roleManager,
          ),
        ]),
        SizedBox(height: 24),
        ComingSoonNotice(
          text: 'These figures will pull live counts from pet, supplier, '
              'submission, and users once each module is wired up.',
        ),
      ],
    );
  }
}