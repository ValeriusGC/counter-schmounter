import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';

import 'package:supa_counter/src/domain/counter/operations/increment_operation.dart';
import 'package:supa_counter/src/domain/shared/services/client_identity_service.dart';
import 'package:supa_counter/src/infrastructure/shared/providers/client_identity_service_provider.dart';

part 'increment_counter_use_case.g.dart';

/// Use case для создания операции увеличения счетчика.
///
/// Инкапсулирует логику создания [IncrementOperation] с правильными метаданными:
/// - генерирует уникальный `op_id` (UUID v4)
/// - устанавливает `created_at` (текущее время)
/// - использует `client_id` из [ClientIdentityService]
///
/// Не содержит зависимостей от UI или инфраструктуры (кроме ClientIdentityService).
class IncrementCounterUseCase {
  /// Создает экземпляр [IncrementCounterUseCase] с указанным сервисом идентификации клиента.
  IncrementCounterUseCase(this._clientIdentityService);

  /// Сервис для получения идентификатора клиента
  final ClientIdentityService _clientIdentityService;

  /// Выполняет создание операции увеличения счетчика.
  ///
  /// Генерирует новую [IncrementOperation] с уникальным идентификатором,
  /// текущим временем и идентификатором клиента.
  ///
  /// Возвращает созданную операцию.
  IncrementOperation execute() {
    final clientId = _clientIdentityService.clientId;
    final opId = const Uuid().v4();
    final createdAt = DateTime.now();

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

    return operation;
  }
}

/// Провайдер для [IncrementCounterUseCase].
///
/// Использует [clientIdentityServiceProvider] для получения сервиса идентификации клиента.
@riverpod
IncrementCounterUseCase incrementCounterUseCase(Ref ref) {
  final clientIdentityService = ref.watch(clientIdentityServiceProvider);
  return IncrementCounterUseCase(clientIdentityService);
}
