import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_state_listenable_provider.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_use_case_providers.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/supabase_client_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/counter_state_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/increment_counter_use_case_provider.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';

part 'counter_viewmodel.g.dart';

/// Состояние ViewModel для экрана счетчика.
///
/// Содержит состояние асинхронной операции выхода из системы.
/// Значение счетчика читается из [counterStateProvider], а не хранится здесь.
class CounterState {
  /// Создает начальное состояние [CounterState].
  const CounterState({
    this.signOutAsyncValue = const AsyncValue.data(null),
    this.navigationAction = NavigationAction.none,
  });

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
    AsyncValue<void>? signOutAsyncValue,
    NavigationAction? navigationAction,
  }) {
    return CounterState(
      signOutAsyncValue: signOutAsyncValue ?? this.signOutAsyncValue,
      navigationAction: navigationAction ?? this.navigationAction,
    );
  }
}

/// Провайдер для счетчика, сгенерированный через build_runner.
///
/// Использует встроенный AsyncNotifier из Riverpod для реактивного управления состоянием.
/// Управляет только UI-состоянием (signOut, navigation), значение счетчика читается
/// из [counterStateProvider].
@riverpod
class CounterViewModel extends _$CounterViewModel {
  @override
  Future<CounterState> build() async {
    // ViewModel теперь не хранит операции - они хранятся в LocalOpLogRepository
    // и агрегируются через counterStateProvider

    // Подписываемся на изменения auth state для логирования
    // Используем isAuthenticatedProvider, который реактивно обновляется
    bool? previousAuthState;
    try {
      final initialAuthState = ref.read(isAuthenticatedProvider);
      previousAuthState = initialAuthState;

      ref.listen<bool>(isAuthenticatedProvider, (previous, next) {
        _onAuthStateChanged(previousAuthState, next);
        previousAuthState = next;
      });
    } catch (e) {
      // В тестах провайдер может быть не настроен - это нормально
      // Логирование auth state не критично для работы ViewModel
    }

    return const CounterState();
  }

  /// Обрабатывает изменения состояния аутентификации.
  ///
  /// Логирует появление/исчезновение user_id, но не выполняет никаких действий,
  /// которые могли бы повлиять на локальные данные.
  void _onAuthStateChanged(bool? previous, bool next) {
    final wasAuthenticated = previous ?? false;
    final isAuthenticated = next;

    if (!wasAuthenticated && isAuthenticated) {
      // Пользователь вошел в систему
      // Получаем userId через supabaseClientProvider
      final supabaseClient = ref.read(supabaseClientProvider);
      final session = supabaseClient.auth.currentSession;
      final userId = session?.user.id ?? 'unknown';
      developer.log(
        '🔐 User logged in',
        name: 'CounterViewModel',
        error: null,
        stackTrace: null,
        level: 700, // FINE level
      );
      developer.log(
        '   User ID: $userId',
        name: 'CounterViewModel',
        error: null,
        stackTrace: null,
        level: 600, // FINER level
      );
      developer.log(
        '   Local counter data remains intact',
        name: 'CounterViewModel',
        error: null,
        stackTrace: null,
        level: 600, // FINER level
      );
    } else if (wasAuthenticated && !isAuthenticated) {
      // Пользователь вышел из системы
      developer.log(
        '🔓 User logged out',
        name: 'CounterViewModel',
        error: null,
        stackTrace: null,
        level: 700, // FINE level
      );
      developer.log(
        '   Local counter data remains intact',
        name: 'CounterViewModel',
        error: null,
        stackTrace: null,
        level: 600, // FINER level
      );
    }
  }

  /// Увеличивает значение счетчика на 1.
  ///
  /// Вызывает [IncrementCounterUseCase], который создает операцию и сохраняет её
  /// в LocalOpLogRepository. После сохранения инвалидирует [counterStateProvider],
  /// чтобы он пересчитал значение счетчика из обновленного op-log.
  Future<void> incrementCounter() async {
    final incrementCounterUseCase = ref.read(incrementCounterUseCaseProvider);
    await incrementCounterUseCase.execute();
    // Инвалидируем counterStateProvider, чтобы он пересчитал значение из обновленного op-log
    ref.invalidate(counterStateProvider);
  }

  /// Выполняет выход пользователя из системы.
  ///
  /// Устанавливает состояние загрузки, вызывает [SignOutUseCase] для выхода,
  /// и обновляет состояние в зависимости от результата операции.
  /// После успешного выхода пользователь остается на экране счетчика.
  Future<void> signOut() async {
    final signOutUseCase = ref.read(signOutUseCaseProvider);

    if (!state.hasValue) {
      return;
    }

    final currentState = state.value!;

    // Устанавливаем состояние загрузки
    state = AsyncValue.data(
      currentState.copyWith(
        signOutAsyncValue: const AsyncValue.loading(),
        navigationAction: NavigationAction.none,
      ),
    );

    try {
      await signOutUseCase.execute();

      // Успешный выход - остаемся на текущем экране
      if (!ref.mounted) return;
      if (state.hasValue) {
        final updatedState = state.value!;
        state = AsyncValue.data(
          updatedState.copyWith(
            signOutAsyncValue: const AsyncValue.data(null),
            navigationAction: NavigationAction.none,
          ),
        );
      }
    } catch (error, stackTrace) {
      // Ошибка выхода - сохраняем информацию об ошибке
      if (!ref.mounted) return;
      if (state.hasValue) {
        final updatedState = state.value!;
        state = AsyncValue.data(
          updatedState.copyWith(
            signOutAsyncValue: AsyncValue.error(error, stackTrace),
            navigationAction: NavigationAction.none,
          ),
        );
      }
    }
  }

  /// Сбрасывает действие навигации после его обработки UI слоем.
  void resetNavigation() {
    if (state.hasValue) {
      final currentState = state.value!;
      state = AsyncValue.data(
        currentState.copyWith(navigationAction: NavigationAction.none),
      );
    }
  }
}
