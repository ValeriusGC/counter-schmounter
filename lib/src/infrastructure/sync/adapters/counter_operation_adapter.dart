/// Адаптер сущности `counter_operation` для ulsync.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/infrastructure/counter/codecs/counter_operation_codec.dart';

/// Создаёт [EntityAdapter] для неизменяемых операций счётчика.
///
/// [apply] делегирует в [LocalOpLogRepository.append]: дедупликация по `op_id`
/// даёт идемпотентность, которую требует контракт адаптера.
EntityAdapter<CounterOperation> counterOperationAdapter(
  LocalOpLogRepository localOpLog,
) {
  return EntityAdapter<CounterOperation>(
    entityType: 'counter_operation',
    schemaVersion: 1,
    encode: (CounterOperation op) => Uint8List.fromList(
      utf8.encode(jsonEncode(CounterOperationCodec.toJson(op))),
    ),
    decode: (Uint8List bytes, int schemaVersion) {
      // Круг 1: версия всегда 1; ветвление по [schemaVersion] не нужно.
      final decoded = jsonDecode(utf8.decode(bytes));
      return CounterOperationCodec.fromJson(
        Map<String, dynamic>.from(decoded as Map),
      );
    },
    load: (String id) => localOpLog.byId(id),
    apply: (CounterOperation op) => localOpLog.append(op),
  );
}
