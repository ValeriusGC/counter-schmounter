import 'package:counter_schmounter/src/domain/auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_repository_provider.dart';

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
    await _repository.signIn(email: email, password: password);
  }
}

/// Провайдер для [SignInUseCase].
///
/// Использует [authRepositoryProvider] для получения репозитория аутентификации.
final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignInUseCase(repository);
});

