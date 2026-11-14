import '../entities/store.dart';

/// Lê sempre do banco local; a sincronização com a nuvem acontece por trás.
abstract class StoreRepository {
  /// Todas as lojas por nome. Reemite quando a sincronização trouxer dados.
  Stream<List<Store>> watchAll();

  /// `null` se a loja não existe (ou o acesso foi removido).
  Stream<Store?> watchById(String id);

  Future<Store?> findById(String id);

  /// Usado pelo leitor de QR.
  Future<Store?> findByQrToken(String qrToken);
}
