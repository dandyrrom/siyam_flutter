import '../mock/mock_database.dart';
import '../models/app_user.dart';

/// Mock auth: checks email/password directly against the in-memory user
/// list. There is no session/token concept -- AuthController just holds
/// onto the returned AppUser for the lifetime of the app (lost on restart).
/// This is a local dev stand-in only, not how real auth should work.
class AuthService {
  final MockDatabase _db = MockDatabase.instance;

  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final user = firstWhereOrNull(
        _db.users, (u) => u.email.toLowerCase() == email.toLowerCase());
    if (user == null || user.password != password) {
      throw Exception('Invalid email or password.');
    }
    return user;
  }

  /// Registers a new donor account.
  Future<AppUser> signUpDonor({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? contactNum,
  }) async {
    final exists = firstWhereOrNull(
        _db.users, (u) => u.email.toLowerCase() == email.toLowerCase());
    if (exists != null) {
      throw Exception('An account with this email already exists.');
    }
    final user = AppUser(
      userId: newMockId('user'),
      firstName: firstName,
      lastName: lastName,
      role: AppRole.donor,
      email: email,
      password: password,
      contactNum: contactNum,
    );
    _db.users.add(user);
    return user;
  }

  Future<AppUser?> fetchProfile(String userId) async {
    return firstWhereOrNull(_db.users, (u) => u.userId == userId);
  }

  /// Every user whose role is in [roles], e.g. donors for a donor picker, or
  /// staff/manager for an "administered by"/"received by" picker.
  Future<List<AppUser>> fetchUsersByRole(List<AppRole> roles) async {
    final list = _db.users.where((u) => roles.contains(u.role)).toList();
    list.sort((a, b) => a.firstName.compareTo(b.firstName));
    return list;
  }

  Future<AppUser> updateProfile({
    required String userId,
    required String firstName,
    required String lastName,
    String? contactNum,
  }) async {
    final index = _db.users.indexWhere((u) => u.userId == userId);
    if (index == -1) throw Exception('User not found');
    final updated = _db.users[index]
        .copyWith(firstName: firstName, lastName: lastName, contactNum: contactNum);
    _db.users[index] = updated;
    return updated;
  }

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final index = _db.users.indexWhere((u) => u.userId == userId);
    if (index == -1) throw Exception('User not found');
    if (_db.users[index].password != currentPassword) {
      throw Exception('Current password is incorrect.');
    }
    _db.users[index] = _db.users[index].copyWith(password: newPassword);
  }
}
