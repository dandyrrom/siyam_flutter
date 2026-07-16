/// Mirrors the Postgres `user_role` enum: 'staff', 'manager', 'donor'.
enum AppRole { staff, manager, donor }

AppRole appRoleFromString(String value) {
  switch (value) {
    case 'manager':
      return AppRole.manager;
    case 'staff':
      return AppRole.staff;
    case 'donor':
    default:
      return AppRole.donor;
  }
}

String appRoleToString(AppRole role) => role.name;

/// Mirrors a row in the public.users table.
///
/// [password] is only present because the mock auth layer
/// (services/auth_service.dart) checks it directly against the in-memory user
/// list -- there's no real backend/session concept behind it. Never treat
/// this as how a real auth system should work.
class AppUser {
  final String userId;
  final String firstName;
  final String lastName;
  final AppRole role;
  final String email;
  final String password;
  final String? contactNum;

  const AppUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.email,
    required this.password,
    this.contactNum,
  });

  String get fullName => '$firstName $lastName';

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return (f + l).toUpperCase();
  }

  AppUser copyWith({
    String? firstName,
    String? lastName,
    String? password,
    String? contactNum,
  }) {
    return AppUser(
      userId: userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      role: role,
      email: email,
      password: password ?? this.password,
      contactNum: contactNum ?? this.contactNum,
    );
  }
}
