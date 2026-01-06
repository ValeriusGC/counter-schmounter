import 'package:counter_schmounter/src/application/auth/use_cases/sign_in_use_case.dart';
import 'package:counter_schmounter/src/application/auth/use_cases/sign_out_use_case.dart';
import 'package:counter_schmounter/src/application/auth/use_cases/sign_up_use_case.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_repository_provider.dart';
import 'mocks.dart';

/// Test provider override for AuthRepository
/// Allows injecting a mock repository for testing
dynamic createAuthRepositoryOverride(MockAuthRepository mockRepository) {
  return authRepositoryProvider.overrideWithValue(mockRepository);
}

/// Test provider override for SignInUseCase
/// Allows injecting a mock use case for testing
dynamic createSignInUseCaseOverride(MockSignInUseCase mockUseCase) {
  return signInUseCaseProvider.overrideWithValue(mockUseCase);
}

/// Test provider override for SignUpUseCase
/// Allows injecting a mock use case for testing
dynamic createSignUpUseCaseOverride(MockSignUpUseCase mockUseCase) {
  return signUpUseCaseProvider.overrideWithValue(mockUseCase);
}

/// Test provider override for SignOutUseCase
/// Allows injecting a mock use case for testing
dynamic createSignOutUseCaseOverride(MockSignOutUseCase mockUseCase) {
  return signOutUseCaseProvider.overrideWithValue(mockUseCase);
}

