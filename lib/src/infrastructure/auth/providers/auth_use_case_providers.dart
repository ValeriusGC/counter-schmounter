import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:supa_counter/src/application/auth/use_cases/sign_in_use_case.dart';
import 'package:supa_counter/src/application/auth/use_cases/sign_out_use_case.dart';
import 'package:supa_counter/src/application/auth/use_cases/sign_up_use_case.dart';
import 'package:supa_counter/src/infrastructure/auth/providers/auth_repository_provider.dart';

/// Провайдер для [SignInUseCase].
///
/// Использует [authRepositoryProvider] для получения репозитория аутентификации.
final signInUseCaseProvider = Provider<SignInUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignInUseCase(repository);
});

/// Провайдер для [SignUpUseCase].
///
/// Использует [authRepositoryProvider] для получения репозитория аутентификации.
final signUpUseCaseProvider = Provider<SignUpUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignUpUseCase(repository);
});

/// Провайдер для [SignOutUseCase].
///
/// Использует [authRepositoryProvider] для получения репозитория аутентификации.
final signOutUseCaseProvider = Provider<SignOutUseCase>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return SignOutUseCase(repository);
});
