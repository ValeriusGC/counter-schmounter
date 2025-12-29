import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:counter_schmounter/src/presentation/counter/viewmodels/counter_viewmodel.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_providers.dart';

void main() {
  late MockSignOutUseCase mockSignOutUseCase;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockSignOutUseCase = MockSignOutUseCase();
    container = ProviderContainer(
      overrides: [
        createSignOutUseCaseOverride(mockSignOutUseCase),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CounterViewModel', () {
    group('initial state', () {
      test('has counter value as 0', () {
        // Arrange & Act
        final state = container.read(counterViewModelProvider);

        // Assert
        expect(state.counter, 0);
      });

      test('has isSigningOut as false initially', () {
        // Arrange & Act
        final state = container.read(counterViewModelProvider);

        // Assert
        expect(state.isSigningOut, isFalse);
      });

      test('has navigationAction as none initially', () {
        // Arrange & Act
        final state = container.read(counterViewModelProvider);

        // Assert
        expect(state.navigationAction, NavigationAction.none);
      });
    });

    group('incrementCounter', () {
      test('increments counter by 1', () {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        viewModel.incrementCounter();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.counter, 1);
      });

      test('increments counter multiple times', () {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        viewModel.incrementCounter();
        viewModel.incrementCounter();
        viewModel.incrementCounter();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.counter, 3);
      });

      test('increments counter from non-zero value', () {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);
        viewModel.incrementCounter();
        viewModel.incrementCounter();

        // Act
        viewModel.incrementCounter();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.counter, 3);
      });

      test('can increment counter many times', () {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        for (int i = 0; i < 100; i++) {
          viewModel.incrementCounter();
        }

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.counter, 100);
      });

      test('does not affect navigation action', () {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        viewModel.incrementCounter();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.navigationAction, NavigationAction.none);
      });

      test('does not affect sign out state', () {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        viewModel.incrementCounter();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.isSigningOut, isFalse);
      });
    });

    group('signOut', () {
      test('successfully signs out and sets navigation action', () async {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        when(() => mockSignOutUseCase.execute()).thenAnswer((_) async => Future.value());

        // Act
        await viewModel.signOut();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.isSigningOut, isFalse);
        expect(state.navigationAction, NavigationAction.navigateToLogin);
        expect(state.signOutAsyncValue.hasError, isFalse);
        verify(() => mockSignOutUseCase.execute()).called(1);
      });

      test('sets loading state during sign out', () async {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        when(() => mockSignOutUseCase.execute()).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return Future.value();
        });

        // Act
        final future = viewModel.signOut();

        // Assert - check loading state immediately
        final loadingState = container.read(counterViewModelProvider);
        expect(loadingState.isSigningOut, isTrue);
        expect(loadingState.navigationAction, NavigationAction.none);

        // Wait for completion
        await future;
      });

      test('handles sign out error and sets error state', () async {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        final exception = Exception('Sign out failed');
        when(() => mockSignOutUseCase.execute()).thenThrow(exception);

        // Act
        await viewModel.signOut();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.isSigningOut, isFalse);
        expect(state.signOutAsyncValue.hasError, isTrue);
        expect(state.navigationAction, NavigationAction.none);
      });

      test('handles AuthException error', () async {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        final exception = Exception('Network error');
        when(() => mockSignOutUseCase.execute()).thenThrow(exception);

        // Act
        await viewModel.signOut();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.signOutAsyncValue.hasError, isTrue);
      });

      test('resets navigation action to none on error', () async {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        when(() => mockSignOutUseCase.execute()).thenThrow(Exception('Error'));

        // Act
        await viewModel.signOut();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.navigationAction, NavigationAction.none);
      });

      test('can be called multiple times sequentially', () async {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        when(() => mockSignOutUseCase.execute()).thenAnswer((_) async => Future.value());

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
        final viewModel = container.read(counterViewModelProvider.notifier);

        when(() => mockSignOutUseCase.execute()).thenAnswer((_) async => Future.value());

        await viewModel.signOut();
        final stateBeforeReset = container.read(counterViewModelProvider);
        expect(stateBeforeReset.navigationAction, NavigationAction.navigateToLogin);

        // Act
        viewModel.resetNavigation();

        // Assert
        final stateAfterReset = container.read(counterViewModelProvider);
        expect(stateAfterReset.navigationAction, NavigationAction.none);
      });

      test('can be called multiple times', () {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        // Act
        viewModel.resetNavigation();
        viewModel.resetNavigation();
        viewModel.resetNavigation();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.navigationAction, NavigationAction.none);
      });
    });

    group('combined operations', () {
      test('increment and sign out work independently', () async {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        when(() => mockSignOutUseCase.execute()).thenAnswer((_) async => Future.value());

        // Act
        viewModel.incrementCounter();
        viewModel.incrementCounter();
        await viewModel.signOut();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.counter, 2);
        expect(state.navigationAction, NavigationAction.navigateToLogin);
      });

      test('sign out error does not affect counter', () async {
        // Arrange
        final viewModel = container.read(counterViewModelProvider.notifier);

        viewModel.incrementCounter();
        viewModel.incrementCounter();

        when(() => mockSignOutUseCase.execute()).thenThrow(Exception('Error'));

        // Act
        await viewModel.signOut();

        // Assert
        final state = container.read(counterViewModelProvider);
        expect(state.counter, 2);
        expect(state.signOutAsyncValue.hasError, isTrue);
      });
    });
  });
}

