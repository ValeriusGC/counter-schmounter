import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supa_counter/src/application/counter/use_cases/increment_counter_use_case.dart';
import 'package:supa_counter/src/domain/counter/operations/increment_operation.dart';
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
    useCase = IncrementCounterUseCase(mockClientIdentityService, mockLocalOpLogRepository);
  });

  group('IncrementCounterUseCase', () {
    group('execute', () {
      test('creates IncrementOperation with correct fields and saves it', () async {
        // Act
        final operation = await useCase.execute();

        // Assert
        expect(operation, isA<IncrementOperation>());
        expect(operation.opId, isNotEmpty);
        expect(operation.clientId, 'test-client-id');
        expect(operation.createdAt, isA<DateTime>());
        verify(() => mockLocalOpLogRepository.append(operation)).called(1);
      });

      test('generates unique operation IDs on each call', () async {
        // Act
        final op1 = await useCase.execute();
        final op2 = await useCase.execute();

        // Assert
        expect(op1.opId, isNot(equals(op2.opId)));
      });

      test('uses client_id from ClientIdentityService', () async {
        // Arrange
        when(() => mockClientIdentityService.clientId).thenReturn('another-client-id');
        final useCase2 = IncrementCounterUseCase(mockClientIdentityService, mockLocalOpLogRepository);

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
        expect(operation.createdAt.isAfter(before) || operation.createdAt.isAtSameMomentAs(before), isTrue);
        expect(operation.createdAt.isBefore(after) || operation.createdAt.isAtSameMomentAs(after), isTrue);
        expect(operation.createdAt.isUtc, isTrue);
      });

      test('creates valid UUID for opId', () async {
        // Act
        final operation = await useCase.execute();

        // Assert
        // UUID v4 format: 8-4-4-4-12 hex digits
        expect(operation.opId, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')));
      });

      test('saves operation to repository', () async {
        // Act
        final operation = await useCase.execute();

        // Assert
        verify(() => mockLocalOpLogRepository.append(operation)).called(1);
      });
    });
  });
}

