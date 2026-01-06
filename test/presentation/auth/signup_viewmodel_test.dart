import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:counter_schmounter/src/presentation/auth/viewmodels/signup_viewmodel.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';
import '../../test_helpers/mocks.dart';

void main() {
  late SignupViewModel viewModel;
  late MockSignUpUseCase mockSignUpUseCase;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockSignUpUseCase = MockSignUpUseCase();
    viewModel = SignupViewModel(mockSignUpUseCase);
  });

  group('SignupViewModel', () {
    group('initial state', () {
      test('has empty email and password', () {
        // Arrange & Act
        final state = viewModel.state;

        // Assert
        expect(state.email, isEmpty);
        expect(state.password, isEmpty);
      });

      test('has canSubmit as false when fields are empty', () {
        // Arrange & Act
        final state = viewModel.state;

        // Assert
        expect(state.canSubmit, isFalse);
      });

      test('has isLoading as false initially', () {
        // Arrange & Act
        final state = viewModel.state;

        // Assert
        expect(state.isLoading, isFalse);
      });

      test('has no error initially', () {
        // Arrange & Act
        final state = viewModel.state;

        // Assert
        expect(state.error, isNull);
      });

      test('has navigationAction as none initially', () {
        // Arrange & Act
        final state = viewModel.state;

        // Assert
        expect(state.navigationAction, NavigationAction.none);
      });
    });

    group('updateEmail', () {
      test('updates email in state', () {
        // Arrange
        const email = 'test@example.com';

        // Act
        viewModel.updateEmail(email);

        // Assert
        expect(viewModel.state.email, email);
      });

      test('updates email with empty string', () {
        // Arrange
        viewModel.updateEmail('test@example.com');

        // Act
        viewModel.updateEmail('');

        // Assert
        expect(viewModel.state.email, isEmpty);
        expect(viewModel.state.canSubmit, isFalse);
      });

      test('updates email with whitespace', () {
        // Arrange
        const email = '  test@example.com  ';

        // Act
        viewModel.updateEmail(email);

        // Assert
        expect(viewModel.state.email, email);
      });

      test('updates email multiple times', () {
        // Act
        viewModel.updateEmail('first@example.com');
        viewModel.updateEmail('second@example.com');
        viewModel.updateEmail('third@example.com');

        // Assert
        expect(viewModel.state.email, 'third@example.com');
      });

      test('updates canSubmit when email is set and password exists', () {
        // Arrange
        viewModel.updatePassword('password123');

        // Act
        viewModel.updateEmail('test@example.com');

        // Assert
        expect(viewModel.state.canSubmit, isTrue);
      });

      test('keeps canSubmit false when only email is set', () {
        // Act
        viewModel.updateEmail('test@example.com');

        // Assert
        expect(viewModel.state.canSubmit, isFalse);
      });
    });

    group('updatePassword', () {
      test('updates password in state', () {
        // Arrange
        const password = 'password123';

        // Act
        viewModel.updatePassword(password);

        // Assert
        expect(viewModel.state.password, password);
      });

      test('updates password with empty string', () {
        // Arrange
        viewModel.updatePassword('password123');

        // Act
        viewModel.updatePassword('');

        // Assert
        expect(viewModel.state.password, isEmpty);
        expect(viewModel.state.canSubmit, isFalse);
      });

      test('updates password multiple times', () {
        // Act
        viewModel.updatePassword('password1');
        viewModel.updatePassword('password2');
        viewModel.updatePassword('password3');

        // Assert
        expect(viewModel.state.password, 'password3');
      });

      test('updates canSubmit when password is set and email exists', () {
        // Arrange
        viewModel.updateEmail('test@example.com');

        // Act
        viewModel.updatePassword('password123');

        // Assert
        expect(viewModel.state.canSubmit, isTrue);
      });

      test('keeps canSubmit false when only password is set', () {
        // Act
        viewModel.updatePassword('password123');

        // Assert
        expect(viewModel.state.canSubmit, isFalse);
      });
    });

    group('signUp', () {
      test('successfully signs up and sets navigation action', () async {
        // Arrange
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
        expect(viewModel.state.isLoading, isFalse);
        expect(viewModel.state.navigationAction, NavigationAction.navigateToLogin);
        expect(viewModel.state.error, isNull);
        verify(
          () => mockSignUpUseCase.execute(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('trims email before signing up', () async {
        // Arrange
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
        viewModel.updateEmail('test@example.com');
        viewModel.updatePassword('password123');

        when(
          () => mockSignUpUseCase.execute(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return Future.value();
        });

        // Act
        final future = viewModel.signUp();

        // Assert - check loading state immediately
        expect(viewModel.state.isLoading, isTrue);
        expect(viewModel.state.navigationAction, NavigationAction.none);

        // Wait for completion
        await future;
      });

      test('handles sign up error and sets error state', () async {
        // Arrange
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
        expect(viewModel.state.isLoading, isFalse);
        expect(viewModel.state.error, isNotNull);
        expect(viewModel.state.navigationAction, NavigationAction.none);
        // Check error state by verifying error getter is not null
        expect(viewModel.state.error, isNotNull);
        expect(viewModel.state.error, isNotNull);
      });

      test('handles AuthException error', () async {
        // Arrange
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
        expect(viewModel.state.isLoading, isFalse);
        expect(viewModel.state.error, isNotNull);
        expect(viewModel.state.navigationAction, NavigationAction.none);
      });

      test('resets navigation action to none on error', () async {
        // Arrange
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
        expect(viewModel.state.navigationAction, NavigationAction.none);
      });

      test('handles empty email and password', () async {
        // Arrange
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
        viewModel.updateEmail('test@example.com');
        viewModel.updatePassword('password123');

        when(
          () => mockSignUpUseCase.execute(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => Future.value());

        await viewModel.signUp();
        expect(viewModel.state.navigationAction, NavigationAction.navigateToLogin);

        // Act
        viewModel.resetNavigation();

        // Assert
        expect(viewModel.state.navigationAction, NavigationAction.none);
      });

      test('can be called multiple times', () {
        // Act
        viewModel.resetNavigation();
        viewModel.resetNavigation();
        viewModel.resetNavigation();

        // Assert
        expect(viewModel.state.navigationAction, NavigationAction.none);
      });
    });
  });
}

