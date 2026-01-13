import 'package:uuid/uuid.dart';

import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/domain/shared/services/client_identity_service.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

/// Use case для увеличения счетчика.
///
/// Инкапсулирует полную логику увеличения счетчика:
/// - создает [IncrementOperation] с правильными метаданными (op_id, client_id, created_at)
/// - сохраняет операцию в [LocalOpLogRepository]
///
/// Не содержит зависимостей от UI слоя.
class IncrementCounterUseCase {
  /// Создает экземпляр [IncrementCounterUseCase] с указанными зависимостями.
  IncrementCounterUseCase(
    this._clientIdentityService,
    this._localOpLogRepository,
  );

  /// Сервис для получения идентификатора клиента
  final ClientIdentityService _clientIdentityService;

  /// Репозиторий для сохранения операций
  final LocalOpLogRepository _localOpLogRepository;

  /// Выполняет увеличение счетчика.
  ///
  /// Создает новую [IncrementOperation] с уникальным идентификатором,
  /// текущим временем и идентификатором клиента, затем сохраняет её
  /// в [LocalOpLogRepository].
  ///
  /// Возвращает созданную операцию.
  Future<IncrementOperation> execute() async {
    final clientId = _clientIdentityService.clientId;
    final opId = const Uuid().v4();
    final createdAt = DateTime.now().toUtc();

    final operation = IncrementOperation(
      opId: opId,
      clientId: clientId,
      createdAt: createdAt,
    );

    AppLogger.info(
      component: AppLogComponent.localOpLog,
      message: 'Creating increment operation',
      context: <String, Object?>{'op_id': opId, 'client_id': clientId},
    );

    // Сохраняем операцию в repository
    await _localOpLogRepository.append(operation);

    AppLogger.info(
      component: AppLogComponent.localOpLog,
      message: 'Increment operation saved to repository',
      context: <String, Object?>{'op_id': opId},
    );

    return operation;
  }
}
