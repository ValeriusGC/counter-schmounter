import 'package:flutter_test/flutter_test.dart';

import 'package:counter_schmounter/src/infrastructure/sync/ulsync_base_url.dart';

/// Класс символов SPEC §1.5 — дублируем в тесте, не «просто not empty».
final RegExp _specOriginPattern = RegExp(r'^[A-Za-z0-9._/-]+$');

void main() {
  group('kUlsyncOrigin', () {
    test('непустая и проходит класс символов SPEC §1.5', () {
      expect(kUlsyncOrigin, isNotEmpty);
      expect(kUlsyncOrigin.length, lessThanOrEqualTo(256));
      expect(_specOriginPattern.hasMatch(kUlsyncOrigin), isTrue);
    });

    test('литерал по умолчанию фиксирован для контура counter_schmounter', () {
      expect(
        kUlsyncOrigin,
        'com.gdetotuta.vfx.counter_schmounter/'
        '7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f',
      );
    });
  });
}
