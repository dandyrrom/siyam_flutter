import 'dart:convert';

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
  // SINGLE-DEVICE SESSION HELPERS
  // ==========================================================================
  //
  // The SQL migration already installed these RPC functions:
  //
  //   claim_user_session()
  //   touch_user_session()
  //   release_user_session()
  //   replace_user_session(previous_session_id)
  //
  // The first active Supabase session claims the SIYAM account.
  // A second fresh session for the same user is rejected.
  // ==========================================================================

  Future<bool> _claimCurrentSession() async {
    final result = await _client.rpc(
      'claim_user_session',
    );

    return result == true;
  }

  @override
  Future<bool> touchSession() async {
    if (_client.auth.currentSession == null) {
      return false;
    }

    final result = await _client.rpc(
      'touch_user_session',
    );

    return result == true;
  }

  Future<void> _releaseCurrentSession() async {
    if (_client.auth.currentSession == null) {
      return;
    }

    try {
      await _client.rpc(
        'release_user_session',
      );
    } catch (_) {
      // Do not prevent logout if the release RPC cannot be reached.
      // The server-side stale timeout allows the account to recover.
    }
  }

  Future<bool> _replaceCurrentSession(
    String previousSessionId,
  ) async {
    final result = await _client.rpc(
      'replace_user_session',
      params: {
        'previous_session_id':
            previousSessionId,
      },
    );

    return result == true;
  }

  String? _sessionIdFromAccessToken(
    String accessToken,
  ) {
    try {
      final parts = accessToken.split('.');

      if (parts.length != 3) {
        return null;
      }

      final payload = utf8.decode(
        base64Url.decode(
          base64Url.normalize(
            parts[1],
          ),
        ),
      );

      final decoded = jsonDecode(payload);

      if (decoded is! Map) {
        return null;
      }

      final value = decoded['session_id'];

      if (value == null) {
        return null;
      }

      final text = value.toString().trim();

      return text.isEmpty
          ? null
          : text;
    } catch (_) {
      return null;
    }
  }

  Future<Never> _rejectSecondLogin() async {
    // Explicitly sign out ONLY the newly-created local session.
    // The already-active browser/device must remain signed in.
    await _client.auth.signOut(
      scope: SignOutScope.local,
    );

    throw Exception(
      'This account is currently signed in on another device. '
      'Please log out from that device before signing in here.',
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

    if (userId == null ||
        res.session == null) {
      await _client.auth.signOut(
        scope: SignOutScope.local,
      );

      throw Exception(
        'Invalid email or password.',
      );
    }

    final profile = await fetchProfile(userId);

    if (profile == null) {
      await _client.auth.signOut(
        scope: SignOutScope.local,
      );

      throw Exception(
        'Your account has no profile. Contact an administrator.',
      );
    }

    final claimed =
        await _claimCurrentSession();

    if (!claimed) {
      await _rejectSecondLogin();
    }

    return profile;
  }

  // ==========================================================================
  // SIGN OUT
  // ==========================================================================

  @override
  Future<void> signOut() async {
    // Release SIYAM's active-device lock first.
    await _releaseCurrentSession();

    // Explicit LOCAL scope so this device does not revoke another
    // Supabase session unexpectedly.
    await _client.auth.signOut(
      scope: SignOutScope.local,
    );
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

    final profile =
        await fetchProfile(userId);

    if (profile == null) {
      await _client.auth.signOut(
        scope: SignOutScope.local,
      );

      return null;
    }

    final claimed =
        await _claimCurrentSession();

    if (!claimed) {
      await _client.auth.signOut(
        scope: SignOutScope.local,
      );

      return null;
    }

    return profile;
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

    if (res.session != null) {
      final claimed =
          await _claimCurrentSession();

      if (!claimed) {
        await _rejectSecondLogin();
      }
    }

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

    final currentSession =
        _client.auth.currentSession;

    if (currentUser == null ||
        currentSession == null) {
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

    final previousSessionId =
        _sessionIdFromAccessToken(
      currentSession.accessToken,
    );

    if (previousSessionId == null) {
      throw Exception(
        'Could not verify the current session. Please log out and sign in again.',
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

    // Re-authentication may create/rotate the Supabase session_id.
    // Move SIYAM's active-device lock from the old session to this new one.
    final replaced =
        await _replaceCurrentSession(
      previousSessionId,
    );

    if (!replaced) {
      await _client.auth.signOut(
        scope: SignOutScope.local,
      );

      throw Exception(
        'Your session is no longer active on this device. Please sign in again.',
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