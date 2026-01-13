import 'dart:async';

import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

/// Debouncer для схлопывания частых событий.
///
/// Логирование сделано намеренно подробным, чтобы диагностировать:
/// - постановку таймера,
/// - отмену предыдущего,
/// - фактическое срабатывание,
/// - dispose.
final class Debouncer {
  /// Создаёт debouncer с фиксированной задержкой.
  Debouncer({required Duration delay, required String debugName})
    : _delay = delay,
      _debugName = debugName;

  final Duration _delay;
  final String _debugName;

  Timer? _timer;
  int _sequence = 0;

  /// Планирует выполнение [action] после задержки.
  ///
  /// Повторный вызов до истечения delay отменяет предыдущий таймер.
  void run(Future<void> Function() action) {
    final prevActive = _timer?.isActive ?? false;
    if (prevActive) {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Debouncer cancel previous timer.',
        context: <String, Object?>{
          'debouncer': _debugName,
          'delay_ms': _delay.inMilliseconds,
        },
      );
    }

    _timer?.cancel();
    _sequence += 1;
    final currentSeq = _sequence;

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'Debouncer scheduled.',
      context: <String, Object?>{
        'debouncer': _debugName,
        'seq': currentSeq,
        'delay_ms': _delay.inMilliseconds,
      },
    );

    _timer = Timer(_delay, () async {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Debouncer fired.',
        context: <String, Object?>{'debouncer': _debugName, 'seq': currentSeq},
      );

      try {
        await action();
      } catch (e, st) {
        AppLogger.error(
          component: AppLogComponent.sync,
          message: 'Debouncer action failed.',
          error: e,
          stackTrace: st,
          context: <String, Object?>{
            'debouncer': _debugName,
            'seq': currentSeq,
          },
        );
      }
    });
  }

  /// Освобождает ресурсы и отменяет запланированное действие (если есть).
  void dispose() {
    final wasActive = _timer?.isActive ?? false;
    _timer?.cancel();
    _timer = null;

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'Debouncer disposed.',
      context: <String, Object?>{
        'debouncer': _debugName,
        'had_active_timer': wasActive,
      },
    );
  }
}
