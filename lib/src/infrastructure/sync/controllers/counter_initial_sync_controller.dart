import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:counter_schmounter/src/application/counter/providers/export_local_operations_use_case_provider.dart';
import 'package:counter_schmounter/src/application/counter/providers/sync_counter_use_case_provider.dart';
import 'package:counter_schmounter/src/domain/counter/constants/counter_entity_ids.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/supabase_user_id_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/counter_state_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';
import 'package:counter_schmounter/src/infrastructure/realtime/controllers/realtime_gate_controller.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

part 'counter_initial_sync_controller.g.dart';

/// Контроллер стартового пайплайна синхронизации после авторизации.
///
/// Назначение:
/// - запускает стартовую синхронизацию на КАЖДЫЙ новый аккаунт (user_id);
/// - обеспечивает правильный порядок (B1/A3):
///   1) pull (fetch remote op-log → apply)
///   2) push/export (export local ops → remote)
///   3) invalidate read-model
///   4) enable realtime gate
///
/// Триггер:
/// - `ref.listen(..., fireImmediately: true)` на [supabaseUserIdProvider]
/// - страховка: `ref.watch` того же провайдера + отложенный запуск (`Future(() async …)`), если realtime gate всё ещё закрыт
///   (редкий порядок инициализации StreamProvider / холодный старт с уже восстановленной сессией).
///
/// Важно:
/// - realtime НЕ включается, пока pipeline не завершён успешно;
/// - при любой ошибке pipeline realtime gate остаётся закрытым.
@Riverpod(keepAlive: true)
class CounterInitialSyncController extends _$CounterInitialSyncController {
  String? _lastSyncedUserId;

  int _pipelineSeq = 0;

  @override
  void build() {
    final authSnapshot = ref.watch(supabaseUserIdProvider);

    ref.listen<AsyncValue<String?>>(supabaseUserIdProvider, (previous, next) {
      unawaited(_handleSupabaseAuthAsync(previous, next));
    }, fireImmediately: true);

    // Страховка поверх listen: один раз после того как AsyncValue содержит user_id,
    // если gate ещё не открыт — форсим тот же обработчик (другие устройства / cold start).
    authSnapshot.maybeWhen(
      data: (userId) {
        if (userId == null) {
          return;
        }
        unawaited(
          Future<void>(() async {
            if (!ref.mounted) {
              return;
            }
            final gateOpen = ref.read(realtimeGateControllerProvider);
            if (gateOpen && _lastSyncedUserId == userId) {
              return;
            }
            await _handleSupabaseAuthAsync(
              null,
              ref.read(supabaseUserIdProvider),
            );
          }),
        );
      },
      orElse: () {},
    );
  }

  Future<void> _handleSupabaseAuthAsync(
    AsyncValue<String?>? previous,
    AsyncValue<String?> next,
  ) async {
    // Первое fireImmediately может быть ещё AsyncLoading у StreamProvider.
    if (next.isLoading) {
      return;
    }

    final prevUserId = previous?.asData?.value;
    final nextUserId = next.asData?.value;

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'Auth state observed in CounterInitialSyncController.',
      context: <String, Object?>{
        'prev_user_id': prevUserId,
        'next_user_id': nextUserId,
        'last_synced_user_id': _lastSyncedUserId,
      },
    );

    // Logout -> переход в anonymous scope.
    if (nextUserId == null) {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Logout detected. Switching to anonymous scope.',
        context: <String, Object?>{'prev_user_id': prevUserId},
      );

      _lastSyncedUserId = null;

