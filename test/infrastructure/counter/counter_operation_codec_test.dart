import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/infrastructure/counter/codecs/counter_operation_codec.dart';

void main() {
  group('CounterOperationCodec', () {
    final operation = IncrementOperation(
      opId: '11111111-1111-1111-1111-111111111111',
      clientId: 'client-a',
      createdAt: DateTime.utc(2026, 1, 8, 12),
    );

    const goldenJson =
        '{"op_id":"11111111-1111-1111-1111-111111111111","type":"increment","client_id":"client-a","created_at":"2026-01-08T12:00:00.000Z"}';

    test('toJson matches historical golden format', () {
      expect(jsonEncode(CounterOperationCodec.toJson(operation)), goldenJson);
    });

    test('fromJson golden round-trips', () {
      final decoded = CounterOperationCodec.fromJson(
        jsonDecode(goldenJson) as Map<String, dynamic>,
      );
      expect(decoded, operation);
    });

    test('fromJson(toJson(op)) == op', () {
      final roundTrip = CounterOperationCodec.fromJson(
        CounterOperationCodec.toJson(operation),
      );
      expect(roundTrip, operation);
    });

    test('unknown type throws ArgumentError', () {
      expect(
        () => CounterOperationCodec.fromJson(<String, dynamic>{
          'op_id': 'x',
          'type': 'decrement',
          'client_id': 'c',
          'created_at': '2026-01-08T12:00:00.000Z',
        }),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
