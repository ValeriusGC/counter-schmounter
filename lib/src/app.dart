import 'package:counter_schmounter/src/core/ext.dart';
import 'package:counter_schmounter/src/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Корневой виджет приложения.
///
/// Настраивает Material Design 3 тему и использует GoRouter
/// для навигации между экранами. Интегрирован с Riverpod
/// для реактивного управления состоянием и роутингом.
class App extends ConsumerWidget {
  /// Создает экземпляр [App].
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Получаем конфигурацию роутера из провайдера
    // Роутер автоматически обновляется при изменении состояния аутентификации
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Counter-Schmounter + Supabase Auth'.hardcoded,
      theme: ThemeData(
        // Используем Material Design 3
        useMaterial3: true,
        // Генерируем цветовую схему на основе синего цвета
        colorSchemeSeed: Colors.blue,
      ),
      // Используем GoRouter для декларативной навигации
      routerConfig: router,
    );
  }
}
