enum AuthFailureType {
  invalidCredentials,
  profileNotFound,
  invalidProfile,
  accessDenied,
  network,
  rateLimited,
  unexpected,
}

class AuthFailure implements Exception {
  const AuthFailure(this.type);

  final AuthFailureType type;

  @override
  String toString() => 'AuthFailure: ${type.name}';
}
