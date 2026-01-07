import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:counter_schmounter/src/domain/auth/repositories/auth_repository.dart';
import 'package:counter_schmounter/src/infrastructure/auth/repositories/supabase_auth_repository.dart';
import '../../test_helpers/mocks.dart';

void main() {
  late AuthRepository repository;
  late MockSupabaseClient mockClient;
  late MockGoTrueClient mockAuth;

  setUpAll(() {
    registerFallbackValues();
  });

  setUp(() {
    mockClient = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    when(() => mockClient.auth).thenReturn(mockAuth);
    repository = SupabaseAuthRepository(mockClient);
  });

  group('AuthRepository', () {
    group('signUp', () {
      test('successfully signs up user when user is returned', () async {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('test-user-id');
        final response = AuthResponse(
          user: mockUser,
          session: null,
        );

        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => response);

        // Act
        await repository.signUp(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        verify(
          () => mockAuth.signUp(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('successfully handles signUp when user is null (email confirmation required)', () async {
        // Arrange
        final response = AuthResponse(
          user: null,
          session: null,
        );

        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => response);

        // Act & Assert - should not throw
        await expectLater(
          repository.signUp(
            email: 'test@example.com',
            password: 'password123',
          ),
          completes,
        );

        verify(
          () => mockAuth.signUp(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('throws exception when signUp fails', () async {
        // Arrange
        final exception = AuthException('Sign up failed');
        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(exception);

        // Act & Assert
        await expectLater(
          repository.signUp(
            email: 'test@example.com',
            password: 'password123',
          ),
          throwsA(isA<AuthException>()),
        );

        verify(
          () => mockAuth.signUp(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('handles empty email', () async {
        // Arrange
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('test-user-id');
        final response = AuthResponse(
          user: mockUser,
          session: null,
        );

        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => response);

        // Act
        await repository.signUp(
          email: '',
          password: 'password123',
        );

        // Assert
        verify(
          () => mockAuth.signUp(
            email: '',
            password: 'password123',
          ),
        ).called(1);
      });

      test('handles empty password', () async {
        // Arrange
        final exception = AuthException('Password is required');
        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(exception);

        // Act & Assert
        await expectLater(
          repository.signUp(
            email: 'test@example.com',
            password: '',
          ),
          throwsA(isA<AuthException>()),
        );
      });

      test('handles very long email', () async {
        // Arrange
        final longEmail = 'a' * 1000 + '@example.com';
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('test-user-id');
        final response = AuthResponse(
          user: mockUser,
          session: null,
        );

        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => response);

        // Act
        await repository.signUp(
          email: longEmail,
          password: 'password123',
        );

        // Assert
        verify(
          () => mockAuth.signUp(
            email: longEmail,
            password: 'password123',
          ),
        ).called(1);
      });

      test('handles very long password', () async {
        // Arrange
        final longPassword = 'a' * 1000;
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('test-user-id');
        final response = AuthResponse(
          user: mockUser,
          session: null,
        );

        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => response);

        // Act
        await repository.signUp(
          email: 'test@example.com',
          password: longPassword,
        );

        // Assert
        verify(
          () => mockAuth.signUp(
            email: 'test@example.com',
            password: longPassword,
          ),
        ).called(1);
      });

      test('handles special characters in email', () async {
        // Arrange
        final specialEmail = 'test+user@example.co.uk';
        final mockUser = MockUser();
        when(() => mockUser.id).thenReturn('test-user-id');
        final response = AuthResponse(
          user: mockUser,
          session: null,
        );

        when(
          () => mockAuth.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => response);

        // Act
        await repository.signUp(
          email: specialEmail,
          password: 'password123',
        );

        // Assert
        verify(
          () => mockAuth.signUp(
            email: specialEmail,
            password: 'password123',
          ),
        ).called(1);
      });
    });

    group('signIn', () {
      test('successfully signs in user', () async {
        // Arrange
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => AuthResponse(user: null, session: null));

        // Act
        await repository.signIn(
          email: 'test@example.com',
          password: 'password123',
        );

        // Assert
        verify(
          () => mockAuth.signInWithPassword(
            email: 'test@example.com',
            password: 'password123',
          ),
        ).called(1);
      });

      test('throws exception when signIn fails with invalid credentials', () async {
        // Arrange
        final exception = AuthException('Invalid login credentials');
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(exception);

        // Act & Assert
        await expectLater(
          repository.signIn(
            email: 'test@example.com',
            password: 'wrongpassword',
          ),
          throwsA(isA<AuthException>()),
        );

        verify(
          () => mockAuth.signInWithPassword(
            email: 'test@example.com',
            password: 'wrongpassword',
          ),
        ).called(1);
      });

      test('throws exception when signIn fails with network error', () async {
        // Arrange
        final exception = Exception('Network error');
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(exception);

        // Act & Assert
        await expectLater(
          repository.signIn(
            email: 'test@example.com',
            password: 'password123',
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('handles empty email', () async {
        // Arrange
        final exception = AuthException('Email is required');
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(exception);

        // Act & Assert
        await expectLater(
          repository.signIn(
            email: '',
            password: 'password123',
          ),
          throwsA(isA<AuthException>()),
        );
      });

      test('handles empty password', () async {
        // Arrange
        final exception = AuthException('Password is required');
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(exception);

        // Act & Assert
        await expectLater(
          repository.signIn(
            email: 'test@example.com',
            password: '',
          ),
          throwsA(isA<AuthException>()),
        );
      });

      test('handles email with whitespace', () async {
        // Arrange
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => AuthResponse(user: null, session: null));

        // Act
        await repository.signIn(
          email: '  test@example.com  ',
          password: 'password123',
        );

        // Assert
        verify(
          () => mockAuth.signInWithPassword(
            email: '  test@example.com  ',
            password: 'password123',
          ),
        ).called(1);
      });

      test('handles case-sensitive email', () async {
        // Arrange
        when(
          () => mockAuth.signInWithPassword(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => AuthResponse(user: null, session: null));

        // Act
        await repository.signIn(
          email: 'Test@Example.COM',
          password: 'password123',
        );

        // Assert
        verify(
          () => mockAuth.signInWithPassword(
            email: 'Test@Example.COM',
            password: 'password123',
          ),
        ).called(1);
      });
    });

    group('signOut', () {
      test('successfully signs out user', () async {
        // Arrange
        when(() => mockAuth.signOut()).thenAnswer((_) async => AuthResponse(user: null, session: null));

        // Act
        await repository.signOut();

        // Assert
        verify(() => mockAuth.signOut()).called(1);
      });

      test('throws exception when signOut fails', () async {
        // Arrange
        final exception = AuthException('Sign out failed');
        when(() => mockAuth.signOut()).thenThrow(exception);

        // Act & Assert
        await expectLater(
          repository.signOut(),
          throwsA(isA<AuthException>()),
        );

        verify(() => mockAuth.signOut()).called(1);
      });

      test('throws exception when signOut fails with network error', () async {
        // Arrange
        final exception = Exception('Network error');
        when(() => mockAuth.signOut()).thenThrow(exception);

        // Act & Assert
        await expectLater(
          repository.signOut(),
          throwsA(isA<Exception>()),
        );
      });

      test('can be called multiple times sequentially', () async {
        // Arrange
        when(() => mockAuth.signOut()).thenAnswer((_) async => AuthResponse(user: null, session: null));

        // Act
        await repository.signOut();
        await repository.signOut();
        await repository.signOut();

        // Assert
        verify(() => mockAuth.signOut()).called(3);
      });
    });
  });
}

