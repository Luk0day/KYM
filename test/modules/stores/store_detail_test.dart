import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/equipment/domain/usecases/watch_store_equipment.dart';
import 'package:kym/modules/equipment/presenter/controllers/equipment_list_controller.dart';
import 'package:kym/modules/stores/domain/entities/store.dart';
import 'package:kym/modules/stores/domain/repositories/store_repository.dart';
import 'package:kym/modules/stores/domain/usecases/watch_store_detail.dart';
import 'package:kym/modules/stores/presenter/controllers/store_detail_controller.dart';
import 'package:kym/modules/stores/presenter/pages/store_detail_page.dart';

import '../../support/equipment_fakes.dart';

class _FakeStoreRepository implements StoreRepository {
  _FakeStoreRepository(this._stores, {this.fail = false});

  final List<Store> _stores;
  final bool fail;

  @override
  Stream<Store?> watchById(String id) => fail
      ? Stream.error(StateError('falhou'))
      : Stream.value(_stores.where((s) => s.id == id).firstOrNull);

  @override
  Stream<List<Store>> watchAll() => Stream.value(_stores);

  @override
  Future<Store?> findById(String id) async =>
      _stores.where((s) => s.id == id).firstOrNull;

  @override
  Future<Store?> findByQrToken(String qrToken) async => null;
}

Store _store({double? lat, double? lng, bool active = true}) => Store(
  id: 's1',
  name: 'Loja Centro',
  code: 'L001',
  address: 'Rua da Aurora, 100',
  city: 'Recife',
  latitude: lat,
  longitude: lng,
  qrToken: 'qr',
  active: active,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  group('StoreDetailController', () {
    StoreDetailController build(_FakeStoreRepository repo) =>
        StoreDetailController(WatchStoreDetail(repo));

    test('carrega a loja', () async {
      final c = build(_FakeStoreRepository([_store()]))..load('s1');
      await pumpEventQueue();
      expect(c.status, StoreDetailStatus.ready);
      expect(c.store?.name, 'Loja Centro');
      c.dispose();
    });

    test('id inexistente vira notFound', () async {
      final c = build(_FakeStoreRepository([]))..load('x');
      await pumpEventQueue();
      expect(c.status, StoreDetailStatus.notFound);
      c.dispose();
    });

    test('falha no banco vira error e retry tenta de novo', () async {
      final c = build(_FakeStoreRepository([], fail: true))..load('s1');
      await pumpEventQueue();
      expect(c.status, StoreDetailStatus.error);
      c.retry();
      expect(c.status, StoreDetailStatus.loading);
      await pumpEventQueue();
      expect(c.status, StoreDetailStatus.error);
      c.dispose();
    });
  });

  group('StoreDetailPage', () {
    Future<void> pump(
      WidgetTester t, {
      required List<Store> stores,
      bool canCheckIn = false,
      VoidCallback? onBack,
    }) async {
      final controller = StoreDetailController(
        WatchStoreDetail(_FakeStoreRepository(stores)),
      );
      final equipmentController = EquipmentListController(
        WatchStoreEquipment(
          FakeEquipmentRepository([equipmentFixture()]),
          FakeOrderRepository(),
        ),
      );
      addTearDown(controller.dispose);
      addTearDown(equipmentController.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: StoreDetailPage(
            storeId: 's1',
            controller: controller,
            equipmentController: equipmentController,
            canCheckIn: canCheckIn,
            onBack: onBack ?? () {},
            onEquipmentSelected: (_) {},
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('sem coordenadas mostra o quadro de endereço', (t) async {
      await pump(t, stores: [_store()]);
      expect(find.text('Mapa indisponível sem internet'), findsOneWidget);
      expect(find.text('Rua da Aurora, 100 · Recife'), findsOneWidget);
      expect(find.text('Loja Centro'), findsOneWidget);
      expect(find.text('Código L001'), findsOneWidget);
    });

    testWidgets('lista os equipamentos da loja', (t) async {
      await pump(t, stores: [_store()]);
      expect(find.text('Freezer 01'), findsOneWidget);
    });

    testWidgets('técnico vê o check-in e lojista não', (t) async {
      await pump(t, stores: [_store()], canCheckIn: true);
      expect(find.text('Fazer check-in'), findsOneWidget);
    });

    testWidgets('sem permissão não mostra o check-in', (t) async {
      await pump(t, stores: [_store()]);
      expect(find.text('Fazer check-in'), findsNothing);
    });

    testWidgets('loja inativa recebe o selo', (t) async {
      await pump(t, stores: [_store(active: false)]);
      expect(find.text('INATIVA'), findsOneWidget);
    });

    testWidgets('loja não encontrada mostra mensagem e volta', (t) async {
      var voltou = false;
      await pump(t, stores: [], onBack: () => voltou = true);
      expect(find.textContaining('Loja não encontrada'), findsOneWidget);
      await t.tap(find.text('Voltar'));
      expect(voltou, isTrue);
    });

    testWidgets('acessibilidade: toque, rótulo e contraste', (t) async {
      final handle = t.ensureSemantics();
      await pump(t, stores: [_store()], canCheckIn: true);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
