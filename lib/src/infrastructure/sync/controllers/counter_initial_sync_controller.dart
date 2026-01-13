import 'package:riverpod_annotation/riverpod_annotation.dart';

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
/// - смена `supabaseUserId`: `<any> → userId`
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
    ref.listen<AsyncValue<String?>>(supabaseUserIdProvider, (
      previous,
      next,
    ) async {
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

        // Важно: read-model должен пересчитаться для нового scope (anonymous).
        ref.invalidate(counterStateProvider);

        // Realtime gate закрывается отдельным контроллером (уже реализовано).
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

      // Старт нового pipeline.
      _pipelineSeq += 1;
      final int pipelineSeq = _pipelineSeq;

      // Фиксируем, что текущий pipeline относится к этому user_id.
      _lastSyncedUserId = nextUserId;

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
        final currentUserId = ref.read(supabaseUserIdProvider).asData?.value;
        return currentUserId == nextUserId;
      }

      try {
        // 0) Гарантируем, что LocalOpLogRepository для текущего scope инициализирован.
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
          return;
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

        // 1) PULL
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
          return;
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
          return;
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

        // 2) PUSH / EXPORT
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
          return;
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
          return;
        }

        // 3) Read-model invalidate (важно для web)
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

        // 4) Realtime enable (A3 + B1 порядок)
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
      } catch (e, st) {
        AppLogger.error(
          component: AppLogComponent.sync,
          message: 'Initial sync pipeline failed (pull/export).',
          error: e,
          stackTrace: st,
          context: <String, Object?>{
            'user_id': nextUserId,
            'entity_id': CounterEntityIds.defaultCounter,
            'pipeline_seq': pipelineSeq,
          },
        );

        // Важно:
        // - gate НЕ открываем, т.к. pipeline не завершился успешно.
        AppLogger.info(
          component: AppLogComponent.realtime,
          message: 'A3/B1: realtime gate remains closed due to failure.',
          context: <String, Object?>{
            'user_id': nextUserId,
            'entity_id': CounterEntityIds.defaultCounter,
            'pipeline_seq': pipelineSeq,
          },
        );
      }
    });
  }
}
