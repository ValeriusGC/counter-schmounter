/// Сборка [UlsyncClient] без Riverpod — для провайдера и тестов.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
// ignore: depend_on_referenced_packages — тип только для тестового [databaseFactory]; пакет в dev_dependencies.
import 'package:sembast/sembast.dart' show DatabaseFactory;
import 'package:ulsync/ulsync.dart';

import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/infrastructure/sync/adapters/counter_operation_adapter.dart';
import 'package:counter_schmounter/src/infrastructure/sync/ulsync_base_url.dart';

/// Фабрика клиента ulsync с адаптером операции счётчика.
abstract final class UlsyncClientFactory {
  /// Открывает клиента для [userScope].
  ///
  /// [transport] и [databaseFactory] — только тесты. В рабочем коде оба null:
  /// транспорт HTTP создаст сам [UlsyncClient], фабрику БД выберет пакет.
  /// [databaseFactory] — только тесты (`databaseFactoryMemory` из dev_dependency sembast).
  static Future<UlsyncClient> open({
    required String userScope,
    required String sourceId,
    required LocalOpLogRepository localOpLog,
    required Future<String?> Function() tokenProvider,
    SyncTransport? transport,
    DatabaseFactory? databaseFactory,
    String? databasePathOverride,
  }) async {
    final path =
        databasePathOverride ??
        (kIsWeb
            ? 'ulsync.db'
            : '${(await getApplicationDocumentsDirectory()).path}/ulsync.db');

    final store = await SembastMetadataStore.open(
      databasePath: path,
      factory: databaseFactory,
    );

    return UlsyncClient(
      baseUrl: Uri.parse(kUlsyncBaseUrl),
      userScope: userScope,
      sourceId: sourceId,
      tokenProvider: tokenProvider,
      store: store,
      adapters: <EntityAdapter<dynamic>>[counterOperationAdapter(localOpLog)],
      transport: transport,
    );
  }
}
