import 'package:shared_preferences/shared_preferences.dart';

import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';
import 'package:counter_schmounter/src/infrastructure/shared/storage/storage_schema_version.dart';

/// Класс для управления миграциями схемы хранилища.
///
/// Применяет миграции последовательно от `fromVersion` до `toVersion`.
/// Каждая миграция должна быть идемпотентной (безопасно применять повторно).
class StorageMigration {
  StorageMigration._();

  /// Применяет миграции от `fromVersion` до `toVersion`.
  ///
  /// Параметры:
  /// - [prefs] - экземпляр SharedPreferences
  /// - [fromVersion] - текущая версия схемы (или 0, если версия не установлена)
  /// - [toVersion] - целевая версия схемы
  ///
  /// Последовательно применяет миграции для каждой версии между `fromVersion` и `toVersion`.
  static Future<void> migrate(
    SharedPreferences prefs,
    int fromVersion,
    int toVersion,
  ) async {
    if (fromVersion >= toVersion) {
      // Миграция не требуется
      return;
    }

    AppLogger.info(
      component: AppLogComponent.state,
      message: 'Starting storage migration',
      context: <String, Object?>{
        'from_version': fromVersion,
        'to_version': toVersion,
      },
    );

    // Применяем миграции последовательно
    for (int version = fromVersion + 1; version <= toVersion; version++) {
      await _migrateToVersion(prefs, version);
    }

    // Обновляем версию схемы
    await prefs.setInt('storage_schema_version', toVersion);

    AppLogger.info(
      component: AppLogComponent.state,
      message: 'Storage migration completed',
      context: <String, Object?>{
        'from_version': fromVersion,
        'to_version': toVersion,
      },
    );
  }

  /// Применяет миграцию к конкретной версии.
  ///
  /// Внутренний метод, который вызывает соответствующую миграцию для версии.
  static Future<void> _migrateToVersion(
    SharedPreferences prefs,
    int version,
  ) async {
    switch (version) {
      case StorageSchemaVersion.kStorageSchemaVersionV1:
        // V1 - базовая версия, миграция не требуется
        // Просто создаем структуру, если её нет
        AppLogger.info(
          component: AppLogComponent.state,
          message: 'Migrating to V1 (initial schema)',
        );
        break;
      // В будущем здесь будут миграции для V2, V3 и т.д.
      // case StorageSchemaVersion.kStorageSchemaVersionV2:
      //   await _migrateToV2(prefs);
      //   break;
      default:
        throw ArgumentError('Unknown storage schema version: $version');
    }
  }
}
