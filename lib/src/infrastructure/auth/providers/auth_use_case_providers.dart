import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/application/auth/use_cases/sign_in_use_case.dart';
import 'package:counter_schmounter/src/application/auth/use_cases/sign_out_use_case.dart';
import 'package:counter_schmounter/src/application/auth/use_cases/sign_up_use_case.dart';
import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_repository_provider.dart';

part 'auth_use_case_providers.g.dart';

/// Провайдер для [SignInUseCase].
///
/// Использует [authRepositoryProvider] для получения репозитория аутентификации.
@riverpod
SignInUseCase signInUseCase(Ref ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignInUseCase(repository);
}

/// Провайдер для [SignUpUseCase].
///
/// Использует [authRepositoryProvider] для получения репозитория аутентификации.
@riverpod
SignUpUseCase signUpUseCase(Ref ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignUpUseCase(repository);
}

/// Провайдер для [SignOutUseCase].
///
/// Использует [authRepositoryProvider] для получения репозитория аутентификации.
@riverpod
SignOutUseCase signOutUseCase(Ref ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignOutUseCase(repository);
}
