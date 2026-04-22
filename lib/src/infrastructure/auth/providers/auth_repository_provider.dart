import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/domain/auth/repositories/auth_repository.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/supabase_client_provider.dart';
import 'package:counter_schmounter/src/infrastructure/auth/repositories/supabase_auth_repository.dart';

part 'auth_repository_provider.g.dart';

/// Провайдер для [AuthRepository], предоставляющий единый экземпляр
/// репозитория аутентификации во всем приложении.
///
/// Использует [supabaseClientProvider] для получения Supabase клиента,
/// что обеспечивает правильную инициализацию и зависимость от
/// глобального состояния Supabase.
///
/// Возвращает доменный интерфейс [AuthRepository], но фактически создает
/// инфраструктурную реализацию [SupabaseAuthRepository].
@riverpod
AuthRepository authRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthRepository(client);
}
