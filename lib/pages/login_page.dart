import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/app_colors.dart';
import '../core/validators.dart';
import '../models/app_user.dart';
import '../services/backend.dart';
import '../state/auth_state.dart';
import '../widgets/public_nav_bar.dart';

/// Sign-in page -- full-width like every other public page (shares
/// [PublicNavBar] rather than a page-specific bar), laid out as a centered
/// card (logo, heading, form) to match the reference mockup.
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
      // ============================================================
      // Show success snackbar before navigating
      // ============================================================
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account successfully Logged In!'),
          backgroundColor: AppColors.sageGreen,
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate after a short delay to let the snackbar show
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // ============================================================
        // Redirect user based on account role
        // ============================================================
        final role = auth.profile?.role;

        if (role == AppRole.donor) {
          context.go('/donor');
        } else {
          context.go('/dashboard');
        }
      }
    }
  }

  Future<void> _openForgotPassword() async {
    final success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
      ),
    );

    if (!mounted || success != true) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Password updated successfully. You can now sign in.',
        ),
        backgroundColor: AppColors.sageGreen,
      ),
    );
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
                        'Sign in to your account',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: AppColors.deepBrown,
                        ),
                      ),
                      const SizedBox(height: 32),
                      _SignInForm(
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        obscurePassword: _obscurePassword,
                        onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        onSubmit: _handleSubmit,
                        isBusy: auth.isBusy,
                        errorMessage: auth.errorMessage,
                        onForgotPasswordTap: _openForgotPassword,
                        onRegisterTap: () => context.go('/register'),
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

class _SignInForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final bool isBusy;
  final String? errorMessage;
  final VoidCallback onForgotPasswordTap;
  final VoidCallback onRegisterTap;

  const _SignInForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.isBusy,
    required this.errorMessage,
    required this.onForgotPasswordTap,
    required this.onRegisterTap,
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
            decoration: _decoration(hintText: 'Enter email'),
            validator: validateEmail,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            decoration: _decoration(
              hintText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.deepBrown,
                  size: 20,
                ),
                onPressed: onToggleObscure,
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: isBusy ? null : onForgotPasswordTap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.sageGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: const TextStyle(
                color: AppColors.coralRed,
                fontSize: 13,
              ),
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
                  offset: const Offset(0, 10),
                ),
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
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: isBusy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sign In',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          // Public self-registration is for Donors only.
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            children: [
              const Text(
                "Don't have an account?",
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.deepBrown,
                ),
              ),
              TextButton(
                onPressed: isBusy ? null : onRegisterTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.sageGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Create an account',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FORGOT PASSWORD DIALOG
// =============================================================================

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;

  const _ForgotPasswordDialog({
    required this.initialEmail,
  });

  @override
  State<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState
    extends State<_ForgotPasswordDialog> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  late final TextEditingController _emailController =
      TextEditingController(
    text: widget.initialEmail,
  );

  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _codeSent = false;
  bool _busy = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_busy ||
        !_emailFormKey.currentState!.validate()) {
      return;
    }

    if (kUseMock) {
      setState(() {
        _error =
            'Password recovery is only available when SIYAM is connected to Supabase.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.auth
          .resetPasswordForEmail(
        _emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _codeSent = true;
      });
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not send the recovery code. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    if (_busy ||
        !_resetFormKey.currentState!.validate()) {
      return;
    }

    if (kUseMock) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final response =
          await Supabase.instance.client.auth
              .verifyOTP(
        email: _emailController.text.trim(),
        token: _codeController.text.trim(),
        type: OtpType.recovery,
      );

      if (response.session == null ||
          response.user == null) {
        throw const AuthException(
          'Invalid or expired recovery code.',
        );
      }

      await Supabase.instance.client.auth
          .updateUser(
        UserAttributes(
          password:
              _newPasswordController.text,
        ),
      );

      await Supabase.instance.client.auth
          .signOut(
        scope: SignOutScope.local,
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error =
            'Could not reset the password. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String? _validateCode(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Recovery code is required';
    }

    return null;
  }

  String? _validateConfirmPassword(
    String? value,
  ) {
    if (value == null ||
        value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value !=
        _newPasswordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  InputDecoration _decoration({
    required String labelText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: labelText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor:
          AppColors.catGray.withValues(
        alpha: 0.20,
      ),
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          16,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      shape:
          RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      title: const Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back',
            style: TextStyle(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Reset your password',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight:
                  FontWeight.w400,
              color:
                  AppColors.mutedForeground,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child:
            SingleChildScrollView(
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Form(
                key: _emailFormKey,
                child:
                    TextFormField(
                  controller:
                      _emailController,
                  readOnly:
                      _codeSent,
                  keyboardType:
                      TextInputType
                          .emailAddress,
                  decoration:
                      _decoration(
                    labelText:
                        'Email address',
                  ),
                  validator:
                      validateEmail,
                  onFieldSubmitted:
                      (_) =>
                          _codeSent
                              ? null
                              : _sendCode(),
                ),
              ),

              if (!_codeSent) ...[
                const SizedBox(
                  height: 12,
                ),
                const Text(
                  'Enter your email address and SIYAM will send a recovery code to your email.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
              ],

              if (_codeSent) ...[
                const SizedBox(
                  height: 12,
                ),
                Text(
                  'A recovery code was sent to ${_emailController.text.trim()}. Enter the code and your new password below.',
                  style:
                      const TextStyle(
                    fontSize: 12.5,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                Form(
                  key: _resetFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller:
                            _codeController,
                        keyboardType:
                            TextInputType
                                .number,
                        decoration:
                            _decoration(
                          labelText:
                              'Recovery code',
                        ),
                        validator:
                            _validateCode,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextFormField(
                        controller:
                            _newPasswordController,
                        obscureText:
                            _obscureNewPassword,
                        decoration:
                            _decoration(
                          labelText:
                              'New password',
                          suffixIcon:
                              IconButton(
                            onPressed:
                                () =>
                                    setState(
                              () =>
                                  _obscureNewPassword =
                                      !_obscureNewPassword,
                            ),
                            icon: Icon(
                              _obscureNewPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator:
                            validatePassword,
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      TextFormField(
                        controller:
                            _confirmPasswordController,
                        obscureText:
                            _obscureConfirmPassword,
                        decoration:
                            _decoration(
                          labelText:
                              'Confirm new password',
                          suffixIcon:
                              IconButton(
                            onPressed:
                                () =>
                                    setState(
                              () =>
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                            ),
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator:
                            _validateConfirmPassword,
                        onFieldSubmitted:
                            (_) =>
                                _resetPassword(),
                      ),
                    ],
                  ),
                ),
              ],

              if (_error !=
                  null) ...[
                const SizedBox(
                  height: 12,
                ),
                Text(
                  _error!,
                  style:
                      const TextStyle(
                    color:
                        AppColors.coralRed,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _busy
                  ? null
                  : () =>
                      Navigator.of(
                        context,
                      ).pop(false),
          child:
              const Text(
            'Cancel',
          ),
        ),
        ElevatedButton(
          onPressed:
              _busy
                  ? null
                  : _codeSent
                      ? _resetPassword
                      : _sendCode,
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                AppColors.sageGreen,
            foregroundColor:
                Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        Colors.white,
                  ),
                )
              : Text(
                  _codeSent
                      ? 'Reset Password'
                      : 'Send Code',
                ),
        ),
      ],
    );
  }
}
