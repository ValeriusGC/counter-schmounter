import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/remote_op_log_repository.dart';
import 'package:counter_schmounter/src/domain/sync/repositories/sync_state_repository.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

/// UseCase initial sync (pull-only) для Counter.
///
/// Алгоритм (строго по плану):
/// 1) прочитать `since` из [SyncStateRepository]
/// 2) fetch remote ops после `since`
/// 3) применить ops в local op-log через append (идемпотентно, т.к. local repo дедуплицирует по op_id)
/// 4) обновить маркер `lastSyncedAt` до максимального `createdAt` применённых ops
///
/// Важно:
/// - UseCase не чистит данные при logout.
/// - Если remote вернул пусто — маркер не меняем.
/// - Ошибки наружу пробрасываем (чтобы их было видно в логах/тестах).
final class SyncCounterUseCase {
  /// Создаёт use case.
  SyncCounterUseCase({
    required RemoteOpLogRepository remoteOpLogRepository,
    required LocalOpLogRepository localOpLogRepository,
    required SyncStateRepository syncStateRepository,
    required String clientId,
  }) : _remoteOpLogRepository = remoteOpLogRepository,
       _localOpLogRepository = localOpLogRepository,
       _syncStateRepository = syncStateRepository,
       _clientId = clientId;

  final RemoteOpLogRepository _remoteOpLogRepository;
  final LocalOpLogRepository _localOpLogRepository;
  final SyncStateRepository _syncStateRepository;
  final String _clientId;

  /// Выполняет pull+apply синхронизацию.
  Future<void> execute({required String entityId}) async {
    final since = await _syncStateRepository.getLastSyncedAt();

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'SyncCounterUseCase started.',
      context: <String, Object?>{
        'client_id': _clientId,
        'entity_id': entityId,
        'since': since?.toIso8601String(),
      },
    );

    final remoteOperations = await _remoteOpLogRepository.fetchAfter(
      entityId: entityId,
      since: since,
    );

    if (remoteOperations.isEmpty) {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'SyncCounterUseCase finished: no new operations.',
        context: <String, Object?>{
          'client_id': _clientId,
          'entity_id': entityId,
        },
      );
      return;
    }

    DateTime? maxCreatedAt;

    for (final CounterOperation operation in remoteOperations) {
      // LocalOpLogRepository гарантирует дедупликацию по op_id.
      await _localOpLogRepository.append(operation);

      final createdAt = operation.createdAt;
      if (maxCreatedAt == null || createdAt.isAfter(maxCreatedAt)) {
        maxCreatedAt = createdAt;
      }
    }

    if (maxCreatedAt != null) {
      await _syncStateRepository.setLastSyncedAt(maxCreatedAt);
    }

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'SyncCounterUseCase finished: applied remote operations.',
      context: <String, Object?>{
        'client_id': _clientId,
        'entity_id': entityId,
        'count': remoteOperations.length,
        'new_since': maxCreatedAt?.toIso8601String(),
      },
    );
  }
}
