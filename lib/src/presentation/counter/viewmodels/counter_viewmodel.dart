import 'dart:developer' as developer;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/application/auth/use_cases/sign_out_use_case.dart';
import 'package:counter_schmounter/src/application/counter/use_cases/increment_counter_use_case.dart';
import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/utils/counter_aggregator.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';

part 'counter_viewmodel.g.dart';

/// Состояние ViewModel для экрана счетчика.
///
/// Содержит список операций счетчика и состояние асинхронной операции выхода.
/// Значение счетчика вычисляется из операций через [CounterAggregator].
class CounterState {
  /// Создает начальное состояние [CounterState].
  const CounterState({
    this.operations = const [],
    this.signOutAsyncValue = const AsyncValue.data(null),
    this.navigationAction = NavigationAction.none,
  });

  /// Список операций над счетчиком.
  ///
  /// Все изменения состояния представлены как операции.
  /// Состояние вычисляется из операций через [CounterAggregator].
  final List<CounterOperation> operations;

  /// Текущее значение счетчика, вычисленное из операций.
  ///
  /// Использует [CounterAggregator.compute] для вычисления итогового значения.
  int get counter => CounterAggregator.compute(operations);

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
    List<CounterOperation>? operations,
    AsyncValue<void>? signOutAsyncValue,
    NavigationAction? navigationAction,
  }) {
    return CounterState(
      operations: operations ?? this.operations,
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
  ///
  /// Вызывает [IncrementCounterUseCase] для создания операции,
  /// затем добавляет её в список операций.
  void incrementCounter() {
    final incrementCounterUseCase = ref.read(incrementCounterUseCaseProvider);
    final operation = incrementCounterUseCase.execute();

    final newOperations = [...state.operations, operation];
    state = state.copyWith(operations: newOperations);

    developer.log(
      '✅ Counter incremented: ${state.counter}',
      name: 'CounterViewModel',
      error: null,
      stackTrace: null,
      level: 800, // INFO level
    );
  }

  /// Выполняет выход пользователя из системы.
  ///
  /// Устанавливает состояние загрузки, вызывает [SignOutUseCase] для выхода,
  /// и обновляет состояние в зависимости от результата операции.
  /// После успешного выхода пользователь остается на экране счетчика.
  Future<void> signOut() async {
    final signOutUseCase = ref.read(signOutUseCaseProvider);

    // Устанавливаем состояние загрузки
    state = state.copyWith(
      signOutAsyncValue: const AsyncValue.loading(),
      navigationAction: NavigationAction.none,
    );

    try {
      await signOutUseCase.execute();

      // Успешный выход - остаемся на текущем экране
      try {
        state = state.copyWith(
          signOutAsyncValue: const AsyncValue.data(null),
          navigationAction: NavigationAction.none,
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
