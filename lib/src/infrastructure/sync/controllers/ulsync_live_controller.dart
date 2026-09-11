import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/application/counter/providers/sync_counter_use_case_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/counter_state_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';
import 'package:counter_schmounter/src/infrastructure/sync/controllers/counter_sync_coordinator.dart';
import 'package:counter_schmounter/src/infrastructure/sync/providers/ulsync_client_provider.dart';
import 'package:counter_schmounter/src/infrastructure/sync/sync_failure_logging.dart';

part 'ulsync_live_controller.g.dart';

/// Видимое состояние живой ленты на экране счётчика.
enum UlsyncLiveStatus {
  /// Ленты нет, клиент закрыт, или последнее событие — потеря связи.
  disconnected,

  /// Последнее событие — [SyncConnectionRestored], включая первое открытие.
  connected,
}

/// Слушатель живой ленты ulsync: передний план, события, признак связи.
///
/// Конверты применяет библиотека; на [SyncApplied] экран перечитывает
/// [counterStateProvider]. В фоне HTTP закрывается через [UlsyncClient.close],
/// потому что отмена подписки на broadcast не рвёт SSE.
@Riverpod(keepAlive: true)
class UlsyncLiveController extends _$UlsyncLiveController {
  /// Подписка на broadcast [UlsyncClient.live]; cancel не закрывает HTTP.
  StreamSubscription<SyncEvent>? _sub;

  /// Слушатель жизненного цикла приложения (resume / фон).
  AppLifecycleListener? _lifecycle;

  /// Клиент, на котором открывали ленту; нужен для [onAppBackgrounded].
  UlsyncClient? _boundClient;

  /// Защита от повторного hide+pause: второй фон не закрывает новый клиент.
  bool _isForeground = true;

  /// Был [SyncConnectionLost] после последнего обмена; на [SyncConnectionRestored]
  /// нужен [syncOnce], чтобы догнать очередь и сервер (сценарии H/J).
  bool _connectionWasLost = false;

  /// Открывающий обмен в [_syncThenLive] не прошёл; на [SyncConnectionRestored]
  /// нужен [syncOnce], иначе приложение, стартовавшее без сервера, не догонит
  /// очередь после его подъёма (шаг 16b).
  bool _openingSyncFailed = false;

  @override
  UlsyncLiveStatus build() {
    _isForeground = _lifecycleStateIsForeground(
      WidgetsBinding.instance.lifecycleState,
    );

    _lifecycle = AppLifecycleListener(
      onResume: () => unawaited(onAppResumed()),
      onHide: () => unawaited(onAppBackgrounded()),
      onPause: () => unawaited(onAppBackgrounded()),
      onDetach: () => unawaited(onAppBackgrounded()),
    );

    ref.listen<AsyncValue<UlsyncClient?>>(
      ulsyncClientProvider,
      (previous, next) => unawaited(_onClientChanged(next)),
      fireImmediately: true,
    );

    ref.onDispose(() {
      _lifecycle?.dispose();
      _lifecycle = null;
      unawaited(_sub?.cancel());
      _sub = null;
    });

    return UlsyncLiveStatus.disconnected;
  }

  /// Вызывается [AppLifecycleListener.onResume] и тестами.
  ///
  /// Сначала [syncOnce] через координатор, затем снова открывает ленту.
  Future<void> onAppResumed() async {
    _isForeground = true;

    final client = await ref.read(ulsyncClientProvider.future);
    if (client == null) {
      state = UlsyncLiveStatus.disconnected;
      return;
    }

    _boundClient = client;
    await _syncThenLive(client);
  }

  /// Вызывается при уходе в фон (`hidden` / `paused` / `detached`) и тестами.
  ///
  /// Закрывает клиент целиком: cancel подписки на [SyncEvent] SSE не останавливает.
  Future<void> onAppBackgrounded() async {
    if (!_isForeground) {
      return;
    }
    _isForeground = false;
    _connectionWasLost = false;
    _openingSyncFailed = false;

    await _sub?.cancel();
    _sub = null;

    final client = _boundClient;
    _boundClient = null;
    if (client != null) {
      await client.close();
    }

    ref.invalidate(ulsyncClientProvider);
    state = UlsyncLiveStatus.disconnected;
  }

