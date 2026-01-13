import 'package:counter_schmounter/src/domain/auth/repositories/auth_repository.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

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
    AppLogger.info(
      component: AppLogComponent.ui,
      message: 'Sign out initiated',
    );

    try {
      await _repository.signOut();
      AppLogger.info(
        component: AppLogComponent.ui,
        message: 'Sign out successful',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        component: AppLogComponent.ui,
        message: 'Sign out failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
