import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:counter_schmounter/src/infrastructure/auth/providers/supabase_client_provider.dart';

/// [ChangeNotifier], который отслеживает изменения состояния аутентификации
/// и уведомляет подписчиков (например, GoRouter) о необходимости обновления.
///
/// Подписывается на поток изменений состояния аутентификации Supabase
/// и вызывает [notifyListeners] при каждом изменении, что позволяет
/// GoRouter автоматически обновлять маршруты при входе/выходе пользователя.
///
/// **Важно:** Supabase Flutter SDK автоматически сохраняет сессию локально,
/// поэтому при запуске приложения [isAuthenticated] может быть `true`,
/// если пользователь ранее авторизовался и сессия еще действительна.
class AuthStateListenable extends ChangeNotifier {
  /// Создает экземпляр [AuthStateListenable] для указанного клиента.
  ///
  /// Автоматически подписывается на изменения состояния аутентификации.
  AuthStateListenable(this._client) {
    _subscription = _client.auth.onAuthStateChange.listen((_) {
      // Уведомляем всех подписчиков (включая GoRouter) об изменении состояния
      notifyListeners();
    });
  }

  /// Supabase клиент для доступа к API аутентификации
  final SupabaseClient _client;

  /// Подписка на поток изменений состояния аутентификации
  StreamSubscription<AuthState>? _subscription;

  /// Проверяет, авторизован ли текущий пользователь.
  ///
  /// Возвращает `true`, если существует активная сессия пользователя.
  bool get isAuthenticated => _client.auth.currentSession != null;

  @override
  void dispose() {
    // Отменяем подписку при уничтожении объекта для предотвращения утечек памяти
    _subscription?.cancel();
    super.dispose();
  }
}

/// Провайдер для [AuthStateListenable], который отслеживает состояние аутентификации.
///
/// Автоматически очищает ресурсы при удалении провайдера из дерева виджетов.
/// Используется GoRouter для реактивного обновления маршрутов.
final authStateListenableProvider = Provider<AuthStateListenable>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final listenable = AuthStateListenable(client);
  // Обеспечиваем правильную очистку ресурсов при удалении провайдера
  ref.onDispose(listenable.dispose);
  return listenable;
});

/// Провайдер для проверки состояния аутентификации пользователя.
///
/// Возвращает `true`, если пользователь авторизован, и `false` в противном случае.
/// Реактивно обновляется при изменении состояния аутентификации.
final isAuthenticatedProvider = Provider<bool>((ref) {
  final auth = ref.watch(authStateListenableProvider);
  return auth.isAuthenticated;
});

