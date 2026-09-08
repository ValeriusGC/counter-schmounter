import 'package:flutter_test/flutter_test.dart';

import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/infrastructure/sync/adapters/counter_operation_adapter.dart';

void main() {
  group('counterOperationAdapter', () {
    late _RecordingLocalOpLog localOpLog;
    late dynamic adapter;

    final operation = IncrementOperation(
      opId: 'op-adapter-1',
      clientId: 'client-b',
      createdAt: DateTime.utc(2026, 2, 1, 9, 30),
    );

    setUp(() {
      localOpLog = _RecordingLocalOpLog();
      adapter = counterOperationAdapter(localOpLog);
    });

    test('encode/decode round-trip', () {
      final bytes = adapter.encode(operation);
      final decoded = adapter.decode(bytes, 1);
      expect(decoded, operation);
    });

    test('apply twice keeps one operation (idempotent append)', () async {
      await adapter.apply(operation);
      await adapter.apply(operation);
      expect(localOpLog.appended.length, 1);
      expect(localOpLog.appended.single.opId, operation.opId);
    });
  });
}

/// In-memory журнал с дедупликацией по `op_id` для теста адаптера.
final class _RecordingLocalOpLog implements LocalOpLogRepository {
  final List<CounterOperation> appended = <CounterOperation>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> append(CounterOperation operation) async {
    if (appended.any((op) => op.opId == operation.opId)) {
      return;
    }
    appended.add(operation);
  }

  @override
  Future<List<CounterOperation>> getAll() async =>
      List<CounterOperation>.from(appended);

  @override
  Future<CounterOperation?> byId(String opId) async {
    for (final CounterOperation operation in appended) {
      if (operation.opId == opId) {
        return operation;
      }
    }
    return null;
  }

  @override
  Future<void> clear() async {
    appended.clear();
  }
}
