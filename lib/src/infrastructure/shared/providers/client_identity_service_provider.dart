import 'package:counter_schmounter/src/domain/shared/services/client_identity_service.dart';
import 'package:counter_schmounter/src/infrastructure/shared/services/client_identity_service_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'client_identity_service_provider.g.dart';

/// Провайдер для [SharedPreferences].
///
/// Должен быть переопределен в [ProviderScope.overrides] при создании приложения
/// с экземпляром, полученным из [SharedPreferences.getInstance()].
@riverpod
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError(
    'SharedPreferences must be initialized in main() and provided via ProviderScope.overrides.',
  );
}

/// Провайдер для [ClientIdentityService].
///
/// Возвращает доменный интерфейс, но создает инфраструктурную реализацию.
/// **Важно:** [init] должен быть вызван после создания экземпляра (обычно в main()).
@riverpod
ClientIdentityService clientIdentityService(Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ClientIdentityServiceImpl(prefs);
}
