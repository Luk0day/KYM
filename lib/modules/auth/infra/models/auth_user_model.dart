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

  /// Papel recebido da fonte de dados.
  ///
  /// Valores esperados:
  /// - technician
  /// - manager
  /// - lojista
  final String role;
}
