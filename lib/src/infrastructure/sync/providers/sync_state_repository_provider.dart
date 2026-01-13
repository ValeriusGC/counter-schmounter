import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:counter_schmounter/src/domain/sync/repositories/sync_state_repository.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/supabase_user_id_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';
import 'package:counter_schmounter/src/infrastructure/shared/providers/client_identity_service_provider.dart';
import 'package:counter_schmounter/src/infrastructure/sync/repositories/sync_state_repository_impl.dart';

part 'sync_state_repository_provider.g.dart';

/// Провайдер [SyncStateRepository].
///
/// ВАЖНО (account-scope):
/// - репозиторий создаётся с учётом текущего `user_id`
/// - при смене `user_id` создаётся новый экземпляр с новым scope
///
/// Scope:
/// - `user:<user_id>` если авторизован
/// - `anonymous` если нет авторизации
@riverpod
Future<SyncStateRepository> syncStateRepository(Ref ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);

  final userIdAsync = ref.watch(supabaseUserIdProvider);
  final userId = userIdAsync.asData?.value;

  final scope = userId == null ? 'anonymous' : 'user:$userId';

  AppLogger.info(
    component: AppLogComponent.state,
    message: 'SyncStateRepositoryProvider build.',
    context: <String, Object?>{'scope': scope, 'user_id': userId},
  );

  return SyncStateRepositoryImpl(sharedPreferences: prefs, scope: scope);
}
