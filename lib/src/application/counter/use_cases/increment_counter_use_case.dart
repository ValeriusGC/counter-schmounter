import 'package:uuid/uuid.dart';
import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/domain/shared/services/client_identity_service.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

/// Use case для увеличения счетчика.
///
/// Инкапсулирует полную логику увеличения счетчика:
/// - создает [IncrementOperation] с правильными метаданными (op_id, client_id, created_at)
/// - сохраняет операцию в [LocalOpLogRepository]
/// - при наличии клиента ulsync записывает операцию через [UlsyncClient.write],
///   чтобы отметка на отправку и persist журнала не расходились
///
/// Не содержит зависимостей от UI слоя.
class IncrementCounterUseCase {
  /// Создает экземпляр [IncrementCounterUseCase] с указанными зависимостями.
  ///
  /// [syncClientOf] по умолчанию всегда возвращает `null` (тесты без ulsync).
  IncrementCounterUseCase(
    this._clientIdentityService,
    this._localOpLogRepository, {
    Future<UlsyncClient?> Function()? syncClientOf,
  }) : _syncClientOf = syncClientOf ?? (() async => null);

  /// Сервис для получения идентификатора клиента
  final ClientIdentityService _clientIdentityService;

  /// Репозиторий для сохранения операций
  final LocalOpLogRepository _localOpLogRepository;

  /// Поставщик клиента ulsync на момент вызова (сессия могла появиться после build).
  final Future<UlsyncClient?> Function() _syncClientOf;

  /// Выполняет увеличение счетчика.
  ///
  /// Создает новую [IncrementOperation] с уникальным идентификатором,
  /// текущим временем и идентификатором клиента, затем сохраняет её.
  ///
  /// С клиентом ulsync вызывает [UlsyncClient.write]: библиотека **сначала**
  /// ставит отметку «есть неотправленное», **затем** выполняет [persist] —
  /// запись в журнал. Прежний порядок (append, потом отдельный
  /// [UlsyncClient.markChanged] через `unawaited`) допускал состояние
  /// «операция в журнале есть, а в очередь не попала» — отсюда расхождение
  /// 79/76 на двух устройствах (круг 1a, §7.1 решения).
  ///
  /// Без клиента (анонимный режим по решению круга 1) — только локальный
  /// [LocalOpLogRepository.append]; синхронизации нет.
  ///
  /// Возвращает созданную операцию. Ошибка [persist] пробрасывается вызывающему.
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

    final client = await _syncClientOf();
    if (client == null) {
      // Без входа синхронизации нет по решению круга 1: журнал остаётся локальным.
      await _localOpLogRepository.append(operation);
      return operation;
    }

    // Внутри persist — только запись журнала; вызовы клиента оттуда библиотека
    // отвергает (шаг 20), чтобы не зависнуть на общем замке.
    await client.write(
      entityType: 'counter_operation',
      id: operation.opId,
      persist: () => _localOpLogRepository.append(operation),
    );

    AppLogger.info(
      component: AppLogComponent.localOpLog,
      message: 'Increment operation saved to repository',
      context: <String, Object?>{
        'op_id': opId,
        'marked_for_sync': true,
      },
    );

    return operation;
  }
}
