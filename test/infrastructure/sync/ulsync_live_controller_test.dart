import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/counter_state_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/repositories/local_op_log_repository_impl.dart';
import 'package:counter_schmounter/src/infrastructure/shared/providers/client_identity_service_provider.dart';
import 'package:counter_schmounter/src/infrastructure/sync/controllers/ulsync_live_controller.dart';
import 'package:counter_schmounter/src/infrastructure/sync/providers/ulsync_client_provider.dart';
import 'package:counter_schmounter/src/infrastructure/sync/ulsync_client_factory.dart';
import '../../test_helpers/counter_envelope.dart';
import '../../test_helpers/fake_sync_transport.dart';

final testUserIdProvider = StateProvider<String?>((ref) => 'user-a');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalOpLogRepositoryImpl localLog;
  final fakes = <FakeSyncTransport>[];

  Future<void> pumpUntil(bool Function() pred) async {
    for (var i = 0; i < 80; i++) {
      if (pred()) {
        return;
      }
      await Future<void>.delayed(Duration.zero);
    }
    fail('pumpUntil timeout');
  }

  /// Собирает контейнер с поддельным [FakeSyncTransport].
  ///
  /// [failOpeningSync] — первый pull в жизни транспорта бросает исключение,
  /// имитируя недоступный сервер при открывающем обмене (шаг 16b).
  ProviderContainer createContainer({
    bool withClient = true,
    bool failOpeningSync = false,
  }) {
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        localOpLogRepositoryProvider.overrideWithValue(localLog),
        if (!withClient)
          ulsyncClientProvider.overrideWith((ref) async => null)
        else
          ulsyncClientProvider.overrideWith((ref) async {
            final uid = ref.watch(testUserIdProvider);
            if (uid == null) {
              return null;
            }
            final fake = FakeSyncTransport();
            fakes.add(fake);
            fake.onPull = ({required int since, int? limit}) async {
              // [pullCalls] уже содержит текущий вызов — падаем только на первом.
              if (failOpeningSync && fake.pullCalls.length == 1) {
                throw Exception('simulated server unavailable at startup');
              }
              return PullPage(envelopes: const <Envelope>[], nextCursor: since);
            };
            final path = 'live_test_${fakes.length}_$uid.db';
            await databaseFactoryMemory.deleteDatabase(path);
            final client = await UlsyncClientFactory.open(
              userScope: uid,
              sourceId: 'device-test',
              localOpLog: localLog,
              tokenProvider: () async => 'test-token',
              transport: fake,
              databaseFactory: databaseFactoryMemory,
              databasePathOverride: path,
            );
            ref.onDispose(() {
              unawaited(client.close());
            });
            return client;
          }),
      ],
    );
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    localLog = LocalOpLogRepositoryImpl(prefs, scope: 'user:test-user');
    await localLog.initialize();
    fakes.clear();
  });

  group('UlsyncLiveController', () {
    test('SyncApplied invalidates counterStateProvider', () async {
      final container = createContainer();
      container.listen(ulsyncLiveControllerProvider, (previous, next) {});

      await pumpUntil(() => fakes.isNotEmpty && fakes.last.liveCalls >= 1);
      await container.read(counterStateProvider.future);

      var builds = 0;
      container.listen(counterStateProvider, (previous, next) => builds++);
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      final baselineBuilds = builds;

      final opRemote = IncrementOperation(
        opId: 'op-live-1',
        clientId: 'device-remote',
        createdAt: DateTime.utc(2026, 9, 9, 10),
      );
      fakes.last.liveController.add(
        LiveEnvelope(counterEnvelope(operation: opRemote, serverSeq: 1)),
      );

      for (var i = 0; i < 80; i++) {
        final all = await localLog.getAll();
        if (all.any((op) => op.opId == 'op-live-1') &&
            builds > baselineBuilds) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }

      final ops = await localLog.getAll();
      expect(ops.length, 1);
      expect(ops.single.opId, 'op-live-1');
      expect(builds, greaterThan(baselineBuilds));
      expect(await container.read(counterStateProvider.future), 1);
      container.dispose();
    });

    test(
      'SyncCursorAdvanced does not invalidate counterStateProvider',
      () async {
        final container = createContainer();
        container.listen(ulsyncLiveControllerProvider, (previous, next) {});

        await pumpUntil(() => fakes.isNotEmpty && fakes.last.liveCalls >= 1);
        await container.read(counterStateProvider.future);

        var builds = 0;
        container.listen(counterStateProvider, (previous, next) => builds++);
        for (var i = 0; i < 5; i++) {
          await Future<void>.delayed(Duration.zero);
        }
        final baseline = builds;

        fakes.last.liveController.add(const LiveCursor(1));
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(builds, baseline);
        container.dispose();
      },
    );

    test('no client means no live subscription', () async {
      final container = createContainer(withClient: false);
      container.listen(ulsyncLiveControllerProvider, (previous, next) {});

      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(fakes, isEmpty);
      expect(
        container.read(ulsyncLiveControllerProvider),
        UlsyncLiveStatus.disconnected,
      );
      container.dispose();
    });

    test('user switch closes old client and opens live on new one', () async {
      final container = createContainer();
      container.listen(ulsyncLiveControllerProvider, (previous, next) {});

      await pumpUntil(() => fakes.length == 1 && fakes[0].liveCalls >= 1);

      container.read(testUserIdProvider.notifier).state = 'user-b';
      await pumpUntil(() => fakes.length >= 2 && fakes[1].liveCalls >= 1);

      expect(fakes[0].closed, isTrue);
      expect(fakes[1].closed, isFalse);
      container.dispose();
    });

    test('background closes live; resume runs pull before live', () async {
      final container = createContainer();
      container.listen(ulsyncLiveControllerProvider, (previous, next) {});

      await pumpUntil(() => fakes.isNotEmpty && fakes[0].liveCalls >= 1);

      await container
          .read(ulsyncLiveControllerProvider.notifier)
          .onAppBackgrounded();
      await pumpUntil(() => fakes[0].closed);
      await pumpUntil(() => fakes.length >= 2);

      expect(fakes[1].liveCalls, 0);

      fakes[1].callLog.clear();
      await container
          .read(ulsyncLiveControllerProvider.notifier)
          .onAppResumed();
      await pumpUntil(() => fakes[1].liveCalls >= 1);

      final pullIndex = fakes[1].callLog.indexOf('pull');
      final liveIndex = fakes[1].callLog.indexOf('live');
      expect(pullIndex, greaterThanOrEqualTo(0));
      expect(liveIndex, greaterThan(pullIndex));

      await container
          .read(ulsyncLiveControllerProvider.notifier)
          .onAppBackgrounded();
      final countAfterSecondBackground = fakes.length;
      expect(countAfterSecondBackground, lessThan(3));

      container.dispose();
    });

    test('resume after background refreshes counter from syncOnce pull', () async {
      final container = createContainer();
      container.listen(ulsyncLiveControllerProvider, (previous, next) {});

      await pumpUntil(() => fakes.isNotEmpty && fakes[0].liveCalls >= 1);
      expect(await container.read(counterStateProvider.future), 0);

      await container
          .read(ulsyncLiveControllerProvider.notifier)
          .onAppBackgrounded();
      await pumpUntil(() => fakes[0].closed);
      await pumpUntil(() => fakes.length >= 2);

      final opRemote = IncrementOperation(
        opId: 'op-resume-pull',
        clientId: 'device-remote',
        createdAt: DateTime.utc(2026, 9, 9, 11),
      );
      fakes[1].onPull = ({required int since, int? limit}) async {
        return PullPage(
          envelopes: <Envelope>[
            counterEnvelope(operation: opRemote, serverSeq: 1),
          ],
          nextCursor: 1,
        );
      };

      await container
          .read(ulsyncLiveControllerProvider.notifier)
          .onAppResumed();
      await pumpUntil(() => fakes[1].liveCalls >= 1);

      for (var i = 0; i < 80; i++) {
        final value = await container.read(counterStateProvider.future);
        if (value == 1) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }

      expect(await container.read(counterStateProvider.future), 1);
      final ops = await localLog.getAll();
      expect(ops.any((op) => op.opId == 'op-resume-pull'), isTrue);
      container.dispose();
    });

    test('connection lost and restored update visible status', () async {
      final container = createContainer();
      container.listen(ulsyncLiveControllerProvider, (previous, next) {});

      await pumpUntil(() => fakes.isNotEmpty && fakes.last.liveCalls >= 1);

      fakes.last.onConnectionState!(LiveConnectionState.lost);
      await pumpUntil(
        () =>
            container.read(ulsyncLiveControllerProvider) ==
            UlsyncLiveStatus.disconnected,
      );
      expect(fakes.last.closed, isFalse);

      fakes.last.onConnectionState!(LiveConnectionState.restored);
      await pumpUntil(
        () =>
            container.read(ulsyncLiveControllerProvider) ==
            UlsyncLiveStatus.connected,
      );

      container.dispose();
    });

    test('connection restored after lost runs syncOnce and refreshes counter',
        () async {
      final container = createContainer();
      container.listen(ulsyncLiveControllerProvider, (previous, next) {});

      await pumpUntil(() => fakes.isNotEmpty && fakes.last.liveCalls >= 1);
      expect(await container.read(counterStateProvider.future), 0);

      fakes.last.onConnectionState!(LiveConnectionState.lost);
      await pumpUntil(
        () =>
            container.read(ulsyncLiveControllerProvider) ==
            UlsyncLiveStatus.disconnected,
      );

      final opRemote = IncrementOperation(
        opId: 'op-reconnect-pull',
        clientId: 'device-remote',
        createdAt: DateTime.utc(2026, 9, 9, 12),
      );
      final pullsBeforeRestore = fakes.last.pullCalls.length;
      fakes.last.onPull = ({required int since, int? limit}) async {
        return PullPage(
          envelopes: <Envelope>[
            counterEnvelope(operation: opRemote, serverSeq: 1),
          ],
          nextCursor: 1,
        );
      };

      fakes.last.onConnectionState!(LiveConnectionState.restored);
      await pumpUntil(
        () => fakes.last.pullCalls.length > pullsBeforeRestore,
      );

      for (var i = 0; i < 80; i++) {
        final value = await container.read(counterStateProvider.future);
        if (value == 1) {
          break;
        }
        await Future<void>.delayed(Duration.zero);
      }

      expect(await container.read(counterStateProvider.future), 1);
      container.dispose();
    });

    test(
      'opening syncOnce failure still opens live and stays disconnected',
      () async {
        // Сервер «лежит» при первом обмене: syncOnce падает, но live() обязан
        // открыться — иначе библиотека не начнёт цикл переподключения SSE.
        final container = createContainer(failOpeningSync: true);
        container.listen(ulsyncLiveControllerProvider, (previous, next) {});

        await pumpUntil(() => fakes.isNotEmpty && fakes.last.liveCalls >= 1);

        expect(
          container.read(ulsyncLiveControllerProvider),
          UlsyncLiveStatus.disconnected,
        );
        expect(fakes.last.liveCalls, greaterThanOrEqualTo(1));
        expect(fakes.last.closed, isFalse);
        expect(fakes.last.pullCalls, isNotEmpty);

        container.dispose();
      },
    );

    test(
      'connection restored after opening sync failure runs syncOnce again',
      () async {
        // После подъёма «сервера» библиотека шлёт Restored; контроллер должен
        // догнать очередь повторным syncOnce и перейти в connected.
        final container = createContainer(failOpeningSync: true);
        container.listen(ulsyncLiveControllerProvider, (previous, next) {});

        await pumpUntil(() => fakes.isNotEmpty && fakes.last.liveCalls >= 1);
        final fake = fakes.last;

        expect(
          container.read(ulsyncLiveControllerProvider),
          UlsyncLiveStatus.disconnected,
        );

        final opRemote = IncrementOperation(
          opId: 'op-opening-restore',
          clientId: 'device-remote',
          createdAt: DateTime.utc(2026, 9, 11, 12),
        );
        fake.onPull = ({required int since, int? limit}) async {
          return PullPage(
            envelopes: <Envelope>[
              counterEnvelope(operation: opRemote, serverSeq: 1),
            ],
            nextCursor: 1,
          );
        };

        final pullsBeforeRestore = fake.pullCalls.length;
        fake.onConnectionState!(LiveConnectionState.restored);

        await pumpUntil(
          () => fake.pullCalls.length > pullsBeforeRestore,
        );
        await pumpUntil(
          () =>
              container.read(ulsyncLiveControllerProvider) ==
              UlsyncLiveStatus.connected,
        );

        for (var i = 0; i < 80; i++) {
          final value = await container.read(counterStateProvider.future);
          if (value == 1) {
            break;
          }
          await Future<void>.delayed(Duration.zero);
        }

        expect(await container.read(counterStateProvider.future), 1);
        container.dispose();
      },
    );

    test(
      'connection restored without lost or opening failure skips extra syncOnce',
      () async {
        // Успешный старт: первый Restored не должен дублировать обмен
        // (нет _connectionWasLost и нет _openingSyncFailed).
        final container = createContainer();
        container.listen(ulsyncLiveControllerProvider, (previous, next) {});

        await pumpUntil(() => fakes.isNotEmpty && fakes.last.liveCalls >= 1);
        final fake = fakes.last;
        final pullsAfterStartup = fake.pullCalls.length;
        expect(pullsAfterStartup, greaterThan(0));

        fake.onConnectionState!(LiveConnectionState.restored);
        await pumpUntil(
          () =>
              container.read(ulsyncLiveControllerProvider) ==
              UlsyncLiveStatus.connected,
        );

        for (var i = 0; i < 20; i++) {
          await Future<void>.delayed(Duration.zero);
        }

        expect(fake.pullCalls.length, pullsAfterStartup);
        container.dispose();
      },
    );
  });
}