      // counterState обновится через localOpLogRepository (см. NeedSyncController).
      return;
    }

    // Авторизованы. Если user_id не изменился и уже синкались — выходим.
    if (_lastSyncedUserId == nextUserId) {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Initial sync skipped: already synced for this user.',
        context: <String, Object?>{
          'user_id': nextUserId,
          'entity_id': CounterEntityIds.defaultCounter,
        },
      );
      return;
    }

    _pipelineSeq += 1;
    final int pipelineSeq = _pipelineSeq;

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'User changed / first login detected. Starting initial sync.',
      context: <String, Object?>{
        'user_id': nextUserId,
        'entity_id': CounterEntityIds.defaultCounter,
        'pipeline_seq': pipelineSeq,
      },
    );

    bool isPipelineValid() {
      if (!ref.mounted) {
        return false;
      }
      if (_pipelineSeq != pipelineSeq) {
        return false;
      }
      // StreamProvider между await может ненадолго вернуться в AsyncLoading без asData —
      // подстраховываемся текущей сессией из Supabase SDK.
      final asyncUid = ref.read(supabaseUserIdProvider).asData?.value;
      final sdkUid = Supabase.instance.client.auth.currentUser?.id;
      final currentUserId = asyncUid ?? sdkUid;

      return currentUserId == nextUserId;
    }

    Future<bool> runInitialSyncOnce() async {
      final localRepo = ref.read(localOpLogRepositoryProvider);
      await localRepo.initialize();

      if (!isPipelineValid()) {
        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'Initial sync pipeline aborted after local repo init.',
          context: <String, Object?>{
            'user_id': nextUserId,
            'entity_id': CounterEntityIds.defaultCounter,
            'pipeline_seq': pipelineSeq,
          },
        );
        return false;
      }

      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Local op-log repository initialized for current scope.',
        context: <String, Object?>{
          'user_id': nextUserId,
          'entity_id': CounterEntityIds.defaultCounter,
          'pipeline_seq': pipelineSeq,
        },
      );

      final syncUseCase = await ref.read(syncCounterUseCaseProvider.future);

      if (!isPipelineValid()) {
        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'Initial sync pipeline aborted before pull.',
          context: <String, Object?>{
            'user_id': nextUserId,
            'entity_id': CounterEntityIds.defaultCounter,
            'pipeline_seq': pipelineSeq,
          },
        );
        return false;
      }

      await syncUseCase.execute(entityId: CounterEntityIds.defaultCounter);

      if (!isPipelineValid()) {
        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'Initial sync pipeline aborted after pull.',
          context: <String, Object?>{
            'user_id': nextUserId,
            'entity_id': CounterEntityIds.defaultCounter,
            'pipeline_seq': pipelineSeq,
          },
        );
        return false;
      }

      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Initial pull finished. Starting export (push).',
        context: <String, Object?>{
          'user_id': nextUserId,
          'entity_id': CounterEntityIds.defaultCounter,
          'pipeline_seq': pipelineSeq,
        },
      );

      final exportUseCase = await ref.read(
        exportLocalOperationsUseCaseProvider.future,
      );

      if (!isPipelineValid()) {
        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'Initial sync pipeline aborted before export.',
          context: <String, Object?>{
            'user_id': nextUserId,
            'entity_id': CounterEntityIds.defaultCounter,
            'pipeline_seq': pipelineSeq,
          },
        );
        return false;
      }

      await exportUseCase.execute(entityId: CounterEntityIds.defaultCounter);

      if (!isPipelineValid()) {
        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'Initial sync pipeline aborted after export.',
          context: <String, Object?>{
            'user_id': nextUserId,
            'entity_id': CounterEntityIds.defaultCounter,
            'pipeline_seq': pipelineSeq,
          },
        );
        return false;
      }

      ref.invalidate(counterStateProvider);

      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Initial sync finished. CounterStateProvider invalidated.',
        context: <String, Object?>{
          'user_id': nextUserId,
          'entity_id': CounterEntityIds.defaultCounter,
          'pipeline_seq': pipelineSeq,
        },
      );

      ref
          .read(realtimeGateControllerProvider.notifier)
          .enable(reason: 'initial_sync_pull_and_export_finished');

      AppLogger.info(
        component: AppLogComponent.realtime,
        message: 'A3/B1: realtime gate opened after pull + export.',
        context: <String, Object?>{
          'user_id': nextUserId,
          'entity_id': CounterEntityIds.defaultCounter,
          'pipeline_seq': pipelineSeq,
        },
      );

      return true;
    }

    const maxAttempts = 3;
    var succeeded = false;
    var attempt = 0;

    while (!succeeded && attempt < maxAttempts) {
      attempt++;

      if (!isPipelineValid()) {
        return;
      }

      try {
        succeeded = await runInitialSyncOnce();
        if (!succeeded) {
          return;
        }
      } catch (e, st) {
        AppLogger.error(
          component: AppLogComponent.sync,
          message:
              'Initial sync pipeline failed (pull/export). '
              'attempt=$attempt/$maxAttempts',
          error: e,
          stackTrace: st,
          context: <String, Object?>{
            'user_id': nextUserId,
            'entity_id': CounterEntityIds.defaultCounter,
            'pipeline_seq': pipelineSeq,
          },
        );

        AppLogger.info(
          component: AppLogComponent.realtime,
          message: 'A3/B1: realtime gate remains closed due to failure.',
          context: <String, Object?>{
            'user_id': nextUserId,
            'entity_id': CounterEntityIds.defaultCounter,
            'pipeline_seq': pipelineSeq,
            'attempt': attempt,
            'max_attempts': maxAttempts,
          },
        );

        if (attempt >= maxAttempts || !isPipelineValid()) {
          return;
        }

        await Future<void>.delayed(const Duration(seconds: 2));
      }
    }

    if (succeeded) {
      _lastSyncedUserId = nextUserId;
    }
  }
}
