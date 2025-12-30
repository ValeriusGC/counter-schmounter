import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:counter_schmounter/src/domain/auth/repositories/auth_repository.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_repository_provider.dart';

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
    await _repository.signOut();
  }
}

/// Провайдер для [SignOutUseCase].
///
/// Использует [authRepositoryProvider] для получения репозитория аутентификации.
final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignOutUseCase(repository);
});

