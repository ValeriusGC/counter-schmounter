import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:supa_counter/src/domain/counter/utils/counter_aggregator.dart';
import 'package:supa_counter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';

part 'counter_state_provider.g.dart';

/// Провайдер для агрегированного состояния счетчика.
///
/// Читает операции из [LocalOpLogRepository] и вычисляет итоговое значение
/// счетчика через [CounterAggregator.compute].
///
/// Обновляется через [ref.invalidate()] после изменений в op-log.
/// Используется ViewModel и UI для получения текущего значения счетчика.
///
/// **Важно:** Repository должен быть инициализирован перед использованием.
@riverpod
Future<int> counterState(Ref ref) async {
  final repository = ref.watch(localOpLogRepositoryProvider);

  // Убеждаемся, что repository инициализирован
  await repository.initialize();

  // Загружаем все операции
  final operations = await repository.getAll();

  // Вычисляем итоговое значение счетчика
  final counter = CounterAggregator.compute(operations);

  developer.log(
    '📊 Counter state computed: $counter (${operations.length} operations)',
    name: 'CounterStateProvider',
    error: null,
    stackTrace: null,
    level: 700, // FINE level
  );

  return counter;
}
