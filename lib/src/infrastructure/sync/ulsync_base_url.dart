/// Единственное место в `lib/`, где задаётся адрес HTTP-сервера синхронизации.
library;

/// Адрес HTTP-сервера синхронизации.
///
/// Единственное место в `lib/`, где фигурируют `ULSYNC_BASE_URL` и `10.0.2.2`.
/// Значение по умолчанию — loopback машины-хозяина **для Android-эмулятора**.
/// iOS-симулятор, macOS и физическое устройство этот default не достают:
/// запускать с `--dart-define=ULSYNC_BASE_URL=http://127.0.0.1:8080`
/// или с LAN-адресом машины.
const String kUlsyncBaseUrl = String.fromEnvironment(
  'ULSYNC_BASE_URL',
  defaultValue: 'http://10.0.2.2:8080',
);
