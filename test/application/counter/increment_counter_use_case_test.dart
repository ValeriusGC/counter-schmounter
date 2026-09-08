import 'package:ulsync/ulsync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_schmounter/src/application/counter/use_cases/increment_counter_use_case.dart';
import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/infrastructure/counter/codecs/counter_operation_codec.dart';
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
  });
}
