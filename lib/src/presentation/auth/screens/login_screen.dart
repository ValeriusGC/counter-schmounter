import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:counter_schmounter/src/presentation/auth/viewmodels/login_viewmodel.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';

import 'package:counter_schmounter/src/core/core.dart';

/// Экран входа в систему.
///
/// Предоставляет форму для авторизации существующих пользователей
/// с использованием email и пароля. После успешного входа
/// автоматически перенаправляет на экран счетчика.
///
/// Использует [LoginViewModel] для управления состоянием и бизнес-логикой.
/// UI слой только отображает состояние и передает события в ViewModel.
class LoginScreen extends ConsumerWidget {
  /// Создает экземпляр [LoginScreen].
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(loginViewModelProvider);
    final viewModel = ref.read(loginViewModelProvider.notifier);

    // Отслеживаем навигацию и выполняем переход при необходимости
    ref.listen<LoginState>(loginViewModelProvider, (previous, next) {
      if (next.navigationAction == NavigationAction.navigateToCounter) {
        viewModel.resetNavigation();
        context.go('/counter');
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text('Sign in'.hardcoded)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Поле ввода email
            TextField(
              key: const ValueKey('email'),
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'Email'.hardcoded),
              onChanged: (value) => viewModel.updateEmail(value),
            ),
            const SizedBox(height: 12),
            // Поле ввода пароля (скрытое)
            TextField(
              key: const ValueKey('password'),
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
            // Кнопка входа с индикатором загрузки
            FilledButton(
              onPressed: (!state.isLoading && state.canSubmit)
                  ? () => viewModel.signIn()
                  : null,
              child: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Sign in'.hardcoded),
            ),
            const SizedBox(height: 12),
            // Ссылка на экран регистрации
            TextButton(
              onPressed: () => context.go('/signup'),
              child: Text('Create account'.hardcoded),
            ),
          ],
        ),
      ),
    );
  }
}

