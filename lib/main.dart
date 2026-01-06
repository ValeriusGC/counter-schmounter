import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:counter_schmounter/src/app.dart';

/// Точка входа в приложение.
///
/// Инициализирует Flutter binding, настраивает Supabase клиент
/// и запускает приложение с провайдером Riverpod.
///
/// Требует передачи переменных окружения через --dart-define:
/// - `SU` - URL Supabase проекта
/// - `SAK` - анонимный ключ Supabase
///
/// Пример запуска:
/// ```bash
/// flutter run --dart-define=SU=https://your-project.supabase.co --dart-define=SAK=your-anon-key
/// ```
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Получаем конфигурацию Supabase из переменных окружения
  const supabaseUrl = String.fromEnvironment('SU');
  const supabaseAnonKey = String.fromEnvironment('SAK');

  // Проверяем наличие обязательных параметров конфигурации
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint(
      '⚠️ Missing Supabase config. '
      'Did you forget --dart-define during web build?',
    );

    // В продакшене здесь можно выбросить исключение для предотвращения
    // запуска приложения с неполной конфигурацией
    throw StateError(
      'Missing SUPABASE_URL / SUPABASE_ANON_KEY. '
      'Run with --dart-define=SU=... --dart-define=SAK=...',
    );
  }

  // Инициализируем Supabase клиент с настройками аутентификации
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      // Автоматически обновлять токены при истечении
      autoRefreshToken: true,
      // Сессия сохраняется локально автоматически Supabase Flutter SDK
      // persistSession: true,
      // Определять сессию из URI (полезно для веб-версии и deep links)
      detectSessionInUri: true,
    ),
  );

  // Запускаем приложение с Riverpod провайдером для управления состоянием
  runApp(ProviderScope(child: const App()));
}
