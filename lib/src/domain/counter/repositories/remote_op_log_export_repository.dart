import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';

/// Репозиторий экспорта (push) операций счётчика в удалённый op-log.
///
/// Назначение:
/// - выполнять запись локальных операций в таблицу `counter_operations`
/// - обеспечивать идемпотентность экспорта (операция с тем же `op_id` не должна ломать push)
///
/// Важно:
/// - Этот репозиторий отделён от [RemoteOpLogRepository], потому что pull и push
///   имеют разные протоколы, ошибки и требования к идемпотентности.
abstract class RemoteOpLogExportRepository {
  /// Экспортирует операции для указанной сущности.
  ///
  /// Параметры:
  /// - [entityId] — идентификатор сущности (например, `default_counter`)
  /// - [operations] — операции, которые нужно отправить на сервер
  ///
  /// Поведение:
  /// - если нет auth session — экспорт должен быть безопасным no-op
  ///   (как и в pull-репозитории на ранних шагах)
  Future<void> exportOperations({
    required String entityId,
    required List<CounterOperation> operations,
  });
}
