import 'package:counter_schmounter/src/core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:counter_schmounter/src/presentation/counter/viewmodels/counter_viewmodel.dart';
import 'package:counter_schmounter/src/presentation/shared/navigation/navigation_state.dart';

/// Экран счетчика - главный защищенный экран приложения.
///
/// Отображает простой счетчик, который можно увеличивать нажатием на кнопку.
/// Доступен только авторизованным пользователям (защита на уровне роутера).
/// Содержит кнопку выхода из системы в AppBar.
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

    // Отслеживаем навигацию и выполняем переход при необходимости
    ref.listen<CounterState>(counterViewModelProvider, (previous, next) {
      if (next.navigationAction == NavigationAction.navigateToLogin) {
        viewModel.resetNavigation();
        context.go('/login');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Counter'.hardcoded),
        actions: [
          // Кнопка выхода из системы с индикатором загрузки
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

