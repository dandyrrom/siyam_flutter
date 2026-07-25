import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../state/auth_state.dart';
import '../widgets/public_nav_bar.dart';

/// Sign-in page -- full-width like every other public page (shares
/// [PublicNavBar] rather than a page-specific bar), laid out to match the
/// reference mockup's content (headline + "Register here!" column with a
/// small illustration, a large standing-figure illustration, and the
/// sign-in form) with our brand illustrations in place of the mockup's
/// generic figures and [AppColors] instead of the mockup's purple.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final success = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (success && mounted) {
      context.go('/dashboard');
    }
  }

  void _notAvailable(String label) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$label isn\'t available yet.')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: const PublicNavBar(currentPath: '/login'),
      body: LayoutBuilder(
        builder: (context, viewportConstraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 900;
                      final leftText = _LeftIntro(narrow: narrow);
                      final illustration = Image.asset(
                        'assets/girl-carry-dog.png',
                        height: narrow ? 220 : 340,
                        fit: BoxFit.contain,
                      );
                      final formCard = _SignInForm(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        onToggleObscure: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        onSubmit: _handleSubmit,
                        isBusy: auth.isBusy,
                        errorMessage: auth.errorMessage,
                        onSocialTap: _notAvailable,
                        onForgotPassword: () => _notAvailable('Password reset'),
                      );

                      if (narrow) {
                        return Column(
                          children: [
                            leftText,
                            const SizedBox(height: 28),
                            illustration,
                            const SizedBox(height: 28),
                            formCard,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(flex: 4, child: leftText),
                          Expanded(flex: 3, child: Center(child: illustration)),
                          const SizedBox(width: 12),
                          Expanded(flex: 4, child: formCard),
                        ],
                      );
                    },
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

class _LeftIntro extends StatelessWidget {
  final bool narrow;
  const _LeftIntro({required this.narrow});

  @override
  Widget build(BuildContext context) {
    final crossAlign =
        narrow ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final textAlign = narrow ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: crossAlign,
      children: [
        Text('Sign In to',
            textAlign: textAlign,
            style: const TextStyle(
                fontSize: 34,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: AppColors.deepBrown)),
        const Text('SIYAM',
            style: TextStyle(
                fontSize: 34,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: AppColors.deepBrown)),
        const SizedBox(height: 20),
        Text('If you don\'t have an account',
            textAlign: textAlign,
            style: const TextStyle(fontSize: 13.5, color: AppColors.deepBrown)),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('You can  ',
                style: TextStyle(fontSize: 13.5, color: AppColors.deepBrown)),
            GestureDetector(
              onTap: () => context.go('/register'),
              child: const Text('Register here!',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.sageGreen)),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Image.asset('assets/dog-human-cat.png', height: 170, fit: BoxFit.contain),
      ],
    );
  }
}

class _SignInForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final bool isBusy;
  final String? errorMessage;
  final void Function(String label) onSocialTap;
  final VoidCallback onForgotPassword;

  const _SignInForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.isBusy,
    required this.errorMessage,
    required this.onSocialTap,
    required this.onForgotPassword,
  });

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
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: _decoration(hintText: 'Enter email or Phone number'),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: _decoration(
              hintText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                    obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.deepBrown, size: 20),
                onPressed: onToggleObscure,
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onForgotPassword,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.lightScheme.onSurfaceVariant,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Forgot password?', style: TextStyle(fontSize: 12.5)),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(errorMessage!,
                style: const TextStyle(color: AppColors.coralRed, fontSize: 13)),
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
              onPressed: isBusy ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
              ),
              child: isBusy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sign In',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                  child: Divider(color: AppColors.catGray.withValues(alpha: 0.8))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('Or continue with',
                    style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.lightScheme.onSurfaceVariant)),
              ),
              Expanded(
                  child: Divider(color: AppColors.catGray.withValues(alpha: 0.8))),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _SocialIconButton(
                  icon: Icons.g_mobiledata_rounded,
                  color: AppColors.coralRed,
                  onTap: () => onSocialTap('Google'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SocialIconButton(
                  icon: Icons.facebook,
                  color: AppColors.skyBlue,
                  onTap: () => onSocialTap('Facebook'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SocialIconButton(
                  icon: Icons.apple,
                  color: AppColors.deepBrown,
                  onTap: () => onSocialTap('Apple/iCloud'),
                ),
              ),
            ],
          ),
        ],
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
