import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../state/auth_state.dart';
import '../widgets/public_nav_bar.dart';

/// Registration page -- styled to match [LoginPage]: centered logos, the
/// same pill-shaped fields, rounded green submit button, and icon-only
/// social row, all built on [AppColors] instead of a page-specific palette.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _agreed = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the Terms & Privacy Policy')),
      );
      return;
    }
    final auth = context.read<AuthController>();
    final success = await auth.registerDonor(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      contactNum: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created! Please sign in.')),
      );
      context.go('/login');
    }
  }

  void _notAvailable(String label) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label isn\'t available yet.')));
  }

  InputDecoration _decoration({required String hintText, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.catGray.withValues(alpha: 0.28),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.sageGreen, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: const PublicNavBar(currentPath: '/register'),
      body: LayoutBuilder(
        builder: (context, viewportConstraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/das-no-bg.png',
                            height: 72,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/branding/pet-house-green.png',
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Create your donor account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepBrown,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Join our community of animal welfare advocates',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.5, color: AppColors.deepBrown),
                      ),
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstName,
                                    decoration: _decoration(hintText: 'First Name'),
                                    validator: (v) =>
                                        (v == null || v.isEmpty) ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastName,
                                    decoration: _decoration(hintText: 'Last Name'),
                                    validator: (v) =>
                                        (v == null || v.isEmpty) ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: _decoration(hintText: 'Email address'),
                              validator: (v) => (v == null || !v.contains('@'))
                                  ? 'Enter a valid email'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: _decoration(hintText: 'Phone number'),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              decoration: _decoration(
                                hintText: 'Password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: AppColors.deepBrown,
                                      size: 20),
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                ),
                              ),
                              validator: (v) => (v == null || v.length < 6)
                                  ? 'At least 6 characters'
                                  : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirm,
                              obscureText: true,
                              decoration: _decoration(hintText: 'Confirm password'),
                              validator: (v) => (v != _password.text)
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Checkbox(
                                  value: _agreed,
                                  activeColor: AppColors.sageGreen,
                                  onChanged: (v) => setState(() => _agreed = v ?? false),
                                ),
                                const Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Text(
                                      'I agree to the Terms of Service and Privacy Policy',
                                      style: TextStyle(
                                          fontSize: 12, color: AppColors.deepBrown),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (auth.errorMessage != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                auth.errorMessage!,
                                style: const TextStyle(
                                    color: AppColors.coralRed, fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                      color: AppColors.sageGreen.withValues(alpha: 0.35),
                                      blurRadius: 22,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 10)),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: auth.isBusy ? null : _handleSubmit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.sageGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28)),
                                ),
                                child: auth.isBusy
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Create Account',
                                        style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(height: 26),
                            Row(
                              children: [
                                Expanded(
                                    child: Divider(
                                        color: AppColors.catGray.withValues(alpha: 0.8))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Or continue with',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.lightScheme.onSurfaceVariant)),
                                ),
                                Expanded(
                                    child: Divider(
                                        color: AppColors.catGray.withValues(alpha: 0.8))),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: _SocialIconButton(
                                    icon: Icons.g_mobiledata_rounded,
                                    color: AppColors.coralRed,
                                    onTap: () => _notAvailable('Google'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SocialIconButton(
                                    icon: Icons.facebook,
                                    color: AppColors.skyBlue,
                                    onTap: () => _notAvailable('Facebook'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SocialIconButton(
                                    icon: Icons.apple,
                                    color: AppColors.deepBrown,
                                    onTap: () => _notAvailable('Apple/iCloud'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account?  ',
                              style: TextStyle(fontSize: 13.5, color: AppColors.deepBrown)),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Text(
                              'Sign in',
                              style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.sageGreen),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _SocialIconButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.catGray.withValues(alpha: 0.8)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}
