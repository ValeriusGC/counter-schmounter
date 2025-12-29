import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:counter_schmounter/src/domain/auth/repositories/auth_repository.dart';

/// Инфраструктурная реализация [AuthRepository] через Supabase.
///
/// Инкапсулирует логику работы с Supabase Auth API, предоставляя
/// простой интерфейс для регистрации, входа и выхода пользователей.
///
/// Все методы выбрасывают исключения при ошибках, которые должны
/// обрабатываться вызывающим кодом.
class SupabaseAuthRepository implements AuthRepository {
  /// Создает экземпляр [SupabaseAuthRepository] с указанным Supabase клиентом.
  SupabaseAuthRepository(this._client);

  /// Supabase клиент для выполнения операций аутентификации
  final SupabaseClient _client;

  /// Регистрирует нового пользователя с использованием email и пароля.
  ///
  /// После успешной регистрации пользователь может быть автоматически
  /// авторизован, если в настройках Supabase отключено подтверждение email.
  /// В противном случае пользователю будет отправлено письмо для подтверждения,
  /// и [response.user] может быть `null` до подтверждения email.
  ///
  /// Параметры:
  /// - [email] - email адрес пользователя
  /// - [password] - пароль пользователя (должен соответствовать требованиям Supabase)
  ///
  /// Выбрасывает исключение при ошибках валидации или проблемах с сетью.
  @override
  Future<void> signUp({required String email, required String password}) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    // Если user == null, это означает, что требуется подтверждение email.
    // Это нормальное поведение при включенной настройке email confirmation в Supabase.
    // Пользователь будет создан после подтверждения email по ссылке из письма.
    if (user == null) {
      return;
    }
  }

  /// Авторизует пользователя с использованием email и пароля.
  ///
  /// При успешном входе создается сессия пользователя, которая автоматически
  /// сохраняется локально Supabase Flutter SDK.
  ///
  /// Параметры:
  /// - [email] - email адрес пользователя
  /// - [password] - пароль пользователя
  ///
  /// Выбрасывает исключение при неверных учетных данных или других ошибках.
  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Выходит из текущей сессии пользователя.
  ///
  /// Удаляет локально сохраненную сессию и токены доступа.
  /// После выхода пользователь должен будет снова авторизоваться
  /// для доступа к защищенным ресурсам.
  ///
  /// Выбрасывает исключение при ошибках сети или других проблемах.
  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
