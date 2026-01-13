import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/operations/increment_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';
import 'package:counter_schmounter/src/infrastructure/shared/storage/storage_migration.dart';
import 'package:counter_schmounter/src/infrastructure/shared/storage/storage_schema_version.dart';

/// Максимальное количество операций в op-log.
///
/// При превышении этого лимита самые старые операции удаляются,
/// остаются только последние [kMaxOperationsCount] операций.
const int kMaxOperationsCount = 1000;

/// Ключ для хранения версии схемы в SharedPreferences.
const String _kSchemaVersionKey = 'storage_schema_version';

/// Базовый префикс ключа для хранения операций счетчика в SharedPreferences.
///
/// Фактический ключ формируется как:
/// - `counter_operations::<scope>`
///
/// Где scope:
/// - `user:<user_id>` для авторизованного пользователя
/// - `anonymous` для неавторизованного режима
const String _kCounterOperationsKeyBase = 'counter_operations';

/// Инфраструктурная реализация [LocalOpLogRepository] через SharedPreferences.
///
/// Сохраняет операции в JSON формате и обеспечивает:
/// - Персистентность между перезапусками приложения
/// - Дедупликацию операций по `op_id`
/// - Ограничение роста op-log (удаление старых операций)
/// - Миграции схемы данных
///
/// ВАЖНО (account-scope):
/// - операции разных аккаунтов НЕ смешиваются
/// - scope задаётся при создании репозитория
class LocalOpLogRepositoryImpl implements LocalOpLogRepository {
  /// Создает экземпляр [LocalOpLogRepositoryImpl].
  ///
  /// [scope] определяет namespace хранения данных.
  /// Рекомендуемые значения:
  /// - `user:<user_id>`
  /// - `anonymous`
  LocalOpLogRepositoryImpl(this._prefs, {required String scope})
    : _scope = scope;

  final SharedPreferences _prefs;
  final String _scope;

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    AppLogger.info(
      component: AppLogComponent.localOpLog,
      message: 'Initializing LocalOpLogRepository',
      context: <String, Object?>{'scope': _scope},
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
    AppLogger.info(
      component: AppLogComponent.localOpLog,
      message: 'LocalOpLogRepository initialized',
      context: <String, Object?>{
        'scope': _scope,
        'operations_count': operations.length,
        'storage_key': _storageKey(),
      },
    );
  }

  @override
  Future<void> append(CounterOperation operation) async {
    if (!_initialized) {
      AppLogger.info(
        component: AppLogComponent.localOpLog,
        message: 'LocalOpLogRepository auto-initialize on append.',
        context: <String, Object?>{
          'scope': _scope,
          'storage_key': _storageKey(),
        },
      );
      await initialize();
    }

    // Загружаем существующие операции
    final operations = await getAll();

    // Проверяем дедупликацию по op_id
    if (operations.any((op) => op.opId == operation.opId)) {
      AppLogger.info(
        component: AppLogComponent.localOpLog,
        message: 'Operation with op_id already exists, skipping',
        context: <String, Object?>{
          'scope': _scope,
          'storage_key': _storageKey(),
          'op_id': operation.opId,
        },
      );
      return;
    }

    // Добавляем новую операцию
    final newOperations = [...operations, operation];

    // Применяем ограничение роста (удаляем старые операции, если превышен лимит)
    final compactedOperations = _compactIfNeeded(newOperations);

    // Сохраняем операции
    await _saveOperations(compactedOperations);

    AppLogger.info(
      component: AppLogComponent.localOpLog,
      message: 'Operation appended',
      context: <String, Object?>{
        'scope': _scope,
        'storage_key': _storageKey(),
        'op_id': operation.opId,
        'total_operations': compactedOperations.length,
      },
    );
  }

  @override
  Future<List<CounterOperation>> getAll() async {
    if (!_initialized) {
      AppLogger.info(
        component: AppLogComponent.localOpLog,
        message: 'LocalOpLogRepository auto-initialize on getAll.',
        context: <String, Object?>{
          'scope': _scope,
          'storage_key': _storageKey(),
        },
      );
      await initialize();
    }

    final key = _storageKey();

    final jsonString = _prefs.getString(key);
    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => _deserializeOperation(json as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      AppLogger.error(
        component: AppLogComponent.localOpLog,
        message: 'Error deserializing operations',
        error: e,
        stackTrace: stackTrace,
        context: <String, Object?>{'scope': _scope, 'storage_key': key},
      );
      // В случае ошибки возвращаем пустой список
      return [];
    }
  }

  @override
  Future<void> clear() async {
    if (!_initialized) {
      AppLogger.info(
        component: AppLogComponent.localOpLog,
        message: 'LocalOpLogRepository auto-initialize on clear.',
        context: <String, Object?>{
          'scope': _scope,
          'storage_key': _storageKey(),
        },
      );
      await initialize();
    }

    final key = _storageKey();
    await _prefs.remove(key);
    AppLogger.info(
      component: AppLogComponent.localOpLog,
      message: 'Operations cleared',
      context: <String, Object?>{'scope': _scope, 'storage_key': key},
    );
  }

  String _storageKey() {
    return '$_kCounterOperationsKeyBase::$_scope';
  }

  /// Сохраняет операции в SharedPreferences.
  Future<void> _saveOperations(List<CounterOperation> operations) async {
    final jsonList = operations.map((op) => _serializeOperation(op)).toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs.setString(_storageKey(), jsonString);
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
    AppLogger.info(
      component: AppLogComponent.localOpLog,
      message: 'Compacting op-log: removing oldest operations',
      context: <String, Object?>{
        'scope': _scope,
        'storage_key': _storageKey(),
        'removed_count': removedCount,
        'limit': kMaxOperationsCount,
      },
    );

    // Оставляем только последние kMaxOperationsCount операций
    return operations.sublist(removedCount);
  }
}
