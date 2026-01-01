import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:supa_counter/src/app.dart';
import 'package:supa_counter/src/infrastructure/shared/providers/client_identity_service_provider.dart';
import 'package:supa_counter/src/infrastructure/shared/services/client_identity_service_impl.dart';

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

  // Baseline standard: use SU / SAK (short form) for Supabase credentials
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
      'Missing SU / SAK. '
      'Run with --dart-define=SU=https://your-project.supabase.co --dart-define=SAK=your-anon-key',
    );
  }

  // Инициализируем Supabase клиент с настройками аутентификации
  developer.log(
    '🔧 Initializing Supabase client...',
    name: 'main',
    error: null,
    stackTrace: null,
    level: 800, // INFO level
  );
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
  developer.log(
    '✅ Supabase client initialized',
    name: 'main',
    error: null,
    stackTrace: null,
    level: 800, // INFO level
  );

  // Инициализируем SharedPreferences
  developer.log(
    '💾 Initializing SharedPreferences...',
    name: 'main',
    error: null,
    stackTrace: null,
    level: 800, // INFO level
  );
  final sharedPreferences = await SharedPreferences.getInstance();
  developer.log(
    '✅ SharedPreferences initialized',
    name: 'main',
    error: null,
    stackTrace: null,
    level: 800, // INFO level
  );

  // Инициализируем ClientIdentityService
  developer.log(
    '🆔 Initializing Client Identity Service...',
    name: 'main',
    error: null,
    stackTrace: null,
    level: 800, // INFO level
  );
  final clientIdentityService = ClientIdentityServiceImpl(sharedPreferences);
  await clientIdentityService.init();

  // Запускаем приложение с Riverpod провайдером для управления состоянием
  developer.log(
    '🚀 Starting application...',
    name: 'main',
    error: null,
    stackTrace: null,
    level: 800, // INFO level
  );
  runApp(
    ProviderScope(
      overrides: [
        // Предоставляем инициализированный SharedPreferences
        sharedPreferencesProvider.overrideWith((ref) => sharedPreferences),
        // Предоставляем инициализированный ClientIdentityService
        clientIdentityServiceProvider.overrideWith(
          (ref) => clientIdentityService,
        ),
      ],
      child: const App(),
    ),
  );
}
