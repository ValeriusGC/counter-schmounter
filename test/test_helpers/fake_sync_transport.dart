/// Поддельный [SyncTransport] для тестов приложения (без HTTP).
library;

import 'dart:async';

import 'package:ulsync/ulsync.dart';

/// In-memory транспорт: записывает вызовы, ответы задаёт тест через [onPush]/[onPull].
final class FakeSyncTransport implements SyncTransport {
  /// Вызовы push в порядке поступления.
  final List<List<Envelope>> pushCalls = <List<Envelope>>[];

  /// Скрипт ответа push; по умолчанию каждый конверт `applied: true`.
  Future<List<PushResult>> Function(List<Envelope> envelopes)? onPush;

  /// Вызовы pull.
  final List<({int since, int? limit})> pullCalls =
      <({int since, int? limit})>[];

  /// Скрипт ответа pull; по умолчанию пустая страница на [since].
  Future<PullPage> Function({required int since, int? limit})? onPull;

  /// Журнал вызовов `push` / `pull` / `live` в порядке поступления.
  final List<String> callLog = <String>[];

  /// Сколько раз вызвали [live].
  int liveCalls = 0;

  /// Последний [appliedSince] из [live]; для проверки курсора в тестах.
  int Function()? appliedSince;

  /// Последний [onConnectionState] из [live]; для эмуляции lost/restored.
  void Function(LiveConnectionState state)? onConnectionState;

  /// Поток live (контракт [SyncTransport.live]); используется в шаге 16.
  final StreamController<LiveMessage> liveController =
      StreamController<LiveMessage>.broadcast();

  /// Закрыт ли транспорт.
  bool closed = false;

  @override
  Future<List<PushResult>> push(List<Envelope> envelopes) async {
    _ensureOpen();
    callLog.add('push');
    pushCalls.add(List<Envelope>.from(envelopes));
    final handler = onPush;
    if (handler != null) {
      return handler(envelopes);
    }
    return <PushResult>[
      for (final envelope in envelopes)
        PushResult(id: envelope.id, part: envelope.part, applied: true),
    ];
  }

  @override
  Future<PullPage> pull({required int since, int? limit}) async {
    _ensureOpen();
    callLog.add('pull');
    pullCalls.add((since: since, limit: limit));
    final handler = onPull;
    if (handler != null) {
      return handler(since: since, limit: limit);
    }
    return PullPage(envelopes: const <Envelope>[], nextCursor: since);
  }

  @override
  Stream<LiveMessage> live({
    required int Function() appliedSince,
    void Function(LiveConnectionState state)? onConnectionState,
  }) {
    _ensureOpen();
    callLog.add('live');
    liveCalls++;
    this.appliedSince = appliedSince;
    this.onConnectionState = onConnectionState;
    return liveController.stream;
  }

  @override
  Future<void> close() async {
    if (closed) {
      return;
    }
    closed = true;
    if (!liveController.isClosed) {
      await liveController.close();
    }
  }

  void _ensureOpen() {
    if (closed) {
      throw StateError('FakeSyncTransport is closed');
    }
  }
}
