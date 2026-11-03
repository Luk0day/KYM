import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables.dart';

part 'photos_dao.g.dart';

@DriftAccessor(tables: [Photos])
class PhotosDao extends DatabaseAccessor<AppDatabase> with _$PhotosDaoMixin {
  PhotosDao(super.db);

  Future<void> upsert(Insertable<Photo> photo) =>
      into(photos).insertOnConflictUpdate(photo);

  Future<Photo?> findById(String id) =>
      (select(photos)..where((p) => p.id.equals(id))).getSingleOrNull();

  Future<List<Photo>> listByOrder(String orderId) => (select(photos)
        ..where((p) => p.orderId.equals(orderId))
        ..orderBy([(p) => OrderingTerm.asc(p.takenAt)]))
      .get();

  Future<List<Photo>> listByUploadStatus(PhotoUploadStatus status) =>
      (select(photos)..where((p) => p.uploadStatus.equalsValue(status))).get();

  Future<void> markUploadStatus(String id, PhotoUploadStatus status) =>
      (update(photos)..where((p) => p.id.equals(id)))
          .write(PhotosCompanion(uploadStatus: Value(status)));
}
