import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Провайдер для получения экземпляра Supabase клиента.
///
/// Возвращает глобальный экземпляр клиента, инициализированный в [main].
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
