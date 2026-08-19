import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/validators.dart';
import '../models/app_user.dart';
import '../state/auth_state.dart';

// ============================================================================
// ROLE COLORS
// ============================================================================

const Map<AppRole, Color> _roleBadgeColor = {
  AppRole.manager: AppColors.roleManager,
  AppRole.staff: AppColors.roleStaff,
  AppRole.donor: AppColors.roleDonor,
};

// ============================================================================
// PROFILE PAGE
// ============================================================================

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() =>
      _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  int _visibleTab = 0;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    _tabController.addListener(() {
      if (_tabController.index != _visibleTab) {
        setState(() {
          _visibleTab =
              _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user =
        context.watch<AuthController>().profile;

    if (user == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final isMobile =
            constraints.maxWidth < 600;

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(
              maxWidth: 900,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ====================================================
                // PAGE HEADER
                // ====================================================
                const Text(
                  'Profile Settings',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Manage your account and security.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),

                const SizedBox(height: 20),

                // ====================================================
                // USER SUMMARY
                // ====================================================
                _ProfileHeaderCard(
                  user: user,
                  isMobile: isMobile,
                ),

                const SizedBox(height: 18),

                // ====================================================
                // PROFILE / SECURITY TABS
                // ====================================================
                _SegmentedTabs(
                  controller:
                      _tabController,
                ),

                const SizedBox(height: 18),

                // ====================================================
                // TAB CONTENT
                // ====================================================
                IndexedStack(
                  index: _visibleTab,
                  children: [
                    _ProfileTab(
                      user: user,
                      isMobile: isMobile,
                    ),

                    // Security uses a smaller centered card on desktop.
                    // On mobile, available width is already smaller than
                    // the max width, so it naturally remains full-width.
                    Align(
                      alignment:
                          Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints:
                            const BoxConstraints(
                          maxWidth: 620,
                        ),
                        child: _SecurityTab(
                          isMobile: isMobile,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// USER SUMMARY CARD
// ============================================================================

class _ProfileHeaderCard
    extends StatelessWidget {
  final AppUser user;
  final bool isMobile;

  const _ProfileHeaderCard({
    required this.user,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor =
        _roleBadgeColor[user.role] ??
            AppColors.mutedForeground;

    if (isMobile) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius:
              BorderRadius.circular(18),
          border:
              Border.all(
            color: AppColors.border,
          ),
        ),
        child: Row(
          children: [
            _ProfileAvatar(
              initials: user.initials,
              size: 58,
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    user.email,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 12.5,
                      color: AppColors
                          .mutedForeground,
                    ),
                  ),

                  const SizedBox(height: 7),

                  _RoleBadge(
                    user: user,
                    color: badgeColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(18),
        border:
            Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          _ProfileAvatar(
            initials: user.initials,
            size: 64,
          ),

          const SizedBox(width: 18),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  user.email,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    color: AppColors
                        .mutedForeground,
                  ),
                ),
              ],
            ),
          ),

          _RoleBadge(
            user: user,
            color: badgeColor,
          ),
        ],
      ),
    );
  }
}

class _ProfileAvatar
    extends StatelessWidget {
  final String initials;
  final double size;

  const _ProfileAvatar({
    required this.initials,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius:
            BorderRadius.circular(
          size * 0.24,
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RoleBadge
    extends StatelessWidget {
  final AppUser user;
  final Color color;

  const _RoleBadge({
    required this.user,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(alpha: 0.12),
        borderRadius:
            BorderRadius.circular(999),
      ),
      child: Text(
        appRoleToString(user.role)
            .toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ============================================================================
// SEGMENTED TABS
// ============================================================================

class _SegmentedTabs
    extends StatelessWidget {
  final TabController controller;

  const _SegmentedTabs({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.card,
          borderRadius:
              BorderRadius.circular(9),
          border: Border.all(
            color: AppColors.border,
          ),
        ),
        indicatorSize:
            TabBarIndicatorSize.tab,
        dividerColor:
            Colors.transparent,
        labelColor:
            AppColors.foreground,
        unselectedLabelColor:
            AppColors.mutedForeground,
        labelStyle:
            const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(
            icon: Icon(
              Icons.person_outline,
              size: 17,
            ),
            text: 'Profile',
          ),
          Tab(
            icon: Icon(
              Icons.lock_outline,
              size: 17,
            ),
            text: 'Security',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PROFILE TAB
// ============================================================================

class _ProfileTab
    extends StatefulWidget {
  final AppUser user;
  final bool isMobile;

  const _ProfileTab({
    required this.user,
    required this.isMobile,
  });

  @override
  State<_ProfileTab> createState() =>
      _ProfileTabState();
}

class _ProfileTabState
    extends State<_ProfileTab> {
  final _formKey =
      GlobalKey<FormState>();

  late final TextEditingController
      _firstName;

  late final TextEditingController
      _lastName;

  late final TextEditingController
      _email;

  late final TextEditingController
      _phone;

  @override
  void initState() {
    super.initState();

    _firstName =
        TextEditingController(
      text: widget.user.firstName,
    );

    _lastName =
        TextEditingController(
      text: widget.user.lastName,
    );

    _email =
        TextEditingController(
      text: widget.user.email,
    );

    _phone =
        TextEditingController(
      text:
          widget.user.contactNum ?? '',
    );
  }

  @override
  void didUpdateWidget(
    covariant _ProfileTab oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.user.firstName !=
            widget.user.firstName ||
        oldWidget.user.lastName !=
            widget.user.lastName ||
        oldWidget.user.email !=
            widget.user.email ||
        oldWidget.user.contactNum !=
            widget.user.contactNum) {
      _firstName.text =
          widget.user.firstName;

      _lastName.text =
          widget.user.lastName;

      _email.text =
          widget.user.email;

      _phone.text =
          widget.user.contactNum ?? '';
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _phone.dispose();

    super.dispose();
  }

  // Resets unsaved values back to the current saved profile.
  void _reset() {
    setState(() {
      _firstName.text =
          widget.user.firstName;

      _lastName.text =
          widget.user.lastName;

      _email.text =
          widget.user.email;

      _phone.text =
          widget.user.contactNum ?? '';
    });
  }

  // Saves the editable profile fields.
  Future<void> _save() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final confirmed =
        await _confirmChanges(
      context: context,
      title: 'Save changes?',
      message:
          'Your profile information will be updated.',
    );

    if (!confirmed || !mounted) {
      return;
    }

    final auth =
        context.read<AuthController>();

    final success =
        await auth.updateProfile(
      firstName:
          _firstName.text.trim(),
      lastName:
          _lastName.text.trim(),
      contactNum:
          _phone.text.trim().isEmpty
              ? null
              : _phone.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Profile updated successfully.'
              : (auth.errorMessage ??
                  'Could not update profile.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth =
        context.watch<AuthController>();

    final isMobile =
        widget.isMobile;

    return _SettingsCard(
      icon: Icons.person_outline,
      title: 'Personal Information',
      subtitle:
          'Update your contact information.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            if (isMobile)
              Column(
                children: [
                  _LabeledField(
                    label: 'First Name',
                    icon:
                        Icons.person_outline,
                    controller:
                        _firstName,
                  ),

                  const SizedBox(height: 14),

                  _LabeledField(
                    label: 'Last Name',
                    icon:
                        Icons.person_outline,
                    controller:
                        _lastName,
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        _LabeledField(
                      label:
                          'First Name',
                      icon: Icons
                          .person_outline,
                      controller:
                          _firstName,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child:
                        _LabeledField(
                      label:
                          'Last Name',
                      icon: Icons
                          .person_outline,
                      controller:
                          _lastName,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 14),

            if (isMobile)
              Column(
                children: [
                  _LabeledField(
                    label:
                        'Email Address',
                    icon:
                        Icons.mail_outline,
                    controller: _email,
                    enabled: false,
                  ),

                  const SizedBox(height: 14),

                  _LabeledField(
                    label:
                        'Phone Number',
                    icon:
                        Icons.phone_outlined,
                    controller: _phone,
                    keyboardType:
                        TextInputType.phone,
                    inputFormatters:
                        phoneInputFormatters,
                    hintText:
                        '09XXXXXXXXX',
                    validator:
                        validatePhoneNumber,
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child:
                        _LabeledField(
                      label:
                          'Email Address',
                      icon:
                          Icons.mail_outline,
                      controller:
                          _email,
                      enabled: false,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child:
                        _LabeledField(
                      label:
                          'Phone Number',
                      icon: Icons
                          .phone_outlined,
                      controller:
                          _phone,
                      keyboardType:
                          TextInputType.phone,
                      inputFormatters:
                          phoneInputFormatters,
                      hintText:
                          '09XXXXXXXXX',
                      validator:
                          validatePhoneNumber,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 20),

            if (isMobile)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          auth.isBusy
                              ? null
                              : _save,
                      icon: auth.isBusy
                          ? const SizedBox(
                              height: 15,
                              width: 15,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .save_outlined,
                              size: 17,
                            ),
                      label:
                          const Text(
                        'Save Changes',
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child:
                        OutlinedButton(
                      onPressed:
                          auth.isBusy
                              ? null
                              : _reset,
                      child:
                          const Text(
                        'Reset',
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        auth.isBusy
                            ? null
                            : _save,
                    icon: auth.isBusy
                        ? const SizedBox(
                            height: 15,
                            width: 15,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons
                                .save_outlined,
                            size: 17,
                          ),
                    label:
                        const Text(
                      'Save Changes',
                    ),
                  ),

                  const SizedBox(width: 10),

                  OutlinedButton(
                    onPressed:
                        auth.isBusy
                            ? null
                            : _reset,
                    child:
                        const Text(
                      'Reset',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SECURITY TAB
// ============================================================================

class _SecurityTab
    extends StatefulWidget {
  final bool isMobile;

  const _SecurityTab({
    required this.isMobile,
  });

  @override
  State<_SecurityTab> createState() =>
      _SecurityTabState();
}

class _SecurityTabState
    extends State<_SecurityTab> {
  final _formKey =
      GlobalKey<FormState>();

  final _current =
      TextEditingController();

  final _newPassword =
      TextEditingController();

  final _confirm =
      TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirm.dispose();

    super.dispose();
  }

  // Clears all password fields.
  void _clear() {
    setState(() {
      _current.clear();
      _newPassword.clear();
      _confirm.clear();
    });
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final confirmed =
        await _confirmChanges(
      context: context,
      title: 'Change password?',
      message:
          'You will use the new password the next time you sign in.',
    );

    if (!confirmed || !mounted) {
      return;
    }

    final auth =
        context.read<AuthController>();

    final success =
        await auth.changePassword(
      currentPassword:
          _current.text,
      newPassword:
          _newPassword.text,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Password updated successfully.'
              : (auth.errorMessage ??
                  'Could not update password.'),
        ),
      ),
    );

    if (success) {
      _clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth =
        context.watch<AuthController>();

    final isMobile =
        widget.isMobile;

    return _SettingsCard(
      icon: Icons.lock_outline,
      title: 'Password',
      subtitle:
          'Keep your account secure with a strong password.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            _LabeledField(
              label:
                  'Current Password',
              icon:
                  Icons.lock_outline,
              controller: _current,
              obscure: true,
              hintText:
                  'Enter current password',
              validator: (value) {
                if (value == null ||
                    value.isEmpty) {
                  return 'Current password is required';
                }

                return null;
              },
            ),

            const SizedBox(height: 14),

            _LabeledField(
              label:
                  'New Password',
              icon:
                  Icons.lock_outline,
              controller:
                  _newPassword,
              obscure: true,
              hintText:
                  'Enter new password',
              validator:
                  validatePassword,
            ),

            const SizedBox(height: 14),

            _LabeledField(
              label:
                  'Confirm New Password',
              icon:
                  Icons.lock_outline,
              controller: _confirm,
              obscure: true,
              hintText:
                  'Re-enter new password',
              validator: (value) {
                if (value !=
                    _newPassword.text) {
                  return 'Passwords do not match';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            if (isMobile)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child:
                        ElevatedButton.icon(
                      onPressed:
                          auth.isBusy
                              ? null
                              : _updatePassword,
                      icon: auth.isBusy
                          ? const SizedBox(
                              height: 15,
                              width: 15,
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                                color:
                                    Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons
                                  .lock_outline,
                              size: 17,
                            ),
                      label:
                          const Text(
                        'Update Password',
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  SizedBox(
                    width: double.infinity,
                    child:
                        OutlinedButton(
                      onPressed:
                          auth.isBusy
                              ? null
                              : _clear,
                      child:
                          const Text(
                        'Clear',
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        auth.isBusy
                            ? null
                            : _updatePassword,
                    icon: auth.isBusy
                        ? const SizedBox(
                            height: 15,
                            width: 15,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons
                                .lock_outline,
                            size: 17,
                          ),
                    label:
                        const Text(
                      'Update Password',
                    ),
                  ),

                  const SizedBox(width: 10),

                  OutlinedButton(
                    onPressed:
                        auth.isBusy
                            ? null
                            : _clear,
                    child:
                        const Text(
                      'Clear',
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SETTINGS CARD
// ============================================================================

class _SettingsCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius:
            BorderRadius.circular(18),
        border:
            Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary
                      .withValues(
                    alpha: 0.08,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color:
                      AppColors.primary,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 1),

                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        fontSize: 11.8,
                        color: AppColors
                            .mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          child,
        ],
      ),
    );
  }
}

// ============================================================================
// CONFIRMATION DIALOG
// ============================================================================

Future<bool> _confirmChanges({
  required BuildContext context,
  required String title,
  required String message,
}) async {
  final confirmed =
      await showDialog<bool>(
    context: context,
    builder: (
      dialogContext,
    ) {
      return AlertDialog(
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(
                  dialogContext,
                ).pop(false),
            child:
                const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(
                  dialogContext,
                ).pop(true),
            child:
                const Text('Confirm'),
          ),
        ],
      );
    },
  );

  return confirmed == true;
}

// ============================================================================
// LABELED FORM FIELD
// ============================================================================

class _LabeledField
    extends StatefulWidget {
  final String label;
  final IconData icon;

  final TextEditingController
      controller;

  final bool enabled;
  final bool obscure;

  final String? hintText;

  final TextInputType?
      keyboardType;

  final List<TextInputFormatter>?
      inputFormatters;

  final String? Function(String?)?
      validator;

  const _LabeledField({
    required this.label,
    required this.icon,
    required this.controller,
    this.enabled = true,
    this.obscure = false,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.validator,
  });

  @override
  State<_LabeledField>
      createState() =>
          _LabeledFieldState();
}

class _LabeledFieldState
    extends State<_LabeledField> {
  late bool _hidden =
      widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight:
                FontWeight.w600,
          ),
        ),

        const SizedBox(height: 6),

        TextFormField(
          controller:
              widget.controller,
          enabled: widget.enabled,

          obscureText:
              widget.obscure &&
                  _hidden,

          keyboardType:
              widget.keyboardType,

          inputFormatters:
              widget.inputFormatters,

          validator:
              widget.validator,

          style: TextStyle(
            fontSize: 13.5,
            color: widget.enabled
                ? AppColors.foreground
                : AppColors
                    .mutedForeground,
          ),

          decoration:
              InputDecoration(
            hintText:
                widget.hintText,

            prefixIcon:
                Icon(
              widget.icon,
              size: 17,
              color: AppColors
                  .mutedForeground,
            ),

            suffixIcon:
                widget.obscure
                    ? IconButton(
                        tooltip:
                            _hidden
                                ? 'Show password'
                                : 'Hide password',
                        icon: Icon(
                          _hidden
                              ? Icons
                                  .visibility_off_outlined
                              : Icons
                                  .visibility_outlined,
                          size: 18,
                          color: AppColors
                              .mutedForeground,
                        ),
                        onPressed: () {
                          setState(() {
                            _hidden =
                                !_hidden;
                          });
                        },
                      )
                    : null,

            filled: true,

            fillColor: widget.enabled
                ? AppColors
                    .inputBackground
                : AppColors.muted,
          ),
        ),
      ],
    );
  }
}