import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../widgets/public_nav_bar.dart';
import '../widgets/public_footer.dart';

/// Blank pending content -- nav bar and footer only.
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      appBar: PublicNavBar(currentPath: '/about'),
      body: Column(
        children: [
          Expanded(child: SizedBox.shrink()),
          PublicFooter(),
        ],
      ),
    );
  }
} //test to merge
