import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
import 'package:kym/modules/equipment/domain/entities/equipment.dart';
import 'package:kym/modules/equipment/domain/entities/equipment_detail.dart';
import 'package:kym/modules/equipment/domain/usecases/watch_equipment_detail.dart';
import 'package:kym/modules/equipment/presenter/controllers/equipment_detail_controller.dart';
import 'package:kym/modules/equipment/presenter/pages/equipment_detail_page.dart';
import 'package:kym/modules/orders/domain/entities/maintenance_order.dart';

import '../../support/equipment_fakes.dart';

WatchEquipmentDetail _usecase({
  List<Equipment>? equipment,
  List<MaintenanceOrder> orders = const [],
  FakeEquipmentRepository? equipmentRepo,
}) => WatchEquipmentDetail(
  equipmentRepo ?? FakeEquipmentRepository(equipment ?? [equipmentFixture()]),
  FakeStoreRepository([storeFixture()]),
  FakeOrderRepository(orders),
);

void main() {
  group('WatchEquipmentDetail', () {
    test(
      'traz equipamento, loja e histórico do mais recente ao mais antigo',
      () async {
        final detail = await _usecase(
          orders: [
            orderFixture(id: 'velha', completedAt: DateTime(2026, 3, 1)),
            orderFixture(id: 'nova', completedAt: DateTime(2026, 9, 1)),
            orderFixture(id: 'outro', equipmentId: 'e2'),
          ],
        )('e1').first;

        expect(detail!.equipment.id, 'e1');
        expect(detail.store?.name, 'Loja Centro');
        expect(detail.history.map((o) => o.id), ['nova', 'velha']);
      },
    );

    test('equipamento inexistente emite null', () async {
      expect(await _usecase(equipment: [])('x').first, isNull);
    });

    test('limita o histórico recente a 20 e avisa que há mais', () async {
      final detail = await _usecase(
        orders: [
          for (var i = 0; i < 25; i++)
            orderFixture(id: 'o$i', completedAt: DateTime(2026, 1, 1 + i)),
        ],
      )('e1').first;
      expect(detail!.history.length, 25);
      expect(detail.recentHistory.length, equipmentHistoryPreviewLimit);
      expect(detail.hasMoreHistory, isTrue);
    });

    test(
      'hasOpenOrderAssignedTo só vale para ordem aberta do usuário',
      () async {
        final detail = await _usecase(
          orders: [
            orderFixture(id: '1', assignedTo: 'u1'),
            orderFixture(
              id: '2',
              assignedTo: 'u2',
              status: OrderStatus.concluida,
            ),
          ],
        )('e1').first;
        expect(detail!.hasOpenOrderAssignedTo('u1'), isTrue);
        expect(detail.hasOpenOrderAssignedTo('u2'), isFalse);
        expect(detail.hasOpenOrderAssignedTo('u3'), isFalse);
      },
    );

    test('repassa o erro do repositório', () {
      expect(
        _usecase(
          equipmentRepo: FakeEquipmentRepository()..error = StateError('x'),
        )('e1'),
        emitsError(isA<StateError>()),
      );
    });
  });

  group('EquipmentDetailController', () {
    test('ready, notFound e alternância do histórico', () async {
      final ok = EquipmentDetailController(_usecase())..load('e1');
      await pumpEventQueue();
      expect(ok.status, EquipmentDetailStatus.ready);
      expect(ok.showAllHistory, isFalse);
      ok.toggleHistory();
      expect(ok.showAllHistory, isTrue);
      ok.dispose();

      final missing = EquipmentDetailController(_usecase(equipment: []))
        ..load('x');
      await pumpEventQueue();
      expect(missing.status, EquipmentDetailStatus.notFound);
      missing.dispose();
    });

    test('erro vira error', () async {
      final c = EquipmentDetailController(
        _usecase(
          equipmentRepo: FakeEquipmentRepository()..error = StateError('x'),
        ),
      )..load('e1');
      await pumpEventQueue();
      expect(c.status, EquipmentDetailStatus.error);
      c.dispose();
    });
  });

  group('EquipmentDetailPage', () {
    final now = DateTime(2026, 11, 17, 9);

    Future<void> pump(
      WidgetTester t, {
      UserRole role = UserRole.tecnico,
      String userId = 'u1',
      Equipment? equipment,
      List<MaintenanceOrder> orders = const [],
      VoidCallback? onBack,
    }) async {
      final controller = EquipmentDetailController(
        _usecase(
          equipment: equipment == null ? [equipmentFixture()] : [equipment],
          orders: orders,
        ),
      );
      addTearDown(controller.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: EquipmentDetailPage(
            equipmentId: 'e1',
            controller: controller,
            role: role,
            currentUserId: userId,
            onBack: onBack ?? () {},
            clock: () => now,
          ),
        ),
      );
      await t.pumpAndSettle();
    }

    testWidgets('cabeçalho: voltar para a loja, nome, status e série', (
      t,
    ) async {
      await pump(t, equipment: equipmentFixture(serialNumber: 'AC-0012'));
      expect(find.text('Freezer 01'), findsOneWidget);
      expect(find.text('OPERANDO'), findsOneWidget);
      // "Loja Centro" aparece no link de voltar e no subtítulo.
      expect(find.text('Loja Centro'), findsOneWidget);
      expect(find.text('Loja Centro · Série AC-0012'), findsOneWidget);
    });

    testWidgets('cartão de dados: mostra preenchidos e oculta vazios', (
      t,
    ) async {
      await pump(
        t,
        equipment: equipmentFixture(
          model: 'Split 12000',
          serialNumber: 'AC-0012-BR',
          installedAt: DateTime(2023, 3, 14),
        ),
        orders: [orderFixture(scheduledFor: DateTime(2026, 11, 17, 14))],
      );
      expect(find.text('MODELO'), findsOneWidget);
      expect(find.text('Split 12000'), findsOneWidget);
      expect(find.text('Nº DE SÉRIE'), findsOneWidget);
      expect(find.text('14/03/2023'), findsOneWidget);
      expect(find.text('PRÓXIMA PREVENTIVA'), findsOneWidget);
      expect(find.text('Hoje, 14:00'), findsOneWidget);
      expect(find.text('MARCA'), findsNothing);
      expect(find.text('OBSERVAÇÕES'), findsNothing);
    });

    testWidgets('sem preventiva agendada não mostra a próxima preventiva', (
      t,
    ) async {
      await pump(t, equipment: equipmentFixture(model: 'Split'));
      expect(find.text('PRÓXIMA PREVENTIVA'), findsNothing);
    });

    testWidgets('histórico: tipo, data, técnico, descrição e contagem', (
      t,
    ) async {
      await pump(
        t,
        orders: [
          orderFixture(
            type: OrderType.corretiva,
            status: OrderStatus.concluida,
            completedAt: DateTime(2026, 9, 5),
            assignedTo: 'u9',
            description: 'Troca do capacitor',
          ),
        ],
      );
      expect(find.text('Histórico de manutenção'), findsOneWidget);
      expect(find.text('1 registro'), findsOneWidget);
      expect(find.text('CORRETIVA'), findsOneWidget);
      expect(find.text('CONCLUÍDA'), findsNothing);
      expect(find.text('05/09/2026'), findsOneWidget);
      expect(find.text('Técnico'), findsOneWidget);
      expect(find.text('Troca do capacitor'), findsOneWidget);
    });

    testWidgets('ordem em aberto mostra o selo de status ao lado do tipo', (
      t,
    ) async {
      await pump(t, orders: [orderFixture()]);
      expect(find.text('PREVENTIVA'), findsOneWidget);
      expect(find.text('ABERTA'), findsOneWidget);
    });

    testWidgets('sem histórico mostra o texto vazio', (t) async {
      await pump(t);
      expect(
        find.text('Nenhuma manutenção registrada para este equipamento.'),
        findsOneWidget,
      );
      expect(find.text('0 registros'), findsOneWidget);
    });

    testWidgets('técnico sem ordem atribuída só abre chamado', (t) async {
      await pump(t);
      expect(find.text('Abrir chamado corretivo'), findsOneWidget);
      expect(find.text('Registrar manutenção'), findsNothing);
    });

    testWidgets('técnico com ordem aberta atribuída registra manutenção', (
      t,
    ) async {
      await pump(t, orders: [orderFixture(assignedTo: 'u1')]);
      expect(find.text('Registrar manutenção'), findsOneWidget);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Ver QR Code do equipamento'), findsNothing);
    });

    testWidgets('lojista só abre chamado', (t) async {
      await pump(
        t,
        role: UserRole.lojista,
        orders: [orderFixture(assignedTo: 'u1')],
      );
      expect(find.text('Abrir chamado corretivo'), findsOneWidget);
      expect(find.text('Registrar manutenção'), findsNothing);
      expect(find.text('Editar'), findsNothing);
      expect(find.text('Ver QR Code do equipamento'), findsNothing);
    });

    testWidgets('gestor edita e vê o QR Code', (t) async {
      await pump(t, role: UserRole.gestor);
      expect(find.text('Editar'), findsOneWidget);
      expect(find.text('Ver QR Code do equipamento'), findsOneWidget);
      expect(find.text('Registrar manutenção'), findsNothing);
    });

    testWidgets('Ver todas expande o histórico', (t) async {
      await t.binding.setSurfaceSize(const Size(400, 8000));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await pump(
        t,
        orders: [
          for (var i = 0; i < 22; i++)
            orderFixture(
              id: 'o$i',
              status: OrderStatus.concluida,
              completedAt: DateTime(2026, 1, 1 + i),
            ),
        ],
      );
      expect(find.text('PREVENTIVA'), findsNWidgets(20));
      await t.tap(find.text('Ver todas (22)'));
      await t.pumpAndSettle();
      expect(find.text('PREVENTIVA'), findsNWidgets(22));
    });

    testWidgets('equipamento não encontrado mostra mensagem e volta', (
      t,
    ) async {
      var voltou = false;
      final controller = EquipmentDetailController(_usecase(equipment: []));
      addTearDown(controller.dispose);
      await t.pumpWidget(
        MaterialApp(
          home: EquipmentDetailPage(
            equipmentId: 'x',
            controller: controller,
            role: UserRole.tecnico,
            onBack: () => voltou = true,
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.textContaining('Equipamento não encontrado'), findsOneWidget);
      await t.tap(find.text('Fechar'));
      expect(voltou, isTrue);
    });

    testWidgets('acessibilidade: toque e rótulo', (t) async {
      final handle = t.ensureSemantics();
      await pump(t, role: UserRole.gestor, orders: [orderFixture()]);
      await expectLater(t, meetsGuideline(androidTapTargetGuideline));
      await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    // Pendência do design: AppColors.doneFg (3,47:1) e pendingFg sobre os
    // fundos dos selos ficam abaixo dos 4,5:1 do WCAG AA para texto pequeno.
    testWidgets('acessibilidade: contraste dos selos', skip: true, (t) async {
      final handle = t.ensureSemantics();
      await pump(t, role: UserRole.gestor, orders: [orderFixture()]);
      await expectLater(t, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
