import '../entities/store.dart';
import '../repositories/store_repository.dart';

/// Observa uma loja pelo id, sempre do banco local. Emite `null` se a loja
/// não existe ou o acesso foi removido.
class WatchStoreDetail {
  WatchStoreDetail(this._repository);

  final StoreRepository _repository;

  Stream<Store?> call(String id) => _repository.watchById(id);
}
