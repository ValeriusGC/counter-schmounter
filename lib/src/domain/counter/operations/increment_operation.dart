import 'package:supa_counter/src/domain/counter/operations/counter_operation.dart';

/// Операция увеличения счетчика на 1.
///
/// Является коммутативной операцией - порядок применения не важен.
/// Результат применения множества IncrementOperation равен количеству операций.
class IncrementOperation extends CounterOperation {
  /// Создает операцию увеличения счетчика.
  ///
  /// Параметры:
  /// - [opId] - уникальный идентификатор операции (UUID)
  /// - [clientId] - идентификатор клиента, создавшего операцию
  /// - [createdAt] - время создания операции
  const IncrementOperation({
    required super.opId,
    required super.clientId,
    required super.createdAt,
  });

  @override
  String toString() {
    return 'IncrementOperation(opId: $opId, clientId: $clientId, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is IncrementOperation &&
        other.opId == opId &&
        other.clientId == clientId &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(opId, clientId, createdAt);
}
