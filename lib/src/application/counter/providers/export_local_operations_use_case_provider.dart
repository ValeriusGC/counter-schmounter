import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/application/counter/use_cases/export_local_operations_use_case.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/remote_op_log_export_repository.dart';
import 'package:counter_schmounter/src/domain/sync/repositories/sync_state_repository.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/remote_op_log_export_repository_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/providers/client_identity_service_provider.dart';
import 'package:counter_schmounter/src/infrastructure/sync/providers/sync_state_repository_provider.dart';

part 'export_local_operations_use_case_provider.g.dart';

/// Провайдер [ExportLocalOperationsUseCase].
///
/// Возвращает Future, т.к.:
/// - [SyncStateRepository] инициализируется асинхронно;
/// - use case создаётся только после полной готовности инфраструктуры.
///
/// Использование:
/// ```dart
/// final exportUseCase = await ref.read(
///   exportLocalOperationsUseCaseProvider.future,
/// );
/// ```
@riverpod
Future<ExportLocalOperationsUseCase> exportLocalOperationsUseCase(
  Ref ref,
) async {
  final LocalOpLogRepository localOpLogRepository = ref.watch(
    localOpLogRepositoryProvider,
  );

  final RemoteOpLogExportRepository remoteOpLogExportRepository = ref.watch(
    remoteOpLogExportRepositoryProvider,
  );

  final SyncStateRepository syncStateRepository = await ref.watch(
    syncStateRepositoryProvider.future,
  );

  final clientIdentityService = ref.watch(clientIdentityServiceProvider);
  final clientId = clientIdentityService.clientId;

  return ExportLocalOperationsUseCase(
    localOpLogRepository: localOpLogRepository,
    remoteOpLogExportRepository: remoteOpLogExportRepository,
    syncStateRepository: syncStateRepository,
    clientId: clientId,
  );
}
