import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/infrastructure/counter/repositories/local_op_log_repository_impl.dart';
import 'package:counter_schmounter/src/infrastructure/sync/sync_failure_logging.dart';
import 'package:counter_schmounter/src/infrastructure/sync/ulsync_base_url.dart';
import 'package:counter_schmounter/src/infrastructure/sync/ulsync_client_factory.dart';
import '../../test_helpers/fake_hello_sync_transport.dart';

void main() {
  group('отказ чужого склада', () {
    test('syncOnce бросает OriginMismatchException до push', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final localLog = LocalOpLogRepositoryImpl(prefs, scope: 'user:h4');
      final transport = FakeHelloSyncTransport();
      transport.onHello = (String origin) async {
        throw OriginMismatchException(
          storeOrigin: 'com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
          requestOrigin: origin,
        );
      };

      const dbPath = 'origin_mismatch.db';
      await databaseFactoryMemory.deleteDatabase(dbPath);

      final client = await UlsyncClientFactory.open(
        userScope: 'user-h4',
        sourceId: 'install-h4',
        localOpLog: localLog,
        tokenProvider: () async => 'token',
        transport: transport,
        databaseFactory: databaseFactoryMemory,
        databasePathOverride: dbPath,
      );

      expect(client.origin, kUlsyncOrigin);

      await expectLater(
        client.syncOnce(),
        throwsA(
          isA<OriginMismatchException>()
              .having(
                (error) => error.requestOrigin,
                'requestOrigin',
                kUlsyncOrigin,
              )
              .having(
                (error) => error.storeOrigin,
                'storeOrigin',
                'com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
              ),
        ),
      );

      expect(transport.pushCalls, isEmpty);
      expect(transport.callLog, <String>['hello']);

      await client.close();
    });

    test('logSyncFailure принимает OriginMismatchException на пути error', () {
      // Не UlsyncNetworkException — значит AppLogger.error, не info (как G9).
      expect(
        () => logSyncFailure(
          message: 'симуляция отказа чужого склада',
          error: OriginMismatchException(
            storeOrigin: 'com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee',
            requestOrigin: kUlsyncOrigin,
          ),
        ),
        returnsNormally,
      );
      expect(
        const UlsyncNetworkException('offline'),
        isNot(isA<OriginMismatchException>()),
      );
    });
  });
}
