import 'dart:developer' as developer;

import 'package:supa_counter/src/domain/auth/repositories/auth_repository.dart';

/// Use case для выхода пользователя из системы.
///
/// Инкапсулирует бизнес-логику выхода пользователя, используя доменный
/// интерфейс [AuthRepository]. Не содержит зависимостей от UI или инфраструктуры.
class SignOutUseCase {
  /// Создает экземпляр [SignOutUseCase] с указанным репозиторием.
  SignOutUseCase(this._repository);

  /// Репозиторий для выполнения операций аутентификации
  final AuthRepository _repository;

  /// Выполняет выход пользователя из системы.
  ///
  /// Выбрасывает исключение при ошибках сети или других проблемах.
  Future<void> execute() async {
    developer.log(
      '🚪 Sign out initiated',
      name: 'SignOutUseCase',
      error: null,
      stackTrace: null,
      level: 800, // INFO level
    );

    try {
      await _repository.signOut();
      developer.log(
        '✅ Sign out successful',
        name: 'SignOutUseCase',
        error: null,
        stackTrace: null,
        level: 800, // INFO level
      );
    } catch (error, stackTrace) {
      developer.log(
        '❌ Sign out failed',
        name: 'SignOutUseCase',
        error: error,
        stackTrace: stackTrace,
        level: 1000, // SEVERE level
      );
      rethrow;
    }
  }
}
