import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:counter_schmounter/src/domain/counter/operations/counter_operation.dart';
import 'package:counter_schmounter/src/domain/counter/repositories/local_op_log_repository.dart';
import 'package:counter_schmounter/src/infrastructure/bootstrap/infrastructure_init_provider.dart';
import 'package:counter_schmounter/src/infrastructure/counter/providers/local_op_log_repository_provider.dart';
import 'package:counter_schmounter/src/infrastructure/shared/providers/client_identity_service_provider.dart';

/// Fake-реализация LocalOpLogRepository для bootstrap-тестов.
///
/// Используется ТОЛЬКО для проверки:
/// - что initialize вызывается;
/// - что ошибка пробрасывается наружу.
final class _FakeLocalOpLogRepository implements LocalOpLogRepository {
  _FakeLocalOpLogRepository({this.initializeError});

  final Object? initializeError;

  int initializeCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls += 1;
    if (initializeError != null) {
      throw initializeError!;
    }
  }

  @override
  Future<void> append(CounterOperation operation) async {}

  @override
  Future<List<CounterOperation>> getAll() async => <CounterOperation>[];

  @override
  Future<void> clear() async {}
}

void main() {
  group('infrastructureInitProvider', () {
    test('initializes LocalOpLogRepository on startup', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final fakeRepo = _FakeLocalOpLogRepository();

      final container = ProviderContainer(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
          localOpLogRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Act
      await expectLater(
        container.read(infrastructureInitProvider.future),
        completes,
      );

      // Assert
      expect(fakeRepo.initializeCalls, 1);
    });

    test('fails when LocalOpLogRepository.initialize throws', () async {
      // Arrange
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final fakeRepo = _FakeLocalOpLogRepository(
        initializeError: StateError('init failed'),
      );

      final container = ProviderContainer(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(prefs),
          localOpLogRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Act & Assert
      await expectLater(
        container.read(infrastructureInitProvider.future),
        throwsA(anything),
      );

      expect(fakeRepo.initializeCalls, 1);
    });
  });
}
