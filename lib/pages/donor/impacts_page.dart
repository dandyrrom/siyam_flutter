import 'package:flutter/material.dart';
import '../placeholder_page.dart';

class ImpactsPage extends StatelessWidget {
  const ImpactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderPage(
      title: 'My Impact',
      icon: Icons.insights_outlined,
      note: 'This will show the donor how their donations have helped '
          '(animals fed, treated, etc.) once wired up to real data.',
    );
  }
}
