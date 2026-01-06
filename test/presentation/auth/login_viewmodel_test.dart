import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:counter_schmounter/src/presentation/auth/viewmodels/login_viewmodel.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';
import '../../test_helpers/mocks.dart';
import '../../test_helpers/test_providers.dart';

void main() {
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    final mockSignInUseCase = MockSignInUseCase();
    container = ProviderContainer(
      overrides: [
        createSignInUseCaseOverride(mockSignInUseCase),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('LoginViewModel', () {
    group('initial state', () {
      test('has empty email and password', () {
        // Arrange & Act
        final state = container.read(loginViewModelProvider);

        // Assert
        expect(state.email, isEmpty);
        expect(state.password, isEmpty);
      });

      test('has canSubmit as false when fields are empty', () {
        // Arrange & Act
        final state = container.read(loginViewModelProvider);

        // Assert
        expect(state.canSubmit, isFalse);
      });

      test('has isLoading as false initially', () {
        // Arrange & Act
        final state = container.read(loginViewModelProvider);

        // Assert
        expect(state.isLoading, isFalse);
      });

      test('has no error initially', () {
        // Arrange & Act
        final state = container.read(loginViewModelProvider);

        // Assert
        expect(state.error, isNull);
      });

      test('has navigationAction as none initially', () {
        // Arrange & Act
        final state = container.read(loginViewModelProvider);

        // Assert
        expect(state.navigationAction, NavigationAction.none);
      });
    });

    group('updateEmail', () {
      test('updates email in state', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);
        const email = 'test@example.com';

        // Act
        viewModel.updateEmail(email);

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.email, email);
      });

      test('updates email with empty string', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);
        viewModel.updateEmail('test@example.com');

        // Act
        viewModel.updateEmail('');

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.email, isEmpty);
        expect(state.canSubmit, isFalse);
      });

      test('updates email with whitespace', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);
        const email = '  test@example.com  ';

        // Act
        viewModel.updateEmail(email);

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.email, email);
      });

      test('updates email multiple times', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);

        // Act
        viewModel.updateEmail('first@example.com');
        viewModel.updateEmail('second@example.com');
        viewModel.updateEmail('third@example.com');

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.email, 'third@example.com');
      });

      test('updates canSubmit when email is set and password exists', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);
        viewModel.updatePassword('password123');

        // Act
        viewModel.updateEmail('test@example.com');

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.canSubmit, isTrue);
      });

      test('keeps canSubmit false when only email is set', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);

        // Act
        viewModel.updateEmail('test@example.com');

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.canSubmit, isFalse);
      });
    });

    group('updatePassword', () {
      test('updates password in state', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);
        const password = 'password123';

        // Act
        viewModel.updatePassword(password);

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.password, password);
      });

      test('updates password with empty string', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);
        viewModel.updatePassword('password123');

        // Act
        viewModel.updatePassword('');

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.password, isEmpty);
        expect(state.canSubmit, isFalse);
      });

      test('updates password multiple times', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);

        // Act
        viewModel.updatePassword('password1');
        viewModel.updatePassword('password2');
        viewModel.updatePassword('password3');

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.password, 'password3');
      });

      test('updates canSubmit when password is set and email exists', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);
        viewModel.updateEmail('test@example.com');

        // Act
        viewModel.updatePassword('password123');

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.canSubmit, isTrue);
      });

      test('keeps canSubmit false when only password is set', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);

        // Act
        viewModel.updatePassword('password123');

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.canSubmit, isFalse);
      });
    });

    group('signIn', () {

    });

    group('resetNavigation', () {
      test('can be called multiple times', () {
        // Arrange
        final viewModel = container.read(loginViewModelProvider.notifier);

        // Act
        viewModel.resetNavigation();
        viewModel.resetNavigation();
        viewModel.resetNavigation();

        // Assert
        final state = container.read(loginViewModelProvider);
        expect(state.navigationAction, NavigationAction.none);
      });
    });
  });
}

