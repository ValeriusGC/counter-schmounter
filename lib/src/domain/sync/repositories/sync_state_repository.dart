/// Репозиторий состояния синхронизации.
///
/// Назначение: хранить маркеры "докуда мы синхронизировались".
/// На шаге 9 используем только `lastSyncedAt`.
///
/// Важно:
/// - Репозиторий не зависит от auth.
/// - Репозиторий не чистится при logout.
/// - Маркер — это server-time (created_at) последней применённой операции.
abstract class SyncStateRepository {
  /// Возвращает момент времени (server-time), после которого нужно делать pull.
  ///
  /// `null` означает "никогда не синхронизировались" → тянуть всё.
  Future<DateTime?> getLastSyncedAt();

  /// Сохраняет момент времени (server-time) последней успешно применённой операции.
  Future<void> setLastSyncedAt(DateTime value);

  /// Returns the timestamp of the last successful export (push).
  ///
  /// Returns null if no export has ever been performed.
  DateTime? getLastExportedAt();

  /// Persists the timestamp of the last successful export (push).
  Future<void> setLastExportedAt(DateTime value);
}
