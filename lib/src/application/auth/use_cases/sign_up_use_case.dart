import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:counter_schmounter/src/domain/auth/repositories/auth_repository.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_repository_provider.dart';

/// Use case для регистрации нового пользователя.
///
/// Инкапсулирует бизнес-логику регистрации пользователя, используя доменный
/// интерфейс [AuthRepository]. Не содержит зависимостей от UI или инфраструктуры.
class SignUpUseCase {
  /// Создает экземпляр [SignUpUseCase] с указанным репозиторием.
  SignUpUseCase(this._repository);

  /// Репозиторий для выполнения операций аутентификации
  final AuthRepository _repository;

  /// Выполняет регистрацию нового пользователя.
  ///
  /// Параметры:
  /// - [email] - email адрес пользователя
  /// - [password] - пароль пользователя
  ///
  /// Выбрасывает исключение при ошибках валидации или проблемах с сетью.
  Future<void> execute({
    required String email,
    required String password,
  }) async {
    developer.log(
      '📝 Sign up initiated',
      name: 'SignUpUseCase',
      error: null,
      stackTrace: null,
      level: 800, // INFO level
    );
    developer.log(
      '   Email: $email',
      name: 'SignUpUseCase',
      error: null,
      stackTrace: null,
      level: 700, // FINE level
    );

    try {
      await _repository.signUp(email: email, password: password);
      developer.log(
        '✅ Sign up successful',
        name: 'SignUpUseCase',
        error: null,
        stackTrace: null,
        level: 800, // INFO level
      );
    } catch (error, stackTrace) {
      developer.log(
        '❌ Sign up failed',
        name: 'SignUpUseCase',
        error: error,
        stackTrace: stackTrace,
        level: 1000, // SEVERE level
      );
      rethrow;
    }
  }
}

/// Провайдер для [SignUpUseCase].
///
/// Использует [authRepositoryProvider] для получения репозитория аутентификации.
final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignUpUseCase(repository);
});
