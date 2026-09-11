/// Единственное место в `lib/`, где задаётся адрес HTTP-сервера синхронизации.
library;

import 'package:flutter/foundation.dart';

const _envOverride = String.fromEnvironment('ULSYNC_BASE_URL');

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
  if (_envOverride.isNotEmpty) {
    return _envOverride;
  }

  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'http://10.0.2.2:8080',
    _ => 'http://127.0.0.1:8080',
  };
}
