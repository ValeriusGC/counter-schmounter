import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_client_provider.g.dart';

/// Провайдер для получения экземпляра Supabase клиента.
///
/// Возвращает глобальный экземпляр клиента, инициализированный в [main].
@riverpod
SupabaseClient supabaseClient(Ref ref) {
  return Supabase.instance.client;
}
