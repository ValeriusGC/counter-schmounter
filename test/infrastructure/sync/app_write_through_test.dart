import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/application/counter/use_cases/sync_counter_use_case.dart';
import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/infrastructure/counter/repositories/local_op_log_repository_impl.dart';
import 'package:counter_schmounter/src/infrastructure/sync/sync_failure_logging.dart';
import 'package:counter_schmounter/src/infrastructure/sync/ulsync_client_factory.dart';
import '../../test_helpers/fake_sync_transport.dart';

void main() {
  group('app write-through sync (круг 1a)', () {
    late SharedPreferences prefs;
    late LocalOpLogRepositoryImpl localLog;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      localLog = LocalOpLogRepositoryImpl(prefs, scope: 'user:g4');
      await localLog.initialize();
    });

    test(
      'local reconcile pushes journal ops when metadata store is empty (G4)',
      () async {
        final operations = List<IncrementOperation>.generate(
          3,
          (index) => IncrementOperation(
            opId: 'historical-op-$index',
            clientId: 'device-g4',
            createdAt: DateTime.utc(2026, 3, 10, index),
          ),
        );
        for (final op in operations) {
          await localLog.append(op);
        }

        final fake = FakeSyncTransport();
        fake.onPull = ({required int since, int? limit}) async {
          return PullPage(envelopes: const <Envelope>[], nextCursor: 0);
        };

        const dbPath = 'g4_empty_metadata.db';
        await databaseFactoryMemory.deleteDatabase(dbPath);

        final client = await UlsyncClientFactory.open(
          userScope: 'user-g4',
          sourceId: 'device-g4',
          localOpLog: localLog,
          tokenProvider: () async => 'token',
          transport: fake,
          databaseFactory: databaseFactoryMemory,
          databasePathOverride: dbPath,
        );

        await SyncCounterUseCase(client: client).execute();

        final pushedIds = fake.pushCalls
            .expand((batch) => batch)
            .map((envelope) => envelope.id)
            .toList();
        expect(pushedIds, operations.map((op) => op.opId).toList());

        await client.close();
      },
    );

    test('source_id mismatch on syncOnce is a loud non-network failure', () async {
      const dbPath = 'g9_identity.db';
      await databaseFactoryMemory.deleteDatabase(dbPath);

      final first = await UlsyncClientFactory.open(
        userScope: 'user-g9',
        sourceId: 'device-a',
        localOpLog: localLog,
        tokenProvider: () async => 'token',
        transport: FakeSyncTransport(),
        databaseFactory: databaseFactoryMemory,
        databasePathOverride: dbPath,
      );
      await first.selfCheck(includeServer: false);
      await first.close();

      final second = await UlsyncClientFactory.open(
        userScope: 'user-g9',
        sourceId: 'device-b',
        localOpLog: localLog,
        tokenProvider: () async => 'token',
        transport: FakeSyncTransport(),
        databaseFactory: databaseFactoryMemory,
        databasePathOverride: dbPath,
      );

      await expectLater(
        second.syncOnce(),
        throwsA(
          isA<StateError>().having(
            (error) => error.toString(),
            'message',
            allOf(contains('device-a'), contains('device-b')),
          ),
        ),
      );

      await second.close();
    });

    test('logSyncFailure records non-network errors at error severity path', () {
      // Путь G9: отказ обмена не глотается — UlsyncNetworkException идёт в info,
      // остальные ошибки (в т.ч. StateError при подмене source_id) — в error.
      expect(
        () => logSyncFailure(
          message: 'симуляция отказа обмена',
          error: StateError('source_id mismatch'),
        ),
        returnsNormally,
      );
      expect(
        () => logSyncFailure(
          message: 'симуляция сети',
          error: const UlsyncNetworkException('offline'),
        ),
        returnsNormally,
      );
    });
  });
}
