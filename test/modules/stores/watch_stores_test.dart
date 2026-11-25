import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/auth/domain/entities/user_role.dart';
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

  Future<List<String>> idsFor(UserRole? role) async {
    final stores = await watchStores(role: role).first;
    return stores.map((s) => s.id).toList();
  }

  group('TextNormalizer', () {
    test('tira acentos, maiúsculas e espaços extras', () {
      expect(TextNormalizer.normalize('  ÁGUA   Fria Ç '), 'agua fria c');
    });

    test('tira acentos de texto decomposto (letra + acento solto)', () {
      // "Água" e "Pão" com o acento como caractere separado (NFD).
      const decomposed = 'A${'́'}gua Pa${'̃'}o';
      expect(decomposed.runes.length, 10);
      expect(TextNormalizer.normalize(decomposed), 'agua pao');
    });
  });

  group('visibilidade por perfil', () {
    test('técnico não vê lojas inativas', () async {
      expect(await idsFor(UserRole.tecnico), ['s2', 's1']);
    });

    test('lojista não vê lojas inativas', () async {
      expect(await idsFor(UserRole.lojista), ['s2', 's1']);
    });

    test('gestor vê as inativas', () async {
      expect(await idsFor(UserRole.gestor), ['s3', 's2', 's1']);
    });

    test('sem perfil esconde as inativas', () async {
      expect(await idsFor(null), ['s2', 's1']);
    });

    test('lista vazia continua vazia', () async {
      final stores = await WatchStores(
        FakeStoreListRepository(),
      ).call(role: UserRole.gestor).first;

      expect(stores, isEmpty);
    });
  });

  group('ordem', () {
    test('alfabética sem considerar acentos e maiúsculas', () async {
      repository.emit(const [
        StoreSummary(id: 'a', name: 'zebra'),
        StoreSummary(id: 'b', name: 'Água Viva'),
        StoreSummary(id: 'c', name: 'Bom Preço'),
      ]);

      expect(await idsFor(UserRole.tecnico), ['b', 'c', 'a']);
    });

    test('nomes iguais desempatam pelo id', () async {
      repository.emit(const [
        StoreSummary(id: 'z', name: 'Loja'),
        StoreSummary(id: 'a', name: 'loja'),
      ]);

      expect(await idsFor(UserRole.tecnico), ['a', 'z']);
    });
  });

  group('banco local', () {
    test('reemite quando os dados mudam', () async {
      final emissions = <List<String>>[];
      final subscription = watchStores(role: UserRole.tecnico).listen(
        (stores) => emissions.add(stores.map((s) => s.id).toList()),
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

      await expectLater(
        WatchStores(mock)(role: UserRole.tecnico).first,
        throwsStateError,
      );
    });
  });
}
