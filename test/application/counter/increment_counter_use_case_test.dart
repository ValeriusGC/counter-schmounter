import 'package:ulsync/ulsync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_schmounter/src/application/counter/use_cases/increment_counter_use_case.dart';
import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/infrastructure/counter/repositories/local_op_log_repository_impl.dart';
import 'package:counter_schmounter/src/infrastructure/sync/ulsync_client_factory.dart';
import '../../test_helpers/fake_sync_transport.dart';
import '../../test_helpers/mocks.dart';

void main() {
  late MockClientIdentityService mockClientIdentityService;
  late MockLocalOpLogRepository mockLocalOpLogRepository;
  late IncrementCounterUseCase useCase;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockClientIdentityService = MockClientIdentityService();
    mockLocalOpLogRepository = MockLocalOpLogRepository();
    when(() => mockClientIdentityService.clientId).thenReturn('test-client-id');
    when(() => mockLocalOpLogRepository.append(any())).thenAnswer((_) async {});
    useCase = IncrementCounterUseCase(
      mockClientIdentityService,
      mockLocalOpLogRepository,
    );
  });

  group('IncrementCounterUseCase', () {
    group('execute', () {
      test(
        'creates IncrementOperation with correct fields and saves it',
        () async {
          // Act
          final operation = await useCase.execute();

          // Assert
          expect(operation, isA<IncrementOperation>());
          expect(operation.opId, isNotEmpty);
          expect(operation.clientId, 'test-client-id');
          expect(operation.createdAt, isA<DateTime>());
          verify(() => mockLocalOpLogRepository.append(operation)).called(1);
        },
      );

      test('generates unique operation IDs on each call', () async {
        // Act
        final op1 = await useCase.execute();
        final op2 = await useCase.execute();

        // Assert
        expect(op1.opId, isNot(equals(op2.opId)));
      });

      test('uses client_id from ClientIdentityService', () async {
        // Arrange
        when(
          () => mockClientIdentityService.clientId,
        ).thenReturn('another-client-id');
        final useCase2 = IncrementCounterUseCase(
          mockClientIdentityService,
          mockLocalOpLogRepository,
        );

        // Act
        final operation = await useCase2.execute();

        // Assert
        expect(operation.clientId, 'another-client-id');
      });

      test('sets createdAt to current time (UTC)', () async {
        // Arrange
        final before = DateTime.now().toUtc();

        // Act
        final operation = await useCase.execute();
        final after = DateTime.now().toUtc();

        // Assert
        expect(
          operation.createdAt.isAfter(before) ||
              operation.createdAt.isAtSameMomentAs(before),
          isTrue,
        );
        expect(
          operation.createdAt.isBefore(after) ||
              operation.createdAt.isAtSameMomentAs(after),
          isTrue,
        );
        expect(operation.createdAt.isUtc, isTrue);
      });

      test('creates valid UUID for opId', () async {
        // Act
        final operation = await useCase.execute();

        // Assert
        // UUID v4 format: 8-4-4-4-12 hex digits
        expect(
          operation.opId,
          matches(
            RegExp(
              r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
            ),
          ),
        );
      });

      test('saves operation to repository', () async {
        // Act
        final operation = await useCase.execute();

        // Assert
        verify(() => mockLocalOpLogRepository.append(operation)).called(1);
      });
    });

    group('markChanged after append', () {
      test('without sync client does not push on execute alone', () async {
        final operation = await useCase.execute();
        expect(operation.opId, isNotEmpty);
        verify(() => mockLocalOpLogRepository.append(operation)).called(1);
      });

      test('with ulsync client marks dirty; push after syncOnce', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final localLog = LocalOpLogRepositoryImpl(prefs, scope: 'user:inc');
        await localLog.initialize();

        final fake = FakeSyncTransport();
        final client = await UlsyncClientFactory.open(
          userScope: 'user-inc',
          sourceId: 'client-inc',
          localOpLog: localLog,
          tokenProvider: () async => 't',
          transport: fake,
          databaseFactory: databaseFactoryMemory,
          databasePathOverride: 'increment_mark_test.db',
        );

        final incrementUseCase = IncrementCounterUseCase(
          mockClientIdentityService,
          localLog,
          syncClientOf: () async => client,
        );

        when(() => mockClientIdentityService.clientId).thenReturn('client-inc');

        final operation = await incrementUseCase.execute();
        expect(fake.pushCalls, isEmpty);

        fake.onPull = ({required int since, int? limit}) async {
          return PullPage(envelopes: const [], nextCursor: 0);
        };

        await client.syncOnce();
        expect(fake.pushCalls.length, 1);
        expect(fake.pushCalls.single.single.id, operation.opId);

        await client.close();
      });
    });

    group('write through ulsync client', () {
      test('marks dirty in metadata when client is present', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final localLog = LocalOpLogRepositoryImpl(prefs, scope: 'user:write');
        await localLog.initialize();

        const dbPath = 'increment_write_dirty.db';
        await databaseFactoryMemory.deleteDatabase(dbPath);

        final fake = FakeSyncTransport();
        final client = await UlsyncClientFactory.open(
          userScope: 'user-write',
          sourceId: 'client-write',
          localOpLog: localLog,
          tokenProvider: () async => 't',
          transport: fake,
          databaseFactory: databaseFactoryMemory,
          databasePathOverride: dbPath,
        );

        final store = await SembastMetadataStore.open(
          databasePath: dbPath,
          factory: databaseFactoryMemory,
        );

        final incrementUseCase = IncrementCounterUseCase(
          mockClientIdentityService,
          localLog,
          syncClientOf: () async => client,
        );
        when(() => mockClientIdentityService.clientId).thenReturn('client-write');

        final operation = await incrementUseCase.execute();

        final dirty = await store.dirtyBatch(userScope: 'user-write', limit: 10);
        expect(dirty.length, 1);
        expect(dirty.single.id, operation.opId);
        expect(dirty.single.dirty, isTrue);

        await client.close();
        await store.close();
      });

      test('persist failure propagates from write', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        final prefs = await SharedPreferences.getInstance();
        final failingLog = _FailingLocalOpLog(prefs, scope: 'user:fail');
        await failingLog.initialize();

        const dbPath = 'increment_write_fail.db';
        await databaseFactoryMemory.deleteDatabase(dbPath);

        final client = await UlsyncClientFactory.open(
          userScope: 'user-fail',
          sourceId: 'client-fail',
          localOpLog: failingLog,
          tokenProvider: () async => 't',
          transport: FakeSyncTransport(),
          databaseFactory: databaseFactoryMemory,
          databasePathOverride: dbPath,
        );

        final incrementUseCase = IncrementCounterUseCase(
          mockClientIdentityService,
          failingLog,
          syncClientOf: () async => client,
        );
        when(() => mockClientIdentityService.clientId).thenReturn('client-fail');

        await expectLater(incrementUseCase.execute(), throwsA(isException));
        expect(failingLog.appendAttempts, 1);

        await client.close();
      });

      test('without sync client only appends locally', () async {
        final recordingLog = _RecordingAppendLog();
        final incrementUseCase = IncrementCounterUseCase(
          mockClientIdentityService,
          recordingLog,
        );

        final operation = await incrementUseCase.execute();

        expect(recordingLog.appended.length, 1);
        expect(recordingLog.appended.single.opId, operation.opId);
      });
    });
  });
}

/// Журнал, который бросает на append — для проверки проброса ошибки [write].
final class _FailingLocalOpLog extends LocalOpLogRepositoryImpl {
  _FailingLocalOpLog(super.prefs, {required super.scope});

  var appendAttempts = 0;

  @override
  Future<void> append(CounterOperation operation) async {
    appendAttempts++;
    throw Exception('simulated persist failure');
  }
}

/// Считает append без реального хранилища.
final class _RecordingAppendLog implements LocalOpLogRepository {
  final List<CounterOperation> appended = <CounterOperation>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> append(CounterOperation operation) async {
    appended.add(operation);
  }

  @override
  Future<List<CounterOperation>> getAll() async =>
      List<CounterOperation>.from(appended);

  @override
  Future<CounterOperation?> byId(String opId) async => null;

  @override
  Future<void> clear() async {
    appended.clear();
  }
}

