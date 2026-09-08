import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

/// Use case одного обмена счётчика через ulsync.
///
/// Вызывает [UlsyncClient.syncOnce]. Курсор прогресса ведёт библиотека;
/// [SyncStateRepository] для счётчика больше не используется.
final class SyncCounterUseCase {
  /// Создаёт use case.
  ///
  /// [client] может быть `null`, если пользователь не вошёл.
  SyncCounterUseCase({required UlsyncClient? client}) : _client = client;

  final UlsyncClient? _client;

  /// Один обмен push + pull.
  ///
  /// Нет клиента (не вошли) — ничего не делает, это не ошибка.
  Future<void> execute() async {
    final client = _client;
    if (client == null) {
      AppLogger.info(
        component: AppLogComponent.sync,
        message:
            'SyncCounterUseCase skipped: no ulsync client (not signed in).',
      );
      return;
    }

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'SyncCounterUseCase started (ulsync syncOnce).',
    );

    await client.syncOnce();

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'SyncCounterUseCase finished (ulsync syncOnce).',
    );
  }
}
