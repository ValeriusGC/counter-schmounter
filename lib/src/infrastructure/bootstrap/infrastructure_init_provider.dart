import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:counter_schmounter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/providers/client_identity_service_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/storage/storage_initializer.dart';

part 'infrastructure_init_provider.g.dart';

/// Глобальный старт-гейт инфраструктуры.
///
/// Гарантирует, что:
/// - storage schema и миграции применены
/// - все локальные хранилища инициализированы
/// ДО использования любых use cases (sync, realtime, mutations).
@riverpod
Future<void> infrastructureInit(Ref ref) async {
  final prefs = ref.watch(sharedPreferencesProvider);

  // 1. Инициализация storage (schema-version + migrations)
  final storageInitializer = StorageInitializer(prefs);
  await storageInitializer.initialize();

  // 2. Инициализация локальных репозиториев
  final localOpLogRepository = ref.watch(localOpLogRepositoryProvider);
  await localOpLogRepository.initialize();
}
