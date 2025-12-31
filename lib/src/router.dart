import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_state_listenable_provider.dart';
import 'package:counter_schmounter/src/presentation/auth/screens/login_screen.dart';
import 'package:counter_schmounter/src/presentation/auth/screens/signup_screen.dart';
import 'package:counter_schmounter/src/presentation/counter/screens/counter_screen.dart';

/// Провайдер конфигурации GoRouter для навигации в приложении.
///
/// Настраивает маршруты и логику редиректов на основе состояния
/// аутентификации. Автоматически обновляется при изменении
/// состояния аутентификации через [AuthStateListenable].
///
/// Маршруты:
/// - `/login` - экран входа
/// - `/signup` - экран регистрации
/// - `/counter` - публичный экран счетчика (не требует аутентификации)
///
/// Логика редиректов:
/// - Авторизованные пользователи на `/login` или `/signup` перенаправляются на `/counter`
final goRouterProvider = Provider<GoRouter>((ref) {
  // Отслеживаем состояние аутентификации для реактивного обновления роутера
  final auth = ref.watch(authStateListenableProvider);

  return GoRouter(
    // Начальный маршрут
    initialLocation: '/counter',
    // Роутер будет обновляться при изменении состояния аутентификации
    refreshListenable: auth,
    // Логика редиректов на основе состояния аутентификации
    redirect: (context, state) {
      final isAuth = auth.isAuthenticated;
      final loc = state.matchedLocation;

      final isOnLogin = loc == '/login';
      final isOnSignup = loc == '/signup';

      // Если пользователь авторизован и находится на экранах входа/регистрации,
      // перенаправляем на главный экран приложения
      if (isAuth && (isOnLogin || isOnSignup)) {
        return '/counter';
      }

      // Разрешаем навигацию без редиректа
      return null;
    },
    routes: [
      /// Экран входа в систему
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),

      /// Экран регистрации нового пользователя
      GoRoute(
        path: '/signup',
        builder: (context, state) => const SignupScreen(),
      ),

      /// Публичный экран счетчика (доступен всем пользователям)
      GoRoute(
        path: '/counter',
        builder: (context, state) => const CounterScreen(),
      ),
    ],
  );
});
