import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:supa_counter/src/infrastructure/auth/providers/auth_use_case_providers.dart';
import 'package:supa_counter/src/presentation/shared/navigation/navigation_state.dart';

part 'signup_viewmodel.g.dart';

/// Состояние ViewModel для экрана регистрации.
///
/// Содержит данные формы и состояние асинхронной операции регистрации.
class SignupState {
  /// Создает начальное состояние [SignupState].
  const SignupState({
    this.email = '',
    this.password = '',
    this.signUpAsyncValue = const AsyncValue.data(null),
    this.navigationAction = NavigationAction.none,
  });

  /// Email адрес пользователя
  final String email;

  /// Пароль пользователя
  final String password;

  /// Асинхронное состояние операции регистрации.
  ///
  /// Использует встроенный [AsyncValue] из Riverpod для управления
  /// состояниями загрузки, успеха и ошибки.
  final AsyncValue<void> signUpAsyncValue;

  /// Действие навигации, которое должно быть выполнено UI слоем.
  final NavigationAction navigationAction;

  /// Проверяет, можно ли отправить форму (оба поля заполнены).
  bool get canSubmit => email.isNotEmpty && password.isNotEmpty;

  /// Проверяет, выполняется ли операция регистрации.
  bool get isLoading => signUpAsyncValue.isLoading;

  /// Возвращает сообщение об ошибке, если операция завершилась с ошибкой.
  String? get error =>
      signUpAsyncValue.hasError ? signUpAsyncValue.error.toString() : null;

  /// Создает копию состояния с обновленными полями.
  SignupState copyWith({
    String? email,
    String? password,
    AsyncValue<void>? signUpAsyncValue,
    NavigationAction? navigationAction,
  }) {
    return SignupState(
      email: email ?? this.email,
      password: password ?? this.password,
      signUpAsyncValue: signUpAsyncValue ?? this.signUpAsyncValue,
      navigationAction: navigationAction ?? this.navigationAction,
    );
  }
}

/// Провайдер для экрана регистрации, сгенерированный через build_runner.
///
/// Использует встроенный Notifier из Riverpod для реактивного управления состоянием.
@riverpod
class SignupViewModel extends _$SignupViewModel {
  @override
  SignupState build() {
    return const SignupState();
  }

  /// Обновляет email адрес в форме.
  void updateEmail(String email) {
    state = state.copyWith(email: email);
  }

  /// Обновляет пароль в форме.
  void updatePassword(String password) {
    state = state.copyWith(password: password);
  }

  /// Выполняет регистрацию нового пользователя.
  ///
  /// Устанавливает состояние загрузки, вызывает [SignUpUseCase] для регистрации,
  /// и обновляет состояние в зависимости от результата операции.
  /// При успешной регистрации устанавливает [NavigationAction.navigateToLogin],
  /// так как в зависимости от настроек Supabase может потребоваться
  /// подтверждение email перед входом.
  Future<void> signUp() async {
    final signUpUseCase = ref.read(signUpUseCaseProvider);

    // Устанавливаем состояние загрузки
    state = state.copyWith(
      signUpAsyncValue: const AsyncValue.loading(),
      navigationAction: NavigationAction.none,
    );

    try {
      await signUpUseCase.execute(
        email: state.email.trim(),
        password: state.password,
      );

      // Успешная регистрация - перенаправляем на экран входа
      // (в зависимости от настроек Supabase может потребоваться подтверждение email)
      state = state.copyWith(
        signUpAsyncValue: const AsyncValue.data(null),
        navigationAction: NavigationAction.navigateToLogin,
      );
    } catch (error, stackTrace) {
      // Ошибка регистрации - сохраняем информацию об ошибке
      state = state.copyWith(
        signUpAsyncValue: AsyncValue.error(error, stackTrace),
        navigationAction: NavigationAction.none,
      );
    }
  }

  /// Сбрасывает действие навигации после его обработки UI слоем.
  void resetNavigation() {
    state = state.copyWith(navigationAction: NavigationAction.none);
  }
}
