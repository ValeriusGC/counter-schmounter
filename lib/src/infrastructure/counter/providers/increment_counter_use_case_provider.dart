import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:supa_counter/src/application/counter/use_cases/increment_counter_use_case.dart';
import 'package:supa_counter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';
import 'package:supa_counter/src/infrastructure/shared/providers/client_identity_service_provider.dart';

part 'increment_counter_use_case_provider.g.dart';

/// Провайдер для [IncrementCounterUseCase].
///
/// Использует [clientIdentityServiceProvider] и [localOpLogRepositoryProvider]
/// для получения зависимостей.
@riverpod
IncrementCounterUseCase incrementCounterUseCase(Ref ref) {
  final clientIdentityService = ref.watch(clientIdentityServiceProvider);
  final localOpLogRepository = ref.watch(localOpLogRepositoryProvider);
  return IncrementCounterUseCase(clientIdentityService, localOpLogRepository);
}
