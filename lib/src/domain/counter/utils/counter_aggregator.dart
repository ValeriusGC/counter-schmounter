import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';

/// Утилита для агрегации операций счетчика в итоговое состояние.
///
/// Реализует доменную логику вычисления состояния счетчика из списка операций.
/// Не зависит от внешних фреймворков (Flutter, Riverpod, Supabase).
class CounterAggregator {
  /// Вычисляет итоговое значение счетчика из списка операций.
  ///
  /// Применяет операции последовательно, суммируя результат.
  /// Для [IncrementOperation] увеличивает счетчик на 1.
  ///
  /// Параметры:
  /// - [operations] - список операций для применения
  ///
  /// Возвращает итоговое значение счетчика.
  ///
  /// Пример:
  /// ```dart
  /// final operations = [
  ///   IncrementOperation(...),
  ///   IncrementOperation(...),
  /// ];
  /// final counter = CounterAggregator.compute(operations); // 2
  /// ```
  static int compute(List<CounterOperation> operations) {
    return operations.fold<int>(0, (value, operation) {
      if (operation is IncrementOperation) {
        return value + 1;
      }
      // Если появится новый тип операции, здесь нужно будет добавить обработку
      return value;
    });
  }
}
