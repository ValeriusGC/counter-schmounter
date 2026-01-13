import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/supabase_user_id_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

part 'realtime_gate_controller.g.dart';

/// Gate (флаг) разрешения realtime.
///
/// Назначение:
/// - realtime НЕ должен включаться автоматически по факту логина;
/// - realtime включается ТОЛЬКО после завершения bootstrap + pull (initial sync);
/// - gate должен быть явным, тестируемым и логируемым.
///
/// Lifecycle:
/// - по умолчанию `false`
/// - после успешного initial sync -> `true`
/// - при logout (user_id -> null) -> принудительно `false`
///
/// Важно:
/// - keepAlive, т.к. gate используется как инфраструктурный глобальный флаг,
///   и должен быть стабилен при пересборках UI.
@Riverpod(keepAlive: true)
class RealtimeGateController extends _$RealtimeGateController {
  @override
  bool build() {
    AppLogger.info(
      component: AppLogComponent.realtime,
      message: 'RealtimeGateController build.',
      context: <String, Object?>{'initial_state': false},
    );

    ref.listen<AsyncValue<String?>>(supabaseUserIdProvider, (previous, next) {
      final userId = next.asData?.value;

      if (userId == null && state) {
        AppLogger.info(
          component: AppLogComponent.realtime,
          message: 'Logout detected. Closing realtime gate.',
          context: <String, Object?>{'state_before': state},
        );
        state = false;
      }
    });

    return false;
  }

  /// Открывает gate realtime.
  ///
  /// Должен вызываться ТОЛЬКО после успешного bootstrap + pull.
  void enable({required String reason}) {
    if (state) {
      AppLogger.info(
        component: AppLogComponent.realtime,
        message: 'Realtime gate already enabled. Skipping.',
        context: <String, Object?>{'reason': reason},
      );
      return;
    }

    state = true;

    AppLogger.info(
      component: AppLogComponent.realtime,
      message: 'Realtime gate enabled.',
      context: <String, Object?>{'reason': reason},
    );
  }

  /// Закрывает gate realtime.
  ///
  /// В текущем шаге используется для явного отключения (если понадобится),
  /// но основной сценарий закрытия — logout (см. listener в build()).
  void disable({required String reason}) {
    if (!state) {
      AppLogger.info(
        component: AppLogComponent.realtime,
        message: 'Realtime gate already disabled. Skipping.',
        context: <String, Object?>{'reason': reason},
      );
      return;
    }

    state = false;

    AppLogger.info(
      component: AppLogComponent.realtime,
      message: 'Realtime gate disabled.',
      context: <String, Object?>{'reason': reason},
    );
  }
}
