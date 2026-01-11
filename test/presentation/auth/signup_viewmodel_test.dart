import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_use_case_providers.dart';
import 'package:counter_schmounter/src/presentation/auth/viewmodels/signup_viewmodel.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_providers.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    final mockSignUpUseCase = MockSignUpUseCase();
    container = ProviderContainer(
      overrides: [
        createSignUpUseCaseOverride(mockSignUpUseCase),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('SignupViewModel', () {
    group('initial state', () {
      test('has empty email and password', () {
        // Arrange & Act
        final state = container.read(signupViewModelProvider);

        // Assert
        expect(state.email, isEmpty);
        expect(state.password, isEmpty);
      });

      test('has canSubmit as false when fields are empty', () {
        // Arrange & Act
        final state = container.read(signupViewModelProvider);

        // Assert
        expect(state.canSubmit, isFalse);
      });

      test('has isLoading as false initially', () {
        // Arrange & Act
        final state = container.read(signupViewModelProvider);

        // Assert
        expect(state.isLoading, isFalse);
      });

      test('has no error initially', () {
        // Arrange & Act
        final state = container.read(signupViewModelProvider);

        // Assert
        expect(state.error, isNull);
      });

      test('has navigationAction as none initially', () {
        // Arrange & Act
        final state = container.read(signupViewModelProvider);

        // Assert
        expect(state.navigationAction, NavigationAction.none);
      });
    });

    group('updateEmail', () {
      test('updates email in state', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        const email = 'test@example.com';

        // Act
        viewModel.updateEmail(email);

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.email, email);
      });

      test('updates email with empty string', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        viewModel.updateEmail('test@example.com');

        // Act
        viewModel.updateEmail('');

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.email, isEmpty);
        expect(state.canSubmit, isFalse);
      });

      test('updates email with whitespace', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        const email = '  test@example.com  ';

        // Act
        viewModel.updateEmail(email);

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.email, email);
      });

      test('updates email multiple times', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);

        // Act
        viewModel.updateEmail('first@example.com');
        viewModel.updateEmail('second@example.com');
        viewModel.updateEmail('third@example.com');

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.email, 'third@example.com');
      });

      test('updates canSubmit when email is set and password exists', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        viewModel.updatePassword('password123');

        // Act
        viewModel.updateEmail('test@example.com');

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.canSubmit, isTrue);
      });

      test('keeps canSubmit false when only email is set', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);

        // Act
        viewModel.updateEmail('test@example.com');

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.canSubmit, isFalse);
      });
    });

    group('updatePassword', () {
      test('updates password in state', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        const password = 'password123';

        // Act
        viewModel.updatePassword(password);

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.password, password);
      });

      test('updates password with empty string', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        viewModel.updatePassword('password123');

        // Act
        viewModel.updatePassword('');

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.password, isEmpty);
        expect(state.canSubmit, isFalse);
      });

      test('updates password multiple times', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);

        // Act
        viewModel.updatePassword('password1');
        viewModel.updatePassword('password2');
        viewModel.updatePassword('password3');

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.password, 'password3');
      });

      test('updates canSubmit when password is set and email exists', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        viewModel.updateEmail('test@example.com');

        // Act
        viewModel.updatePassword('password123');

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.canSubmit, isTrue);
      });

      test('keeps canSubmit false when only password is set', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);

        // Act
        viewModel.updatePassword('password123');

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.canSubmit, isFalse);
      });
    });

    group('signUp', () {
      test('successfully signs up and sets navigation action', () async {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        final mockSignUpUseCase = container.read(signUpUseCaseProvider) as MockSignUpUseCase;
        viewModel.updateEmail('test@example.com');
        viewModel.updatePassword('password123');

        when(
          () => mockSignUpUseCase.execute(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => Future.value());

        // Act
        await viewModel.signUp();

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.isLoading, isFalse);
        expect(state.navigationAction, NavigationAction.navigateToLogin);
        expect(state.error, isNull);
        verify(
          () => mockSignUpUseCase.execute(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('trims email before signing up', () async {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        final mockSignUpUseCase = container.read(signUpUseCaseProvider) as MockSignUpUseCase;
        viewModel.updateEmail('  test@example.com  ');
        viewModel.updatePassword('password123');

        when(
          () => mockSignUpUseCase.execute(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => Future.value());

        // Act
        await viewModel.signUp();

        // Assert
        verify(
          () => mockSignUpUseCase.execute(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('sets loading state during sign up', () async {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        final mockSignUpUseCase = container.read(signUpUseCaseProvider) as MockSignUpUseCase;
        viewModel.updateEmail('test@example.com');
        viewModel.updatePassword('password123');

        final completer = Completer<void>();
        when(
          () => mockSignUpUseCase.execute(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async {
          await completer.future;
          return Future.value();
        });

        // Используем listen для отслеживания изменений состояния
        SignupState? capturedState;
        final subscription = container.listen(
          signupViewModelProvider,
          (previous, next) {
            capturedState = next;
          },
          fireImmediately: true,
        );

        // Act - запускаем signUp, но не ждем завершения
        final future = viewModel.signUp();

        // Assert - ждем, пока состояние обновится через listen
        // Используем цикл с таймаутом для ожидания обновления состояния
        var attempts = 0;
        while (attempts < 50 && (capturedState == null || !capturedState!.isLoading)) {
          await Future.delayed(const Duration(milliseconds: 10));
          attempts++;
        }

        subscription.close();

        expect(capturedState, isNotNull);
        expect(capturedState!.isLoading, isTrue, reason: 'Should be in loading state during sign up');
        expect(capturedState!.navigationAction, NavigationAction.none);

        // Complete the sign up
        completer.complete();
        await future;
      });

      test('handles sign up error and sets error state', () async {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        final mockSignUpUseCase = container.read(signUpUseCaseProvider) as MockSignUpUseCase;
        viewModel.updateEmail('test@example.com');
        viewModel.updatePassword('password123');

        final exception = Exception('Registration failed');
        when(
          () => mockSignUpUseCase.execute(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(exception);

        // Act
        await viewModel.signUp();

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.isLoading, isFalse);
        expect(state.error, isNotNull);
        expect(state.navigationAction, NavigationAction.none);
      });

      test('handles AuthException error', () async {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        final mockSignUpUseCase = container.read(signUpUseCaseProvider) as MockSignUpUseCase;
        viewModel.updateEmail('test@example.com');
        viewModel.updatePassword('password123');

        final exception = Exception('Email already exists');
        when(
          () => mockSignUpUseCase.execute(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(exception);

        // Act
        await viewModel.signUp();

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.isLoading, isFalse);
        expect(state.error, isNotNull);
        expect(state.navigationAction, NavigationAction.none);
      });

      test('resets navigation action to none on error', () async {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        final mockSignUpUseCase = container.read(signUpUseCaseProvider) as MockSignUpUseCase;
        viewModel.updateEmail('test@example.com');
        viewModel.updatePassword('password123');

        when(
          () => mockSignUpUseCase.execute(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(Exception('Error'));

        // Act
        await viewModel.signUp();

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.navigationAction, NavigationAction.none);
      });

      test('handles empty email and password', () async {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        final mockSignUpUseCase = container.read(signUpUseCaseProvider) as MockSignUpUseCase;
        when(
          () => mockSignUpUseCase.execute(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => Future.value());

        // Act
        await viewModel.signUp();

        // Assert
        verify(
          () => mockSignUpUseCase.execute(
            email: '',
            password: '',
          ),
        ).called(1);
      });
    });

    group('resetNavigation', () {
      test('resets navigation action to none', () async {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);
        final mockSignUpUseCase = container.read(signUpUseCaseProvider) as MockSignUpUseCase;
        viewModel.updateEmail('test@example.com');
        viewModel.updatePassword('password123');

        when(
          () => mockSignUpUseCase.execute(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => Future.value());

        await viewModel.signUp();
        final stateAfterSignUp = container.read(signupViewModelProvider);
        expect(stateAfterSignUp.navigationAction, NavigationAction.navigateToLogin);

        // Act
        viewModel.resetNavigation();

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.navigationAction, NavigationAction.none);
      });

      test('can be called multiple times', () {
        // Arrange
        final viewModel = container.read(signupViewModelProvider.notifier);

        // Act
        viewModel.resetNavigation();
        viewModel.resetNavigation();
        viewModel.resetNavigation();

        // Assert
        final state = container.read(signupViewModelProvider);
        expect(state.navigationAction, NavigationAction.none);
      });
    });
  });
}

