import '../../domain/entities/user_role.dart';

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
    UserRole.tecnico => 'Técnico',
    UserRole.gestor => 'Gestor',
    UserRole.lojista => 'Lojista',
  };
}
