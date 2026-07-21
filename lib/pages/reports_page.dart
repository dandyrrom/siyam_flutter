import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_user.dart';
import '../state/auth_state.dart';
import 'reports/manager_reports_page.dart';
import 'reports/staff_reports_page.dart';

/// Renders the correct role-specific Reports content. `/reports` is a
/// single route (see app_router.dart) but the content shown differs by
/// role, same as the dashboard: Manager sees full analytics, Staff does
/// not.
class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().profile;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (user.role) {
      case AppRole.manager:
        return const ManagerReportsPage();
      case AppRole.staff:
        return const StaffReportsPage();
      case AppRole.donor:
        return const StaffReportsPage();
    }
  }
}
