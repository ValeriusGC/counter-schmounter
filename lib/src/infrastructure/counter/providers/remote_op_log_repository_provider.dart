import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/counter/repositories/remote_op_log_repository.dart';
import '../../shared/providers/client_identity_service_provider.dart';
import '../repositories/remote_op_log_repository_impl.dart';

part 'remote_op_log_repository_provider.g.dart';

/// Провайдер удалённого op-log репозитория.
///
/// На Шаге 8 репозиторий используется read-only.
@riverpod
RemoteOpLogRepository remoteOpLogRepository(Ref ref) {
  final clientIdService = ref.watch(clientIdentityServiceProvider);
  final clientId = clientIdService.clientId;

  return RemoteOpLogRepositoryImpl(
    supabaseClient: Supabase.instance.client,
    clientId: clientId,
  );
}
