import 'package:flutter/material.dart';
import 'placeholder_page.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(title: 'Dashboard', icon: Icons.dashboard_outlined);
  }
}
