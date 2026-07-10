import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_user.dart';

/// Thin wrapper around Supabase auth + the public.users profile table.
///
/// Table reference (from your schema):
///   users(userid uuid PK -> auth.users.id, userfname, userlname,
///         role user_role, email, contactnum)
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentSupabaseUser => _client.auth.currentUser;
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Registers a new donor account:
  ///  1) creates the auth.users row via Supabase Auth
  ///  2) inserts the matching profile row into public.users with role='donor'
  ///
  /// Requires an RLS policy on public.users allowing an authenticated
  /// user to insert a row where userid = auth.uid().
  Future<AuthResponse> signUpDonor({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? contactNum,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final newUser = response.user;
    if (newUser != null) {
      await _client.from('users').insert({
        'userid': newUser.id,
        'userfname': firstName,
        'userlname': lastName,
        'role': 'donor',
        'email': email,
        'contactnum': contactNum,
      });
    }

    return response;
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Fetches the public.users profile row for the given auth user id.
  Future<AppUser?> fetchProfile(String userId) async {
    final row = await _client
        .from('users')
        .select()
        .eq('userid', userId)
        .maybeSingle();

    if (row == null) return null;
    return AppUser.fromMap(row);
  }

  /// Fetches every user whose role is in [roles], e.g. donors for a
  /// donor picker, or staff/manager for an "administered by"/"received
  /// by" picker.
  Future<List<AppUser>> fetchUsersByRole(List<AppRole> roles) async {
    final rows = await _client
        .from('users')
        .select()
        .inFilter('role', roles.map(appRoleToString).toList())
        .order('userfname', ascending: true);
    return (rows as List)
        .map((r) => AppUser.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Updates the editable fields of a user's own profile row.
  /// Requires an RLS UPDATE policy on public.users allowing
  /// auth.uid() = userid.
  Future<void> updateProfile({
    required String userId,
    required String firstName,
    required String lastName,
    String? contactNum,
  }) {
    return _client.from('users').update({
      'userfname': firstName,
      'userlname': lastName,
      'contactnum': contactNum,
    }).eq('userid', userId);
  }

  /// Changes the signed-in user's password. Re-authenticates with the
  /// current password first as a safety check before applying the new one
  /// (Supabase's updateUser call doesn't verify the old password itself).
  Future<void> changePassword({
    required String email,
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }
}