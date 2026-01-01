import 'package:supa_counter/src/domain/counter/operations/counter_operation.dart';
import 'package:supa_counter/src/domain/counter/operations/increment_operation.dart';
import 'package:supa_counter/src/domain/counter/repositories/remote_op_log_repository.dart';
import 'package:supa_counter/src/infrastructure/shared/logging/app_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Реализация [RemoteOpLogRepository] через Supabase PostgREST.
///
/// На Шаге 8 поддерживается **только чтение**.
/// В local-only режиме (без auth session) возвращает пустой список.
///
/// Договорённости (строго по плану):
/// - таблица: `counter_operations`
/// - фильтры:
///   - `user_id = currentSession.user.id`
///   - `entity_id = <entityId>`
///   - `created_at > since` (если since != null)
/// - сортировка: `created_at ASC`
///
/// Валидация:
/// - `op_id`, `type`, `client_id`, `created_at` — обязательны
/// - невалидные строки логируются и пропускаются
final class RemoteOpLogRepositoryImpl implements RemoteOpLogRepository {
  /// Создаёт репозиторий.
  RemoteOpLogRepositoryImpl({
    required SupabaseClient supabaseClient,
    required String clientId,
  }) : _supabaseClient = supabaseClient,
       _clientId = clientId;

  final SupabaseClient _supabaseClient;
  final String _clientId;

  @override
  Future<List<CounterOperation>> fetchAfter({
    required String entityId,
    required DateTime? since,
  }) async {
    final session = _supabaseClient.auth.currentSession;
    final userId = session?.user.id;

    if (userId == null) {
      AppLogger.info(
        component: AppLogComponent.syncRemoteOpLog,
        message: 'Skip remote op-log fetch: no auth session.',
        context: <String, Object?>{
          'client_id': _clientId,
          'entity_id': entityId,
        },
      );
      return <CounterOperation>[];
    }

    try {
      AppLogger.info(
        component: AppLogComponent.syncRemoteOpLog,
        message: 'Fetching remote op-log.',
        context: <String, Object?>{
          'client_id': _clientId,
          'user_id': userId,
          'entity_id': entityId,
          'since': since?.toIso8601String(),
        },
      );

      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _supabaseClient
          .from('counter_operations')
          .select()
          .eq('user_id', userId)
          .eq('entity_id', entityId);

      if (since != null) {
        query = query.gt('created_at', since.toIso8601String());
      }

      final rows = await query.order('created_at', ascending: true);

      final operations = <CounterOperation>[];
      for (final row in rows) {
        final operation = _tryMapRowToOperation(
          row: row,
          entityId: entityId,
          userId: userId,
        );

        if (operation == null) {
          continue;
        }

        operations.add(operation);
      }

      AppLogger.info(
        component: AppLogComponent.syncRemoteOpLog,
        message: 'Remote op-log fetched.',
        context: <String, Object?>{
          'client_id': _clientId,
          'user_id': userId,
          'entity_id': entityId,
          'count': operations.length,
        },
      );

      return operations;
    } catch (e, st) {
      AppLogger.error(
        component: AppLogComponent.syncRemoteOpLog,
        message: 'Remote op-log fetch failed.',
        error: e,
        stackTrace: st,
        context: <String, Object?>{
          'client_id': _clientId,
          'user_id': userId,
          'entity_id': entityId,
          'since': since?.toIso8601String(),
        },
      );
      rethrow;
    }
  }

  CounterOperation? _tryMapRowToOperation({
    required Map<String, dynamic> row,
    required String entityId,
    required String userId,
  }) {
    try {
      final opId = row['op_id'] as String?;
      final type = row['type'] as String?;
      final clientId = row['client_id'] as String?;
      final createdAtRaw = row['created_at'];

      if (opId == null ||
          opId.isEmpty ||
          type == null ||
          type.isEmpty ||
          clientId == null ||
          clientId.isEmpty ||
          createdAtRaw == null) {
        AppLogger.error(
          component: AppLogComponent.syncRemoteOpLog,
          message: 'Skip invalid op-log row: missing required fields.',
          error: StateError('Invalid op-log row'),
          context: <String, Object?>{
            'client_id': _clientId,
            'user_id': userId,
            'entity_id': entityId,
            'row': row.toString(),
          },
        );
        return null;
      }

      final createdAt = DateTime.tryParse(createdAtRaw.toString());
      if (createdAt == null) {
        AppLogger.error(
          component: AppLogComponent.syncRemoteOpLog,
          message: 'Skip invalid op-log row: created_at is not parseable.',
          error: StateError('Invalid created_at'),
          context: <String, Object?>{
            'client_id': _clientId,
            'user_id': userId,
            'entity_id': entityId,
            'created_at': createdAtRaw.toString(),
            'op_id': opId,
          },
        );
        return null;
      }

      switch (type) {
        case 'increment':
          // ВАЖНО:
          // Здесь должен быть вызван ваш реальный конструктор IncrementOperation.
          // Если сигнатура отличается — компилятор скажет, и мы исправим точечно.
          return IncrementOperation(
            opId: opId,
            clientId: clientId,
            createdAt: createdAt,
          );
        default:
          AppLogger.error(
            component: AppLogComponent.syncRemoteOpLog,
            message: 'Skip unsupported operation type.',
            error: UnsupportedError('Unsupported type: $type'),
            context: <String, Object?>{
              'client_id': _clientId,
              'user_id': userId,
              'entity_id': entityId,
              'op_id': opId,
              'type': type,
            },
          );
          return null;
      }
    } catch (e, st) {
      AppLogger.error(
        component: AppLogComponent.syncRemoteOpLog,
        message: 'Skip op-log row: mapping failed.',
        error: e,
        stackTrace: st,
        context: <String, Object?>{
          'client_id': _clientId,
          'user_id': userId,
          'entity_id': entityId,
          'row': row.toString(),
        },
      );
      return null;
    }
  }
}
