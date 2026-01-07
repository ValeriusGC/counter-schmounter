import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/domain/counter/utils/counter_aggregator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  group('CounterAggregator', () {
    group('compute', () {
      test('returns 0 for empty list', () {
        // Arrange
        const operations = <IncrementOperation>[];

        // Act
        final result = CounterAggregator.compute(operations);

        // Assert
        expect(result, 0);
      });

      test('returns 1 for single IncrementOperation', () {
        // Arrange
        final operation = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client-id',
          createdAt: DateTime.now(),
        );
        final operations = [operation];

        // Act
        final result = CounterAggregator.compute(operations);

        // Assert
        expect(result, 1);
      });

      test('returns sum for multiple IncrementOperation', () {
        // Arrange
        final operations = List.generate(
          5,
          (index) => IncrementOperation(
            opId: const Uuid().v4(),
            clientId: 'test-client-id',
            createdAt: DateTime.now().add(Duration(seconds: index)),
          ),
        );

        // Act
        final result = CounterAggregator.compute(operations);

        // Assert
        expect(result, 5);
      });

      test('replay operations gives same result', () {
        // Arrange
        final operations = List.generate(
          3,
          (index) => IncrementOperation(
            opId: const Uuid().v4(),
            clientId: 'test-client-id',
            createdAt: DateTime.now().add(Duration(seconds: index)),
          ),
        );

        // Act - compute twice
        final result1 = CounterAggregator.compute(operations);
        final result2 = CounterAggregator.compute(operations);

        // Assert
        expect(result1, 3);
        expect(result2, 3);
        expect(result1, equals(result2));
      });

      test('order of operations does not matter (commutative)', () {
        // Arrange
        final op1 = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client-id',
          createdAt: DateTime.now(),
        );
        final op2 = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client-id',
          createdAt: DateTime.now().add(const Duration(seconds: 1)),
        );
        final op3 = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client-id',
          createdAt: DateTime.now().add(const Duration(seconds: 2)),
        );

        // Act - compute in different orders
        final result1 = CounterAggregator.compute([op1, op2, op3]);
        final result2 = CounterAggregator.compute([op3, op1, op2]);
        final result3 = CounterAggregator.compute([op2, op3, op1]);

        // Assert
        expect(result1, 3);
        expect(result2, 3);
        expect(result3, 3);
        expect(result1, equals(result2));
        expect(result2, equals(result3));
      });
    });
  });
}

