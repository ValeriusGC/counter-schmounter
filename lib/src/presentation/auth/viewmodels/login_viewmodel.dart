import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_use_case_providers.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';

part 'login_viewmodel.g.dart';

/// Состояние ViewModel для экрана входа.
///
/// Содержит данные формы и состояние асинхронной операции входа.
class LoginState {
  /// Создает начальное состояние [LoginState].
  const LoginState({
    this.email = '',
    this.password = '',
    this.signInAsyncValue = const AsyncValue.data(null),
    this.navigationAction = NavigationAction.none,
  });

  /// Email адрес пользователя
  final String email;

  /// Пароль пользователя
  final String password;

  /// Асинхронное состояние операции входа.
  ///
  /// Использует встроенный [AsyncValue] из Riverpod для управления
  /// состояниями загрузки, успеха и ошибки.
  final AsyncValue<void> signInAsyncValue;

  /// Действие навигации, которое должно быть выполнено UI слоем.
  final NavigationAction navigationAction;

  /// Проверяет, можно ли отправить форму (оба поля заполнены).
  bool get canSubmit => email.isNotEmpty && password.isNotEmpty;

  /// Проверяет, выполняется ли операция входа.
  bool get isLoading => signInAsyncValue.isLoading;

  /// Возвращает сообщение об ошибке, если операция завершилась с ошибкой.
  String? get error =>
      signInAsyncValue.hasError ? signInAsyncValue.error.toString() : null;

  /// Создает копию состояния с обновленными полями.
  LoginState copyWith({
    String? email,
    String? password,
    AsyncValue<void>? signInAsyncValue,
    NavigationAction? navigationAction,
  }) {
    return LoginState(
      email: email ?? this.email,
      password: password ?? this.password,
      signInAsyncValue: signInAsyncValue ?? this.signInAsyncValue,
      navigationAction: navigationAction ?? this.navigationAction,
    );
  }
}

/// Провайдер для экрана входа, сгенерированный через build_runner.
///
/// Использует встроенный Notifier из Riverpod для реактивного управления состоянием.
@riverpod
class LoginViewModel extends _$LoginViewModel {
  @override
  LoginState build() {
    return const LoginState();
  }

  /// Обновляет email адрес в форме.
  void updateEmail(String email) {
    state = state.copyWith(email: email);
  }

  /// Обновляет пароль в форме.
  void updatePassword(String password) {
    state = state.copyWith(password: password);
  }

  /// Выполняет вход пользователя в систему.
  ///
  /// Устанавливает состояние загрузки, вызывает [SignInUseCase] для аутентификации,
  /// и обновляет состояние в зависимости от результата операции.
  /// При успешном входе устанавливает [NavigationAction.navigateToCounter].
  Future<void> signIn() async {
    final signInUseCase = ref.read(signInUseCaseProvider);

    // Устанавливаем состояние загрузки
    state = state.copyWith(
      signInAsyncValue: const AsyncValue.loading(),
      navigationAction: NavigationAction.none,
    );

    try {
      await signInUseCase.execute(
        email: state.email.trim(),
        password: state.password,
      );

      // Успешный вход - устанавливаем навигацию на главный экран
      state = state.copyWith(
        signInAsyncValue: const AsyncValue.data(null),
        navigationAction: NavigationAction.navigateToCounter,
      );
    } catch (error, stackTrace) {
      // Ошибка входа - сохраняем информацию об ошибке
      state = state.copyWith(
        signInAsyncValue: AsyncValue.error(error, stackTrace),
        navigationAction: NavigationAction.none,
      );
    }
  }

  /// Сбрасывает действие навигации после его обработки UI слоем.
  void resetNavigation() {
    state = state.copyWith(navigationAction: NavigationAction.none);
  }
}
