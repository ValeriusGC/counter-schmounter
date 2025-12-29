import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:counter_schmounter/src/core/core.dart';
import 'package:counter_schmounter/src/presentation/auth/viewmodels/signup_viewmodel.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';

/// Экран регистрации нового пользователя.
///
/// Предоставляет форму для создания нового аккаунта с использованием
/// email и пароля. После успешной регистрации поведение зависит от
/// настроек Supabase: если требуется подтверждение email, пользователь
/// будет перенаправлен на экран входа; если нет - может быть
/// автоматически авторизован и перенаправлен на экран счетчика.
///
/// Использует [SignupViewModel] для управления состоянием и бизнес-логикой.
/// UI слой только отображает состояние и передает события в ViewModel.
class SignupScreen extends ConsumerWidget {
  /// Создает экземпляр [SignupScreen].
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.watch(signupViewModelProvider);
    final state = ref.watch(
      signupViewModelProvider.select((vm) => vm.currentState),
    );

    // Отслеживаем навигацию и выполняем переход при необходимости
    ref.listen<SignupState>(
      signupViewModelProvider.select((vm) => vm.currentState),
      (previous, next) {
        if (next.navigationAction == NavigationAction.navigateToLogin) {
          viewModel.resetNavigation();
          context.go('/login');
        }
      },
    );

    return Scaffold(
      appBar: AppBar(title: Text('Sign up'.hardcoded)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Поле ввода email
            TextField(
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'Email'.hardcoded),
              onChanged: (value) => viewModel.updateEmail(value),
            ),
            const SizedBox(height: 12),
            // Поле ввода пароля (скрытое)
            TextField(
              obscureText: true,
              decoration: InputDecoration(labelText: 'Password'.hardcoded),
              onChanged: (value) => viewModel.updatePassword(value),
            ),
            const SizedBox(height: 16),
            // Отображаем сообщение об ошибке, если оно есть
            if (state.error != null) ...[
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            // Кнопка регистрации с индикатором загрузки
            FilledButton(
              onPressed: (!state.isLoading && state.canSubmit)
                  ? () => viewModel.signUp()
                  : null,
              child: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Create account'.hardcoded),
            ),
            const SizedBox(height: 12),
            // Ссылка на экран входа
            TextButton(
              onPressed: () => context.go('/login'),
              child: Text('Back to sign in'.hardcoded),
            ),
          ],
        ),
      ),
    );
  }
}
