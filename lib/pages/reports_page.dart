import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../state/auth_state.dart';
import 'reports/manager_reports_page.dart';
import 'reports/staff_reports_page.dart';

// =============================================================================
// ROLE-SPECIFIC REPORTS
// =============================================================================
//
// Manager:
// - Monthly Usage
// - ROP Status
//
// Staff:
// - Monthly Usage only
//
// Donor:
// - No internal Reports access
//
// nav_config.dart already allows Manager and Staff to reach /reports.
// =============================================================================

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<AuthController>().profile;

    if (user == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    switch (user.role) {
      case AppRole.manager:
        return const ManagerReportsPage();

      case AppRole.staff:
        return const StaffReportsPage();

      case AppRole.donor:
        return const _ReportsAccessDenied();
    }
  }
}

class _ReportsAccessDenied
    extends StatelessWidget {
  const _ReportsAccessDenied();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            size: 36,
            color:
                AppColors.mutedForeground,
          ),
          SizedBox(height: 10),
          Text(
            'Reports unavailable',
            style: TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Internal reports are available to Staff and Manager accounts.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color:
                  AppColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}
