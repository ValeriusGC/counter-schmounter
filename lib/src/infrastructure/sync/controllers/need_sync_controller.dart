import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:counter_schmounter/src/application/counter/providers/export_local_operations_use_case_provider.dart';
import 'package:counter_schmounter/src/application/counter/providers/sync_counter_use_case_provider.dart';
import 'package:counter_schmounter/src/domain/counter/constants/counter_entity_ids.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/supabase_user_id_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/counter_state_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';
import 'package:counter_schmounter/src/infrastructure/shared/utils/debouncer.dart';

part 'need_sync_controller.g.dart';

/// Контроллер "нужно синхронизироваться".
///
/// Назначение:
/// - принимать сигналы (realtime / другие источники),
/// - схлопывать их через debounce,
/// - запускать sync,
/// - уведомлять read-model (UI) через invalidate.
///
/// КРИТИЧНО:
/// - помечен keepAlive, так как вызывается из realtime callback через `ref.read`.
/// - без keepAlive debounce умирал бы из-за autoDispose.
///
/// ВАЖНО (account-scope):
/// - при смене user_id нужно сбрасывать pending debounce
///   чтобы не было синка "не того аккаунта" после переключения.
@Riverpod(keepAlive: true)
class NeedSyncController extends _$NeedSyncController {
  Debouncer? _debouncer;

  @override
  bool build() {
    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'NeedSyncController build.',
    );

    _debouncer = Debouncer(
      delay: const Duration(milliseconds: 600),
      debugName: 'NeedSyncController.counter',
    );

    ref.listen<AsyncValue<String?>>(supabaseUserIdProvider, (previous, next) {
      final prevUserId = previous?.asData?.value;
      final nextUserId = next.asData?.value;

      if (prevUserId == nextUserId) {
        return;
      }

      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Auth scope changed. Resetting NeedSyncController state.',
        context: <String, Object?>{
          'prev_user_id': prevUserId,
          'next_user_id': nextUserId,
          'state_before': state,
        },
      );

      // Отменяем pending debounce и сбрасываем флаг needSync.
      _debouncer?.dispose();

      _debouncer = Debouncer(
        delay: const Duration(milliseconds: 600),
        debugName: 'NeedSyncController.counter',
      );

      if (state) {
        state = false;
      }

      // Read-model: [counterStateProvider] смотрит [localOpLogRepositoryProvider], тот
      // — [supabaseUserIdProvider]. Смена user_id пересобирает localOpLog и сама
      // инвалидирует counterState. Явный invalidate отсюда ломал граф (реентрантность).

      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'NeedSyncController reset finished.',
        context: <String, Object?>{
          'prev_user_id': prevUserId,
          'next_user_id': nextUserId,
          'state_after': state,
        },
      );
    });

    ref.onDispose(() {
      _debouncer?.dispose();
      _debouncer = null;
    });

    /// state == true  → sync ожидается
    /// state == false → всё синхронизировано
    return false;
  }

  /// Помечает, что counter требует синхронизации.
  ///
  /// Метод безопасен для частых вызовов.
  Future<void> markCounterNeedSync({required String reason}) async {
    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'NeedSync markCounterNeedSync called.',
      context: <String, Object?>{
        'entity_id': CounterEntityIds.defaultCounter,
        'reason': reason,
        'state_before': state,
      },
    );

    if (!state) {
      state = true;
    }

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'NeedSync marked. Scheduling sync (debounced).',
      context: <String, Object?>{
        'entity_id': CounterEntityIds.defaultCounter,
        'reason': reason,
        'state_after': state,
      },
    );

    final debouncer = _debouncer;
    if (debouncer == null) {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Debouncer is null. Skipping scheduling.',
        context: <String, Object?>{
          'entity_id': CounterEntityIds.defaultCounter,
          'reason': reason,
        },
      );
      return;
    }

    debouncer.run(() async {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Debounce window passed. Starting sync.',
        context: <String, Object?>{
          'entity_id': CounterEntityIds.defaultCounter,
          'reason': reason,
        },
      );

      try {
        final exportUseCase = await ref.read(
          exportLocalOperationsUseCaseProvider.future,
        );

        await exportUseCase.execute(entityId: CounterEntityIds.defaultCounter);

        final useCase = await ref.read(syncCounterUseCaseProvider.future);

        await useCase.execute(entityId: CounterEntityIds.defaultCounter);

        /// 🔑 КРИТИЧНО ДЛЯ WEB:
        /// Явно инвалидируем read-model и сразу читаем его,
        /// чтобы гарантировать пересчёт.
        ref.invalidate(counterStateProvider);

        final debugCounter = ref.read(counterStateProvider);

        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'CounterStateProvider invalidated and read.',
          context: <String, Object?>{
            'counter_state_after_sync': debugCounter.toString(),
          },
        );

        state = false;

        AppLogger.info(
          component: AppLogComponent.sync,
          message: 'Sync finished. NeedSync reset.',
          context: <String, Object?>{
            'entity_id': CounterEntityIds.defaultCounter,
            'reason': reason,
            'state_after': state,
          },
        );
      } catch (e, st) {
        AppLogger.error(
          component: AppLogComponent.sync,
          message: 'Sync failed from NeedSyncController.',
          error: e,
          stackTrace: st,
          context: <String, Object?>{
            'entity_id': CounterEntityIds.defaultCounter,
            'reason': reason,
          },
        );

        /// state остаётся true — сигнал, что sync всё ещё требуется
      }
    });
  }
}
