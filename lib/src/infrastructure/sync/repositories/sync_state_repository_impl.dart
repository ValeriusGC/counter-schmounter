import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_schmounter/src/domain/sync/repositories/sync_state_repository.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

/// Реализация [SyncStateRepository] на SharedPreferences.
///
/// Схема хранения (account-scope):
/// - ключи формируются как `<base>::<scope>`
///
/// Где scope:
/// - `user:<user_id>` для авторизованного пользователя
/// - `anonymous` для неавторизованного режима
///
/// ВАЖНО (B1 idempotency):
/// - `last_exported_at` хранится с точностью до МИКРОСЕКУНД (`microsecondsSinceEpoch`)
///   чтобы курсор не "обрезал" дробную часть `createdAt` операций.
/// - Для обратной совместимости:
///   - если в storage лежит старое значение в миллисекундах,
///     оно будет корректно прочитано и интерпретировано как millis.
final class SyncStateRepositoryImpl implements SyncStateRepository {
  /// Создаёт репозиторий.
  SyncStateRepositoryImpl({
    required SharedPreferences sharedPreferences,
    required String scope,
  }) : _sharedPreferences = sharedPreferences,
       _scope = scope {
    AppLogger.info(
      component: AppLogComponent.state,
      message: 'SyncStateRepositoryImpl created.',
      context: <String, Object?>{'scope': _scope},
    );
  }

  final SharedPreferences _sharedPreferences;
  final String _scope;

  static const String _lastSyncedAtKeyBase = 'sync.last_synced_at';

  /// Storage key for the last successful export timestamp.
  static const String _lastExportedAtKeyBase = 'sync.last_exported_at';

  String _scopedKey(String base) => '$base::$_scope';

  @override
  Future<DateTime?> getLastSyncedAt() async {
    final raw = _sharedPreferences.getString(_scopedKey(_lastSyncedAtKeyBase));
    if (raw == null || raw.isEmpty) {
      return null;
    }

    return DateTime.tryParse(raw);
  }

  @override
  Future<void> setLastSyncedAt(DateTime value) async {
    await _sharedPreferences.setString(
      _scopedKey(_lastSyncedAtKeyBase),
      value.toIso8601String(),
    );
  }

  @override
  DateTime? getLastExportedAt() {
    final raw = _sharedPreferences.getInt(_scopedKey(_lastExportedAtKeyBase));
    if (raw == null) {
      return null;
    }

    // Backward compatibility:
    // - Old format stored millisecondsSinceEpoch (≈ 1e12..1e13).
    // - New format stores microsecondsSinceEpoch (≈ 1e15).
    //
    // Threshold: any realistic epoch micros in 2025+ is > 10^14.
    const int microsThreshold = 100000000000000;

    if (raw < microsThreshold) {
      // Old millis-based value (precision lost).
      // Advance cursor by +1 microsecond to make it exclusive.
      return DateTime.fromMillisecondsSinceEpoch(
        raw,
        isUtc: true,
      ).add(const Duration(microseconds: 1));
    }

    // New micros-based value.
    return DateTime.fromMicrosecondsSinceEpoch(raw, isUtc: true);
  }

  @override
  Future<void> setLastExportedAt(DateTime value) async {
    // Persist in UTC with microsecond precision.
    await _sharedPreferences.setInt(
      _scopedKey(_lastExportedAtKeyBase),
      value.toUtc().microsecondsSinceEpoch,
    );
  }
}
