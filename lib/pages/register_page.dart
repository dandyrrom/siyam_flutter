import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/validators.dart';
import '../state/auth_state.dart';
import '../widgets/public_nav_bar.dart';

/// Public registration page.
///
/// SIYAM public self-registration creates DONOR accounts only.
/// Staff accounts remain an internal Manager-managed workflow.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() =>
      _RegisterPageState();
}

class _RegisterPageState
    extends State<RegisterPage> {
  final _formKey =
      GlobalKey<FormState>();

  final _confirmFieldKey =
      GlobalKey<FormFieldState<String>>();

  final _firstName =
      TextEditingController();

  final _lastName =
      TextEditingController();

  final _email =
      TextEditingController();

  final _phone =
      TextEditingController();

  final _password =
      TextEditingController();

  final _confirm =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmFocus = FocusNode();

  final Set<String> _touched = {};

  @override
  void initState() {
    super.initState();

    _watchBlur(_firstNameFocus, 'firstName');
    _watchBlur(_lastNameFocus, 'lastName');
    _watchBlur(_emailFocus, 'email');
    _watchBlur(_phoneFocus, 'phone');
    _watchBlur(_passwordFocus, 'password');
    _watchBlur(_confirmFocus, 'confirm');
  }

  void _watchBlur(
    FocusNode focusNode,
    String field,
  ) {
    focusNode.addListener(() {
      if (!focusNode.hasFocus && mounted) {
        setState(() {
          _touched.add(field);
        });
      }
    });
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();

    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _passwordFocus.dispose();
    _confirmFocus.dispose();

    super.dispose();
  }

  // ==========================================================================
  // PASSWORD RULES
  // ==========================================================================

  bool get _hasMinLength =>
      _password.text.length >= 8;

  bool get _hasUppercase =>
      RegExp(r'[A-Z]').hasMatch(
        _password.text,
      );

  bool get _hasLowercase =>
      RegExp(r'[a-z]').hasMatch(
        _password.text,
      );

  bool get _hasNumber =>
      RegExp(r'[0-9]').hasMatch(
        _password.text,
      );

  bool get _hasSymbol =>
      RegExp(
        r'[!@#$%^&*()_\-+=\[\]{};:,.?/~]',
      ).hasMatch(
        _password.text,
      );

  bool get _passwordIsStrong =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSymbol;

  String? _validateStrongPassword(
    String? value,
  ) {
    final password =
        value ?? '';

    if (password.isEmpty) {
      return 'Password is required';
    }

    if (!_passwordIsStrong) {
      return 'Password does not meet all requirements';
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
        _password.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  String? _validateName(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Required';
    }

    return null;
  }

  // ==========================================================================
  // SUBMIT
  // ==========================================================================

  Future<void> _handleSubmit() async {
    setState(() {
      _touched.addAll({
        'firstName',
        'lastName',
        'email',
        'phone',
        'password',
        'confirm',
      });
    });

    final valid =
        _formKey.currentState
                ?.validate() ??
            false;

    if (!valid) {
      return;
    }

    final auth =
        context.read<AuthController>();

    final success =
        await auth.registerDonor(
      firstName:
          _firstName.text.trim(),
      lastName:
          _lastName.text.trim(),
      email:
          _email.text.trim(),
      password:
          _password.text,
      contactNum:
          _phone.text.trim().isEmpty
              ? null
              : _phone.text.trim(),
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'Account created. Please confirm your email before signing in.',
        ),
        backgroundColor:
            AppColors.sageGreen,
        duration:
            Duration(seconds: 2),
      ),
    );

    await Future.delayed(
      const Duration(
        milliseconds: 650,
      ),
    );

    if (mounted) {
      context.go('/login');
    }
  }

  // ==========================================================================
  // FIELD DECORATION
  // ==========================================================================

  InputDecoration _decoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor:
          AppColors.catGray.withValues(
        alpha: 0.28,
      ),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(28),
        borderSide:
            const BorderSide(
          color: AppColors.sageGreen,
          width: 1.5,
        ),
      ),
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(28),
        borderSide:
            const BorderSide(
          color: AppColors.coralRed,
          width: 1.4,
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(28),
        borderSide:
            const BorderSide(
          color: AppColors.coralRed,
          width: 1.6,
        ),
      ),
      errorStyle: const TextStyle(
        color: AppColors.coralRed,
        fontSize: 12,
      ),
    );
  }

  String? _validateIfTouched(
    String field,
    String? value,
    String? Function(String?) validator,
  ) {
    if (!_touched.contains(field)) {
      return null;
    }

    return validator(value);
  }

  Widget _nameField({
    required TextEditingController
        controller,
    required String hint,
    required Iterable<String>
        autofillHints,
    required FocusNode focusNode,
    required String field,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      textCapitalization:
          TextCapitalization.words,
      textInputAction:
          TextInputAction.next,
      autofillHints: autofillHints,
      decoration: _decoration(
        hintText: hint,
      ),
      validator: (value) =>
          _validateIfTouched(
        field,
        value,
        _validateName,
      ),
    );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final auth =
        context.watch<AuthController>();

    return Scaffold(
      backgroundColor:
          AppColors.cream,
      appBar: const PublicNavBar(
        currentPath: '/register',
      ),
      body: LayoutBuilder(
        builder: (
          context,
          viewportConstraints,
        ) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight:
                    viewportConstraints
                        .maxHeight,
              ),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 24,
                  vertical: 48,
                ),
                alignment:
                    Alignment.topCenter,
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 480,
                  ),
                  child: AutofillGroup(
                    child: Column(
                      children: [
                        // ====================================================
                        // BRANDING
                        // ====================================================

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .center,
                          children: [
                            Image.asset(
                              'assets/das-no-bg.png',
                              height: 72,
                              fit: BoxFit
                                  .contain,
                            ),
                            const SizedBox(
                              width: 16,
                            ),
                            ClipRRect(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                16,
                              ),
                              child:
                                  Image.asset(
                                'assets/branding/pet-house-green.png',
                                width: 72,
                                height: 72,
                                fit:
                                    BoxFit.cover,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(
                          height: 28,
                        ),

                        const Text(
                          'Create your account',
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight:
                                FontWeight.w800,
                            color: AppColors
                                .deepBrown,
                          ),
                        ),

                        const SizedBox(
                          height: 8,
                        ),

                        const SizedBox(
                          height: 30,
                        ),

                        // ====================================================
                        // FORM
                        // ====================================================

                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .stretch,
                            children: [
                              // ----------------------------------------------
                              // NAME
                              // ----------------------------------------------

                              LayoutBuilder(
                                builder: (
                                  context,
                                  constraints,
                                ) {
                                  final stacked =
                                      constraints
                                              .maxWidth <
                                          420;

                                  if (stacked) {
                                    return Column(
                                      children: [
                                        _nameField(
                                          controller:
                                              _firstName,
                                          hint:
                                              'First name',
                                          autofillHints:
                                              const [
                                            AutofillHints
                                                .givenName,
                                          ],
                                          focusNode:
                                              _firstNameFocus,
                                          field:
                                              'firstName',
                                        ),
                                        const SizedBox(
                                          height: 16,
                                        ),
                                        _nameField(
                                          controller:
                                              _lastName,
                                          hint:
                                              'Last name',
                                          autofillHints:
                                              const [
                                            AutofillHints
                                                .familyName,
                                          ],
                                          focusNode:
                                              _lastNameFocus,
                                          field:
                                              'lastName',
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: [
                                      Expanded(
                                        child:
                                            _nameField(
                                          controller:
                                              _firstName,
                                          hint:
                                              'First name',
                                          autofillHints:
                                              const [
                                            AutofillHints
                                                .givenName,
                                          ],
                                          focusNode:
                                              _firstNameFocus,
                                          field:
                                              'firstName',
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 12,
                                      ),
                                      Expanded(
                                        child:
                                            _nameField(
                                          controller:
                                              _lastName,
                                          hint:
                                              'Last name',
                                          autofillHints:
                                              const [
                                            AutofillHints
                                                .familyName,
                                          ],
                                          focusNode:
                                              _lastNameFocus,
                                          field:
                                              'lastName',
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(
                                height: 16,
                              ),

                              // ----------------------------------------------
                              // EMAIL
                              // ----------------------------------------------

                              TextFormField(
                                controller:
                                    _email,
                                focusNode:
                                    _emailFocus,
                                keyboardType:
                                    TextInputType
                                        .emailAddress,
                                textInputAction:
                                    TextInputAction
                                        .next,
                                autofillHints:
                                    const [
                                  AutofillHints
                                      .email,
                                ],
                                autocorrect: false,
                                decoration:
                                    _decoration(
                                  hintText:
                                      'Email address',
                                ),
                                validator: (value) =>
                                    _validateIfTouched(
                                  'email',
                                  value,
                                  validateEmail,
                                ),
                              ),

                              const SizedBox(
                                height: 16,
                              ),

                              // ----------------------------------------------
                              // PHONE
                              // ----------------------------------------------

                              TextFormField(
                                controller:
                                    _phone,
                                focusNode:
                                    _phoneFocus,
                                keyboardType:
                                    TextInputType
                                        .phone,
                                textInputAction:
                                    TextInputAction
                                        .next,
                                autofillHints:
                                    const [
                                  AutofillHints
                                      .telephoneNumber,
                                ],
                                inputFormatters:
                                    phoneInputFormatters,
                                decoration:
                                    _decoration(
                                  hintText:
                                      '09XXXXXXXXX (optional)',
                                ),
                                validator: (value) =>
                                    _validateIfTouched(
                                  'phone',
                                  value,
                                  validatePhoneNumber,
                                ),
                              ),

                              const SizedBox(
                                height: 16,
                              ),

                              // ----------------------------------------------
                              // PASSWORD
                              // ----------------------------------------------

                              TextFormField(
                                controller:
                                    _password,
                                focusNode:
                                    _passwordFocus,
                                obscureText:
                                    _obscurePassword,
                                textInputAction:
                                    TextInputAction
                                        .next,
                                autofillHints:
                                    const [
                                  AutofillHints
                                      .newPassword,
                                ],
                                autocorrect: false,
                                enableSuggestions:
                                    false,
                                onChanged:
                                    (_) {
                                  setState(() {});
                                },
                                decoration:
                                    _decoration(
                                  hintText:
                                      'Create a strong password',
                                  suffixIcon:
                                      IconButton(
                                    tooltip:
                                        _obscurePassword
                                            ? 'Show password'
                                            : 'Hide password',
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons
                                              .visibility_off_outlined
                                          : Icons
                                              .visibility_outlined,
                                      color: AppColors
                                          .deepBrown,
                                      size: 20,
                                    ),
                                    onPressed:
                                        () {
                                      setState(
                                        () {
                                          _obscurePassword =
                                              !_obscurePassword;
                                        },
                                      );
                                    },
                                  ),
                                ),
                                validator: (value) =>
                                    _validateIfTouched(
                                  'password',
                                  value,
                                  _validateStrongPassword,
                                ),
                              ),

                              const SizedBox(
                                height: 10,
                              ),

                              _PasswordRequirements(
                                hasMinLength:
                                    _hasMinLength,
                                hasUppercase:
                                    _hasUppercase,
                                hasLowercase:
                                    _hasLowercase,
                                hasNumber:
                                    _hasNumber,
                                hasSymbol:
                                    _hasSymbol,
                              ),

                              const SizedBox(
                                height: 16,
                              ),

                              // ----------------------------------------------
                              // CONFIRM PASSWORD
                              // ----------------------------------------------

                              TextFormField(
                                key:
                                    _confirmFieldKey,
                                controller:
                                    _confirm,
                                focusNode:
                                    _confirmFocus,
                                obscureText:
                                    _obscureConfirm,
                                textInputAction:
                                    TextInputAction
                                        .done,
                                autofillHints:
                                    const [
                                  AutofillHints
                                      .newPassword,
                                ],
                                autocorrect: false,
                                enableSuggestions:
                                    false,
                                decoration:
                                    _decoration(
                                  hintText:
                                      'Confirm password',
                                  suffixIcon:
                                      IconButton(
                                    tooltip:
                                        _obscureConfirm
                                            ? 'Show password'
                                            : 'Hide password',
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons
                                              .visibility_off_outlined
                                          : Icons
                                              .visibility_outlined,
                                      color: AppColors
                                          .deepBrown,
                                      size: 20,
                                    ),
                                    onPressed:
                                        () {
                                      setState(
                                        () {
                                          _obscureConfirm =
                                              !_obscureConfirm;
                                        },
                                      );
                                    },
                                  ),
                                ),
                                validator: (value) =>
                                    _validateIfTouched(
                                  'confirm',
                                  value,
                                  _validateConfirmPassword,
                                ),
                                onFieldSubmitted:
                                    (_) {
                                  if (!auth
                                      .isBusy) {
                                    _handleSubmit();
                                  }
                                },
                              ),

                              if (auth
                                      .errorMessage !=
                                  null) ...[
                                const SizedBox(
                                  height: 10,
                                ),
                                Text(
                                  auth.errorMessage!,
                                  style:
                                      const TextStyle(
                                    color: AppColors
                                        .coralRed,
                                    fontSize: 13,
                                  ),
                                ),
                              ],

                              const SizedBox(
                                height: 18,
                              ),

                              // ----------------------------------------------
                              // CREATE ACCOUNT
                              // ----------------------------------------------

                              Container(
                                decoration:
                                    BoxDecoration(
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    28,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors
                                          .sageGreen
                                          .withValues(
                                        alpha:
                                            0.35,
                                      ),
                                      blurRadius:
                                          22,
                                      spreadRadius:
                                          1,
                                      offset:
                                          const Offset(
                                        0,
                                        10,
                                      ),
                                    ),
                                  ],
                                ),
                                child:
                                    ElevatedButton(
                                  onPressed:
                                      auth.isBusy
                                          ? null
                                          : _handleSubmit,
                                  style:
                                      ElevatedButton
                                          .styleFrom(
                                    backgroundColor:
                                        AppColors
                                            .sageGreen,
                                    foregroundColor:
                                        Colors.white,
                                    elevation: 0,
                                    padding:
                                        const EdgeInsets
                                            .symmetric(
                                      vertical: 18,
                                    ),
                                    shape:
                                        RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius
                                              .circular(
                                        28,
                                      ),
                                    ),
                                  ),
                                  child: auth
                                          .isBusy
                                      ? const SizedBox(
                                          height:
                                              18,
                                          width:
                                              18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2,
                                            color:
                                                Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Create Account',
                                          style:
                                              TextStyle(
                                            fontWeight:
                                                FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(
                          height: 20,
                        ),

                        Wrap(
                          alignment:
                              WrapAlignment
                                  .center,
                          crossAxisAlignment:
                              WrapCrossAlignment
                                  .center,
                          spacing: 2,
                          children: [
                            const Text(
                              'Already have an account?',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: AppColors
                                    .deepBrown,
                              ),
                            ),
                            TextButton(
                              onPressed:
                                  auth.isBusy
                                      ? null
                                      : () => context
                                          .go(
                                          '/login',
                                        ),
                              style:
                                  TextButton
                                      .styleFrom(
                                foregroundColor:
                                    AppColors
                                        .sageGreen,
                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                minimumSize:
                                    const Size(
                                  0,
                                  0,
                                ),
                                tapTargetSize:
                                    MaterialTapTargetSize
                                        .shrinkWrap,
                              ),
                              child:
                                  const Text(
                                'Sign in',
                                style:
                                    TextStyle(
                                  fontSize: 13.5,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

// =============================================================================
// PASSWORD REQUIREMENTS
// =============================================================================

class _PasswordRequirements
    extends StatelessWidget {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSymbol;

  const _PasswordRequirements({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.catGray
            .withValues(
          alpha: 0.15,
        ),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight:
                  FontWeight.w700,
              color:
                  AppColors.deepBrown,
            ),
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 12,
            runSpacing: 7,
            children: [
              _PasswordRule(
                met: hasMinLength,
                label:
                    '8+ characters',
              ),
              _PasswordRule(
                met: hasUppercase,
                label:
                    'Uppercase letter',
              ),
              _PasswordRule(
                met: hasLowercase,
                label:
                    'Lowercase letter',
              ),
              _PasswordRule(
                met: hasNumber,
                label: 'Number',
              ),
              _PasswordRule(
                met: hasSymbol,
                label: 'Symbol',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PasswordRule
    extends StatelessWidget {
  final bool met;
  final String label;

  const _PasswordRule({
    required this.met,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = met
        ? AppColors.sageGreen
        : AppColors.mutedForeground;

    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Icon(
          met
              ? Icons
                  .check_circle
              : Icons.circle_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.8,
            fontWeight: met
                ? FontWeight.w600
                : FontWeight.w400,
            color: color,
          ),
        ),
      ],
    );
  }
}
