import '../../../auth/domain/entities/user_role.dart';
import '../../../orders/domain/entities/agenda_item.dart';
import '../../../orders/domain/repositories/order_repository.dart';

class WatchAgenda {
  WatchAgenda(this._repository);

  final OrderRepository _repository;

  /// Técnico vê só as ordens atribuídas a ele; gestor vê todas.
  Stream<List<AgendaItem>> call({
    required String userId,
    required UserRole role,
  }) => _repository.watchAgenda(
    assignedTo: role == UserRole.gestor ? null : userId,
  );
}
