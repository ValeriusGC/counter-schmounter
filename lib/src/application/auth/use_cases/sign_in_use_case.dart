import 'dart:developer' as developer;

import 'package:counter_schmounter/src/domain/auth/repositories/auth_repository.dart';

/// Use case для входа пользователя в систему.
///
/// Инкапсулирует бизнес-логику входа пользователя, используя доменный
/// интерфейс [AuthRepository]. Не содержит зависимостей от UI или инфраструктуры.
class SignInUseCase {
  /// Создает экземпляр [SignInUseCase] с указанным репозиторием.
  SignInUseCase(this._repository);

  /// Репозиторий для выполнения операций аутентификации
  final AuthRepository _repository;

  /// Выполняет вход пользователя в систему.
  ///
  /// Параметры:
  /// - [email] - email адрес пользователя
  /// - [password] - пароль пользователя
  ///
  /// Выбрасывает исключение при неверных учетных данных или других ошибках.
  Future<void> execute({
    required String email,
    required String password,
  }) async {
    developer.log(
      '🔐 Sign in initiated',
      name: 'SignInUseCase',
      error: null,
      stackTrace: null,
      level: 800, // INFO level
    );
    developer.log(
      '   Email: $email',
      name: 'SignInUseCase',
      error: null,
      stackTrace: null,
      level: 700, // FINE level
    );

    try {
      await _repository.signIn(email: email, password: password);
      developer.log(
        '✅ Sign in successful',
        name: 'SignInUseCase',
        error: null,
        stackTrace: null,
        level: 800, // INFO level
      );
    } catch (error, stackTrace) {
      developer.log(
        '❌ Sign in failed',
        name: 'SignInUseCase',
        error: error,
        stackTrace: stackTrace,
        level: 1000, // SEVERE level
      );
      rethrow;
    }
  }
}
