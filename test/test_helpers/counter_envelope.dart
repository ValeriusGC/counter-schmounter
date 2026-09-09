import 'dart:convert';
import 'dart:typed_data';

import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/infrastructure/counter/codecs/counter_operation_codec.dart';

/// Собирает wire-конверт операции счётчика для тестов ulsync.
Envelope counterEnvelope({
  required IncrementOperation operation,
  required int serverSeq,
}) {
  final createdMs = operation.createdAt.toUtc().millisecondsSinceEpoch;
  return Envelope(
    id: operation.opId,
    part: 'full',
    entityType: 'counter_operation',
    createdAtMs: createdMs,
    lastEditedAtMs: createdMs,
    revision: 1,
    sourceId: operation.clientId,
    flags: 0,
    schemaVersion: 1,
    payloadEncoding: 'json',
    payload: Uint8List.fromList(
      utf8.encode(jsonEncode(CounterOperationCodec.toJson(operation))),
    ),
    serverSeq: serverSeq,
  );
}
