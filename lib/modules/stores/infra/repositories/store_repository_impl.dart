import '../../../../app/database/app_database.dart' as local;
import '../../../../app/database/daos/stores_dao.dart';
import '../../domain/entities/store.dart';
import '../../domain/repositories/store_repository.dart';

class StoreRepositoryImpl implements StoreRepository {
  StoreRepositoryImpl(this._dao);

  final StoresDao _dao;

  @override
  Stream<List<Store>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_toEntity).toList());

  @override
  Stream<Store?> watchById(String id) =>
      _dao.watchById(id).map((row) => row == null ? null : _toEntity(row));

  @override
  Future<Store?> findById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<Store?> findByQrToken(String qrToken) async {
    final row = await _dao.findByQrToken(qrToken);
    return row == null ? null : _toEntity(row);
  }

  Store _toEntity(local.Store row) => Store(
    id: row.id,
    name: row.name,
    code: row.code,
    address: row.address,
    city: row.city,
    latitude: row.latitude,
    longitude: row.longitude,
    qrToken: row.qrToken,
    active: row.active,
    createdAt: row.createdAt,
  );
}
