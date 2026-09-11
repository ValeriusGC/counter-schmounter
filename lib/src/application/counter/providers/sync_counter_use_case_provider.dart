import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/application/counter/use_cases/sync_counter_use_case.dart';
import 'package:counter_schmounter/src/infrastructure/sync/providers/ulsync_client_provider.dart';

part 'sync_counter_use_case_provider.g.dart';

/// Провайдер [SyncCounterUseCase] с клиентом ulsync текущего пользователя.
@riverpod
Future<SyncCounterUseCase> syncCounterUseCase(Ref ref) async {
  final client = await ref.watch(ulsyncClientProvider.future);
  return SyncCounterUseCase(client: client);
}
