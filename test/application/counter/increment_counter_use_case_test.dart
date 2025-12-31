import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supa_counter/src/application/counter/use_cases/increment_counter_use_case.dart';
import 'package:supa_counter/src/domain/counter/operations/increment_operation.dart';
import 'package:supa_counter/src/domain/shared/services/client_identity_service.dart';
import '../../test_helpers/mocks.dart';

void main() {
  late MockClientIdentityService mockClientIdentityService;
  late IncrementCounterUseCase useCase;

  setUp(() {
    mockClientIdentityService = MockClientIdentityService();
    when(() => mockClientIdentityService.clientId).thenReturn('test-client-id');
    useCase = IncrementCounterUseCase(mockClientIdentityService);
  });

  group('IncrementCounterUseCase', () {
    group('execute', () {
      test('creates IncrementOperation with correct fields', () {
        // Act
        final operation = useCase.execute();

        // Assert
        expect(operation, isA<IncrementOperation>());
        expect(operation.opId, isNotEmpty);
        expect(operation.clientId, 'test-client-id');
        expect(operation.createdAt, isA<DateTime>());
      });

      test('generates unique operation IDs on each call', () {
        // Act
        final op1 = useCase.execute();
        final op2 = useCase.execute();

        // Assert
        expect(op1.opId, isNot(equals(op2.opId)));
      });

      test('uses client_id from ClientIdentityService', () {
        // Arrange
        when(() => mockClientIdentityService.clientId).thenReturn('another-client-id');
        final useCase2 = IncrementCounterUseCase(mockClientIdentityService);

        // Act
        final operation = useCase2.execute();

        // Assert
        expect(operation.clientId, 'another-client-id');
      });

      test('sets createdAt to current time', () {
        // Arrange
        final before = DateTime.now();

        // Act
        final operation = useCase.execute();
        final after = DateTime.now();

        // Assert
        expect(operation.createdAt.isAfter(before) || operation.createdAt.isAtSameMomentAs(before), isTrue);
        expect(operation.createdAt.isBefore(after) || operation.createdAt.isAtSameMomentAs(after), isTrue);
      });

      test('creates valid UUID for opId', () {
        // Act
        final operation = useCase.execute();

        // Assert
        // UUID v4 format: 8-4-4-4-12 hex digits
        expect(operation.opId, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')));
      });
    });
  });
}

