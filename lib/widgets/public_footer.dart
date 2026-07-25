import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/app_colors.dart';

/// Shared footer for the public marketing pages -- brand blurb, quick nav
/// links, and Dumaguete Animal Sanctuary's real contact details (sourced
/// from dumagueteanimalsanctuary.com).
class PublicFooter extends StatelessWidget {
  const PublicFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.deepBrown,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 640;
          return Column(
            crossAxisAlignment:
                narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: narrow ? WrapAlignment.center : WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: 48,
                runSpacing: 24,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 280),
                    child: Column(
                      crossAxisAlignment: narrow
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/branding/pet-house.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text('SIYAM',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Helping end the suffering of stray dogs in '
                          'Dumaguete and surrounding areas through rescue, '
                          'rehabilitation, and rehoming.',
                          textAlign: narrow ? TextAlign.center : TextAlign.start,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12.5, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  _FooterLinks(narrow: narrow),
                  _FooterContact(narrow: narrow),
                ],
              ),
              const SizedBox(height: 28),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),
              const Text(
                '© Dumaguete Animal Sanctuary. SIYAM donation & care management system.',
                style: TextStyle(color: Colors.white54, fontSize: 11.5),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  final bool narrow;
  const _FooterLinks({required this.narrow});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        const Text('Explore',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        for (final entry in const [
          ('Home', '/'),
          ('About DAS', '/about'),
          ('Donate', '/donate-info'),
          ('FAQs', '/faqs'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => context.go(entry.$2),
              child: Text(entry.$1,
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
            ),
          ),
      ],
    );
  }
}

class _FooterContact extends StatelessWidget {
  final bool narrow;
  const _FooterContact({required this.narrow});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: const [
        Text('Contact',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
        SizedBox(height: 10),
        Text('Isuagan, Bacong, Negros Oriental, Philippines',
            style: TextStyle(color: Colors.white70, fontSize: 12.5)),
        SizedBox(height: 6),
        Text('0949 035 50484',
            style: TextStyle(color: Colors.white70, fontSize: 12.5)),
      ],
    );
  }
}
