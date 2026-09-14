import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:counter_schmounter/src/infrastructure/sync/controllers/counter_sync_coordinator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('параллельные runOnce не глотают второй обмен', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final coordinator = container.read(counterSyncCoordinatorProvider.notifier);

    var runs = 0;
    final started = Completer<void>();
    final release = Completer<void>();

    final first = coordinator.runOnce(() async {
      runs++;
      if (runs == 1) {
        started.complete();
        await release.future;
      }
    });
    await started.future;
    final second = coordinator.runOnce(() async {
      runs++;
    });
    release.complete();

    await first;
    await second;
    expect(runs, 2);
  });
}
