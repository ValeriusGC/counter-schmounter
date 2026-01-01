import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:supa_counter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:supa_counter/src/infrastructure/counter/repositories/local_op_log_repository_impl.dart';
import 'package:supa_counter/src/infrastructure/shared/providers/client_identity_service_provider.dart';

part 'local_op_log_repository_provider.g.dart';

/// Провайдер для [LocalOpLogRepository].
///
/// Возвращает доменный интерфейс, но создает инфраструктурную реализацию.
/// **Важно:** [initialize] должен быть вызван после создания экземпляра
/// (обычно в main() или при первом использовании).
@riverpod
LocalOpLogRepository localOpLogRepository(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return LocalOpLogRepositoryImpl(prefs);
}
