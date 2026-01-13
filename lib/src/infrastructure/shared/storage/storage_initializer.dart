import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_schmounter/src/infrastructure/shared/storage/storage_schema_version.dart';

/// Инициализатор локального storage.
///
/// Отвечает за:
/// - проверку версии схемы
/// - выполнение миграций
/// - установку актуальной версии схемы
///
/// ВАЖНО:
/// Репозитории не управляют версией схемы напрямую.
/// Они предполагают, что storage уже инициализирован.
final class StorageInitializer {
  StorageInitializer(this._prefs);

  final SharedPreferences _prefs;

  /// Выполняет инициализацию storage.
  ///
  /// На текущем шаге миграции являются no-op,
  /// но инфраструктура готова к расширению.
  Future<void> initialize() async {
    final currentVersion =
        _prefs.getInt('storage_schema_version') ??
        StorageSchemaVersion.kStorageSchemaVersionV1 - 1;

    if (currentVersion < StorageSchemaVersion.kCurrentStorageSchemaVersion) {
      await _migrate(currentVersion);
    }

    await _prefs.setInt(
      'storage_schema_version',
      StorageSchemaVersion.kCurrentStorageSchemaVersion,
    );
  }

  Future<void> _migrate(int fromVersion) async {
    // На текущем шаге миграции отсутствуют.
    // Метод оставлен намеренно для будущих schema changes.
  }
}
