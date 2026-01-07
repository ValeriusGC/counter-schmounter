import 'package:counter_schmounter/src/infrastructure/shared/services/client_identity_service_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mock для SharedPreferences
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late SharedPreferences prefs;
  late ClientIdentityServiceImpl service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    service = ClientIdentityServiceImpl(prefs);
  });

  tearDown(() async {
    await prefs.clear();
  });

  group('ClientIdentityServiceImpl', () {
    group('init', () {
      test('generates new UUID when client_id is not found', () async {
        // Arrange - ensure no client_id exists
        await prefs.remove('client_id');

        // Act
        await service.init();

        // Assert
        expect(service.clientId, isNotEmpty);
        expect(prefs.getString('client_id'), isNotNull);
        expect(prefs.getString('client_id'), equals(service.clientId));
      });

      test('generates new UUID when client_id is empty string', () async {
        // Arrange
        await prefs.setString('client_id', '');

        // Act
        await service.init();

        // Assert
        expect(service.clientId, isNotEmpty);
        expect(prefs.getString('client_id'), isNotEmpty);
      });

      test('uses existing UUID when client_id is found', () async {
        // Arrange
        const existingId = 'existing-uuid-12345';
        await prefs.setString('client_id', existingId);

        // Act
        await service.init();

        // Assert
        expect(service.clientId, equals(existingId));
        expect(prefs.getString('client_id'), equals(existingId));
      });

      test('saves generated UUID to SharedPreferences', () async {
        // Arrange - ensure no client_id exists
        await prefs.remove('client_id');

        // Act
        await service.init();
        final clientId = service.clientId;

        // Assert
        expect(clientId, isNotEmpty);
        expect(prefs.getString('client_id'), equals(clientId));
      });
    });

    group('clientId getter', () {
      test('returns same UUID after init', () async {
        // Arrange
        await prefs.remove('client_id');
        await service.init();
        final firstId = service.clientId;

        // Act
        final secondId = service.clientId;

        // Assert
        expect(firstId, equals(secondId));
      });

      test('throws StateError when accessed before init', () {
        // Arrange - create new service without init
        final newService = ClientIdentityServiceImpl(prefs);

        // Act & Assert
        expect(
          () => newService.clientId,
          throwsA(isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('not initialized'),
          )),
        );
      });

      test('returns UUID in correct format', () async {
        // Arrange
        await prefs.remove('client_id');
        await service.init();

        // Act
        final clientId = service.clientId;

        // Assert
        // UUID v4 format: 8-4-4-4-12 hex digits
        expect(clientId, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')));
      });
    });

    group('persistence', () {
      test('persists UUID between service instances', () async {
        // Arrange
        const savedId = 'persisted-uuid-67890';
        await prefs.setString('client_id', savedId);

        // Act - create new instance and init
        final newService = ClientIdentityServiceImpl(prefs);
        await newService.init();

        // Assert
        expect(newService.clientId, equals(savedId));
      });

      test('generates UUID when not persisted', () async {
        // Arrange
        await prefs.remove('client_id');

        // Act
        final service1 = ClientIdentityServiceImpl(prefs);
        await service1.init();
        final id1 = service1.clientId;

        // Assert - should be valid UUID
        expect(id1, isNotEmpty);
        expect(id1, matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')));
      });
    });
  });
}

