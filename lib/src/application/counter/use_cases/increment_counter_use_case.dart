import 'dart:developer' as developer;

import 'package:uuid/uuid.dart';

import 'package:supa_counter/src/domain/counter/operations/increment_operation.dart';
import 'package:supa_counter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:supa_counter/src/domain/shared/services/client_identity_service.dart';

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

    developer.log(
      '➕ Creating increment operation',
      name: 'IncrementCounterUseCase',
      error: null,
      stackTrace: null,
      level: 700, // FINE level
    );
    developer.log(
      '   Operation ID: $opId',
      name: 'IncrementCounterUseCase',
      error: null,
      stackTrace: null,
      level: 600, // FINER level
    );
    developer.log(
      '   Client ID: $clientId',
      name: 'IncrementCounterUseCase',
      error: null,
      stackTrace: null,
      level: 600, // FINER level
    );

    // Сохраняем операцию в repository
    await _localOpLogRepository.append(operation);

    developer.log(
      '✅ Increment operation saved to repository',
      name: 'IncrementCounterUseCase',
      error: null,
      stackTrace: null,
      level: 700, // FINE level
    );

    return operation;
  }
}
