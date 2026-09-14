import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/infrastructure/sync/controllers/ulsync_catch_up.dart';

part 'counter_sync_coordinator.g.dart';

/// Один обмен за раз, до тишины.
///
/// Живая лента, стартовый пайплайн и локальный плюс зовут [runOnce].
/// Пока обмен идёт, новые вызовы ждут и после него получают свой круг.
/// Чужой проход не считается за наш — иначе хвост очереди теряется.
@Riverpod(keepAlive: true)
class CounterSyncCoordinator extends _$CounterSyncCoordinator {
  final UlsyncCatchUp _catchUp = UlsyncCatchUp();

  @override
  void build() {}

  /// Ставит обмен в очередь и ждёт тишины.
  ///
  /// Ошибку обрабатывает ведущий круг. Ожидающие чужой сбой не пробрасывают —
  /// иначе живая лента падает вместе со стартовым пайплайном.
  Future<void> runOnce(Future<void> Function() action) {
    return _catchUp.run(action);
  }
}
