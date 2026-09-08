---
name: delivery-checklist
description: >-
  Финальная проверка перед сдачей задачи/PR: analyze, реестры, UI Projection,
  локализация, тесты. Вызов: /delivery-checklist
paths: lib/**
disable-model-invocation: true
---
# Delivery Checklist

**Дата создания:** 2026-07-25 17:13:00 +0500  
**Последнее обновление:** 2026-07-29 09:30 +0500  
**Версия:** 2

## 1. Статический анализ

Monorepo **нет** — анализ только корневого приложения:

```bash
flutter analyze --fatal-warnings lib
```

- Исправить **error** и новые **warning** в затронутых файлах
- Skill `dart-run-static-analysis` или MCP `analyze_files` / shell `dart analyze`
- `dart fix --apply` при механических фиксах
- Логи: нет `error`, `exception`, `failed`, stack trace

## 2. Codegen (если @riverpod/@freezed)

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze --fatal-warnings lib
```

## 3. DartDoc (публичный API)

- [ ] Новые/изменённые публичные символы с `///` **на русском** (rule `dart-dartdoc-comments`)
- [ ] Параметры и нетривиальное поведение описаны; при наличии модуля — `docs/.../README.md` обновлён

## 4. UI Projection

- [ ] Виджеты dumb: нет бизнес-логики, форматирования, навигации
- [ ] Нет prop drilling — `ref.watch` + `.select()`
- [ ] Локализация: нет hardcoded user-facing strings

## 5. DRY и реестры

- [ ] Новые shared-артефакты добавлены в `docs/registries/`
- [ ] Нет дублирования существующих виджетов/утилит/расширений

## 6. Не сломать работающее

- Минимальный diff
- Изменение поведения — явно в ответе
- Тесты при изменении логики

## 7. Тесты

```bash
flutter test <path>
```

Skills: `dart-add-unit-test`, `flutter-add-widget-test`

## 8. Runtime (только UI PR + запущенное app)

- MCP: `get_runtime_errors`, widget inspector; skill `flutter-fix-layout-issues`
- Core-only PR без UI — этот пункт **пропустить**

## Итог

В ответе: analyzer (результат), codegen, DartDoc, UI Projection, реестры, тесты.
