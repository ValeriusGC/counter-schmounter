# AGENTS.md — counter_schmounter

**Дата создания:** 2026-09-08 15:08:08 +0300  
**Последнее обновление:** 2026-09-08 15:08:08 +0300  
**Версия:** 1

Инструкции для AI-агентов в Cursor. Flutter/Dart-проект.

## Стек

- Flutter (Material 3)
- `supabase_flutter` — вход и сессия
- `flutter_riverpod` + `riverpod_annotation` / `riverpod_generator` — DI и реактивность
- `go_router` — навигация
- `shared_preferences` — локальный журнал операций счётчика
- `uuid` — идентификаторы операций
- `logging` — структурированные логи

## Архитектура

Стандарты команды: **планка качества** (`quality-bar`), **DDD**, **SOLID / YAGNI / KISS / DRY**.

| Документ | Назначение |
|---|---|
| `docs/architecture.md` | Обзор слоёв и потоков данных |
| `.cursor/rules/architecture.mdc` | Нормативные правила DDD этого репозитория |

При сложных задачах подключать архитектурную документацию через `@`.

## Реестры общих артефактов

Путь: `docs/registries/`

Перед новым shared-кодом — **обязательно** `/registry-before-create`.

| Реестр | Файл |
|--------|------|
| Виджеты | `docs/registries/widgets.md` |
| Диалоги / modals | `docs/registries/dialogs_and_modals.md` |
| Форматтеры | `docs/registries/formatters.md` |
| Extensions | `docs/registries/extensions.md` |
| Утилиты | `docs/registries/utilities.md` |
| Провайдеры | `docs/registries/providers_and_services.md` |

## Cursor Rules

**Always-on (5):** `quality-bar`, `team-principles`, `dry-and-registries`, `honesty-time-no-fabrication`, `git-sovereignty`

**По globs `**/*.dart` / `lib/**`:** `no-reinvent-wheel`, `dart-cg-file-naming`, `riverpod-first-reactivity`, `pre-delivery-analyzer-and-logs-check`, `dart-dartdoc-comments`

**По globs `**/*.md`:** `doc-header-metadata` — шапка **Дата создания / Последнее обновление / Версия**

**Правила приложения (сохранены):** `architecture`, `domain`, `application`, `flutter`, `ui`, `code_style`, `definition_of_done`, `riverpod_services`, `testing`, `time_rules`, `base`, `search_first`

## Git и Hooks

**Commit, push, PR — только пользователь**, если явно не попросил agent («Сделай коммит», «Сделай пуш»).

- Rule `git-sovereignty.mdc` — agent **не предлагает** commit/push; plan/todos не отменяют.
- Hook `.cursor/hooks/gate-git.sh` — `git commit`, `git push`, `gh pr create` → **Ask** в UI Cursor (`failClosed`).
- Read-only git (`status`, `diff`, `log`) — без ограничений.

После развёртывания: `chmod +x .cursor/hooks/gate-git.sh` → **Reload Window** → Settings → Hooks.

## MCP

Dart & Flutter MCP: `.cursor/mcp.json`

```json
{ "command": "dart", "args": ["mcp-server"] }
```

Требует Dart ≥ 3.9. Инструменты: analyze, pub.dev, runtime errors, widget tree, tests.

При сбоях roots: `"args": ["mcp-server", "--force-roots-fallback"]`

## Skills

### Проектные (`.cursor/skills/`)

| Skill | Вызов | Когда |
|---|---|---|
| `architecture-ui-workflow` | `/architecture-ui-workflow` | Новый экран/виджет |
| `riverpod-codegen` | `/riverpod-codegen` | @riverpod, build_runner |
| `registry-before-create` | `/registry-before-create` | Перед новым shared-кодом |
| `delivery-checklist` | `/delivery-checklist` | Перед сдачей / PR |

### Официальные (`.agents/skills/`)

Источник: [flutter/agent-plugins](https://github.com/flutter/agent-plugins).

Приоритетные:

- `dart-run-static-analysis`, `dart-fix-runtime-errors`, `dart-add-unit-test`, `dart-use-primary-constructors`
- `flutter-fix-layout-issues`, `flutter-setup-declarative-routing`, `flutter-add-widget-test`

**Осторожно:** `flutter-apply-architecture-best-practices` — сверять с DDD в `.cursor/rules/architecture.mdc`.

## Codegen

В этом репозитории провайдеры — `*_provider.dart` / `*_controller.dart` рядом с
`part '….g.dart'` (riverpod_generator). Суффикс `.cg.dart` и каталог `gen/`
**не вводить**. Существующие файлы не переименовывать.

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Pre-delivery

1. `flutter analyze` — без новых errors в затронутых файлах
2. `/delivery-checklist`
3. Реестры обновлены при новом shared-коде
4. Тесты при изменении логики: `flutter test <path>`

## Типовые промпты

- «Добавь use case по DDD, ViewModel только через application-слой»
- «Проверь static analysis, исправь замечания в затронутых файлах»
- «Перед созданием провайдера — проверь реестры»
- «Добавь @riverpod провайдер, запусти codegen»
