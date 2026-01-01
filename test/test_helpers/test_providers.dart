import 'package:supa_counter/src/infrastructure/auth/providers/auth_repository_provider.dart';
import 'package:supa_counter/src/infrastructure/auth/providers/auth_use_case_providers.dart';
import 'package:supa_counter/src/infrastructure/counter/providers/increment_counter_use_case_provider.dart';
import 'package:supa_counter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';
import 'package:supa_counter/src/infrastructure/shared/providers/client_identity_service_provider.dart';
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

/// Test provider override for ClientIdentityService
/// Allows injecting a mock service for testing
dynamic createClientIdentityServiceOverride(MockClientIdentityService mockService) {
  return clientIdentityServiceProvider.overrideWithValue(mockService);
}

/// Test provider override for IncrementCounterUseCase
/// Allows injecting a mock use case for testing
dynamic createIncrementCounterUseCaseOverride(MockIncrementCounterUseCase mockUseCase) {
  return incrementCounterUseCaseProvider.overrideWithValue(mockUseCase);
}

/// Test provider override for LocalOpLogRepository
/// Allows injecting a mock repository for testing
dynamic createLocalOpLogRepositoryOverride(MockLocalOpLogRepository mockRepository) {
  return localOpLogRepositoryProvider.overrideWithValue(mockRepository);
}

