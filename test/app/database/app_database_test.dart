// Imports relativos para o arquivo funcionar sem conhecer o nome do pacote.
// Se preferir, troque por `package:<nome_do_pacote>/app/database/...`.
// ignore_for_file: avoid_relative_lib_imports

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../lib/app/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertStore([String id = 'store-1', String qr = 'qr-store-1']) =>
      db.storesDao.upsert(
        StoresCompanion.insert(id: id, name: 'Loja $id', qrToken: qr),
      );

  Future<void> insertEquipment({
    String id = 'eq-1',
    String storeId = 'store-1',
    String qr = 'qr-eq-1',
  }) =>
      db.equipmentsDao.upsert(
        EquipmentsCompanion.insert(
          id: id,
          storeId: storeId,
          name: 'Freezer $id',
          qrToken: qr,
        ),
      );

  Future<void> insertOrder({
    String id = 'order-1',
    String equipmentId = 'eq-1',
    String storeId = 'store-1',
  }) =>
      db.maintenanceOrdersDao.upsert(
        MaintenanceOrdersCompanion.insert(
          id: id,
          equipmentId: equipmentId,
          storeId: storeId,
          type: OrderType.corretiva,
        ),
      );

  Future<void> insertPhoto({
    String id = 'photo-1',
    String orderId = 'order-1',
  }) =>
      db.photosDao.upsert(
        PhotosCompanion.insert(
          id: id,
          orderId: orderId,
          storagePath: 'orders/$orderId/$id.jpg',
        ),
      );

  Future<void> insertChain() async {
    await insertStore();
    await insertEquipment();
    await insertOrder();
    await insertPhoto();
  }

  group('criação do banco', () {
    test('cria as cinco tabelas', () async {
      final rows = await db
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = rows.map((r) => r.read<String>('name')).toSet();

      expect(
        names,
        containsAll(
          ['stores', 'equipment', 'maintenance_orders', 'photos', 'outbox'],
        ),
      );
    });

    test('habilita as chaves estrangeiras', () async {
      final row = await db.customSelect('PRAGMA foreign_keys').getSingle();

      expect(row.read<int>('foreign_keys'), 1);
    });
  });

  group('tabelas espelho', () {
    test('loja: grava, lê e aplica os valores padrão', () async {
      await insertStore();

      final store = await db.storesDao.findById('store-1');

      expect(store, isNotNull);
      expect(store!.name, 'Loja store-1');
      expect(store.active, isTrue);
      expect(store.syncedAt, isNull);
      expect(store.code, isNull);
    });

    test('equipamento: status padrão e listagem por loja', () async {
      await insertStore();
      await insertStore('store-2', 'qr-store-2');
      await insertEquipment();
      await insertEquipment(id: 'eq-2', storeId: 'store-2', qr: 'qr-eq-2');

      final equipment = await db.equipmentsDao.findById('eq-1');
      final fromStore1 = await db.equipmentsDao.listByStore('store-1');

      expect(equipment!.status, 'operando');
      expect(fromStore1.map((e) => e.id), ['eq-1']);
    });

    test('ordem: status padrão e listagem por loja e por equipamento',
        () async {
      await insertStore();
      await insertEquipment();
      await insertOrder();

      final order = await db.maintenanceOrdersDao.findById('order-1');

      expect(order!.status, OrderStatus.aberta);
      expect(order.type, OrderType.corretiva);
      expect(
        (await db.maintenanceOrdersDao.listByStore('store-1')).length,
        1,
      );
      expect(
        (await db.maintenanceOrdersDao.listByEquipment('eq-1')).length,
        1,
      );
    });

    test('ordem: o status é gravado com o texto do Postgres', () async {
      await insertStore();
      await insertEquipment();
      await db.maintenanceOrdersDao.upsert(
        MaintenanceOrdersCompanion.insert(
          id: 'order-1',
          equipmentId: 'eq-1',
          storeId: 'store-1',
          type: OrderType.preventiva,
          status: const Value(OrderStatus.emAndamento),
        ),
      );

      final raw = await db
          .customSelect('SELECT status, type FROM maintenance_orders')
          .getSingle();
      final order = await db.maintenanceOrdersDao.findById('order-1');

      expect(raw.read<String>('status'), 'em_andamento');
      expect(raw.read<String>('type'), 'preventiva');
      expect(order!.status, OrderStatus.emAndamento);
    });

    test('foto: guarda o caminho local e começa como pendente', () async {
      await insertStore();
      await insertEquipment();
      await insertOrder();
      await db.photosDao.upsert(
        PhotosCompanion.insert(
          id: 'photo-1',
          orderId: 'order-1',
          storagePath: 'orders/order-1/photo-1.jpg',
          localPath: const Value('/data/user/0/app/cache/photo-1.jpg'),
        ),
      );

      final photo = await db.photosDao.findById('photo-1');

      expect(photo!.localPath, '/data/user/0/app/cache/photo-1.jpg');
      expect(photo.kind, PhotoKind.depois);
      expect(photo.uploadStatus, PhotoUploadStatus.pending);
    });

    test('foto: lista por ordem e atualiza o status de envio', () async {
      await insertChain();

      await db.photosDao.markUploadStatus(
        'photo-1',
        PhotoUploadStatus.uploaded,
      );

      expect((await db.photosDao.listByOrder('order-1')).length, 1);
      expect(
        (await db.photosDao.listByUploadStatus(PhotoUploadStatus.uploaded))
            .length,
        1,
      );
      expect(
        await db.photosDao.listByUploadStatus(PhotoUploadStatus.pending),
        isEmpty,
      );
    });

    test('upsert atualiza o registro existente em vez de duplicar', () async {
      await insertStore();
      await db.storesDao.upsert(
        StoresCompanion.insert(
          id: 'store-1',
          name: 'Nome novo',
          qrToken: 'qr-store-1',
        ),
      );

      final all = await db.storesDao.listAll();

      expect(all.length, 1);
      expect(all.single.name, 'Nome novo');
    });
  });

  group('relações e restrições', () {
    test('equipamento sem loja existente é rejeitado', () async {
      await expectLater(
        insertEquipment(storeId: 'loja-inexistente'),
        throwsA(anything),
      );
    });

    test('ordem sem equipamento existente é rejeitada', () async {
      await insertStore();

      await expectLater(
        insertOrder(equipmentId: 'eq-inexistente'),
        throwsA(anything),
      );
    });

    test('foto sem ordem existente é rejeitada', () async {
      await expectLater(
        insertPhoto(orderId: 'order-inexistente'),
        throwsA(anything),
      );
    });

    test('apagar a loja apaga equipamentos, ordens e fotos', () async {
      await insertChain();

      await (db.delete(db.stores)..where((s) => s.id.equals('store-1'))).go();

      expect(await db.equipmentsDao.listAll(), isEmpty);
      expect(await db.maintenanceOrdersDao.listAll(), isEmpty);
      expect(await db.photosDao.listByOrder('order-1'), isEmpty);
    });

    test('qr_token repetido é rejeitado', () async {
      await insertStore();
      await insertEquipment();

      await expectLater(
        insertEquipment(id: 'eq-2', qr: 'qr-eq-1'),
        throwsA(anything),
      );
    });
  });

  group('outbox', () {
    test('enfileira com valores padrão e payload em JSON', () async {
      final id = await db.outboxDao.enqueue(
        operation: OutboxOperation.insert,
        entity: OutboxEntity.maintenanceOrder,
        entityId: 'order-1',
        payload: {'status': 'aberta', 'type': 'corretiva'},
      );

      final entry = await db.outboxDao.findById(id);

      expect(entry!.status, OutboxStatus.pending);
      expect(entry.attempts, 0);
      expect(entry.lastError, isNull);
      expect(entry.operation, OutboxOperation.insert);
      expect(entry.entity, OutboxEntity.maintenanceOrder);
      expect(jsonDecode(entry.payload), {'status': 'aberta', 'type': 'corretiva'});
    });

    test('lista os pendentes na ordem de criação', () async {
      final first = await db.outboxDao.enqueue(
        operation: OutboxOperation.insert,
        entity: OutboxEntity.photo,
        entityId: 'photo-1',
        payload: {},
      );
      final second = await db.outboxDao.enqueue(
        operation: OutboxOperation.update,
        entity: OutboxEntity.maintenanceOrder,
        entityId: 'order-1',
        payload: {},
      );
      final third = await db.outboxDao.enqueue(
        operation: OutboxOperation.delete,
        entity: OutboxEntity.photo,
        entityId: 'photo-2',
        payload: {},
      );

      final pending = await db.outboxDao.listPending();

      expect(pending.map((e) => e.id), [first, second, third]);
    });

    test('muda o status e tira o item da lista de pendentes', () async {
      final id = await db.outboxDao.enqueue(
        operation: OutboxOperation.insert,
        entity: OutboxEntity.photo,
        entityId: 'photo-1',
        payload: {},
      );

      await db.outboxDao.markProcessing(id);
      expect((await db.outboxDao.findById(id))!.status,
          OutboxStatus.processing);
      expect(await db.outboxDao.listPending(), isEmpty);

      await db.outboxDao.markDone(id);
      expect((await db.outboxDao.findById(id))!.status, OutboxStatus.done);
    });

    test('falha guarda o erro e incrementa as tentativas', () async {
      final id = await db.outboxDao.enqueue(
        operation: OutboxOperation.insert,
        entity: OutboxEntity.photo,
        entityId: 'photo-1',
        payload: {},
      );

      await db.outboxDao.markFailed(id, 'sem conexão');
      await db.outboxDao.markFailed(id, 'timeout');

      final entry = await db.outboxDao.findById(id);

      expect(entry!.status, OutboxStatus.failed);
      expect(entry.attempts, 2);
      expect(entry.lastError, 'timeout');
    });
  });
}
