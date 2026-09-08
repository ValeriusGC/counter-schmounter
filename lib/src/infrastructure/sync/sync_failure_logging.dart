import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

/// Логирует сбой sync: сетевой таймаут — info без stack trace, остальное — error.
void logSyncFailure({
  required String message,
  required Object error,
  StackTrace? stackTrace,
  Map<String, Object?> context = const <String, Object?>{},
}) {
  if (error is UlsyncNetworkException) {
    AppLogger.info(
      component: AppLogComponent.sync,
      message: message,
      context: <String, Object?>{
        ...context,
        'detail': error.message,
      },
    );
    return;
  }

  AppLogger.error(
    component: AppLogComponent.sync,
    message: message,
    error: error,
    stackTrace: stackTrace,
    context: context,
  );
}
