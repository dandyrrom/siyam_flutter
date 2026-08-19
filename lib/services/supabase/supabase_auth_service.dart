import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/app_user.dart';
import '../auth_service.dart';

/// Supabase-backed auth.
///
/// Credentials are stored securely in Supabase Auth (`auth.users`).
/// Profile data such as name, role, email, and contact number is stored in
/// `public.users`.
///
/// [AppUser.password] is always empty in the real Supabase implementation.
/// The application never reads or stores the user's actual password.
class SupabaseAuthService implements AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  static const String _table = 'users';

  static const String _columns =
      'id, fname, lname, role, email, contactnum';

  // ==========================================================================
  // MAP USER
  // ==========================================================================

  AppUser _mapUser(Map<String, dynamic> row) {
    return AppUser(
      userId: row['id'] as String,
      firstName: (row['fname'] as String?) ?? '',
      lastName: (row['lname'] as String?) ?? '',
      role: appRoleFromString(
        (row['role'] as String?) ?? 'donor',
      ),
      email: (row['email'] as String?) ?? '',
      password: '',
      contactNum: row['contactnum'] as String?,
    );
  }

  // ==========================================================================
  // SIGN IN
  // ==========================================================================

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
      throw Exception(
        'Invalid email or password.',
      );
    }

    final userId = res.user?.id;

    if (userId == null) {
      throw Exception(
        'Invalid email or password.',
      );
    }

    final profile = await fetchProfile(userId);

    if (profile == null) {
      throw Exception(
        'Your account has no profile. Contact an administrator.',
      );
    }

    return profile;
  }

  // ==========================================================================
  // SIGN OUT
  // ==========================================================================

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ==========================================================================
  // RESTORE SESSION
  // ==========================================================================

  @override
  Future<AppUser?> restoreSession() async {
    // Prefer the currently restored in-memory Supabase session.
    var userId =
        _client.auth.currentSession?.user.id;

    // If recoverSession() is still completing after app initialization,
    // briefly wait for the first authentication event.
    if (userId == null) {
      try {
        final event = await _client.auth.onAuthStateChange.first.timeout(
          const Duration(seconds: 2),
        );

        userId = event.session?.user.id;
      } catch (_) {
        // Timeout or no authentication event.
        //
        // Fall through and check currentSession one more time.
      }

      userId ??=
          _client.auth.currentSession?.user.id;
    }

    if (userId == null) {
      return null;
    }

    return fetchProfile(userId);
  }

  // ==========================================================================
  // REGISTER DONOR
  // ==========================================================================

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
      // Most likely email confirmation is enabled.
      throw Exception(
        'Account created. Please confirm your email before signing in.',
      );
    }

    final profile = await fetchProfile(userId);

    if (profile != null) {
      return profile;
    }

    // ------------------------------------------------------------------------
    // PROFILE FALLBACK
    // ------------------------------------------------------------------------
    //
    // This can occur briefly when the public.users trigger has not become
    // readable yet immediately after registration.
    // ------------------------------------------------------------------------

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

  // ==========================================================================
  // FETCH PROFILE
  // ==========================================================================

  @override
  Future<AppUser?> fetchProfile(
    String userId,
  ) async {
    final row = await _client
        .from(_table)
        .select(_columns)
        .eq('id', userId)
        .maybeSingle();

    return row == null
        ? null
        : _mapUser(row);
  }

  // ==========================================================================
  // FETCH USERS BY ROLE
  // ==========================================================================

  @override
  Future<List<AppUser>> fetchUsersByRole(
    List<AppRole> roles,
  ) async {
    if (roles.isEmpty) {
      return [];
    }

    final roleNames =
        roles.map(appRoleToString).toList();

    final rows = await _client
        .from(_table)
        .select(_columns)
        .inFilter(
          'role',
          roleNames,
        )
        .order('fname');

    return rows
        .map(
          (row) => _mapUser(row),
        )
        .toList();
  }

  // ==========================================================================
  // UPDATE PROFILE
  // ==========================================================================

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

  // ==========================================================================
  // CHANGE PASSWORD
  // ==========================================================================
  //
  // IMPORTANT:
  //
  // The Supabase Auth SDK version currently used by this project does NOT
  // expose:
  //
  // UserAttributes(
  //   currentPassword: ...
  // )
  //
  // Therefore the compatible password-change flow is:
  //
  // 1. Make sure the signed-in Supabase user matches the SIYAM profile.
  // 2. Validate the entered values.
  // 3. Re-authenticate using the entered current password.
  // 4. If verification succeeds, update the password.
  //
  // No password is stored in public.users.
  // ==========================================================================

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    // ------------------------------------------------------------------------
    // CURRENT AUTHENTICATED USER
    // ------------------------------------------------------------------------

    final currentUser =
        _client.auth.currentUser;

    if (currentUser == null) {
      throw Exception(
        'You are not signed in.',
      );
    }

    // ------------------------------------------------------------------------
    // PROFILE / SESSION SAFETY CHECK
    // ------------------------------------------------------------------------
    //
    // Prevent a password update if the authenticated Supabase account does
    // not match the SIYAM profile currently loaded by AuthController.
    // ------------------------------------------------------------------------

    if (currentUser.id != userId) {
      throw Exception(
        'The authenticated account does not match the current profile.',
      );
    }

    final email = currentUser.email;

    if (email == null ||
        email.trim().isEmpty) {
      throw Exception(
        'No email address is associated with this account.',
      );
    }

    // ------------------------------------------------------------------------
    // VALIDATION
    // ------------------------------------------------------------------------

    if (currentPassword.isEmpty) {
      throw Exception(
        'Current password is required.',
      );
    }

    if (newPassword.isEmpty) {
      throw Exception(
        'New password is required.',
      );
    }

    if (currentPassword == newPassword) {
      throw Exception(
        'New password must be different from your current password.',
      );
    }

    // ------------------------------------------------------------------------
    // VERIFY CURRENT PASSWORD
    // ------------------------------------------------------------------------
    //
    // Supabase does not expose a user's existing password.
    //
    // With the SDK version currently used by SIYAM, re-authentication is the
    // compatible way to verify that the entered current password is valid.
    // ------------------------------------------------------------------------

    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: currentPassword,
      );
    } on AuthException {
      throw Exception(
        'Current password is incorrect.',
      );
    }

    // ------------------------------------------------------------------------
    // UPDATE PASSWORD
    // ------------------------------------------------------------------------

    try {
      await _client.auth.updateUser(
        UserAttributes(
          password: newPassword,
        ),
      );
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }
}