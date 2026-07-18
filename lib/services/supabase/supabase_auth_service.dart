import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../auth_service.dart';

/// Supabase-backed auth. Credentials live in GoTrue (`auth.users`); profile
/// data (name, role, contact) lives in `public.users`, created on signup by
/// the `handle_new_user` trigger. [AppUser.password] is always empty here --
/// the app never sees the real password.
class SupabaseAuthService implements AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _table = 'users';
  static const String _columns = 'id, fname, lname, role, email, contactnum';

  AppUser _mapUser(Map<String, dynamic> row) {
    return AppUser(
      userId: row['id'] as String,
      firstName: (row['fname'] as String?) ?? '',
      lastName: (row['lname'] as String?) ?? '',
      role: appRoleFromString((row['role'] as String?) ?? 'donor'),
      email: (row['email'] as String?) ?? '',
      password: '',
      contactNum: row['contactnum'] as String?,
    );
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final AuthResponse res;
    try {
      res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException {
      throw Exception('Invalid email or password.');
    }
    final userId = res.user?.id;
    if (userId == null) throw Exception('Invalid email or password.');

    final profile = await fetchProfile(userId);
    if (profile == null) {
      throw Exception('Your account has no profile. Contact an administrator.');
    }
    return profile;
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<AppUser> signUpDonor({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? contactNum,
  }) async {
    final AuthResponse res;
    try {
      res = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'first_name': firstName,
          'last_name': lastName,
          'contact_num': contactNum ?? '',
          'role': 'donor',
        },
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    }

    final userId = res.user?.id;
    if (userId == null) {
      // No session returned -- most likely email confirmation is enabled.
      throw Exception(
          'Account created. Please confirm your email before signing in.');
    }

    final profile = await fetchProfile(userId);
    if (profile != null) return profile;

    // Fallback if the profile row isn't readable yet.
    return AppUser(
      userId: userId,
      firstName: firstName,
      lastName: lastName,
      role: AppRole.donor,
      email: email.trim(),
      password: '',
      contactNum: contactNum,
    );
  }

  @override
  Future<AppUser?> fetchProfile(String userId) async {
    final row = await _client
        .from(_table)
        .select(_columns)
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : _mapUser(row);
  }

  @override
  Future<List<AppUser>> fetchUsersByRole(List<AppRole> roles) async {
    if (roles.isEmpty) return [];
    final roleNames = roles.map(appRoleToString).toList();
    final rows = await _client
        .from(_table)
        .select(_columns)
        .inFilter('role', roleNames)
        .order('fname');
    return rows.map((r) => _mapUser(r)).toList();
  }

  @override
  Future<AppUser> updateProfile({
    required String userId,
    required String firstName,
    required String lastName,
    String? contactNum,
  }) async {
    final row = await _client
        .from(_table)
        .update({
          'fname': firstName,
          'lname': lastName,
          'contactnum': contactNum,
        })
        .eq('id', userId)
        .select(_columns)
        .single();
    return _mapUser(row);
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final email = _client.auth.currentUser?.email;
    if (email == null) throw Exception('Not signed in.');

    // GoTrue has no "verify current password" call, so re-authenticate first.
    try {
      await _client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException {
      throw Exception('Current password is incorrect.');
    }

    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }
}
