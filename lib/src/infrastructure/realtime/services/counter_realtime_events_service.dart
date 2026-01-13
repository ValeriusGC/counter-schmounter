import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/supabase_user_id_provider.dart';
import 'package:counter_schmounter/src/infrastructure/realtime/controllers/realtime_gate_controller.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';
import 'package:counter_schmounter/src/infrastructure/sync/controllers/need_sync_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'counter_realtime_events_service.g.dart';

/// Realtime-сервис для Counter.
///
/// Подписывается на INSERT в `counter_operations`
/// и переводит события в `needSync`, не применяя payload напрямую.
///
/// A3 lifecycle:
/// - realtime НЕ включается автоматически по факту логина
/// - realtime включается ТОЛЬКО когда:
///   - `user_id != null`
///   - и `RealtimeGateController == true` (после bootstrap + pull)
///
/// Жизненный цикл:
/// - при `user_id == null` → отписываемся + закрываем канал
/// - при `gate == false` → отписываемся + закрываем канал
/// - при `user_id != null && gate == true` → подписываемся
@riverpod
class CounterRealtimeEventsService extends _$CounterRealtimeEventsService {
  RealtimeChannel? _channel;

  String? _lastUserId;
  bool _isGateOpen = false;

  @override
  void build() {
    ref.listen<AsyncValue<String?>>(supabaseUserIdProvider, (previous, next) {
      final userId = next.asData?.value;
      _lastUserId = userId;
      _reconcile();
    });

    ref.listen<bool>(realtimeGateControllerProvider, (previous, next) {
      _isGateOpen = next;
      _reconcile();
    });

    ref.onDispose(() async {
      await _disposeChannel();
    });
  }

  void _reconcile() {
    final userId = _lastUserId;
    final gateOpen = _isGateOpen;

    if (userId == null) {
      AppLogger.info(
        component: AppLogComponent.realtime,
        message:
            'A3: user is null. Disabling realtime subscription (dispose channel).',
      );
      _disposeChannel();
      return;
    }

    if (!gateOpen) {
      AppLogger.info(
        component: AppLogComponent.realtime,
        message:
            'A3: realtime gate is closed. Not subscribing (dispose channel).',
        context: <String, Object?>{'user_id': userId},
      );
      _disposeChannel();
      return;
    }

    AppLogger.info(
      component: AppLogComponent.realtime,
      message:
          'A3: gate open + user authorized. Enabling realtime subscription.',
      context: <String, Object?>{'user_id': userId},
    );

    _ensureSubscribed(userId);
  }

  void _ensureSubscribed(String userId) {
    if (_channel != null) {
      // Уже подписаны — повторно не подписываемся.
      return;
    }

    final supabase = Supabase.instance.client;
    final channelName = 'counter_ops:$userId';

    _channel = supabase.channel(channelName);

    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'counter_operations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final opId = payload.newRecord['op_id']?.toString();
            final createdAt = payload.newRecord['created_at']?.toString();

            AppLogger.info(
              component: AppLogComponent.realtime,
              message: 'Realtime INSERT received. Marking needSync.',
              context: <String, Object?>{
                'user_id': userId,
                'op_id': opId,
                'created_at': createdAt,
              },
            );

            // Не await — realtime callback должен быть быстрым.
            ref
                .read(needSyncControllerProvider.notifier)
                .markCounterNeedSync(reason: 'realtime_insert');
          },
        )
        .subscribe((status, error) {
          if (error != null) {
            AppLogger.error(
              component: AppLogComponent.realtime,
              message: 'Realtime subscription error.',
              error: error,
              context: <String, Object?>{
                'user_id': userId,
                'channel': channelName,
                'status': status.name,
              },
            );
            return;
          }

          AppLogger.info(
            component: AppLogComponent.realtime,
            message: 'Realtime subscription status changed.',
            context: <String, Object?>{
              'user_id': userId,
              'channel': channelName,
              'status': status.name,
            },
          );
        });
  }

  Future<void> _disposeChannel() async {
    final channel = _channel;
    if (channel == null) {
      return;
    }

    _channel = null;

    try {
      await Supabase.instance.client.removeChannel(channel);
      AppLogger.info(
        component: AppLogComponent.realtime,
        message: 'Realtime channel removed.',
      );
    } catch (e, st) {
      AppLogger.error(
        component: AppLogComponent.realtime,
        message: 'Failed to remove realtime channel.',
        error: e,
        stackTrace: st,
      );
    }
  }
}
