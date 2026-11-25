import 'package:flutter_test/flutter_test.dart';
import 'package:kym/app/sync/incremental_puller.dart';
import 'package:kym/app/sync/sync_exception.dart';
import 'package:kym/app/sync/sync_service.dart';
import 'package:kym/modules/stores/domain/services/store_sync_trigger.dart';
import 'package:kym/modules/stores/infra/services/sync_service_store_sync_trigger.dart';
import 'package:mocktail/mocktail.dart';

class MockSyncService extends Mock implements SyncService {}

void main() {
  late MockSyncService service;
  late SyncServiceStoreSyncTrigger trigger;

  setUp(() {
    service = MockSyncService();
    trigger = SyncServiceStoreSyncTrigger(service);
  });

  void answer(SyncResult result) {
    when(() => service.sync(fullPull: any(named: 'fullPull')))
        .thenAnswer((_) async => result);
  }

  Matcher failure(SyncFailureType type) =>
      throwsA(isA<SyncFailure>().having((f) => f.type, 'type', type));

  test(
    'pede a reconciliação completa e confirma quando a baixada roda',
    () async {
      answer(const SyncResult(pulled: PullResult(written: 3)));

      expect(await trigger.sync(), isTrue);
      verify(() => service.sync(fullPull: true)).called(1);
    },
  );

  test('rodada interrompida pela rede vira falha offline', () {
    answer(
      const SyncResult(interruptedBy: SyncNetworkException('sem internet')),
    );

    expect(trigger.sync(), failure(SyncFailureType.offline));
  });

  test('erro do servidor na baixada vira falha do servidor', () {
    answer(const SyncResult(pullError: '[42501] permission denied'));

    expect(trigger.sync(), failure(SyncFailureType.server));
  });

  test('item da outbox recusado não impede a lista de ficar em dia', () async {
    answer(const SyncResult(failed: 1, pulled: PullResult()));

    expect(await trigger.sync(), isTrue);
  });

  test('sem baixada, não afirma que a lista está em dia', () async {
    answer(const SyncResult());

    expect(await trigger.sync(), isFalse);
  });
}
