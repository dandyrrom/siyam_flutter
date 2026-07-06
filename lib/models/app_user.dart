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
class AppUser {
  final String userId; // uuid, references auth.users(id)
  final String firstName;
  final String lastName;
  final AppRole role;
  final String email;
  final String? contactNum;

  const AppUser({
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.email,
    this.contactNum,
  });

  String get fullName => '$firstName $lastName';

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return (f + l).toUpperCase();
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      userId: map['userid'] as String,
      firstName: map['userfname'] as String? ?? '',
      lastName: map['userlname'] as String? ?? '',
      role: appRoleFromString(map['role'] as String? ?? 'donor'),
      email: map['email'] as String? ?? '',
      contactNum: map['contactnum'] as String?,
    );
  }
}
