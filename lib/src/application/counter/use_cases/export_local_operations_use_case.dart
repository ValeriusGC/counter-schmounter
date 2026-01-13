import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/remote_op_log_export_repository.dart';
import 'package:counter_schmounter/src/domain/sync/repositories/sync_state_repository.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

/// UseCase экспорта (push) локальных операций счётчика.
///
/// Алгоритм (B1):
/// 1) прочитать `lastExportedAt` из [SyncStateRepository]
/// 2) прочитать все локальные операции из [LocalOpLogRepository]
/// 3) отфильтровать операции:
///    - операция создана текущей репликой (`op.clientId == clientId`)
///    - и `createdAt > lastExportedAt` (если маркер задан)
/// 4) отправить их в remote op-log через [RemoteOpLogExportRepository]
/// 5) при успехе сохранить новый `lastExportedAt` как max(createdAt) экспортированных ops
///
/// Важно:
/// - UseCase не зависит от UI.
/// - UseCase не включает realtime.
/// - Ошибки пробрасываются наружу (чтобы было видно в логах и тестах).
///
/// Почему фильтр по `clientId` обязателен:
/// - после initial pull локальный op-log содержит операции, пришедшие с сервера
/// - эти операции могли быть созданы другой репликой (другой `clientId`)
/// - их нельзя экспортировать обратно, иначе каждый новый клиент будет “пушить” весь импорт.
final class ExportLocalOperationsUseCase {
  /// Создаёт use case.
  ExportLocalOperationsUseCase({
    required LocalOpLogRepository localOpLogRepository,
    required RemoteOpLogExportRepository remoteOpLogExportRepository,
    required SyncStateRepository syncStateRepository,
    required String clientId,
  }) : _localOpLogRepository = localOpLogRepository,
       _remoteOpLogExportRepository = remoteOpLogExportRepository,
       _syncStateRepository = syncStateRepository,
       _clientId = clientId;

  final LocalOpLogRepository _localOpLogRepository;
  final RemoteOpLogExportRepository _remoteOpLogExportRepository;
  final SyncStateRepository _syncStateRepository;
  final String _clientId;

  /// Выполняет экспорт локальных операций для [entityId].
  Future<void> execute({required String entityId}) async {
    final lastExportedAt = _syncStateRepository.getLastExportedAt();

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'ExportLocalOperationsUseCase started.',
      context: <String, Object?>{
        'client_id': _clientId,
        'entity_id': entityId,
        'last_exported_at': lastExportedAt?.toIso8601String(),
      },
    );

    final allLocalOps = await _localOpLogRepository.getAll();

    final opsToExport = _filterOperationsToExport(
      operations: allLocalOps,
      lastExportedAt: lastExportedAt,
      clientId: _clientId,
    );

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'Filtered operations for export.',
      context: <String, Object?>{
        'client_id': _clientId,
        'entity_id': entityId,
        'all_ops_count': allLocalOps.length,
        'to_export_count': opsToExport.length,
        'last_exported_at': lastExportedAt?.toIso8601String(),
      },
    );

    if (opsToExport.isEmpty) {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'ExportLocalOperationsUseCase finished: nothing to export.',
        context: <String, Object?>{
          'client_id': _clientId,
          'entity_id': entityId,
          'local_ops_count': allLocalOps.length,
        },
      );
      return;
    }

    await _remoteOpLogExportRepository.exportOperations(
      entityId: entityId,
      operations: opsToExport,
    );

    final newLastExportedAt = _maxCreatedAt(opsToExport);

    await _syncStateRepository.setLastExportedAt(newLastExportedAt);

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'ExportLocalOperationsUseCase finished: exported operations.',
      context: <String, Object?>{
        'client_id': _clientId,
        'entity_id': entityId,
        'exported_count': opsToExport.length,
        'new_last_exported_at': newLastExportedAt.toIso8601String(),
      },
    );
  }

  /// Фильтрует список операций к экспорту.
  ///
  /// Правила:
  /// - экспортируем только операции текущей реплики (`op.clientId == clientId`)
  /// - если [lastExportedAt] == null → экспортируем все операции этой реплики
  /// - иначе → экспортируем операции этой реплики с `createdAt > lastExportedAt`
  List<CounterOperation> _filterOperationsToExport({
    required List<CounterOperation> operations,
    required DateTime? lastExportedAt,
    required String clientId,
  }) {
    final createdByThisClient = operations.where(
      (op) => op.clientId == clientId,
    );

    if (lastExportedAt == null) {
      return createdByThisClient.toList();
    }

    return createdByThisClient
        .where((op) => op.createdAt.isAfter(lastExportedAt))
        .toList();
  }

  /// Находит максимальный `createdAt` среди операций.
  DateTime _maxCreatedAt(List<CounterOperation> operations) {
    var maxValue = operations.first.createdAt;
    for (final op in operations.skip(1)) {
      if (op.createdAt.isAfter(maxValue)) {
        maxValue = op.createdAt;
      }
    }
    return maxValue;
  }
}
