import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/equipment/domain/usecases/watch_equipment_detail.dart';
import 'package:kym/modules/equipment/presenter/utils/equipment_messages.dart';
import 'package:kym/modules/orders/domain/entities/maintenance_order.dart';

import '../../support/equipment_fakes.dart';

void main() {
  group('formatWhen', () {
    final now = DateTime(2026, 11, 17, 9);

    test('hoje, amanhã e outra data', () {
      expect(formatWhen(DateTime(2026, 11, 17, 14), now), 'Hoje, 14:00');
      expect(formatWhen(DateTime(2026, 11, 18, 9, 5), now), 'Amanhã, 09:05');
      expect(formatWhen(DateTime(2026, 11, 20, 10, 30), now), '20/11, 10:30');
      expect(formatWhen(DateTime(2026, 11, 10, 8), now), '10/11, 08:00');
    });
  });

  group('EquipmentDetail.nextPreventive', () {
    Future<DateTime?> next(List<MaintenanceOrder> orders) async {
      final usecase = WatchEquipmentDetail(
        FakeEquipmentRepository([equipmentFixture()]),
        FakeStoreRepository([storeFixture()]),
        FakeOrderRepository(orders),
      );
      return (await usecase('e1').first)!.nextPreventive;
    }

    test('pega a preventiva aberta com a data mais próxima', () async {
      expect(
        await next([
          orderFixture(id: '1', scheduledFor: DateTime(2026, 12, 1)),
          orderFixture(id: '2', scheduledFor: DateTime(2026, 11, 20)),
        ]),
        DateTime(2026, 11, 20),
      );
    });

    test('ignora corretiva, concluída e sem data', () async {
      expect(
        await next([
          orderFixture(
            id: '1',
            type: OrderType.corretiva,
            scheduledFor: DateTime(2026, 11, 20),
          ),
          orderFixture(
            id: '2',
            status: OrderStatus.concluida,
            scheduledFor: DateTime(2026, 11, 21),
          ),
          orderFixture(id: '3'),
        ]),
        isNull,
      );
    });

    test('sem ordens devolve null', () async {
      expect(await next([]), isNull);
    });
  });
}
