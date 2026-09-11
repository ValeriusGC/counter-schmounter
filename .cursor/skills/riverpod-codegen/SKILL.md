---
name: riverpod-codegen
description: >-
  Добавление @riverpod/@freezed: именование *.cg.dart, build_runner, riverpod_lint.
  Для нового провайдера, контроллера, freezed-модели.
paths: lib/**
---
# Riverpod & Codegen

**Дата создания:** 2026-09-08 15:08:08 +0300  
**Последнее обновление:** 2026-09-08 15:08:08 +0300  
**Версия:** 1

Rule: `.cursor/rules/dart-cg-file-naming.mdc`

## Именование

- **`.cg.dart`** — только `@riverpod` / `@freezed` + `part 'gen/...'`
- Ручные файлы — обычное имя: `user_type.dart`

## @riverpod

```dart
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'gen/example_ctrl.cg.g.dart';

@riverpod
class ExampleCtrl extends _$ExampleCtrl {
  @override
  ExampleState build() { ... }
}
```

Перед созданием — grep аналогов в `lib/` и реестр `docs/registries/providers_and_services.md`.

## @freezed

- Домен: `lib/domain/**/<name>.cg.dart`
- DTO: `lib/data/dto/**/<name>.cg.dart`

## Codegen

```bash
dart run build_runner build --delete-conflicting-outputs
```

Watch-режим: `dart run build_runner watch --delete-conflicting-outputs`

## После codegen

1. `flutter analyze` на затронутых файлах
2. `riverpod_lint` / `custom_lint` (если настроены)
3. Коммит вместе с `gen/*.g.dart` / `*.freezed.dart`

## Reactivity

- `ref.watch(provider.select(...))` в виджетах
- Параметры конструктора — только `Key`, `index`, layout-флаги
