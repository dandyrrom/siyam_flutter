import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../state/auth_state.dart';

const Map<AppRole, Color> _roleBadgeColor = {
  AppRole.manager: AppColors.roleManager,
  AppRole.staff: AppColors.roleStaff,
  AppRole.donor: AppColors.roleDonor,
};

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _visibleTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != _visibleTab) {
        setState(() => _visibleTab = _tabController.index);
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
    final user = context.watch<AuthController>().profile;

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    // ============================================================
    // MOBILE DETECTION: Check if screen width is less than 600px
    // ============================================================
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // TITLE: Responsive
          // ============================================================
          Text(
            isMobile ? 'Profile' : 'Profile & Settings',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            isMobile
                ? 'Manage your account'
                : 'Manage your account information and preferences',
            style: const TextStyle(color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 20),

          // ============================================================
          // HEADER: Mobile uses centered layout, Web uses row layout
          // ============================================================
          isMobile
              ? _ProfileHeaderCardMobile(user: user)
              : _ProfileHeaderCard(user: user),
          const SizedBox(height: 20),

          // ============================================================
          // TABS: Mobile uses shorter labels, Web uses full labels
          // ============================================================
          isMobile
              ? _SegmentedTabsMobile(controller: _tabController)
              : _SegmentedTabs(controller: _tabController),
          const SizedBox(height: 20),

          // ============================================================
          // TAB CONTENT: Pass isMobile to child widgets
          // ============================================================
          IndexedStack(
            index: _visibleTab,
            children: [
              _ProfileTab(user: user, isMobile: isMobile),
              _SecurityTab(isMobile: isMobile),
              _NotificationsTab(isMobile: isMobile),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// WEB HEADER (Original - UNCHANGED)
// ============================================================
class _ProfileHeaderCard extends StatelessWidget {
  final AppUser user;
  const _ProfileHeaderCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final badgeColor = _roleBadgeColor[user.role] ?? AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                user.initials,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(user.email,
                    style: const TextStyle(
                        color: AppColors.mutedForeground, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    appRoleToString(user.role).toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// WEB TABS (Original - UNCHANGED)
// ============================================================
class _SegmentedTabs extends StatelessWidget {
  final TabController controller;
  const _SegmentedTabs({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(9),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.foreground,
        unselectedLabelColor: AppColors.mutedForeground,
        labelStyle:
            const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Profile'),
          Tab(text: 'Security'),
          Tab(text: 'Notifications'),
        ],
      ),
    );
  }
}

// ============================================================
// MOBILE HEADER (NEW - Mobile Optimized)
// ============================================================
class _ProfileHeaderCardMobile extends StatelessWidget {
  final AppUser user;
  const _ProfileHeaderCardMobile({required this.user});

  @override
  Widget build(BuildContext context) {
    final badgeColor = _roleBadgeColor[user.role] ?? AppColors.mutedForeground;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar - centered on mobile
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                user.initials,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Name - centered
          Text(
            user.fullName,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            user.email,
            style:
                const TextStyle(color: AppColors.mutedForeground, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // Role badge - centered
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              appRoleToString(user.role).toUpperCase(),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: badgeColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MOBILE TABS (NEW - Mobile Optimized with shorter labels)
// ============================================================
class _SegmentedTabsMobile extends StatelessWidget {
  final TabController controller;
  const _SegmentedTabsMobile({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(9),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.foreground,
        unselectedLabelColor: AppColors.mutedForeground,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Profile'),
          Tab(text: 'Security'),
          Tab(text: 'Notif'), // Shorter for mobile
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// Profile tab: edits public.users (first/last name, phone). Email and
/// role are shown read-only -- email changes go through Supabase Auth's
/// own confirmation flow and aren't wired up here yet; role is
/// staff-assigned, not self-editable.
/// ----------------------------------------------------------------------
class _ProfileTab extends StatefulWidget {
  final AppUser user;
  final bool isMobile;

  const _ProfileTab({required this.user, required this.isMobile});

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _firstName = TextEditingController(text: widget.user.firstName);
    _lastName = TextEditingController(text: widget.user.lastName);
    _phone = TextEditingController(text: widget.user.contactNum ?? '');
  }

  @override
  void didUpdateWidget(covariant _ProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.userId != widget.user.userId) {
      _firstName.text = widget.user.firstName;
      _lastName.text = widget.user.lastName;
      _phone.text = widget.user.contactNum ?? '';
    }
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final auth = context.read<AuthController>();
    final success = await auth.updateProfile(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim(),
      contactNum: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Profile updated.'
            : (auth.errorMessage ?? 'Could not update profile.')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final bool isMobile = widget.isMobile;

    return _CardSection(
      title: 'Personal Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ============================================================
          // FIRST/LAST NAME: Stacked on mobile, Row on web
          // ============================================================
          isMobile
              ? Column(
                  children: [
                    _LabeledField(
                      label: 'First Name',
                      icon: Icons.person_outline,
                      controller: _firstName,
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'Last Name',
                      icon: Icons.person_outline,
                      controller: _lastName,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'First Name',
                        icon: Icons.person_outline,
                        controller: _firstName,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _LabeledField(
                        label: 'Last Name',
                        icon: Icons.person_outline,
                        controller: _lastName,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 14),

          // ============================================================
          // EMAIL/PHONE: Stacked on mobile, Row on web
          // ============================================================
          isMobile
              ? Column(
                  children: [
                    _LabeledField(
                      label: 'Email Address',
                      icon: Icons.mail_outline,
                      controller:
                          TextEditingController(text: widget.user.email),
                      enabled: false,
                      helperText: 'Contact an admin to change your email.',
                    ),
                    const SizedBox(height: 14),
                    _LabeledField(
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      controller: _phone,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _LabeledField(
                        label: 'Email Address',
                        icon: Icons.mail_outline,
                        controller:
                            TextEditingController(text: widget.user.email),
                        enabled: false,
                        helperText: 'Contact an admin to change your email.',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _LabeledField(
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        controller: _phone,
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 14),

          // ============================================================
          // ROLE (read-only)
          // ============================================================
          _LabeledField(
            label: 'Role',
            icon: Icons.shield_outlined,
            controller: TextEditingController(
                text: '${appRoleToString(widget.user.role)} (read-only)'),
            enabled: false,
          ),
          const SizedBox(height: 18),

          // ============================================================
          // SAVE BUTTON: Full width on mobile, normal on web
          // ============================================================
          SizedBox(
            width: isMobile ? double.infinity : null,
            child: ElevatedButton.icon(
              onPressed: auth.isBusy ? null : _save,
              icon: auth.isBusy
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save Changes'),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// Security tab: change password via Supabase Auth. Current password is
/// verified by re-authenticating before applying the new one.
/// ----------------------------------------------------------------------
class _SecurityTab extends StatefulWidget {
  final bool isMobile;

  const _SecurityTab({required this.isMobile});

  @override
  State<_SecurityTab> createState() => _SecurityTabState();
}

class _SecurityTabState extends State<_SecurityTab> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthController>();
    final success = await auth.changePassword(
      currentPassword: _current.text,
      newPassword: _newPassword.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success
            ? 'Password updated.'
            : (auth.errorMessage ?? 'Could not update password.')),
      ),
    );
    if (success) {
      _current.clear();
      _newPassword.clear();
      _confirm.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final bool isMobile = widget.isMobile;

    return _CardSection(
      title: 'Change Password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabeledField(
                    label: 'Current Password',
                    icon: Icons.lock_outline,
                    controller: _current,
                    obscure: true,
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 14),
                  _LabeledField(
                    label: 'New Password',
                    icon: Icons.lock_outline,
                    controller: _newPassword,
                    obscure: true,
                    validator: (v) => (v == null || v.length < 6)
                        ? 'At least 6 characters'
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _LabeledField(
                    label: 'Confirm New Password',
                    icon: Icons.lock_outline,
                    controller: _confirm,
                    obscure: true,
                    validator: (v) => (v != _newPassword.text)
                        ? 'Passwords do not match'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  // ============================================================
                  // UPDATE BUTTON: Full width on mobile, normal on web
                  // ============================================================
                  SizedBox(
                    width: isMobile ? double.infinity : null,
                    child: ElevatedButton.icon(
                      onPressed: auth.isBusy ? null : _updatePassword,
                      icon: auth.isBusy
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.lock_outline, size: 16),
                      label: const Text('Update Password'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const Text('Two-Factor Authentication',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Add an extra layer of security to your account.',
            style: TextStyle(fontSize: 13, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 12),
          const ComingSoonNotice(
            text: 'Two-factor authentication isn\'t wired up yet -- Supabase '
                'supports MFA, this just needs the enrollment flow built.',
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// Notifications tab: UI only for now -- there's no notification
/// preferences table in the schema yet, so toggles are local state and
/// don't persist between sessions.
/// ----------------------------------------------------------------------
class _NotifPref {
  final String label;
  final String description;
  bool enabled;
  _NotifPref(this.label, this.description, this.enabled);
}

class _NotificationsTab extends StatefulWidget {
  final bool isMobile;

  const _NotificationsTab({required this.isMobile});

  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  final List<_NotifPref> _prefs = [
    _NotifPref(
        'Low Stock Alerts', 'Notify when items fall below reorder point', true),
    _NotifPref(
        'Expiry Warnings', 'Notify when items expire within 30 days', true),
    _NotifPref(
        'New Donations', 'Notify when a new donation is submitted', true),
    _NotifPref('Audit Log Digest', 'Daily summary of system activity', false),
    _NotifPref('Weekly Reports',
        'Automated weekly inventory and donation report', true),
  ];

  @override
  Widget build(BuildContext context) {
    final bool isMobile = widget.isMobile;

    return _CardSection(
      title: 'Notification Preferences',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final pref in _prefs) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pref.label,
                            style: TextStyle(
                                fontSize: isMobile ? 13 : 13.5,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(pref.description,
                            style: TextStyle(
                                fontSize: isMobile ? 11.5 : 12,
                                color: AppColors.mutedForeground)),
                      ],
                    ),
                  ),
                  Switch(
                    value: pref.enabled,
                    activeThumbColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => setState(() => pref.enabled = v),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const ComingSoonNotice(
            text:
                'These preferences aren\'t saved yet -- persisting them needs '
                'a notification_preferences table, which isn\'t in the schema yet.',
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------------------
/// Shared small building blocks
/// ----------------------------------------------------------------------
class _CardSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _CardSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool enabled;
  final bool obscure;
  final String? helperText;
  final String? Function(String?)? validator;

  const _LabeledField({
    required this.label,
    required this.icon,
    required this.controller,
    this.enabled = true,
    this.obscure = false,
    this.helperText,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          validator: validator,
          style: TextStyle(
              color:
                  enabled ? AppColors.foreground : AppColors.mutedForeground),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 16, color: AppColors.mutedForeground),
            helperText: helperText,
            filled: true,
            fillColor: enabled ? AppColors.inputBackground : AppColors.muted,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// COMING SOON NOTICE
// ============================================================
class ComingSoonNotice extends StatelessWidget {
  final String text;
  const ComingSoonNotice({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.mutedForeground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
