import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_state_listenable_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/counter_state_provider.dart';
import 'package:counter_schmounter/src/presentation/counter/viewmodels/counter_viewmodel.dart';

import 'package:counter_schmounter/src/core/src/extensions/string_extensions.dart';

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
    final stateAsync = ref.watch(counterViewModelProvider);
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
            stateAsync.when(
              data: (state) => TextButton(
                onPressed: state.isSigningOut
                    ? null
                    : () => viewModel.signOut(),
                child: state.isSigningOut
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Sign out'.hardcoded),
              ),
              loading: () => const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, _) => const Text('Error'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: stateAsync.when(
        data: (_) {
          // Читаем значение счетчика из counterStateProvider
          final counterAsync = ref.watch(counterStateProvider);
          return counterAsync.when(
            data: (counter) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text('You have pushed the button this many times:'.hardcoded),
                  // Отображаем текущее значение счетчика крупным шрифтом
                  Text(
                    '$counter',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(child: Text('Error: $error')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(child: Text('Error: $error')),
      ),
      // Кнопка для увеличения счетчика
      floatingActionButton: stateAsync.when(
        data: (_) => FloatingActionButton(
          onPressed: () => viewModel.incrementCounter(),
          child: const Icon(Icons.add),
        ),
        loading: () => null,
        error: (_, _) => null,
      ),
    );
  }
}
