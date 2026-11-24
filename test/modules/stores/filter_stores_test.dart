import 'package:flutter_test/flutter_test.dart';
import 'package:kym/modules/stores/domain/entities/store_filter.dart';
import 'package:kym/modules/stores/domain/entities/store_summary.dart';
import 'package:kym/modules/stores/domain/usecases/filter_stores.dart';

import '../../support/store_fakes.dart';

void main() {
  const filterStores = FilterStores();

  /// As lojas ativas do exemplo, já na ordem que o `WatchStores` entrega.
  final visible = [sampleStores[1], sampleStores[0]];

  List<String> idsFor(
    StoreFilter filter, [
    List<StoreSummary>? stores,
  ]) {
    return filterStores(
      stores ?? visible,
      filter,
    ).items.map((s) => s.id).toList();
  }

  group('busca', () {
    test('por nome, sem acento e sem diferenciar maiúsculas', () {
      expect(idsFor(const StoreFilter(query: 'PAO de acucar')), ['s1']);
    });

    test('acento digitado casa com texto sem acento', () {
      expect(idsFor(const StoreFilter(query: 'água')), ['s2']);
    });

    test('por código', () {
      expect(idsFor(const StoreFilter(query: 'l002')), ['s2']);
    });

    test('por cidade', () {
      expect(idsFor(const StoreFilter(query: 'olinda')), ['s2']);
    });

    test('por endereço', () {
      expect(idsFor(const StoreFilter(query: 'matriz')), ['s2']);
    });

    test('termo só com espaços não filtra', () {
      expect(idsFor(const StoreFilter(query: '   ')), ['s2', 's1']);
    });

    test('mantém a ordem recebida', () {
      expect(idsFor(const StoreFilter(query: 'a')), ['s2', 's1']);
    });
  });

  group('totalVisible', () {
    test('conta as lojas antes da busca e do filtro', () {
      final result = filterStores(visible, const StoreFilter(query: 'zzz'));

      expect(result.items, isEmpty);
      expect(result.totalVisible, 2);
    });

    test('lista vazia vira resultado vazio', () {
      final result = filterStores(const [], const StoreFilter());

      expect(result.items, isEmpty);
      expect(result.totalVisible, 0);
    });
  });

  group('abas de filtro', () {
    const stores = [
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

    List<String> idsOf(StoreFilterKind kind) =>
        idsFor(StoreFilter(kind: kind), stores);

    test('todas', () {
      expect(idsOf(StoreFilterKind.todas), ['a', 'b', 'c', 'd']);
    });

    test('com atrasadas', () {
      expect(idsOf(StoreFilterKind.comAtrasadas), ['a']);
    });

    test('em dia: só lojas sem nada em aberto, como o selo do cartão', () {
      expect(idsOf(StoreFilterKind.emDia), ['d']);
    });

    test('preventivas', () {
      expect(idsOf(StoreFilterKind.preventivas), ['a', 'c']);
    });

    test('corretivas', () {
      expect(idsOf(StoreFilterKind.corretivas), ['a', 'b']);
    });

    test('combina aba e busca', () {
      expect(
        idsFor(
          const StoreFilter(query: 'c', kind: StoreFilterKind.preventivas),
          stores,
        ),
        ['c'],
      );
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
}
