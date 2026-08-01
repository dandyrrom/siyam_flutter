import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/validators.dart';
import '../state/auth_state.dart';
import '../widgets/public_nav_bar.dart';

/// Registration page -- styled to match [LoginPage]: centered logos, the
/// same pill-shaped fields, rounded green submit button.
/// Social login options removed (not implemented).
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

  // Track which fields have been touched
  final _touchedFields = <String>{};

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
    // Mark all fields as touched to show validation errors
    setState(() {
      _touchedFields.addAll(['email', 'phone', 'password', 'confirm']);
    });
    
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final success = await auth.registerDonor(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      email: _email.text.trim(),
      password: _password.text,
      contactNum: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    );
    
    if (success && mounted) {
      // ============================================================
      // Log out immediately so user stays on login page
      // ============================================================
      await auth.logout();
      
      // ============================================================
      // Show snackbar after logout
      // ============================================================
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created! Please sign in.'),
          backgroundColor: AppColors.sageGreen,
          duration: Duration(seconds: 2),
        ),
      );
      
      // ============================================================
      // Navigate to login after delay
      // ============================================================
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (mounted) {
        context.go('/login');
      }
    }
  }

  // ============================================================
  // MODIFIED: Decoration with red border for errors
  // ============================================================
  InputDecoration _decoration({
    required String hintText,
    Widget? suffixIcon,
    String? errorText,
    bool showError = false,
  }) {
    final hasError = showError && errorText != null;
    
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.catGray.withValues(alpha: 0.28),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: hasError
            ? const BorderSide(color: AppColors.coralRed, width: 2)
            : BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: hasError
            ? const BorderSide(color: AppColors.coralRed, width: 2)
            : BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: hasError
            ? const BorderSide(color: AppColors.coralRed, width: 2)
            : const BorderSide(color: AppColors.sageGreen, width: 1.5),
      ),
      errorText: showError ? errorText : null,
      errorStyle: const TextStyle(
        color: AppColors.coralRed,
        fontSize: 12,
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
                              onChanged: (_) {
                                setState(() {
                                  _touchedFields.add('email');
                                });
                              },
                              decoration: _decoration(
                                hintText: 'Email address (xxx@xxxx.xxx)',
                                showError: _touchedFields.contains('email'),
                                errorText: validateEmail(_email.text),
                              ),
                              validator: validateEmail,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: phoneInputFormatters,
                              onChanged: (_) {
                                setState(() {
                                  _touchedFields.add('phone');
                                });
                              },
                              decoration: _decoration(
                                hintText: '09XXXXXXXXX',
                                showError: _touchedFields.contains('phone'),
                                errorText: validatePhoneNumber(_phone.text),
                              ),
                              validator: validatePhoneNumber,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _password,
                              obscureText: _obscure,
                              onChanged: (_) {
                                setState(() {
                                  _touchedFields.add('password');
                                });
                              },
                              decoration: _decoration(
                                hintText: 'Password (8+ chars, A-Z, a-z, 0-9, symbol)',
                                showError: _touchedFields.contains('password'),
                                errorText: validatePassword(_password.text),
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
                              validator: validatePassword,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _confirm,
                              obscureText: true,
                              onChanged: (_) {
                                setState(() {
                                  _touchedFields.add('confirm');
                                });
                              },
                              decoration: _decoration(
                                hintText: 'Confirm password',
                                showError: _touchedFields.contains('confirm'),
                                errorText: _confirm.text != _password.text
                                    ? 'Passwords do not match'
                                    : null,
                              ),
                              validator: (v) => (v != _password.text)
                                  ? 'Passwords do not match'
                                  : null,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 20),
                              child: Text(
                                'Password must be at least 8 characters and include: uppercase, lowercase, number, and symbol',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.mutedForeground,
                                ),
                              ),
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