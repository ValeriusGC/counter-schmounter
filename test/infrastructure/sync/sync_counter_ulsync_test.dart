import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/application/counter/use_cases/sync_counter_use_case.dart';
import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/domain/counter/utils/counter_aggregator.dart';
import 'package:counter_schmounter/src/infrastructure/counter/codecs/counter_operation_codec.dart';
import 'package:counter_schmounter/src/infrastructure/counter/repositories/local_op_log_repository_impl.dart';
import 'package:counter_schmounter/src/infrastructure/sync/ulsync_client_factory.dart';
import '../../test_helpers/counter_envelope.dart';
import '../../test_helpers/fake_sync_transport.dart';

void main() {
  group('ulsync counter sync', () {
    late SharedPreferences prefs;
    late LocalOpLogRepositoryImpl localLog;
    late FakeSyncTransport fake;
    var dbCounter = 0;

    Future<UlsyncClient> openClient({
      required String userScope,
      String? dbPath,
    }) async {
      fake = FakeSyncTransport();
      final path = dbPath ?? 'sync_test_${dbCounter++}.db';
      await databaseFactoryMemory.deleteDatabase(path);
      return UlsyncClientFactory.open(
        userScope: userScope,
        sourceId: 'device-test',
        localOpLog: localLog,
        tokenProvider: () async => 'test-token',
        transport: fake,
        databaseFactory: databaseFactoryMemory,
        databasePathOverride: path,
      );
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
      localLog = LocalOpLogRepositoryImpl(prefs, scope: 'user:test-user');
      await localLog.initialize();
    });

    test('local operation is pushed on syncOnce', () async {
      final opA = IncrementOperation(
        opId: 'op-a',
        clientId: 'device-test',
        createdAt: DateTime.utc(2026, 3, 1, 10),
      );

      final client = await openClient(userScope: 'user-1');
      await localLog.append(opA);
      await client.markChanged(entityType: 'counter_operation', id: opA.opId);

      fake.onPull = ({required int since, int? limit}) async {
        return PullPage(envelopes: const <Envelope>[], nextCursor: 0);
      };

      await client.syncOnce();

      expect(fake.pushCalls.length, 1);
      expect(fake.pushCalls.single.single.id, opA.opId);

      final payload = fake.pushCalls.single.single.payload;
      final decoded = CounterOperationCodec.fromJson(
        jsonDecode(utf8.decode(payload)) as Map<String, dynamic>,
      );
      expect(decoded, opA);

      await client.close();
    });

    test('remote operation arrives on second client via pull', () async {
      final opB = IncrementOperation(
        opId: 'op-b',
        clientId: 'device-remote',
        createdAt: DateTime.utc(2026, 3, 2, 11),
      );

      final envelope = counterEnvelope(operation: opB, serverSeq: 1);

      final client1 = await openClient(
        userScope: 'user-1',
        dbPath: 'sync_a.db',
      );
      fake.onPull = ({required int since, int? limit}) async {
        return PullPage(envelopes: const <Envelope>[], nextCursor: 0);
      };
      await client1.syncOnce();
      await client1.close();

      localLog = LocalOpLogRepositoryImpl(prefs, scope: 'user:test-user');
      await localLog.clear();
      await localLog.initialize();

      final client2 = await openClient(
        userScope: 'user-1',
        dbPath: 'sync_b.db',
      );
      fake.onPull = ({required int since, int? limit}) async {
        return PullPage(envelopes: <Envelope>[envelope], nextCursor: 1);
      };

      await SyncCounterUseCase(client: client2).execute();

      final all = await localLog.getAll();
      expect(all.length, 1);
      expect(all.single.opId, opB.opId);
      expect(CounterAggregator.compute(all), 1);

      await client2.close();
    });
  });
}
