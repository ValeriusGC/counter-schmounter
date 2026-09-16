/// Единственное место в `lib/`, где задаются адрес HTTP-сервера и происхождение склада.
library;

import 'package:flutter/foundation.dart';

const _envUrlOverride = String.fromEnvironment('ULSYNC_BASE_URL');

/// Происхождение склада (SPEC §1.5): reverse-DNS приложения и UUID проекта.
///
/// Одно значение на все установки этого контура. Не путать с `client_id`
/// установки: тот идентифицирует устройство и участвует в правиле конфликта
/// `source_id` (SPEC §1.4). Это имя стопки данных на сервере.
///
/// Строка живёт в исходнике, а не на устройстве: UUID при первом запуске
/// превратил бы второй телефон в чужака навсегда. Рядом с [kUlsyncBaseUrl],
/// чтобы флейвор подставлял другое имя **вместе** с другим URL.
///
/// При `OriginMismatchException` приложение не сообщает об успехе обмена:
/// отказ пишется в лог уровнем error (`logSyncFailure`). Склад и константу
/// меняют вместе в конфигурации сборки, не в настройках на телефоне.
const String kUlsyncOrigin = String.fromEnvironment(
  'ULSYNC_ORIGIN',
  defaultValue:
      'com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f',
);

/// Адрес HTTP API ulsync (`push` / `pull`), порт **8080**.
///
/// Не путать с админкой `http://127.0.0.1:8081/admin` — это отдельный bind
/// только на loopback хоста для проверки JWT в браузере.
///
/// Приоритет:
/// 1. `--dart-define=ULSYNC_BASE_URL=...` (физическое устройство в LAN и т.п.)
/// 2. Android-эмулятор → `http://10.0.2.2:8080` (loopback машины-хозяина)
/// 3. iOS-симулятор, macOS, desktop → `http://127.0.0.1:8080`
String get kUlsyncBaseUrl {
  if (_envUrlOverride.isNotEmpty) {
    return _envUrlOverride;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'http://10.0.2.2:8080',
    _ => 'http://127.0.0.1:8080',
  };
}
