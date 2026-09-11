import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'counter_sync_coordinator.g.dart';

/// Координатор единственного [UlsyncClient.syncOnce] для счётчика.
///
/// ulsync сериализует вызовы внутри клиента, но без координатора
/// [CounterInitialSyncController] и [NeedSyncController] запускают
/// конкурирующие пайплайны с дублирующими retry и шумом в логах.
@Riverpod(keepAlive: true)
class CounterSyncCoordinator extends _$CounterSyncCoordinator {
  Future<void>? _inFlight;

  @override
  void build() {}

  /// Выполняет [action] не чаще одного раза одновременно.
  ///
  /// Параллельные вызовы ждут текущий обмен и не дублируют его.
  /// Ошибку обрабатывает только инициатор; ожидающие вызовы не пробрасывают
  /// чужой сбой — иначе [UlsyncLiveController] падает вместе с initial sync.
  Future<void> runOnce(Future<void> Function() action) async {
    if (_inFlight != null) {
      try {
        await _inFlight!;
      } on Object {
        // Инициатор уже залогировал или залогирует сбой.
      }
      return;
    }

    _inFlight = action();
    try {
      await _inFlight!;
    } finally {
      _inFlight = null;
    }
  }
}
