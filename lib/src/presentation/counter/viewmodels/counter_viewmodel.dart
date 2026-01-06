import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/application/auth/use_cases/sign_out_use_case.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';

part 'counter_viewmodel.g.dart';

/// Состояние ViewModel для экрана счетчика.
///
/// Содержит значение счетчика и состояние асинхронной операции выхода.
class CounterState {
  /// Создает начальное состояние [CounterState].
  const CounterState({
    this.counter = 0,
    this.signOutAsyncValue = const AsyncValue.data(null),
    this.navigationAction = NavigationAction.none,
  });

  /// Текущее значение счетчика
  final int counter;

  /// Асинхронное состояние операции выхода из системы.
  ///
  /// Использует встроенный [AsyncValue] из Riverpod для управления
  /// состояниями загрузки, успеха и ошибки.
  final AsyncValue<void> signOutAsyncValue;

  /// Действие навигации, которое должно быть выполнено UI слоем.
  final NavigationAction navigationAction;

  /// Проверяет, выполняется ли операция выхода из системы.
  bool get isSigningOut => signOutAsyncValue.isLoading;

  /// Создает копию состояния с обновленными полями.
  CounterState copyWith({
    int? counter,
    AsyncValue<void>? signOutAsyncValue,
    NavigationAction? navigationAction,
  }) {
    return CounterState(
      counter: counter ?? this.counter,
      signOutAsyncValue: signOutAsyncValue ?? this.signOutAsyncValue,
      navigationAction: navigationAction ?? this.navigationAction,
    );
  }
}

/// Провайдер для счетчика, сгенерированный через build_runner.
///
/// Использует встроенный Notifier из Riverpod для реактивного управления состоянием.
@riverpod
class CounterViewModel extends _$CounterViewModel {
  @override
  CounterState build() {
    return const CounterState();
  }

  /// Увеличивает значение счетчика на 1.
  void incrementCounter() {
    state = state.copyWith(counter: state.counter + 1);
  }

  /// Выполняет выход пользователя из системы.
  ///
  /// Устанавливает состояние загрузки, вызывает [SignOutUseCase] для выхода,
  /// и обновляет состояние в зависимости от результата операции.
  /// При успешном выходе устанавливает [NavigationAction.navigateToLogin],
  /// так как после выхода пользователь должен быть перенаправлен на экран входа.
  Future<void> signOut() async {
    final signOutUseCase = ref.read(signOutUseCaseProvider);

    // Устанавливаем состояние загрузки
    state = state.copyWith(
      signOutAsyncValue: const AsyncValue.loading(),
      navigationAction: NavigationAction.none,
    );

    try {
      await signOutUseCase.execute();

      // Успешный выход - перенаправляем на экран входа
      try {
        state = state.copyWith(
          signOutAsyncValue: const AsyncValue.data(null),
          navigationAction: NavigationAction.navigateToLogin,
        );
      } catch (e) {
        // Provider was disposed, ignore state update
        return;
      }
    } catch (error, stackTrace) {
      // Ошибка выхода - сохраняем информацию об ошибке
      try {
        state = state.copyWith(
          signOutAsyncValue: AsyncValue.error(error, stackTrace),
          navigationAction: NavigationAction.none,
        );
      } catch (e) {
        // Provider was disposed, ignore state update
        return;
      }
    }
  }

  /// Сбрасывает действие навигации после его обработки UI слоем.
  void resetNavigation() {
    state = state.copyWith(navigationAction: NavigationAction.none);
  }
}
