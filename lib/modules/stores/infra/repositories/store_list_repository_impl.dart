import '../../domain/entities/store_summary.dart';
import '../../domain/repositories/store_list_repository.dart';
import '../datasources/store_local_datasource.dart';
import '../models/store_model.dart';

class StoreListRepositoryImpl implements StoreListRepository {
  StoreListRepositoryImpl(this._dataSource);

  final StoreLocalDataSource _dataSource;

  /// Registros sem id ou sem nome não dá para exibir nem abrir: são ignorados.
  @override
  Stream<List<StoreSummary>> watchStores() {
    return _dataSource.watchStores().map(
      (models) => [
        for (final model in models)
          if (_isValid(model)) _toEntity(model),
      ],
    );
  }

  bool _isValid(StoreModel model) =>
      model.id.trim().isNotEmpty && model.name.trim().isNotEmpty;

  StoreSummary _toEntity(StoreModel model) {
    return StoreSummary(
      id: model.id.trim(),
      name: model.name.trim(),
      code: _blankToNull(model.code),
      address: _blankToNull(model.address),
      city: _blankToNull(model.city),
      isActive: model.active,
      openOrders: _count(model.openOrders),
      overdueOrders: _count(model.overdueOrders),
      preventiveOrders: _count(model.preventiveOrders),
      correctiveOrders: _count(model.correctiveOrders),
    );
  }

  int _count(int value) => value < 0 ? 0 : value;

  String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}
