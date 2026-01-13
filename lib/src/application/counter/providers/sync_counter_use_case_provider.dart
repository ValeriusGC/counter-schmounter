import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:counter_schmounter/src/application/counter/use_cases/sync_counter_use_case.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/remote_op_log_repository.dart';
import 'package:counter_schmounter/src/domain/sync/repositories/sync_state_repository.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/remote_op_log_repository_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/providers/client_identity_service_provider.dart';
import 'package:counter_schmounter/src/infrastructure/sync/providers/sync_state_repository_provider.dart';

part 'sync_counter_use_case_provider.g.dart';

/// Провайдер [SyncCounterUseCase].
@riverpod
Future<SyncCounterUseCase> syncCounterUseCase(Ref ref) async {
  final RemoteOpLogRepository remoteRepo = ref.watch(
    remoteOpLogRepositoryProvider,
  );

  final LocalOpLogRepository localRepo = ref.watch(
    localOpLogRepositoryProvider,
  );

  final SyncStateRepository syncStateRepo = await ref.watch(
    syncStateRepositoryProvider.future,
  );

  final clientIdService = ref.watch(clientIdentityServiceProvider);
  final clientId = clientIdService.clientId;

  return SyncCounterUseCase(
    remoteOpLogRepository: remoteRepo,
    localOpLogRepository: localRepo,
    syncStateRepository: syncStateRepo,
    clientId: clientId,
  );
}
