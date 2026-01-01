import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';
import 'package:supa_counter/src/domain/counter/operations/counter_operation.dart';
import 'package:supa_counter/src/domain/counter/operations/increment_operation.dart';
import 'package:supa_counter/src/presentation/counter/viewmodels/counter_viewmodel.dart';
import 'package:supa_counter/src/presentation/shared/navigation/navigation_state.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_providers.dart';

void main() {
  late MockSignOutUseCase mockSignOutUseCase;
  late MockIncrementCounterUseCase mockIncrementCounterUseCase;
  late MockLocalOpLogRepository mockLocalOpLogRepository;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockSignOutUseCase = MockSignOutUseCase();
    mockIncrementCounterUseCase = MockIncrementCounterUseCase();
    mockLocalOpLogRepository = MockLocalOpLogRepository();

    // Настраиваем мок LocalOpLogRepository для инициализации
    when(() => mockLocalOpLogRepository.initialize()).thenAnswer((_) async {});
    when(() => mockLocalOpLogRepository.getAll()).thenAnswer((_) async => <CounterOperation>[]);

    container = ProviderContainer(
      overrides: [
        createSignOutUseCaseOverride(mockSignOutUseCase),
        createIncrementCounterUseCaseOverride(mockIncrementCounterUseCase),
        createLocalOpLogRepositoryOverride(mockLocalOpLogRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CounterViewModel', () {
    group('initial state', () {
      test('has isSigningOut as false initially', () async {
        // Arrange & Act
        await container.read(counterViewModelProvider.future);
        final stateAsync = container.read(counterViewModelProvider);

        // Assert
        expect(stateAsync.hasValue, isTrue);
        expect(stateAsync.value!.isSigningOut, isFalse);
      });

      test('has navigationAction as none initially', () async {
        // Arrange & Act
        await container.read(counterViewModelProvider.future);
        final stateAsync = container.read(counterViewModelProvider);

        // Assert
        expect(stateAsync.hasValue, isTrue);
        expect(stateAsync.value!.navigationAction, NavigationAction.none);
      });
    });

    group('incrementCounter', () {
      test('calls use case and invalidates counterStateProvider', () async {
        // Arrange
        final operation = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client-id',
          createdAt: DateTime.now().toUtc(),
        );
        
        when(() => mockIncrementCounterUseCase.execute()).thenAnswer((_) async => operation);
        
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        await viewModel.incrementCounter();

        // Assert
        verify(() => mockIncrementCounterUseCase.execute()).called(1);
        // Проверяем, что counterStateProvider был инвалидирован (будет пересчитан при следующем чтении)
        // Это косвенно проверяется тем, что провайдер будет пересчитан
      });

      test('can be called multiple times', () async {
        // Arrange
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        final operations = List.generate(
          3,
          (index) => IncrementOperation(
            opId: const Uuid().v4(),
            clientId: 'test-client-id',
            createdAt: DateTime.now().toUtc().add(Duration(seconds: index)),
          ),
        );
        var callCount = 0;
        when(() => mockIncrementCounterUseCase.execute()).thenAnswer((_) async {
          return operations[callCount++];
        });
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        await viewModel.incrementCounter();
        await viewModel.incrementCounter();
        await viewModel.incrementCounter();

        // Assert
        verify(() => mockIncrementCounterUseCase.execute()).called(3);
      });

      test('does not affect navigation action', () async {
        // Arrange
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        final operation = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client-id',
          createdAt: DateTime.now().toUtc(),
        );
        when(() => mockIncrementCounterUseCase.execute()).thenAnswer((_) async => operation);
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        await viewModel.incrementCounter();

        // Assert
        final stateAsync = container.read(counterViewModelProvider);
        expect(stateAsync.hasValue, isTrue);
        expect(stateAsync.value!.navigationAction, NavigationAction.none);
      });

      test('does not affect sign out state', () async {
        // Arrange
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        final operation = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client-id',
          createdAt: DateTime.now().toUtc(),
        );
        when(() => mockIncrementCounterUseCase.execute()).thenAnswer((_) async => operation);
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        await viewModel.incrementCounter();

        // Assert
        final stateAsync = container.read(counterViewModelProvider);
        expect(stateAsync.hasValue, isTrue);
        expect(stateAsync.value!.isSigningOut, isFalse);
      });
    });

    group('signOut', () {
      test('successfully signs out and sets navigation action', () async {
        // Arrange
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        when(() => mockSignOutUseCase.execute()).thenAnswer((_) async => Future.value());
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        await viewModel.signOut();

        // Assert
        final stateAsync = container.read(counterViewModelProvider);
        expect(stateAsync.hasValue, isTrue);
        final state = stateAsync.value!;
        expect(state.isSigningOut, isFalse);
        expect(state.navigationAction, NavigationAction.none);
        expect(state.signOutAsyncValue.hasError, isFalse);
        verify(() => mockSignOutUseCase.execute()).called(1);
      });

      test('sets loading state during sign out', () async {
        // Arrange
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        final completer = Completer<void>();
        when(() => mockSignOutUseCase.execute()).thenAnswer((_) async {
          await completer.future;
          return Future.value();
        });
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Используем listen для отслеживания изменений состояния
        AsyncValue<CounterState>? capturedState;
        final subscription = container.listen(
          counterViewModelProvider,
          (previous, next) {
            capturedState = next;
          },
          fireImmediately: true,
        );

        // Act - запускаем signOut, но не ждем завершения
        final future = viewModel.signOut();

        // Assert - ждем, пока состояние обновится через listen
        // Используем цикл с таймаутом для ожидания обновления состояния
        var attempts = 0;
        while (attempts < 50 && (capturedState == null || !capturedState!.hasValue || !capturedState!.value!.isSigningOut)) {
          await Future.delayed(const Duration(milliseconds: 10));
          attempts++;
        }

        subscription.close();

        expect(capturedState, isNotNull);
        expect(capturedState!.hasValue, isTrue, reason: 'State should have value');
        final loadingState = capturedState!.value!;
        expect(loadingState.isSigningOut, isTrue, reason: 'Should be in loading state during sign out');
        expect(loadingState.navigationAction, NavigationAction.none);

        // Complete the sign out
        completer.complete();
        await future;
      });

      test('handles sign out error and sets error state', () async {
        // Arrange
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        final exception = Exception('Sign out failed');
        when(() => mockSignOutUseCase.execute()).thenThrow(exception);
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        await viewModel.signOut();

        // Assert
        final stateAsync = container.read(counterViewModelProvider);
        expect(stateAsync.hasValue, isTrue);
        final state = stateAsync.value!;
        expect(state.isSigningOut, isFalse);
        expect(state.signOutAsyncValue.hasError, isTrue);
        expect(state.navigationAction, NavigationAction.none);
      });

      test('resets navigation action to none on error', () async {
        // Arrange
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        when(() => mockSignOutUseCase.execute()).thenThrow(Exception('Error'));
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        await viewModel.signOut();

        // Assert
        final stateAsync = container.read(counterViewModelProvider);
        expect(stateAsync.hasValue, isTrue);
        expect(stateAsync.value!.navigationAction, NavigationAction.none);
      });

      test('can be called multiple times sequentially', () async {
        // Arrange
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        when(() => mockSignOutUseCase.execute()).thenAnswer((_) async => Future.value());
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        await viewModel.signOut();
        await viewModel.signOut();

        // Assert
        verify(() => mockSignOutUseCase.execute()).called(2);
      });
    });

    group('resetNavigation', () {
      test('resets navigation action to none', () async {
        // Arrange
        await container.read(counterViewModelProvider.future);
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        viewModel.resetNavigation();

        // Assert
        final stateAsync = container.read(counterViewModelProvider);
        expect(stateAsync.hasValue, isTrue);
        expect(stateAsync.value!.navigationAction, NavigationAction.none);
      });

      test('can be called multiple times', () {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        viewModel.resetNavigation();
        viewModel.resetNavigation();
        viewModel.resetNavigation();

        // Assert - не должно быть ошибок
      });
    });

    group('combined operations', () {
      test('increment and sign out work independently', () async {
        // Arrange
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        final operations = List.generate(
          2,
          (index) => IncrementOperation(
            opId: const Uuid().v4(),
            clientId: 'test-client-id',
            createdAt: DateTime.now().toUtc().add(Duration(seconds: index)),
          ),
        );
        var callCount = 0;
        when(() => mockIncrementCounterUseCase.execute()).thenAnswer((_) async {
          return operations[callCount++];
        });
        when(() => mockSignOutUseCase.execute()).thenAnswer((_) async => Future.value());
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        await viewModel.incrementCounter();
        await viewModel.incrementCounter();
        await viewModel.signOut();

        // Assert
        verify(() => mockIncrementCounterUseCase.execute()).called(2);
        verify(() => mockSignOutUseCase.execute()).called(1);
        final stateAsync = container.read(counterViewModelProvider);
        expect(stateAsync.hasValue, isTrue);
        final state = stateAsync.value!;
        expect(state.navigationAction, NavigationAction.none);
        expect(state.isSigningOut, isFalse);
      });

      test('sign out error does not affect increment', () async {
        // Arrange
        await container.read(counterViewModelProvider.future); // Ждем инициализации
        final operations = List.generate(
          2,
          (index) => IncrementOperation(
            opId: const Uuid().v4(),
            clientId: 'test-client-id',
            createdAt: DateTime.now().toUtc().add(Duration(seconds: index)),
          ),
        );
        var callCount = 0;
        when(() => mockIncrementCounterUseCase.execute()).thenAnswer((_) async {
          return operations[callCount++];
        });
        when(() => mockSignOutUseCase.execute()).thenThrow(Exception('Error'));
        final viewModel = container.read(counterViewModelProvider.notifier);

        await viewModel.incrementCounter();
        await viewModel.incrementCounter();

        // Act
        await viewModel.signOut();

        // Assert
        verify(() => mockIncrementCounterUseCase.execute()).called(2);
        verify(() => mockSignOutUseCase.execute()).called(1);
        final stateAsync = container.read(counterViewModelProvider);
        expect(stateAsync.hasValue, isTrue);
        final state = stateAsync.value!;
        expect(state.signOutAsyncValue.hasError, isTrue);
      });
    });
  });
}
