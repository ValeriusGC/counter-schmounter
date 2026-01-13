import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/remote_op_log_export_repository.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Реализация [RemoteOpLogExportRepository] через Supabase PostgREST.
///
/// Договорённости (строго по существующему pull-коду и таблице):
/// - таблица: `counter_operations`
/// - поля:
///   - user_id (из currentSession.user.id)
///   - entity_id
///   - op_id
///   - client_id
///   - created_at (ISO-8601)
///   - type (например, `increment`)
///
/// Идемпотентность:
/// - используется upsert по `op_id`
/// - повторная отправка тех же операций не должна ломать экспорт
final class RemoteOpLogExportRepositoryImpl
    implements RemoteOpLogExportRepository {
  /// Создаёт репозиторий экспорта.
  RemoteOpLogExportRepositoryImpl({
    required SupabaseClient supabaseClient,
    required String clientId,
  }) : _supabaseClient = supabaseClient,
       _clientId = clientId;

  final SupabaseClient _supabaseClient;
  final String _clientId;

  @override
  Future<void> exportOperations({
    required String entityId,
    required List<CounterOperation> operations,
  }) async {
    final session = _supabaseClient.auth.currentSession;

    if (session == null) {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Export skipped: no auth session (local-only mode).',
        context: <String, Object?>{
          'client_id': _clientId,
          'entity_id': entityId,
          'operations_count': operations.length,
        },
      );
      return;
    }

    if (operations.isEmpty) {
      AppLogger.info(
        component: AppLogComponent.sync,
        message: 'Export skipped: no operations to export.',
        context: <String, Object?>{
          'client_id': _clientId,
          'user_id': session.user.id,
          'entity_id': entityId,
          'operations_count': 0,
        },
      );
      return;
    }

    final userId = session.user.id;

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'Exporting local operations to remote op-log (push).',
      context: <String, Object?>{
        'client_id': _clientId,
        'user_id': userId,
        'entity_id': entityId,
        'operations_count': operations.length,
      },
    );

    final rows = operations
        .map((op) {
          final type = _mapOperationToType(op);

          return <String, dynamic>{
            'user_id': userId,
            'entity_id': entityId,
            'op_id': op.opId,
            'client_id': op.clientId,
            'created_at': op.createdAt.toIso8601String(),
            'type': type,
          };
        })
        .toList(growable: false);

    // Идемпотентность: upsert по op_id.
    // Если `op_id` уникален — повторная отправка не создаст дубликат.
    await _supabaseClient
        .from('counter_operations')
        .upsert(rows, onConflict: 'op_id', ignoreDuplicates: true);

    AppLogger.info(
      component: AppLogComponent.sync,
      message: 'Export finished (push).',
      context: <String, Object?>{
        'client_id': _clientId,
        'user_id': userId,
        'entity_id': entityId,
        'exported_count': rows.length,
      },
    );
  }

  /// Маппит [CounterOperation] в строковый тип для хранения в БД.
  ///
  /// В текущем проекте поддерживаются только типы, которые уже
  /// сериализуются локальным op-log репозиторием.
  String _mapOperationToType(CounterOperation operation) {
    if (operation is IncrementOperation) {
      return 'increment';
    }

    throw ArgumentError(
      'Unknown operation type for export: ${operation.runtimeType}',
    );
  }
}
