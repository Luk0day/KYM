import '../../../../app/database/app_database.dart' as local;
import '../../../../app/database/daos/equipments_dao.dart';
import '../../domain/entities/equipment.dart';
import '../../domain/repositories/equipment_repository.dart';

class EquipmentRepositoryImpl implements EquipmentRepository {
  EquipmentRepositoryImpl(this._dao);

  final EquipmentsDao _dao;

  @override
  Stream<List<Equipment>> watchAll() =>
      _dao.watchAll().map((rows) => rows.map(_toEntity).toList());

  @override
  Stream<List<Equipment>> watchByStore(String storeId) =>
      _dao.watchByStore(storeId).map((rows) => rows.map(_toEntity).toList());

  @override
  Stream<Equipment?> watchById(String id) =>
      _dao.watchById(id).map((row) => row == null ? null : _toEntity(row));

  @override
  Future<Equipment?> findById(String id) async {
    final row = await _dao.findById(id);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<Equipment?> findByQrToken(String qrToken) async {
    final row = await _dao.findByQrToken(qrToken);
    return row == null ? null : _toEntity(row);
  }

  Equipment _toEntity(local.Equipment row) => Equipment(
    id: row.id,
    storeId: row.storeId,
    name: row.name,
    category: row.category,
    brand: row.brand,
    model: row.model,
    serialNumber: row.serialNumber,
    qrToken: row.qrToken,
    status: row.status,
    installedAt: row.installedAt,
    notes: row.notes,
    createdAt: row.createdAt,
  );
}
