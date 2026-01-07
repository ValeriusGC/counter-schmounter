import 'dart:developer' as developer;

import 'package:counter_schmounter/src/domain/shared/services/client_identity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

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
      developer.log(
        '🆔 Client Identity created',
        name: 'ClientIdentityService',
        error: null,
        stackTrace: null,
        level: 800, // INFO level
      );
      developer.log(
        '   Client ID: $_cachedClientId',
        name: 'ClientIdentityService',
        error: null,
        stackTrace: null,
        level: 700, // FINE level
      );
    } else {
      developer.log(
        '🆔 Client Identity restored',
        name: 'ClientIdentityService',
        error: null,
        stackTrace: null,
        level: 800, // INFO level
      );
      developer.log(
        '   Client ID: $_cachedClientId',
        name: 'ClientIdentityService',
        error: null,
        stackTrace: null,
        level: 700, // FINE level
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
