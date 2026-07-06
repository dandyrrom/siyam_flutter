import 'package:flutter/material.dart';
import '../../core/app_theme.dart';
import '../../widgets/stat_card.dart';

class DonorDashboard extends StatelessWidget {
  const DonorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DashboardHeader(
          title: 'Donor Dashboard',
          subtitle: 'Thank you for supporting the sanctuary -- here\'s your impact so far.',
        ),
        StatCardRow(cards: [
          StatCard(
            label: 'Total Donations',
            value: '—',
            icon: Icons.favorite_outline,
            accent: AppColors.roleDonor,
          ),
          StatCard(
            label: 'Items Donated',
            value: '—',
            icon: Icons.inventory_2_outlined,
            accent: AppColors.roleDonor,
          ),
          StatCard(
            label: 'Animals Helped',
            value: '—',
            icon: Icons.pets_outlined,
            accent: AppColors.roleDonor,
          ),
          StatCard(
            label: 'Last Donation',
            value: '—',
            icon: Icons.event_outlined,
            accent: AppColors.roleDonor,
          ),
        ]),
        SizedBox(height: 24),
        ComingSoonNotice(
          text: 'These figures will pull live counts from your donation and '
              'donation_item records once the Impacts and Donations pages are wired up.',
        ),
      ],
    );
  }
}