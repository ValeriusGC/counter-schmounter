/// Поддельный транспорт с [SyncHelloTransport] для тестов отказа склада.
library;

import 'dart:async';

import 'package:ulsync/ulsync.dart';

/// In-memory транспорт, умеющий hello (SPEC §3.5).
///
/// Отдельный тип, а не расширение [FakeSyncTransport]: в пакете hello вынесен
/// в [SyncHelloTransport], чтобы старые дублёры без hello продолжали собираться.
final class FakeHelloSyncTransport
    implements SyncTransport, SyncHelloTransport {
  /// Скрипт hello; по умолчанию успешный ответ с тем же [origin].
  Future<HelloResult?> Function(String origin)? onHello;

  /// Вызовы push в порядке поступления.
  final List<List<Envelope>> pushCalls = <List<Envelope>>[];

  /// Скрипт ответа push; по умолчанию каждый конверт `applied: true`.
  Future<List<PushResult>> Function(List<Envelope> envelopes)? onPush;

  /// Вызовы pull.
  final List<({int since, int? limit})> pullCalls =
      <({int since, int? limit})>[];

  /// Скрипт ответа pull; по умолчанию пустая страница на [since].
  Future<PullPage> Function({required int since, int? limit})? onPull;

  /// Журнал вызовов в порядке поступления.
  final List<String> callLog = <String>[];

  /// Сколько раз вызвали [live].
  int liveCalls = 0;

  /// Закрыт ли транспорт.
  bool closed = false;

  @override
  Future<HelloResult?> hello(String origin) async {
    _ensureOpen();
    callLog.add('hello');
    final handler = onHello;
    if (handler != null) {
      return handler(origin);
    }
    return HelloResult(origin: origin, userId: 'alice');
  }

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
    return const Stream<LiveMessage>.empty();
  }

  @override
  Future<void> close() async {
    closed = true;
  }

  void _ensureOpen() {
    if (closed) {
      throw StateError('FakeHelloSyncTransport is closed');
    }
  }
}
