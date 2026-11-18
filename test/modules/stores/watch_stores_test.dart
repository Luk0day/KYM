import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/stores/domain/entities/store_filter.dart';
import 'package:kym/modules/stores/domain/entities/store_summary.dart';
import 'package:kym/modules/stores/domain/repositories/store_list_repository.dart';
import 'package:kym/modules/stores/domain/usecases/watch_stores.dart';
import 'package:kym/modules/stores/domain/utils/text_normalizer.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/store_fakes.dart';

class MockStoreListRepository extends Mock implements StoreListRepository {}

void main() {
  late FakeStoreListRepository repository;
  late WatchStores watchStores;

  setUp(() {
    repository = FakeStoreListRepository(sampleStores);
    watchStores = WatchStores(repository);
  });

  tearDown(() => repository.close());

  Future<List<String>> idsFor({
    StoreFilter filter = const StoreFilter(),
    bool includeInactive = false,
  }) async {
    final result = await watchStores(
      filter: filter,
      includeInactive: includeInactive,
    ).first;
    return result.items.map((s) => s.id).toList();
  }

  group('TextNormalizer', () {
    test('tira acentos, maiúsculas e espaços extras', () {
      expect(TextNormalizer.normalize('  ÁGUA   Fria Ç '), 'agua fria c');
    });
  });

  group('visibilidade', () {
    test('esconde lojas inativas por padrão', () async {
      expect(await idsFor(), ['s2', 's1']);
    });

    test('gestor vê as inativas', () async {
      expect(await idsFor(includeInactive: true), ['s3', 's2', 's1']);
    });

    test('totalVisible ignora a busca e o filtro', () async {
      final result = await watchStores(filter: const StoreFilter(query: 'zzz'))
          .first;

      expect(result.items, isEmpty);
      expect(result.totalVisible, 2);
    });

    test('lista vazia vira resultado vazio', () async {
      final result = await WatchStores(FakeStoreListRepository()).call().first;

      expect(result.items, isEmpty);
      expect(result.totalVisible, 0);
    });
  });

  group('ordem', () {
    test('alfabética sem considerar acentos e maiúsculas', () async {
      repository.emit(const [
        StoreSummary(id: 'a', name: 'zebra'),
        StoreSummary(id: 'b', name: 'Água Viva'),
        StoreSummary(id: 'c', name: 'Bom Preço'),
      ]);

      final result = await watchStores().first;

      expect(result.items.map((s) => s.id), ['b', 'c', 'a']);
    });
  });

  group('busca', () {
    test('por nome, sem acento e sem diferenciar maiúsculas', () async {
      expect(await idsFor(filter: const StoreFilter(query: 'PAO de acucar')), [
        's1',
      ]);
    });

    test('acento digitado casa com texto sem acento', () async {
      expect(await idsFor(filter: const StoreFilter(query: 'água')), ['s2']);
    });

    test('por código', () async {
      expect(await idsFor(filter: const StoreFilter(query: 'l002')), ['s2']);
    });

    test('por cidade', () async {
      expect(await idsFor(filter: const StoreFilter(query: 'olinda')), ['s2']);
    });

    test('por endereço', () async {
      expect(await idsFor(filter: const StoreFilter(query: 'matriz')), ['s2']);
    });

    test('termo só com espaços não filtra', () async {
      expect(await idsFor(filter: const StoreFilter(query: '   ')), [
        's2',
        's1',
      ]);
    });
  });

  group('abas de filtro', () {
    const withOverdue = [
      StoreSummary(
        id: 'a',
        name: 'A',
        openOrders: 3,
        overdueOrders: 2,
        preventiveOrders: 2,
        correctiveOrders: 1,
      ),
      StoreSummary(id: 'b', name: 'B', openOrders: 1, correctiveOrders: 1),
      StoreSummary(id: 'c', name: 'C', openOrders: 1, preventiveOrders: 1),
      StoreSummary(id: 'd', name: 'D'),
    ];

    Future<List<String>> idsOf(StoreFilterKind kind) async {
      repository.emit(withOverdue);
      final result = await watchStores(filter: StoreFilter(kind: kind)).first;
      return result.items.map((s) => s.id).toList();
    }

    test('todas', () async {
      expect(await idsOf(StoreFilterKind.todas), ['a', 'b', 'c', 'd']);
    });

    test('com atrasadas', () async {
      expect(await idsOf(StoreFilterKind.comAtrasadas), ['a']);
    });

    test('preventivas', () async {
      expect(await idsOf(StoreFilterKind.preventivas), ['a', 'c']);
    });

    test('corretivas', () async {
      expect(await idsOf(StoreFilterKind.corretivas), ['a', 'b']);
    });

    test('combina aba e busca', () async {
      repository.emit(withOverdue);

      final result = await watchStores(
        filter: const StoreFilter(
          query: 'c',
          kind: StoreFilterKind.preventivas,
        ),
      ).first;

      expect(result.items.map((s) => s.id), ['c']);
    });
  });

  group('StoreFilter', () {
    test('copyWith troca só o que foi pedido', () {
      const filter = StoreFilter(query: 'a', kind: StoreFilterKind.corretivas);

      expect(filter.copyWith(query: 'b').kind, StoreFilterKind.corretivas);
      expect(filter.copyWith(kind: StoreFilterKind.todas).query, 'a');
      expect(const StoreFilter(query: ' ').isEmpty, isTrue);
      expect(filter.isEmpty, isFalse);
    });
  });

  group('banco local', () {
    test('reemite quando os dados mudam', () async {
      final emissions = <List<String>>[];
      final subscription = watchStores().listen(
        (result) => emissions.add(result.items.map((s) => s.id).toList()),
      );
      await pumpEventQueue();

      repository.emit(const [StoreSummary(id: 'x', name: 'Nova loja')]);
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [
        ['s2', 's1'],
        ['x'],
      ]);
    });

    test('propaga o erro do repositório', () async {
      final mock = MockStoreListRepository();
      when(mock.watchStores).thenAnswer(
        (_) => Stream<List<StoreSummary>>.error(StateError('banco fechado')),
      );

      await expectLater(WatchStores(mock)().first, throwsStateError);
    });
  });
}
