import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/application/counter/providers/sync_counter_use_case_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/counter_state_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';
import 'package:counter_schmounter/src/infrastructure/sync/controllers/counter_sync_coordinator.dart';
import 'package:counter_schmounter/src/infrastructure/sync/controllers/ulsync_catch_up.dart';
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
/// Обмен гоняет [CounterSyncCoordinator] до тишины. Поводы одни и те же:
/// старт, возврат на экран, «связь есть», плюс с экрана, таймер 3 с.
/// Конверты применяет библиотека; журнал сам будит экран. В фоне HTTP
/// закрывается через [UlsyncClient.close], потому что отмена подписки на
/// broadcast не рвёт SSE.
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

  /// Пока на экране — раз в 3 с ещё один обмен. Подстраховка, не эвристика.
  Timer? _safety;

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
      _safety?.cancel();
      _safety = null;
      _lifecycle?.dispose();
      _lifecycle = null;
      unawaited(_sub?.cancel());
      _sub = null;
    });

    return UlsyncLiveStatus.disconnected;
  }

  /// Вызывается [AppLifecycleListener.onResume] и тестами.
  Future<void> onAppResumed() async {
    _isForeground = true;

    final client = await ref.read(ulsyncClientProvider.future);
    if (client == null) {
      state = UlsyncLiveStatus.disconnected;
      _stopSafety();
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
    _stopSafety();

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
      _stopSafety();
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
    if (!ref.mounted) {
      return;
    }

    if (!_isForeground || !identical(_boundClient, client)) {
      return;
    }

    // Ленту открываем сразу: нет сервера — стучимся сами, не ждём, пока
    // один обмен 30 секунд убедится, что никто не отвечает.
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
      return;
    }

    _startSafety();
    await _runSyncOnce();
  }

  void _onEvent(SyncEvent event) {
    switch (event) {
      case SyncApplied():
        ref.invalidate(counterStateProvider);
      case SyncCursorAdvanced():
        break;
      case SyncConnectionLost():
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
        unawaited(_runSyncOnce());
      case SyncUnknownType(:final entityType, :final id):
        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'Живая лента: неизвестный тип сущности, курсор сдвинут.',
          context: <String, Object?>{'entity_type': entityType, 'id': id},
        );
    }
  }

  /// Обмен до тишины и перечитывание счётчика; ленту не переоткрывает.
  Future<bool> _runSyncOnce() async {
    if (!_isForeground || !ref.mounted) {
      return false;
    }

    try {
      await ref.read(counterSyncCoordinatorProvider.notifier).runOnce(() async {
        final useCase = await ref.read(syncCounterUseCaseProvider.future);
        await useCase.execute();
      });
    } catch (e, st) {
      logSyncFailure(
        message: 'Обмен живой ленты не удался',
        error: e,
        stackTrace: st,
      );
      if (ref.mounted && state != UlsyncLiveStatus.connected) {
        state = UlsyncLiveStatus.disconnected;
      }
      return false;
    }

    if (ref.mounted) {
      ref.invalidate(counterStateProvider);
    }
    return true;
  }

  void _startSafety() {
    _safety?.cancel();
    _safety = Timer.periodic(kUlsyncCatchUpSafetyInterval, (_) {
      unawaited(_runSyncOnce());
    });
  }

  void _stopSafety() {
    _safety?.cancel();
    _safety = null;
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
