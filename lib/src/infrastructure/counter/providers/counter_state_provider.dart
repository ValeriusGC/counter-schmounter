import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/domain/counter/utils/counter_aggregator.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

part 'counter_state_provider.g.dart';

/// Провайдер агрегированного состояния счетчика.
///
/// Назначение:
/// - читает локальный op-log,
/// - агрегирует операции через [CounterAggregator],
/// - возвращает текущее значение счетчика.
///
/// Обновляется исключительно через:
/// - invalidate (sync / realtime),
/// - первый watch (startup).
///
/// КРИТИЧНО:
/// - не содержит побочных эффектов,
/// - детерминирован,
/// - одинаково работает на Web и Mobile.
@riverpod
Future<int> counterState(Ref ref) async {
  AppLogger.info(
    component: AppLogComponent.state,
    message: 'CounterStateProvider build START',
  );

  final repository = ref.watch(localOpLogRepositoryProvider);

  /// Читаем все операции
  final operations = await repository.getAll();

  AppLogger.info(
    component: AppLogComponent.state,
    message: 'CounterStateProvider loaded operations',
    context: <String, Object?>{'operations_count': operations.length},
  );

  /// Агрегируем
  final counter = CounterAggregator.compute(operations);

  AppLogger.info(
    component: AppLogComponent.state,
    message: 'CounterStateProvider build END',
    context: <String, Object?>{
      'computed_value': counter,
      'operations_count': operations.length,
    },
  );

  return counter;
}
