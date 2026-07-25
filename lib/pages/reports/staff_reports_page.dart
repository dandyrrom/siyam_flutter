import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

/// Staff-side Reports tab. Analytics (stat cards, category breakdown,
/// monthly charts) are Manager-only -- see [ManagerReportsPage].
class StaffReportsPage extends StatelessWidget {
  const StaffReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reports',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 56),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart_outlined, size: 36, color: AppColors.mutedForeground),
                SizedBox(height: 10),
                Text('No reports available', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text('Analytics reporting is available to managers.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.mutedForeground)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
