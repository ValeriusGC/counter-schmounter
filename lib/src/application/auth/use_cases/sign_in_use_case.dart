import 'package:counter_schmounter/src/domain/auth/repositories/auth_repository.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

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
    AppLogger.info(
      component: AppLogComponent.ui,
      message: 'Sign in initiated',
      context: <String, Object?>{'email': email},
    );

    try {
      await _repository.signIn(email: email, password: password);
      AppLogger.info(
        component: AppLogComponent.ui,
        message: 'Sign in successful',
      );
    } catch (error, stackTrace) {
      AppLogger.error(
        component: AppLogComponent.ui,
        message: 'Sign in failed',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
