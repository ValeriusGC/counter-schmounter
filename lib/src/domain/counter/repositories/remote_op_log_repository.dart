import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';

/// Read-only репозиторий удалённого op-log.
///
/// На Шаге 8 используется **только для чтения** операций с сервера.
/// Без авторизации (local-only режим) репозиторий обязан работать безопасно и
/// возвращать пустой список.
///
/// Репозиторий возвращает **доменные операции** (не DTO).
abstract class RemoteOpLogRepository {
  /// Загружает операции указанной сущности, созданные строго после [since].
  ///
  /// Если [since] равен `null`, возвращает всю историю доступных операций.
  Future<List<CounterOperation>> fetchAfter({
    required String entityId,
    required DateTime? since,
  });
}