  Future<void> _onClientChanged(AsyncValue<UlsyncClient?> next) async {
    if (next.isLoading) {
      return;
    }

    await _sub?.cancel();
    _sub = null;

    if (!ref.mounted) {
      return;
    }

    final client = next.asData?.value;
    if (client == null) {
      _boundClient = null;
      _connectionWasLost = false;
      _openingSyncFailed = false;
      state = UlsyncLiveStatus.disconnected;
      return;
    }

    _boundClient = client;
    if (!_isForeground) {
      return;
    }

    await _syncThenLive(client);
  }

  Future<void> _syncThenLive(UlsyncClient client) async {
    final synced = await _runSyncOnce();
    if (!synced) {
      if (ref.mounted) {
        _openingSyncFailed = true;
        state = UlsyncLiveStatus.disconnected;
      }
    } else {
      _openingSyncFailed = false;
    }

    if (!ref.mounted) {
      return;
    }

    if (!_isForeground || !identical(_boundClient, client)) {
      return;
    }

    await _sub?.cancel();
    try {
      _sub = client.live().listen(_onEvent, onError: _onError);
    } on StateError catch (e, st) {
      logSyncFailure(
        message: 'live() on closed ulsync client',
        error: e,
        stackTrace: st,
      );
      state = UlsyncLiveStatus.disconnected;
    }
  }

  void _onEvent(SyncEvent event) {
    switch (event) {
      case SyncApplied():
        ref.invalidate(counterStateProvider);
      case SyncCursorAdvanced():
        break;
      case SyncConnectionLost():
        _connectionWasLost = true;
        state = UlsyncLiveStatus.disconnected;
        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'Живая лента: связь потеряна (библиотека переподключится).',
        );
      case SyncConnectionRestored():
        state = UlsyncLiveStatus.connected;
        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'Живая лента: связь восстановлена.',
        );
        final needsResync = _connectionWasLost || _openingSyncFailed;
        _connectionWasLost = false;
        _openingSyncFailed = false;
        if (needsResync) {
          unawaited(_syncAfterReconnect());
        }
      case SyncUnknownType(:final entityType, :final id):
        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'Живая лента: неизвестный тип сущности, курсор сдвинут.',
          context: <String, Object?>{'entity_type': entityType, 'id': id},
        );
    }
  }

  /// Один [syncOnce] и перечитывание счётчика; ленту не переоткрывает.
  Future<bool> _runSyncOnce() async {
    try {
      await ref.read(counterSyncCoordinatorProvider.notifier).runOnce(() async {
        final useCase = await ref.read(syncCounterUseCaseProvider.future);
        await useCase.execute();
      });
    } catch (e, st) {
      logSyncFailure(
        message: 'Обмен на старте живой ленты не удался',
        error: e,
        stackTrace: st,
      );
      return false;
    }

    if (ref.mounted) {
      // syncOnce мог применить входящие конверты без SyncApplied на ленте.
      ref.invalidate(counterStateProvider);
    }
    return true;
  }

  /// После обрыва в переднем плане: догнать сервер и сбросить локальную очередь.
  Future<void> _syncAfterReconnect() async {
    if (!_isForeground || _boundClient == null) {
      return;
    }

    try {
      await ref.read(counterSyncCoordinatorProvider.notifier).runOnce(() async {
        final useCase = await ref.read(syncCounterUseCaseProvider.future);
        await useCase.execute();
      });
    } catch (e, st) {
      logSyncFailure(
        message: 'Обмен после восстановления связи не удался',
        error: e,
        stackTrace: st,
      );
      return;
    }

    if (ref.mounted) {
      ref.invalidate(counterStateProvider);
    }
  }

  void _onError(Object error, StackTrace stackTrace) {
    logSyncFailure(
      message: 'Ошибка потока живой ленты',
      error: error,
      stackTrace: stackTrace,
    );
    state = UlsyncLiveStatus.disconnected;
  }

  static bool _lifecycleStateIsForeground(AppLifecycleState? lifecycleState) {
    return lifecycleState == null ||
        lifecycleState == AppLifecycleState.resumed ||
        lifecycleState == AppLifecycleState.inactive;
  }
}
