import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:counter_schmounter/src/domain/shared/services/client_identity_service.dart';
import 'package:counter_schmounter/src/infrastructure/shared/logging/app_logger.dart';

/// Реализация [ClientIdentityService] с использованием SharedPreferences.
///
/// Генерирует UUID при первом запуске и сохраняет его локально.
/// UUID остается неизменным между перезапусками приложения.
class ClientIdentityServiceImpl implements ClientIdentityService {
  /// Создает экземпляр [ClientIdentityServiceImpl].
  ClientIdentityServiceImpl(this._prefs);

  final SharedPreferences _prefs;
  static const String _key = 'client_id';
  String? _cachedClientId;

  @override
  Future<void> init() async {
    // Пытаемся прочитать сохраненный client_id
    _cachedClientId = _prefs.getString(_key);

    // Если client_id не найден, генерируем новый
    if (_cachedClientId == null || _cachedClientId!.isEmpty) {
      _cachedClientId = const Uuid().v4();
      await _prefs.setString(_key, _cachedClientId!);
      AppLogger.info(
        component: AppLogComponent.state,
        message: 'Client Identity created',
        context: <String, Object?>{'client_id': _cachedClientId},
      );
    } else {
      AppLogger.info(
        component: AppLogComponent.state,
        message: 'Client Identity restored',
        context: <String, Object?>{'client_id': _cachedClientId},
      );
    }
  }

  @override
  String get clientId {
    if (_cachedClientId == null) {
      throw StateError(
        'ClientIdentityService not initialized. Call init() first.',
      );
    }
    return _cachedClientId!;
  }
}
