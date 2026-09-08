/// Кодек операции счётчика: один JSON для SharedPreferences и payload конверта ulsync.
library;

import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';

/// Сериализация [CounterOperation] в JSON и обратно.
///
/// Формат зафиксирован для уже сохранённых на устройстве данных; ключи
/// snake_case как в историческом `_serializeOperation` локального журнала.
abstract final class CounterOperationCodec {
  /// Сериализует операцию.
  ///
  /// Формат обязан читаться данными, уже лежащими на устройстве.
  static Map<String, dynamic> toJson(CounterOperation operation) {
    if (operation is IncrementOperation) {
      return <String, dynamic>{
        'op_id': operation.opId,
        'type': 'increment',
        'client_id': operation.clientId,
        'created_at': operation.createdAt.toIso8601String(),
      };
    }
    throw ArgumentError('Unknown operation type: ${operation.runtimeType}');
  }

  /// Десериализует операцию из JSON.
  ///
  /// Неизвестный `type` — [ArgumentError], не молчаливый skip.
  static CounterOperation fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final opId = json['op_id'] as String;
    final clientId = json['client_id'] as String;
    final createdAt = DateTime.parse(json['created_at'] as String);

    switch (type) {
      case 'increment':
        return IncrementOperation(
          opId: opId,
          clientId: clientId,
          createdAt: createdAt,
        );
      default:
        throw ArgumentError('Unknown operation type: $type');
    }
  }
}
