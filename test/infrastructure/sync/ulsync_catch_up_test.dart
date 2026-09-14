import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:counter_schmounter/src/infrastructure/sync/controllers/ulsync_catch_up.dart';

void main() {
  group('UlsyncCatchUp', () {
    test('один вызов — один круг, потом тишина', () async {
      final machine = UlsyncCatchUp();
      var runs = 0;

      await machine.run(() async {
        runs++;
      });

      expect(runs, 1);
      expect(machine.state, UlsyncCatchUpState.idle);
    });

    test('второй вызов во время первого не выкидывается — ещё один круг', () async {
      final machine = UlsyncCatchUp();
      var runs = 0;
      final started = Completer<void>();
      final release = Completer<void>();

      final first = machine.run(() async {
        runs++;
        if (runs == 1) {
          started.complete();
          await release.future;
        }
      });

      await started.future;
      final second = machine.run(() async {
        runs++;
      });
      release.complete();

      await first;
      await second;

      expect(runs, 2);
      expect(machine.state, UlsyncCatchUpState.idle);
    });

    test('оба вызова ждут тишины, не расходятся по кругам', () async {
      final machine = UlsyncCatchUp();
      final order = <String>[];
      final started = Completer<void>();
      final release = Completer<void>();

      final first = machine.run(() async {
        order.add('a-start');
        started.complete();
        await release.future;
        order.add('a-end');
      });
      await started.future;

      final second = machine.run(() async {
        order.add('b');
      });
      release.complete();

      await Future.wait<void>([first, second]);
      expect(order, ['a-start', 'a-end', 'b']);
      expect(machine.state, UlsyncCatchUpState.idle);
    });

    test('ошибка без хвоста очереди выходит наружу', () async {
      final machine = UlsyncCatchUp();

      await expectLater(
        machine.run(() async {
          throw StateError('boom');
        }),
        throwsA(isA<StateError>()),
      );
      expect(machine.state, UlsyncCatchUpState.idle);
    });

    test('ошибка при втором в очереди — очередь не бросаем, ещё круг', () async {
      final machine = UlsyncCatchUp();
      var runs = 0;
      final started = Completer<void>();
      final release = Completer<void>();

      final first = machine.run(() async {
        runs++;
        if (runs == 1) {
          started.complete();
          await release.future;
          throw StateError('first failed');
        }
      });

      await started.future;
      final second = machine.run(() async {
        runs++;
      });
      release.complete();

      // Ведущий круг после сбоя берёт хвост очереди. Тишина = оба дождались.
      await first;
      await second;
      expect(runs, 2);
      expect(machine.state, UlsyncCatchUpState.idle);
    });
  });
}
