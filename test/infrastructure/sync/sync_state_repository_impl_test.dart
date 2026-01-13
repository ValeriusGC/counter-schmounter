import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:counter_schmounter/src/infrastructure/sync/repositories/sync_state_repository_impl.dart';

void main() {
  late SharedPreferences prefs;
  late SyncStateRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = SyncStateRepositoryImpl(sharedPreferences: prefs, scope: 'A');
  });

  tearDown(() async {
    await prefs.clear();
  });

  group('SyncStateRepositoryImpl', () {
    group('last_synced_at', () {
      test('getLastSyncedAt returns null when no value is stored', () async {
        final result = await repository.getLastSyncedAt();
        expect(result, isNull);
      });

      test('setLastSyncedAt stores value and getLastSyncedAt returns it', () async {
        // Arrange — нормализуем ДО записи
        final now = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
        );

        // Act
        await repository.setLastSyncedAt(now);
        final result = await repository.getLastSyncedAt();

        // Assert
        expect(result, equals(now));
      });
    });

    group('last_exported_at', () {
      test('getLastExportedAt returns null when no value is stored', () {
        final result = repository.getLastExportedAt();
        expect(result, isNull);
      });

      test('setLastExportedAt stores value and getLastExportedAt returns it', () async {
        // Arrange — нормализуем ДО записи
        final now = DateTime.fromMillisecondsSinceEpoch(
          DateTime.now().millisecondsSinceEpoch,
        ).toUtc();

        // Act
        await repository.setLastExportedAt(now);
        final result = repository.getLastExportedAt();

        // Assert
        expect(result, equals(now));
      });
    });
  });
}
