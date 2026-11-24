import '../entities/agenda_item.dart';
import '../entities/maintenance_order.dart';

/// Lê sempre do banco local; toda gravação vai para o banco local e para a
/// outbox na mesma transação.
abstract class OrderRepository {
  /// Mais recentes primeiro.
  Stream<List<MaintenanceOrder>> watchAll();

  Stream<List<MaintenanceOrder>> watchByStore(String storeId);

  Stream<List<MaintenanceOrder>> watchByEquipment(String equipmentId);

  Stream<MaintenanceOrder?> watchById(String id);

  /// Ordens não canceladas com o nome do equipamento e da loja. Com
  /// [assignedTo], só as atribuídas a essa pessoa.
  Stream<List<AgendaItem>> watchAgenda({String? assignedTo});

  Future<MaintenanceOrder?> findById(String id);

  /// Cria a ordem com id (uuid v4) gerado no cliente. Grava no banco local e
  /// enfileira o envio juntos: se um falhar, nenhum dos dois fica.
  Future<MaintenanceOrder> create(NewOrder order);
}
