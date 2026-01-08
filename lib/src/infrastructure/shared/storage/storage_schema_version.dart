/// Константы версий схемы хранилища.
///
/// Используются для управления миграциями данных в SharedPreferences.
/// При изменении структуры данных необходимо:
/// 1. Добавить новую константу версии (например, `kStorageSchemaVersionV2 = 2`)
/// 2. Обновить `kCurrentStorageSchemaVersion`
/// 3. Добавить логику миграции в `StorageMigration.migrate()`
class StorageSchemaVersion {
  StorageSchemaVersion._();

  /// Версия схемы 1 (базовая версия).
  ///
  /// Используется для хранения операций счетчика в JSON формате.
  static const int kStorageSchemaVersionV1 = 1;

  /// Текущая версия схемы хранилища.
  ///
  /// Должна быть равна последней версии схемы.
  /// При добавлении новой версии обновить эту константу.
  static const int kCurrentStorageSchemaVersion = kStorageSchemaVersionV1;
}
