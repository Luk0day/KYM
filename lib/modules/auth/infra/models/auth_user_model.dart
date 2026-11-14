class AuthUserModel {
  const AuthUserModel({
    required this.id,
    required this.email,
    required this.role,
    this.displayName,
  });

  final String id;
  final String email;
  final String? displayName;

  final String role;
}
