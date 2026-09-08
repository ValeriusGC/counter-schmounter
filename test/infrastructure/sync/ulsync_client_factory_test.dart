import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/infrastructure/counter/repositories/local_op_log_repository_impl.dart';
import 'package:counter_schmounter/src/infrastructure/sync/ulsync_client_factory.dart';
import '../../test_helpers/fake_sync_transport.dart';

void main() {
  group('UlsyncClientFactory', () {
    test(
      'opens and closes client; closed client rejects markChanged',
      () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final localLog = LocalOpLogRepositoryImpl(prefs, scope: 'user:u1');
        final fake = FakeSyncTransport();
        const path = 'factory_test.db';
        await databaseFactoryMemory.deleteDatabase(path);

        final client1 = await UlsyncClientFactory.open(
          userScope: 'user-1',
          sourceId: 'install-1',
          localOpLog: localLog,
          tokenProvider: () async => 'token',
          transport: fake,
          databaseFactory: databaseFactoryMemory,
          databasePathOverride: path,
        );

        expect(client1, isA<UlsyncClient>());

        await client1.close();

        expect(
          () =>
              client1.markChanged(entityType: 'counter_operation', id: 'op-1'),
          throwsA(isA<StateError>()),
        );
      },
    );

    test('second client after close of first is independent', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final localLog = LocalOpLogRepositoryImpl(prefs, scope: 'user:u2');
      final fake1 = FakeSyncTransport();
      final fake2 = FakeSyncTransport();

      final client1 = await UlsyncClientFactory.open(
        userScope: 'user-2',
        sourceId: 'install-2',
        localOpLog: localLog,
        tokenProvider: () async => 'token',
        transport: fake1,
        databaseFactory: databaseFactoryMemory,
        databasePathOverride: 'factory_u2_a.db',
      );
      await client1.close();

      final client2 = await UlsyncClientFactory.open(
        userScope: 'user-3',
        sourceId: 'install-2',
        localOpLog: localLog,
        tokenProvider: () async => 'token',
        transport: fake2,
        databaseFactory: databaseFactoryMemory,
        databasePathOverride: 'factory_u2_b.db',
      );

      expect(client2, isA<UlsyncClient>());
      await client2.close();
    });
  });
}
