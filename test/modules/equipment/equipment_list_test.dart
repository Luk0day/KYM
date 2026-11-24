import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/app_database.dart';
import 'package:kym/modules/equipment/domain/usecases/watch_store_equipment.dart';
import 'package:kym/modules/equipment/infra/repositories/equipment_repository_impl.dart';
import 'package:kym/modules/equipment/presenter/controllers/equipment_list_controller.dart';
import 'package:kym/modules/equipment/presenter/widgets/equipment_list.dart';
import 'package:kym/modules/orders/infra/repositories/order_repository_impl.dart';

void main() {
  late AppDatabase db;
  late EquipmentListController controller;
  final now = DateTime(2026, 11, 17, 12);

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    controller = EquipmentListController(
      WatchStoreEquipment(
        EquipmentRepositoryImpl(db.equipmentsDao),
        OrderRepositoryImpl(db, idGenerator: () => 'id'),
        clock: () => now,
      ),
    );
  });

  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  Future<void> seed(WidgetTester t) => t.runAsync(() async {
    await db.storesDao.upsert(
      StoresCompanion.insert(id: 's1', name: 'Loja Centro', qrToken: 'qs1'),
    );
    for (final (id, name, status) in [
      ('e1', 'Ar-condicionado', EquipmentStatus.operando),
      ('e2', 'Câmara Fria', EquipmentStatus.emManutencao),
      ('e3', 'Freezer', EquipmentStatus.parado),
    ]) {
      await db.equipmentsDao.upsert(
        EquipmentsCompanion.insert(
          id: id,
          storeId: 's1',
          name: name,
          qrToken: 'q$id',
          category: const Value('Refrigeração'),
          status: Value(status),
        ),
      );
    }
    // Câmara Fria: ordem atrasada. Freezer: ordem em aberto no prazo.
    await db.maintenanceOrdersDao.upsert(
      MaintenanceOrdersCompanion.insert(
        id: 'o1',
        equipmentId: 'e2',
        storeId: 's1',
        type: OrderType.preventiva,
        scheduledFor: Value(DateTime(2026, 11, 1)),
      ),
    );
    await db.maintenanceOrdersDao.upsert(
      MaintenanceOrdersCompanion.insert(
        id: 'o2',
        equipmentId: 'e3',
        storeId: 's1',
        type: OrderType.corretiva,
        scheduledFor: Value(DateTime(2026, 12, 1)),
      ),
    );
  });

  Future<void> pumpList(
    WidgetTester t, {
    ValueChanged<String>? onSelected,
  }) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: EquipmentList(
              storeId: 's1',
              controller: controller,
              onEquipmentSelected: (e) => onSelected?.call(e.id),
            ),
          ),
        ),
      ),
    );
    // Deixa o Drift responder (acesso real ao SQLite fora do relógio falso).
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await t.pump();
  }

  testWidgets('estado vazio', (t) async {
    await pumpList(t);
    expect(
      find.text('Nenhum equipamento cadastrado nesta loja'),
      findsOneWidget,
    );
  });

  testWidgets('selo mostra o status ou o tipo da ordem aberta', (t) async {
    await seed(t);
    await pumpList(t);

    expect(find.text('Equipamentos'), findsOneWidget);
    expect(find.text('3 equipamentos'), findsOneWidget);
    // Sem ordem aberta o selo é o status; com ordem aberta é o tipo da ordem
    // e a situação fora do normal vai para a linha de baixo.
    expect(find.text('OPERANDO'), findsOneWidget);
    expect(find.text('PREVENTIVA'), findsOneWidget);
    expect(find.text('CORRETIVA'), findsOneWidget);
    expect(find.textContaining('Em manutenção'), findsOneWidget);
    expect(find.textContaining('Parado'), findsOneWidget);
  });

  testWidgets('equipamento com ordem atrasada aparece primeiro', (t) async {
    await seed(t);
    await pumpList(t);

    final first = t.getTopLeft(find.text('Câmara Fria')).dy;
    expect(first, lessThan(t.getTopLeft(find.text('Ar-condicionado')).dy));
    expect(first, lessThan(t.getTopLeft(find.text('Freezer')).dy));
  });

  testWidgets('toque abre o equipamento', (t) async {
    await seed(t);
    String? opened;
    await pumpList(t, onSelected: (id) => opened = id);

    await t.tap(find.text('Freezer'));
    expect(opened, 'e3');
  });

  testWidgets('acessibilidade: toque, rótulo e contraste', (t) async {
    final handle = t.ensureSemantics();
    await seed(t);
    await pumpList(t);

    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(t, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
