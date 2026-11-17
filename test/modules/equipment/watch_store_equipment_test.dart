import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/database/enums.dart';
import 'package:kym/modules/equipment/domain/usecases/watch_store_equipment.dart';
import 'package:kym/modules/orders/domain/entities/maintenance_order.dart'
    as orders;

import '../../support/equipment_fakes.dart';

void main() {
  group('EquipmentStatusConverter', () {
    const converter = EquipmentStatusConverter();

    test('converte os três valores do Postgres nos dois sentidos', () {
      for (final status in EquipmentStatus.values) {
        expect(converter.toSql(status), status.dbValue);
        expect(converter.fromSql(status.dbValue), status);
      }
      expect(converter.fromSql('em_manutencao'), EquipmentStatus.emManutencao);
    });

    test('valor desconhecido cai em operando sem quebrar', () {
      expect(converter.fromSql('valor_novo'), EquipmentStatus.operando);
      expect(converter.fromSql(''), EquipmentStatus.operando);
    });
  });

  group('WatchStoreEquipment', () {
    final now = DateTime(2026, 11, 17, 12);

    WatchStoreEquipment build(
      FakeEquipmentRepository eq,
      FakeOrderRepository ord,
    ) => WatchStoreEquipment(eq, ord, clock: () => now);

    test('conta ordens abertas e atrasadas por equipamento', () async {
      final usecase = build(
        FakeEquipmentRepository([
          equipmentFixture(id: 'a', name: 'A'),
          equipmentFixture(id: 'b', name: 'B'),
        ]),
        FakeOrderRepository([
          orderFixture(
            id: '1',
            equipmentId: 'a',
            scheduledFor: DateTime(2026, 11, 1),
          ),
          orderFixture(
            id: '2',
            equipmentId: 'a',
            scheduledFor: DateTime(2026, 12, 1),
          ),
          orderFixture(
            id: '3',
            equipmentId: 'a',
            status: orders.OrderStatus.concluida,
            scheduledFor: DateTime(2026, 10, 1),
          ),
        ]),
      );

      final items = await usecase('s1').first;
      final a = items.firstWhere((i) => i.equipment.id == 'a');
      final b = items.firstWhere((i) => i.equipment.id == 'b');
      expect(a.openOrders, 2);
      expect(a.overdueOrders, 1);
      expect(b.hasOpenOrder, isFalse);
    });

    test('atrasados primeiro, depois por nome', () async {
      final usecase = build(
        FakeEquipmentRepository([
          equipmentFixture(id: 'a', name: 'Alfa'),
          equipmentFixture(id: 'b', name: 'Beta'),
          equipmentFixture(id: 'c', name: 'Charlie'),
        ]),
        FakeOrderRepository([
          orderFixture(
            id: '1',
            equipmentId: 'c',
            scheduledFor: DateTime(2026, 11, 1),
          ),
        ]),
      );

      final names = (await usecase('s1').first).map((i) => i.equipment.name);
      expect(names, ['Charlie', 'Alfa', 'Beta']);
    });

    test('só traz equipamentos da loja pedida', () async {
      final usecase = build(
        FakeEquipmentRepository([
          equipmentFixture(id: 'a'),
          equipmentFixture(id: 'b', storeId: 's2'),
        ]),
        FakeOrderRepository(),
      );
      expect((await usecase('s1').first).map((i) => i.equipment.id), ['a']);
    });

    test('repassa o erro do repositório', () {
      final usecase = build(
        FakeEquipmentRepository()..error = StateError('falhou'),
        FakeOrderRepository(),
      );
      expect(usecase('s1'), emitsError(isA<StateError>()));
    });

    test('atualiza quando o banco muda', () async {
      final eq = FakeEquipmentRepository([equipmentFixture(id: 'a')]);
      final usecase = build(eq, FakeOrderRepository());
      final emissions = <int>[];
      final sub = usecase('s1').listen((l) => emissions.add(l.length));
      await pumpEventQueue();
      eq.emit([equipmentFixture(id: 'a'), equipmentFixture(id: 'b')]);
      await pumpEventQueue();
      await sub.cancel();
      expect(emissions, [1, 2]);
    });
  });
}
