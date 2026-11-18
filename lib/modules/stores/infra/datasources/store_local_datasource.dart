import '../models/store_model.dart';

abstract interface class StoreLocalDataSource {
  /// Todas as lojas do banco local, cada uma com a contagem de ordens em
  /// aberto, calculada numa única consulta.
  Stream<List<StoreModel>> watchStores();
}
