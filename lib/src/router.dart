import 'package:counter_schmounter/src/auth/auth_providers.dart';
import 'package:counter_schmounter/src/ui/counter_screen.dart';
import 'package:counter_schmounter/src/ui/login_screen.dart';
import 'package:counter_schmounter/src/ui/signup_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final authListenable = ref.watch(authStateListenableProvider);

  return GoRouter(
    initialLocation: '/counter',
    refreshListenable: authListenable,
    redirect: (_, state) {
      final isAuth = authListenable.isAuthenticated;
      final loc = state.matchedLocation;

      final isOnLogin = loc == '/login';
      final isOnSignup = loc == '/signup';

      if (!isAuth) {
        // Не залогинен: разрешаем только login/signup.
        return (isOnLogin || isOnSignup) ? null : '/login';
      }

      // Залогинен: запрещаем login/signup.
      if (isOnLogin || isOnSignup) {
        return '/counter';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/counter', builder: (_, _) => const CounterScreen()),
    ],
  );
});
