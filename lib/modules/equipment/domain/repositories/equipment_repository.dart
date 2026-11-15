import '../entities/equipment.dart';

/// Lê sempre do banco local; a sincronização com a nuvem acontece por trás.
abstract class EquipmentRepository {
  Stream<List<Equipment>> watchAll();

  /// Equipamentos da loja, por nome.
  Stream<List<Equipment>> watchByStore(String storeId);

  Stream<Equipment?> watchById(String id);

  Future<Equipment?> findById(String id);

  /// Usado pelo leitor de QR.
  Future<Equipment?> findByQrToken(String qrToken);
}
