import 'package:supabase_flutter/supabase_flutter.dart';

/// Repository for Supabase Auth operations.
class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient _client;

  /// Signs up a user using email/password.
  Future<void> signUp({required String email, required String password}) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );

    final user = response.user;
    if (user == null) {
      // Такое возможно при настройках подтверждения email.
      // Это не ошибка. Пользователь может появиться после подтверждения.
      return;
    }
  }

  /// Signs in a user using email/password.
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Signs out current user.
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
