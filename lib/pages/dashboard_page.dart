import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../state/auth_state.dart';
import 'dashboard/donor_dashboard.dart';
import 'dashboard/manager_dashboard.dart';
import 'dashboard/staff_dashboard.dart';

/// Renders the correct role-specific dashboard. `/dashboard` is a single
/// route (see app_router.dart) but the content shown differs by role,
/// same as the sidebar.
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().profile;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (user.role) {
      case AppRole.manager:
        return const ManagerDashboard();
      case AppRole.staff:
        return const StaffDashboard();
      case AppRole.donor:
        return const DonorDashboard();
    }
  }
}
