import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../widgets/stat_card.dart';

class StaffDashboard extends StatelessWidget {
  const StaffDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardHeader(
          title: 'Staff Dashboard',
          subtitle: 'Your day-to-day: inventory, medical care, and donations.',
        ),
        StatCardRow(cards: [
          StatCard(
            label: 'Low Stock Items',
            value: '—',
            icon: Icons.inventory_2_outlined,
            accent: AppColors.roleStaff,
          ),
          StatCard(
            label: 'Animals Under Treatment',
            value: '—',
            icon: Icons.medical_services_outlined,
            accent: AppColors.roleStaff,
          ),
          StatCard(
            label: 'Donations This Week',
            value: '—',
            icon: Icons.volunteer_activism_outlined,
            accent: AppColors.roleStaff,
          ),
          StatCard(
            label: 'Pending Pickups',
            value: '—',
            icon: Icons.schedule_outlined,
            accent: AppColors.roleStaff,
          ),
        ]),
        SizedBox(height: 24),
        ComingSoonNotice(
          text: 'These figures will pull live counts from item, treatment, '
              'and donation once each module is wired up -- Inventory is next.',
        ),
      ],
    );
  }
}