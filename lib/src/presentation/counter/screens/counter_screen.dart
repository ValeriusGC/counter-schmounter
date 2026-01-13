import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:counter_schmounter/src/infrastructure/auth/providers/auth_state_listenable_provider.dart';
import 'package:counter_schmounter/src/infrastructure/bootstrap/infrastructure_init_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/counter_state_provider.dart';
import 'package:counter_schmounter/src/infrastructure/realtime/services/counter_realtime_events_service.dart';
import 'package:counter_schmounter/src/infrastructure/sync/controllers/counter_initial_sync_controller.dart';
import 'package:counter_schmounter/src/presentation/counter/viewmodels/counter_viewmodel.dart';

/// Экран счетчика — главный публичный экран приложения.
///
/// Архитектурные принципы:
/// - counterStateProvider отображается ВСЕГДА (read-model).
/// - CounterViewModel НЕ гейтит отображение счетчика.
/// - Initial sync и realtime запускаются ТОЛЬКО после infrastructure init.
/// - Экран корректно работает одинаково на Web и Mobile.
class CounterScreen extends ConsumerWidget {
  const CounterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    /// 1. Старт-гейт инфраструктуры
    final infraInit = ref.watch(infrastructureInitProvider);

    if (infraInit.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (infraInit.hasError) {
      return Scaffold(
        body: Center(child: Text('Init error: ${infraInit.error}')),
      );
    }

    /// 2. ПРОГРЕВ read-model (КРИТИЧНО ДЛЯ WEB)
    final counterAsync = ref.watch(counterStateProvider);

    /// 3. Разрешаем сайд-эффекты ТОЛЬКО после init
    ref.watch(counterInitialSyncControllerProvider);
    ref.watch(counterRealtimeEventsServiceProvider);

    /// 4. ViewModel используется ТОЛЬКО для действий (sign out / increment)
    final stateAsync = ref.watch(counterViewModelProvider);
    final viewModel = ref.read(counterViewModelProvider.notifier);

    final isAuthenticated = ref
        .watch(authStateListenableProvider)
        .isAuthenticated;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Counter'),
        actions: [
          if (!isAuthenticated)
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Sign in / Sign up'),
            ),
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
                    : const Text('Sign out'),
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
      body: Center(
        child: counterAsync.when(
          data: (counter) => Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text('You have pushed the button this many times:'),
              Text(
                '$counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ],
          ),
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Text('Error: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => viewModel.incrementCounter(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
