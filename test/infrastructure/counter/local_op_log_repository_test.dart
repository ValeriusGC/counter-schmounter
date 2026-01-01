import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:supa_counter/src/domain/counter/operations/increment_operation.dart';
import 'package:supa_counter/src/domain/counter/utils/counter_aggregator.dart';
import 'package:supa_counter/src/infrastructure/counter/repositories/local_op_log_repository_impl.dart';
import 'package:supa_counter/src/infrastructure/shared/storage/storage_schema_version.dart';

void main() {
  late SharedPreferences prefs;
  late LocalOpLogRepositoryImpl repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repository = LocalOpLogRepositoryImpl(prefs);
  });

  tearDown(() async {
    await prefs.clear();
  });

  group('LocalOpLogRepositoryImpl', () {
    group('initialize', () {
      test('initializes repository and sets schema version', () async {
        // Act
        await repository.initialize();

        // Assert
        final version = prefs.getInt('storage_schema_version');
        expect(version, StorageSchemaVersion.kCurrentStorageSchemaVersion);
      });

      test('can be called multiple times safely', () async {
        // Act
        await repository.initialize();
        await repository.initialize();
        await repository.initialize();

        // Assert - не должно быть ошибок
        expect(await repository.getAll(), isEmpty);
      });

      test('migrates from missing version (0) to V1', () async {
        // Arrange - SharedPreferences без версии (версия = null, что означает 0)
        SharedPreferences.setMockInitialValues({});
        final prefsWithoutVersion = await SharedPreferences.getInstance();
        final repoWithoutVersion = LocalOpLogRepositoryImpl(prefsWithoutVersion);

        // Act
        await repoWithoutVersion.initialize();

        // Assert
        final version = prefsWithoutVersion.getInt('storage_schema_version');
        expect(version, StorageSchemaVersion.kCurrentStorageSchemaVersion);
        expect(version, StorageSchemaVersion.kStorageSchemaVersionV1);
      });

      test('does not migrate when version is already current', () async {
        // Arrange - устанавливаем текущую версию вручную
        SharedPreferences.setMockInitialValues({
          'storage_schema_version': StorageSchemaVersion.kCurrentStorageSchemaVersion,
        });
        final prefsWithVersion = await SharedPreferences.getInstance();
        final repoWithVersion = LocalOpLogRepositoryImpl(prefsWithVersion);

        // Act
        await repoWithVersion.initialize();

        // Assert - версия не должна измениться
        final version = prefsWithVersion.getInt('storage_schema_version');
        expect(version, StorageSchemaVersion.kCurrentStorageSchemaVersion);
      });

      test('migrates from old version to current version', () async {
        // Arrange - устанавливаем старую версию (V1, но можно было бы и 0)
        SharedPreferences.setMockInitialValues({
          'storage_schema_version': StorageSchemaVersion.kStorageSchemaVersionV1 - 1, // 0 или меньше
        });
        final prefsWithOldVersion = await SharedPreferences.getInstance();
        final repoWithOldVersion = LocalOpLogRepositoryImpl(prefsWithOldVersion);

        // Act
        await repoWithOldVersion.initialize();

        // Assert - версия должна быть обновлена до текущей
        final version = prefsWithOldVersion.getInt('storage_schema_version');
        expect(version, StorageSchemaVersion.kCurrentStorageSchemaVersion);
      });
    });

    group('append', () {
      test('throws StateError if not initialized', () async {
        // Arrange
        final operation = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client',
          createdAt: DateTime.now(),
        );

        // Act & Assert
        expect(
          () => repository.append(operation),
          throwsA(isA<StateError>()),
        );
      });

      test('appends operation to repository', () async {
        // Arrange
        await repository.initialize();
        final operation = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client',
          createdAt: DateTime.now(),
        );

        // Act
        await repository.append(operation);

        // Assert
        final operations = await repository.getAll();
        expect(operations.length, 1);
        expect(operations.first, equals(operation));
      });

      test('deduplicates operations by op_id', () async {
        // Arrange
        await repository.initialize();
        final opId = const Uuid().v4();
        final operation1 = IncrementOperation(
          opId: opId,
          clientId: 'test-client',
          createdAt: DateTime.now(),
        );
        final operation2 = IncrementOperation(
          opId: opId, // Тот же op_id
          clientId: 'test-client',
          createdAt: DateTime.now().add(const Duration(seconds: 1)),
        );

        // Act
        await repository.append(operation1);
        await repository.append(operation2); // Дубликат

        // Assert
        final operations = await repository.getAll();
        expect(operations.length, 1);
        expect(operations.first.opId, opId);
      });

      test('appends multiple operations', () async {
        // Arrange
        await repository.initialize();
        final operations = List.generate(
          5,
          (index) => IncrementOperation(
            opId: const Uuid().v4(),
            clientId: 'test-client',
            createdAt: DateTime.now().add(Duration(seconds: index)),
          ),
        );

        // Act
        for (final op in operations) {
          await repository.append(op);
        }

        // Assert
        final loaded = await repository.getAll();
        expect(loaded.length, 5);
        expect(loaded, equals(operations));
      });
    });

    group('getAll', () {
      test('throws StateError if not initialized', () {
        // Act & Assert
        expect(
          () => repository.getAll(),
          throwsA(isA<StateError>()),
        );
      });

      test('returns empty list when no operations', () async {
        // Arrange
        await repository.initialize();

        // Act
        final operations = await repository.getAll();

        // Assert
        expect(operations, isEmpty);
      });

      test('returns all operations in order', () async {
        // Arrange
        await repository.initialize();
        final operations = List.generate(
          3,
          (index) => IncrementOperation(
            opId: const Uuid().v4(),
            clientId: 'test-client',
            createdAt: DateTime.now().add(Duration(seconds: index)),
          ),
        );

        for (final op in operations) {
          await repository.append(op);
        }

        // Act
        final loaded = await repository.getAll();

        // Assert
        expect(loaded.length, 3);
        expect(loaded, equals(operations));
      });

      test('persists operations between repository instances', () async {
        // Arrange
        await repository.initialize();
        final operation = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client',
          createdAt: DateTime.now(),
        );
        await repository.append(operation);

        // Act - создаем новый экземпляр
        final newRepository = LocalOpLogRepositoryImpl(prefs);
        await newRepository.initialize();
        final loaded = await newRepository.getAll();

        // Assert
        expect(loaded.length, 1);
        expect(loaded.first, equals(operation));
      });

      test('replay operations from repository gives same result', () async {
        // Arrange - сохраняем несколько операций
        await repository.initialize();
        final operations = List.generate(
          5,
          (index) => IncrementOperation(
            opId: const Uuid().v4(),
            clientId: 'test-client',
            createdAt: DateTime.now().add(Duration(seconds: index)),
          ),
        );

        for (final op in operations) {
          await repository.append(op);
        }

        // Act - загружаем операции и применяем несколько раз
        final loaded1 = await repository.getAll();
        final result1 = CounterAggregator.compute(loaded1);

        final loaded2 = await repository.getAll();
        final result2 = CounterAggregator.compute(loaded2);

        final loaded3 = await repository.getAll();
        final result3 = CounterAggregator.compute(loaded3);

        // Assert - повторные вычисления дают одинаковый результат
        expect(result1, 5);
        expect(result2, 5);
        expect(result3, 5);
        expect(result1, equals(result2));
        expect(result2, equals(result3));
        expect(loaded1.length, 5);
        expect(loaded2.length, 5);
        expect(loaded3.length, 5);
      });

      test('replay operations after repository restart gives same result', () async {
        // Arrange - сохраняем операции в первом экземпляре
        await repository.initialize();
        final operations = List.generate(
          3,
          (index) => IncrementOperation(
            opId: const Uuid().v4(),
            clientId: 'test-client',
            createdAt: DateTime.now().add(Duration(seconds: index)),
          ),
        );

        for (final op in operations) {
          await repository.append(op);
        }

        // Вычисляем состояние до "перезапуска"
        final operationsBefore = await repository.getAll();
        final counterBefore = CounterAggregator.compute(operationsBefore);

        // Act - создаем новый экземпляр (симулируем перезапуск)
        final newRepository = LocalOpLogRepositoryImpl(prefs);
        await newRepository.initialize();
        final operationsAfter = await newRepository.getAll();
        final counterAfter = CounterAggregator.compute(operationsAfter);

        // Применяем повторно
        final counterAfter2 = CounterAggregator.compute(operationsAfter);
        final counterAfter3 = CounterAggregator.compute(operationsAfter);

        // Assert - состояние восстанавливается корректно и повторные применения дают тот же результат
        expect(counterBefore, 3);
        expect(counterAfter, 3);
        expect(counterAfter2, 3);
        expect(counterAfter3, 3);
        expect(counterBefore, equals(counterAfter));
        expect(counterAfter, equals(counterAfter2));
        expect(counterAfter2, equals(counterAfter3));
        expect(operationsBefore.length, 3);
        expect(operationsAfter.length, 3);
      });
    });

    group('clear', () {
      test('clears all operations', () async {
        // Arrange
        await repository.initialize();
        final operation = IncrementOperation(
          opId: const Uuid().v4(),
          clientId: 'test-client',
          createdAt: DateTime.now(),
        );
        await repository.append(operation);

        // Act
        await repository.clear();

        // Assert
        final operations = await repository.getAll();
        expect(operations, isEmpty);
      });
    });

    group('compaction', () {
      test('removes oldest operations when limit exceeded', () async {
        // Arrange
        await repository.initialize();
        const maxOps = 1000;
        final operations = List.generate(
          maxOps + 100, // Превышаем лимит на 100
          (index) => IncrementOperation(
            opId: const Uuid().v4(),
            clientId: 'test-client',
            createdAt: DateTime.now().add(Duration(seconds: index)),
          ),
        );

        // Act
        for (final op in operations) {
          await repository.append(op);
        }

        // Assert
        final loaded = await repository.getAll();
        expect(loaded.length, maxOps);
        // Должны остаться последние maxOps операций
        expect(loaded.first.opId, operations[100].opId);
        expect(loaded.last.opId, operations.last.opId);
      });
    });
  });
}

