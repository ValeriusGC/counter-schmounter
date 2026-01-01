import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import 'package:supa_counter/src/domain/counter/operations/counter_operation.dart';
import 'package:supa_counter/src/domain/counter/operations/increment_operation.dart';
import 'package:supa_counter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:supa_counter/src/infrastructure/shared/storage/storage_migration.dart';
import 'package:supa_counter/src/infrastructure/shared/storage/storage_schema_version.dart';

/// Максимальное количество операций в op-log.
///
/// При превышении этого лимита самые старые операции удаляются,
/// остаются только последние [kMaxOperationsCount] операций.
const int kMaxOperationsCount = 1000;

/// Ключ для хранения версии схемы в SharedPreferences.
const String _kSchemaVersionKey = 'storage_schema_version';

/// Ключ для хранения операций счетчика в SharedPreferences.
const String _kCounterOperationsKey = 'counter_operations';

/// Инфраструктурная реализация [LocalOpLogRepository] через SharedPreferences.
///
/// Сохраняет операции в JSON формате и обеспечивает:
/// - Персистентность между перезапусками приложения
/// - Дедупликацию операций по `op_id`
/// - Ограничение роста op-log (удаление старых операций)
/// - Миграции схемы данных
class LocalOpLogRepositoryImpl implements LocalOpLogRepository {
  /// Создает экземпляр [LocalOpLogRepositoryImpl].
  LocalOpLogRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    developer.log(
      '📦 Initializing LocalOpLogRepository...',
      name: 'LocalOpLogRepositoryImpl',
      error: null,
      stackTrace: null,
      level: 800, // INFO level
    );

    // Читаем текущую версию схемы (или 0, если не установлена)
    final currentVersion = _prefs.getInt(_kSchemaVersionKey) ?? 0;
    final targetVersion = StorageSchemaVersion.kCurrentStorageSchemaVersion;

    // Применяем миграции, если необходимо
    if (currentVersion < targetVersion) {
      await StorageMigration.migrate(_prefs, currentVersion, targetVersion);
    }

    _initialized = true;

    // Загружаем операции для проверки
    final operations = await getAll();
    developer.log(
      '✅ LocalOpLogRepository initialized: ${operations.length} operations loaded',
      name: 'LocalOpLogRepositoryImpl',
      error: null,
      stackTrace: null,
      level: 800, // INFO level
    );
  }

  @override
  Future<void> append(CounterOperation operation) async {
    if (!_initialized) {
      throw StateError(
        'LocalOpLogRepository not initialized. Call initialize() first.',
      );
    }

    // Загружаем существующие операции
    final operations = await getAll();

    // Проверяем дедупликацию по op_id
    if (operations.any((op) => op.opId == operation.opId)) {
      developer.log(
        '⚠️ Operation with op_id ${operation.opId} already exists, skipping',
        name: 'LocalOpLogRepositoryImpl',
        error: null,
        stackTrace: null,
        level: 700, // FINE level
      );
      return;
    }

    // Добавляем новую операцию
    final newOperations = [...operations, operation];

    // Применяем ограничение роста (удаляем старые операции, если превышен лимит)
    final compactedOperations = _compactIfNeeded(newOperations);

    // Сохраняем операции
    await _saveOperations(compactedOperations);

    developer.log(
      '➕ Operation appended: ${operation.opId} (total: ${compactedOperations.length})',
      name: 'LocalOpLogRepositoryImpl',
      error: null,
      stackTrace: null,
      level: 700, // FINE level
    );
  }

  @override
  Future<List<CounterOperation>> getAll() async {
    if (!_initialized) {
      throw StateError(
        'LocalOpLogRepository not initialized. Call initialize() first.',
      );
    }

    final jsonString = _prefs.getString(_kCounterOperationsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => _deserializeOperation(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      developer.log(
        '❌ Error deserializing operations: $e',
        name: 'LocalOpLogRepositoryImpl',
        error: e,
        stackTrace: stackTrace,
        level: 1000, // SEVERE level
      );
      // В случае ошибки возвращаем пустой список
      return [];
    }
  }

  @override
  Future<void> clear() async {
    await _prefs.remove(_kCounterOperationsKey);
    developer.log(
      '🗑️ Operations cleared',
      name: 'LocalOpLogRepositoryImpl',
      error: null,
      stackTrace: null,
      level: 800, // INFO level
    );
  }

  /// Сохраняет операции в SharedPreferences.
  Future<void> _saveOperations(List<CounterOperation> operations) async {
    final jsonList = operations.map((op) => _serializeOperation(op)).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs.setString(_kCounterOperationsKey, jsonString);
  }

  /// Сериализует операцию в JSON.
  Map<String, dynamic> _serializeOperation(CounterOperation operation) {
    if (operation is IncrementOperation) {
      return {
        'op_id': operation.opId,
        'type': 'increment',
        'client_id': operation.clientId,
        'created_at': operation.createdAt.toIso8601String(),
      };
    }
    throw ArgumentError('Unknown operation type: ${operation.runtimeType}');
  }

  /// Десериализует операцию из JSON.
  CounterOperation _deserializeOperation(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final opId = json['op_id'] as String;
    final clientId = json['client_id'] as String;
    final createdAt = DateTime.parse(json['created_at'] as String);

    switch (type) {
      case 'increment':
        return IncrementOperation(
          opId: opId,
          clientId: clientId,
          createdAt: createdAt,
        );
      default:
        throw ArgumentError('Unknown operation type: $type');
    }
  }

  /// Применяет компактизацию op-log, если превышен лимит операций.
  ///
  /// Удаляет самые старые операции, оставляя только последние [kMaxOperationsCount] операций.
  List<CounterOperation> _compactIfNeeded(List<CounterOperation> operations) {
    if (operations.length <= kMaxOperationsCount) {
      return operations;
    }

    final removedCount = operations.length - kMaxOperationsCount;
    developer.log(
      '📉 Compacting op-log: removing $removedCount oldest operations (limit: $kMaxOperationsCount)',
      name: 'LocalOpLogRepositoryImpl',
      error: null,
      stackTrace: null,
      level: 800, // INFO level
    );

    // Оставляем только последние kMaxOperationsCount операций
    return operations.sublist(removedCount);
  }
}
