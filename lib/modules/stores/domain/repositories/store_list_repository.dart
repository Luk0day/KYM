import '../entities/store_summary.dart';

abstract interface class StoreListRepository {
  /// Lojas permitidas ao usuário (a RLS já filtra o que foi baixado), lidas do
  /// banco local, com a contagem de ordens em aberto de cada uma. Emite de novo
  /// sempre que o banco muda e funciona sem internet.
  Stream<List<StoreSummary>> watchStores();
}
