import 'package:flutter/material.dart';
import '../core/landing_theme.dart';

/// Google/Facebook/Apple sign-in buttons for the login and register pages.
///
/// No OAuth provider is wired up in [AuthService] yet (email/password via
/// Supabase only), so these are presentational placeholders that tell the
/// user the option isn't available rather than silently doing nothing or
/// faking a successful sign-in.
class SocialAuthRow extends StatelessWidget {
  final String actionLabel;
  const SocialAuthRow({super.key, this.actionLabel = 'Sign in'});

  void _notAvailable(BuildContext context, String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$actionLabel with $provider isn\'t available yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Expanded(child: Divider(color: LandingColors.border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('Or continue with',
                  style: TextStyle(
                      color: LandingColors.mutedInk, fontSize: 12.5)),
            ),
            Expanded(child: Divider(color: LandingColors.border)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: 'Google',
                icon: Icons.g_mobiledata_rounded,
                onTap: () => _notAvailable(context, 'Google'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialButton(
                label: 'Facebook',
                icon: Icons.facebook,
                onTap: () => _notAvailable(context, 'Facebook'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialButton(
                label: 'Apple',
                icon: Icons.apple,
                onTap: () => _notAvailable(context, 'Apple/iCloud'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _SocialButton({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18, color: LandingColors.ink),
      label: Text(label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: LandingColors.ink, fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: LandingColors.border),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}
