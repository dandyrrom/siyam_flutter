import '../mock/mock_database.dart';
import '../models/app_user.dart';
import 'backend.dart';
import 'supabase/supabase_auth_service.dart';

/// Data-access interface for auth/profile. The factory resolves to the mock
/// or Supabase implementation based on [kUseMock], chosen at build time.
abstract interface class AuthService {
  factory AuthService() => kUseMock ? MockAuthService() : SupabaseAuthService();

  Future<AppUser> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();

  /// Returns true while this client still owns the active SIYAM session.
  ///
  /// Supabase uses this as a lightweight heartbeat for the single-device
  /// login restriction. Mock mode always returns true.
  Future<bool> touchSession();

  /// Returns the signed-in profile if a persisted session exists (Supabase),
  /// or null when there is none (mock always returns null).
  Future<AppUser?> restoreSession();

  Future<AppUser> signUpDonor({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? contactNum,
  });

  Future<AppUser?> fetchProfile(String userId);

  Future<List<AppUser>> fetchUsersByRole(
    List<AppRole> roles,
  );

  /// Manager-only Staff account list in production.
  ///
  /// Supabase is backed by public.get_staff_accounts().
  Future<List<AppUser>> fetchStaffAccounts();

  /// Manager-only creation of a real Staff account.
  ///
  /// Supabase is backed by the create-staff-account Edge Function.
  Future<AppUser> createStaffAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? contactNum,
  });

  /// Manager-only Staff account enable/disable action in production.
  ///
  /// Supabase is backed by public.set_staff_account_active(...).
  Future<void> setStaffAccountActive({
    required String userId,
    required bool isActive,
  });

  Future<AppUser> updateProfile({
    required String userId,
    required String firstName,
    required String lastName,
    String? contactNum,
  });

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  });
}

/// Mock auth: checks email/password directly against the in-memory user
/// list. There is no session/token concept -- AuthController just holds
/// onto the returned AppUser for the lifetime of the app (lost on restart).
/// This is a local dev stand-in only, not how real auth should work.
class MockAuthService implements AuthService {
  final MockDatabase _db = MockDatabase.instance;

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final user = firstWhereOrNull(
      _db.users,
      (u) => u.email.toLowerCase() == email.toLowerCase(),
    );

    if (user == null || user.password != password) {
      throw Exception(
        'Invalid email or password.',
      );
    }

    if (!user.isActive) {
      throw Exception(
        'This account has been disabled. Please contact a manager.',
      );
    }

    return user;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<bool> touchSession() async => true;

  @override
  Future<AppUser?> restoreSession() async => null;

  /// Registers a new donor account.
  @override
  Future<AppUser> signUpDonor({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? contactNum,
  }) async {
    final exists = firstWhereOrNull(
      _db.users,
      (u) => u.email.toLowerCase() == email.toLowerCase(),
    );

    if (exists != null) {
      throw Exception(
        'An account with this email already exists.',
      );
    }

    final user = AppUser(
      userId: newMockId('user'),
      firstName: firstName,
      lastName: lastName,
      role: AppRole.donor,
      email: email,
      password: password,
      contactNum: contactNum,
      isActive: true,
    );

    _db.users.add(user);
    return user;
  }

  @override
  Future<AppUser?> fetchProfile(
    String userId,
  ) async {
    return firstWhereOrNull(
      _db.users,
      (u) => u.userId == userId,
    );
  }

  /// Every user whose role is in [roles], e.g. donors for a donor picker, or
  /// staff/manager for an "administered by"/"received by" picker.
  @override
  Future<List<AppUser>> fetchUsersByRole(
    List<AppRole> roles,
  ) async {
    final list = _db.users
        .where(
          (u) => roles.contains(u.role),
        )
        .toList();

    list.sort(
      (a, b) => a.firstName.compareTo(b.firstName),
    );

    return list;
  }

  @override
  Future<List<AppUser>> fetchStaffAccounts() async {
    final list = _db.users
        .where(
          (u) => u.role == AppRole.staff,
        )
        .toList();

    list.sort((a, b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? -1 : 1;
      }

      final byFirst = a.firstName.toLowerCase().compareTo(
            b.firstName.toLowerCase(),
          );

      if (byFirst != 0) {
        return byFirst;
      }

      return a.lastName.toLowerCase().compareTo(
            b.lastName.toLowerCase(),
          );
    });

    return list;
  }

  /// Creates a Staff account in mock mode only.
  @override
  Future<AppUser> createStaffAccount({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? contactNum,
  }) async {
    final cleanEmail = email.trim();

    final exists = firstWhereOrNull(
      _db.users,
      (u) => u.email.toLowerCase() == cleanEmail.toLowerCase(),
    );

    if (exists != null) {
      throw Exception(
        'An account with this email already exists.',
      );
    }

    final user = AppUser(
      userId: newMockId('user'),
      firstName: firstName.trim(),
      lastName: lastName.trim(),
      role: AppRole.staff,
      email: cleanEmail,
      password: password,
      contactNum:
          contactNum?.trim().isEmpty ?? true ? null : contactNum!.trim(),
      isActive: true,
    );

    _db.users.add(user);
    return user;
  }

  @override
  Future<void> setStaffAccountActive({
    required String userId,
    required bool isActive,
  }) async {
    final index = _db.users.indexWhere(
      (u) => u.userId == userId && u.role == AppRole.staff,
    );

    if (index == -1) {
      throw Exception(
        'Staff account not found.',
      );
    }

    _db.users[index] = _db.users[index].copyWith(
      isActive: isActive,
    );
  }

  @override
  Future<AppUser> updateProfile({
    required String userId,
    required String firstName,
    required String lastName,
    String? contactNum,
  }) async {
    final index = _db.users.indexWhere(
      (u) => u.userId == userId,
    );

    if (index == -1) {
      throw Exception('User not found');
    }

    final updated = _db.users[index].copyWith(
      firstName: firstName,
      lastName: lastName,
      contactNum: contactNum,
    );

    _db.users[index] = updated;
    return updated;
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final index = _db.users.indexWhere(
      (u) => u.userId == userId,
    );

    if (index == -1) {
      throw Exception('User not found');
    }

    if (_db.users[index].password != currentPassword) {
      throw Exception(
        'Current password is incorrect.',
      );
    }

    _db.users[index] = _db.users[index].copyWith(
      password: newPassword,
    );
  }
}
