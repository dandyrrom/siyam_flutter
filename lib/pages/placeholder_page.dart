import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// Generic "coming soon" placeholder used for every content page
/// except the ones we've actually built out.
class PlaceholderPage extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? note;

  const PlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 32, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            note ?? 'This page will be built out next.',
            style: const TextStyle(color: AppColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}
