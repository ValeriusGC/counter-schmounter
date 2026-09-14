import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/infrastructure/counter/codecs/counter_operation_codec.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';
import 'package:counter_schmounter/src/infrastructure/shared/storage/storage_migration.dart';
import 'package:counter_schmounter/src/infrastructure/shared/storage/storage_schema_version.dart';

/// Порог предупреждения о размере op-log (не лимит удаления).
///
/// После круга 1a журнал **не усекается**: неподтверждённое сервером
/// удалять нельзя (§7.4 решения), а число на экране равно длине журнала —
/// усечение ломало бы счётчик. При превышении порога пишется одна строка
/// в лог; осмысленное усечение потребует базового значения в модели (OQ).
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
/// - Предупреждение при большом размере op-log (без удаления операций)
/// - Миграции схемы данных
///
/// ВАЖНО (account-scope):
/// - операции разных аккаунтов НЕ смешиваются
/// - scope задаётся при создании репозитория
class LocalOpLogRepositoryImpl extends ChangeNotifier
    implements LocalOpLogRepository {
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

    _warnIfJournalLarge(newOperations.length);

    // Сохраняем операции
    await _saveOperations(newOperations);
    notifyListeners();

    AppLogger.info(
      component: AppLogComponent.localOpLog,
      message: 'Operation appended',
      context: <String, Object?>{
        'scope': _scope,
        'storage_key': _storageKey(),
        'op_id': operation.opId,
        'total_operations': newOperations.length,
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
          .map(
            (json) =>
                CounterOperationCodec.fromJson(json as Map<String, dynamic>),
          )
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
  Future<CounterOperation?> byId(String opId) async {
    final operations = await getAll();
    for (final CounterOperation operation in operations) {
      if (operation.opId == opId) {
        return operation;
      }
    }
    return null;
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
    notifyListeners();
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
    final jsonList = operations
        .map((op) => CounterOperationCodec.toJson(op))
        .toList();
    final jsonString = jsonEncode(jsonList);
    await _prefs.setString(_storageKey(), jsonString);
  }

  /// Пишет предупреждение, если журнал превысил [kMaxOperationsCount].
  ///
  /// Удаление снято: вместе со «старыми» операциями исчезали неотправленные
  /// и само число на экране. Рост журнала без базового значения счётчика —
  /// открытый вопрос приложения; здесь только фиксируем размер в логе.
  void _warnIfJournalLarge(int operationCount) {
    if (operationCount <= kMaxOperationsCount) {
      return;
    }

    AppLogger.info(
      component: AppLogComponent.localOpLog,
      message:
          'Журнал операций превысил порог предупреждения; усечение отключено',
      context: <String, Object?>{
        'scope': _scope,
        'storage_key': _storageKey(),
        'operations_count': operationCount,
        'warning_threshold': kMaxOperationsCount,
      },
    );
  }
}
