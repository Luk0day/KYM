import 'package:drift/drift.dart';

import '../app_database.dart';

/// Popula o banco local no modo fake (`USE_FAKE_AUTH=true`), onde não há
/// Supabase: 3 lojas, 10 equipamentos e algumas ordens, ligadas aos ids do
/// `FakeAuthDataSource` (`fake-tecnico-id`, `fake-gestor-id`,
/// `fake-lojista-id`).
class FakeDataSeeder {
  FakeDataSeeder(this._db);

  final AppDatabase _db;

  static const tecnicoId = 'fake-tecnico-id';
  static const gestorId = 'fake-gestor-id';
  static const lojistaId = 'fake-lojista-id';

  /// Só insere se o banco estiver sem lojas, então é seguro chamar em toda
  /// abertura do app. Devolve `true` se populou.
  Future<bool> seedIfEmpty() async {
    if ((await _db.storesDao.listAll()).isNotEmpty) return false;

    // Não usa a outbox: são dados de demonstração e não vão para a nuvem.
    await _db.transaction(() async {
      for (final store in _stores) {
        await _db.storesDao.upsert(store);
      }
      for (final equipment in _equipments) {
        await _db.equipmentsDao.upsert(equipment);
      }
      for (final order in _orders) {
        await _db.maintenanceOrdersDao.upsert(order);
      }
    });
    return true;
  }

  static const _centro = '00000000-0000-4000-8000-0000000000a1';
  static const _boaViagem = '00000000-0000-4000-8000-0000000000a2';
  static const _shopping = '00000000-0000-4000-8000-0000000000a3';

  static final _stores = [
    StoresCompanion.insert(
      id: _centro,
      name: 'Loja Centro',
      code: const Value('LJ-001'),
      address: const Value('Av. Guararapes, 120'),
      city: const Value('Recife'),
      latitude: const Value(-8.0631),
      longitude: const Value(-34.8711),
      qrToken: '00000000-0000-4000-8000-0000000001a1',
    ),
    StoresCompanion.insert(
      id: _boaViagem,
      name: 'Loja Boa Viagem',
      code: const Value('LJ-002'),
      address: const Value('Av. Boa Viagem, 3500'),
      city: const Value('Recife'),
      latitude: const Value(-8.1181),
      longitude: const Value(-34.8999),
      qrToken: '00000000-0000-4000-8000-0000000001a2',
    ),
    StoresCompanion.insert(
      id: _shopping,
      name: 'Loja Shopping',
      code: const Value('LJ-003'),
      address: const Value('Rua Padre Carapuceiro, 777'),
      city: const Value('Recife'),
      // Sem coordenadas, para exercitar o quadro de endereço sem mapa.
      qrToken: '00000000-0000-4000-8000-0000000001a3',
    ),
  ];

  static EquipmentsCompanion _eq(
    int n,
    String storeId,
    String name,
    String category, {
    String? brand,
    String? model,
    String status = 'operando',
  }) => EquipmentsCompanion.insert(
    id: '00000000-0000-4000-8000-0000000000e${n.toRadixString(16)}',
    storeId: storeId,
    name: name,
    category: Value(category),
    brand: Value(brand),
    model: Value(model),
    status: Value(status),
    qrToken: '00000000-0000-4000-8000-0000000001e${n.toRadixString(16)}',
  );

  static final _equipments = [
    _eq(
      1,
      _centro,
      'Ar-condicionado Salão',
      'Climatização',
      brand: 'Carrier',
      model: 'Split 24000',
    ),
    _eq(
      2,
      _centro,
      'Câmara Fria',
      'Refrigeração',
      brand: 'Elber',
      model: 'CF-300',
      status: 'em_manutencao',
    ),
    _eq(
      3,
      _centro,
      'Balcão Refrigerado',
      'Refrigeração',
      brand: 'Gelopar',
      model: 'GBR-120',
    ),
    _eq(4, _centro, 'Nobreak', 'Elétrica', brand: 'SMS', model: 'Manager III'),
    _eq(
      5,
      _boaViagem,
      'Ar-condicionado Vitrine',
      'Climatização',
      brand: 'Gree',
      model: 'Eco Garden',
    ),
    _eq(
      6,
      _boaViagem,
      'Freezer Horizontal',
      'Refrigeração',
      brand: 'Metalfrio',
      model: 'DA550',
      status: 'parado',
    ),
    _eq(
      7,
      _boaViagem,
      'Gerador',
      'Elétrica',
      brand: 'Branco',
      model: 'B4T-8000',
    ),
    _eq(
      8,
      _shopping,
      'Ar-condicionado Loja',
      'Climatização',
      brand: 'LG',
      model: 'Dual Inverter',
    ),
    _eq(
      9,
      _shopping,
      'Expositor Refrigerado',
      'Refrigeração',
      brand: 'Gelopar',
      model: 'GPTU-120',
    ),
    _eq(10, _shopping, 'Exaustor', 'Ventilação', brand: 'Ventisol'),
  ];

  static final _orders = [
    // Chamado corretivo aberto pelo lojista.
    MaintenanceOrdersCompanion.insert(
      id: '00000000-0000-4000-8000-0000000000f1',
      equipmentId: '00000000-0000-4000-8000-0000000000e2',
      storeId: _centro,
      type: OrderType.corretiva,
      description: const Value('Câmara fria não está mantendo a temperatura.'),
      openedBy: const Value(lojistaId),
    ),
    // Preventiva agendada para o técnico.
    MaintenanceOrdersCompanion.insert(
      id: '00000000-0000-4000-8000-0000000000f2',
      equipmentId: '00000000-0000-4000-8000-0000000000e5',
      storeId: _boaViagem,
      type: OrderType.preventiva,
      status: Value(OrderStatus.agendada),
      description: const Value('Limpeza de filtros e checagem de gás.'),
      scheduledFor: Value(DateTime(2026, 11, 20, 9)),
      openedBy: const Value(gestorId),
      assignedTo: const Value(tecnicoId),
    ),
    // Preventiva já concluída (aparece no histórico).
    MaintenanceOrdersCompanion.insert(
      id: '00000000-0000-4000-8000-0000000000f3',
      equipmentId: '00000000-0000-4000-8000-0000000000e1',
      storeId: _centro,
      type: OrderType.preventiva,
      status: Value(OrderStatus.concluida),
      description: const Value('Manutenção preventiva trimestral.'),
      scheduledFor: Value(DateTime(2026, 10, 15, 14)),
      openedBy: const Value(gestorId),
      assignedTo: const Value(tecnicoId),
      completedAt: Value(DateTime(2026, 10, 15, 15, 30)),
    ),
  ];
}
