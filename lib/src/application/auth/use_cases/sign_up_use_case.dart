import 'package:counter_schmounter/src/domain/auth/repositories/auth_repository.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

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
    AppLogger.info(
      component: AppLogComponent.ui,
      message: 'Sign up initiated',
      context: <String, Object?>{'email': email},
    );

    try {
      await _repository.signUp(email: email, password: password);
      AppLogger.info(
        component: AppLogComponent.ui,
        message: 'Sign up successful',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        component: AppLogComponent.ui,
        message: 'Sign up failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
