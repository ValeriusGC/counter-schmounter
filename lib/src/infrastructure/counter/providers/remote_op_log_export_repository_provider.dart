import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/remote_op_log_export_repository.dart';
import 'package:counter_schmounter/src/infrastructure/counter/repositories/remote_op_log_export_repository_impl.dart';
import 'package:counter_schmounter/src/infrastructure/shared/providers/client_identity_service_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'remote_op_log_export_repository_provider.g.dart';

/// Провайдер репозитория экспорта (push) операций в удалённый op-log.
@riverpod
RemoteOpLogExportRepository remoteOpLogExportRepository(Ref ref) {
  final clientIdService = ref.watch(clientIdentityServiceProvider);
  final clientId = clientIdService.clientId;

  return RemoteOpLogExportRepositoryImpl(
    supabaseClient: Supabase.instance.client,
    clientId: clientId,
  );
}
