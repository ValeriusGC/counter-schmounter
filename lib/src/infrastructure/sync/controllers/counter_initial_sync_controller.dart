import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
/// - один обмен ulsync ([SyncCounterUseCase.execute] → `syncOnce`);
/// - invalidate read-model;
/// - enable realtime gate (шаг 16 снимет Realtime, gate пока оставляем).
///
/// Триггер:
/// - `ref.listen(..., fireImmediately: true)` на [supabaseUserIdProvider]
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

    if (nextUserId == null) {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Logout detected. Switching to anonymous scope.',
        context: <String, Object?>{'prev_user_id': prevUserId},
      );

      _lastSyncedUserId = null;
      return;
    }

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
      final asyncUid = ref.read(supabaseUserIdProvider).asData?.value;
      final sdkUid = Supabase.instance.client.auth.currentUser?.id;
      final currentUserId = asyncUid ?? sdkUid;

      return currentUserId == nextUserId;
    }

    Future<bool> runInitialSyncOnce() async {
      final localRepo = ref.read(localOpLogRepositoryProvider);
      await localRepo.initialize();

      if (!isPipelineValid()) {
        return false;
      }

      final syncUseCase = await ref.read(syncCounterUseCaseProvider.future);

      if (!isPipelineValid()) {
        return false;
      }

      await syncUseCase.execute();

      if (!isPipelineValid()) {
        return false;
      }

      ref.invalidate(counterStateProvider);

      ref
          .read(realtimeGateControllerProvider.notifier)
          .enable(reason: 'initial_sync_ulsync_finished');

      AppLogger.info(
        component: AppLogComponent.realtime,
        message: 'Realtime gate opened after initial ulsync sync.',
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
              'Initial sync pipeline failed (ulsync). '
              'attempt=$attempt/$maxAttempts',
          error: e,
          stackTrace: st,
          context: <String, Object?>{
            'user_id': nextUserId,
            'entity_id': CounterEntityIds.defaultCounter,
            'pipeline_seq': pipelineSeq,
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
