enum AuthFailureType {
  invalidCredentials,
  profileNotFound,
  invalidProfile,
  accessDenied,
  network,
  rateLimited,

  /// O usuário fechou a seleção de conta do Google. Não é um erro a exibir.
  cancelled,
  unexpected,
}

class AuthFailure implements Exception {
  const AuthFailure(this.type);

  final AuthFailureType type;

  @override
  String toString() => 'AuthFailure: ${type.name}';
}
