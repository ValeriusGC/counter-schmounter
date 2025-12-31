import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_state_listenable_provider.dart';
import 'package:counter_schmounter/src/presentation/counter/viewmodels/counter_viewmodel.dart';

/// Экран счетчика - главный публичный экран приложения.
///
/// Отображает простой счетчик, который можно увеличивать нажатием на кнопку.
/// Доступен всем пользователям (не требует аутентификации).
/// Содержит кнопку "Sign in/Sign up" в AppBar (для неавторизованных) или кнопку выхода (для авторизованных).
///
/// Использует [CounterViewModel] для управления состоянием и бизнес-логикой.
/// UI слой только отображает состояние и передает события в ViewModel.
class CounterScreen extends ConsumerWidget {
  /// Создает экземпляр [CounterScreen].
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(counterViewModelProvider);
    final viewModel = ref.read(counterViewModelProvider.notifier);
    final isAuthenticated = ref
        .watch(authStateListenableProvider)
        .isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: Text('Counter'.hardcoded),
        actions: [
          // Кнопка входа/регистрации (для неавторизованных пользователей)
          if (!isAuthenticated)
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Sign in/Sign up'),
            ),
          // Кнопка выхода из системы с индикатором загрузки (только для авторизованных)
          if (isAuthenticated)
            TextButton(
              onPressed: state.isSigningOut ? null : () => viewModel.signOut(),
              child: state.isSigningOut
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                : Text('Sign out'.hardcoded),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('You have pushed the button this many times:'.hardcoded),
            // Отображаем текущее значение счетчика крупным шрифтом
            Text(
              '${state.counter}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      // Кнопка для увеличения счетчика
      floatingActionButton: FloatingActionButton(
        onPressed: () => viewModel.incrementCounter(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
