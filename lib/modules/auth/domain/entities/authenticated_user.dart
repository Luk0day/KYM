import 'user_role.dart';

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
  });

  final String id;
  final String email;
  final String? displayName;
  final UserRole role;
}
