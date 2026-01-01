import 'dart:developer' as developer;

/// Компоненты логирования.
///
/// Используются как `name` в [developer.log] для удобной фильтрации.
abstract final class AppLogComponent {
  /// Логи удалённого op-log (pull).
  static const String syncRemoteOpLog = 'SYNC/REMOTE_OPLOG';

  /// Общие логи синхронизации.
  static const String sync = 'SYNC';

  /// Логи realtime (следующий этап).
  static const String realtime = 'REALTIME';

  /// Логи экспорта (следующий этап).
  static const String export = 'EXPORT';

  /// Логи локального op-log.
  static const String localOpLog = 'LOCAL_OPLOG';
}

/// Минималистичный логгер.
///
/// Требования:
/// - не использовать `print`;
/// - выводиться и на Web (console), и на mobile;
/// - поддерживать error + stacktrace.
abstract final class AppLogger {
  /// Лог информационного события.
  static void info({
    required String component,
    required String message,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    developer.log(
      _format(message: message, context: context),
      name: component,
    );
  }

  /// Лог ошибки.
  static void error({
    required String component,
    required String message,
    required Object error,
    StackTrace? stackTrace,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    developer.log(
      _format(message: message, context: context),
      name: component,
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );
  }

  static String _format({
    required String message,
    required Map<String, Object?> context,
  }) {
    if (context.isEmpty) {
      return message;
    }

    final buffer = StringBuffer(message);
    buffer.write(' | ');
    buffer.write(context.entries.map((e) => '${e.key}=${e.value}').join(' '));
    return buffer.toString();
  }
}
