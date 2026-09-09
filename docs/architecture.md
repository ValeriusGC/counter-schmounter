# Архитектура counter_schmounter

**Дата создания:** 2026-09-08 15:08:08 +0300  
**Последнее обновление:** 2026-09-09 11:45:00 +0300  
**Версия:** 2

Нормативные правила слоёв и зависимостей — в `.cursor/rules/architecture.mdc`. Этот документ — краткая карта репозитория.

## Структура

```
lib/
 └── src/
      ├── domain/           # Контракты, сущности, value objects (чистый Dart)
      ├── application/    # Use cases, оркестрация доменной логики
      ├── infrastructure/ # Репозитории, Supabase, SharedPreferences, sync, realtime
      ├── presentation/   # Экраны и viewmodels (Flutter + Riverpod)
      └── router.dart     # go_router
```

Monorepo **нет**: один Flutter-пакет `counter_schmounter`.

## Поток зависимостей

```
Presentation → Application → Domain ← Infrastructure
```

- ViewModels зависят **только** от use cases (application), не от репозиториев напрямую.
- Infrastructure реализует интерфейсы domain.
- Domain не импортирует Flutter, Riverpod, Supabase.

## Счётчик и синхронизация (текущее состояние)

- Значение на экране — агрегат **неизменяемых операций** в локальном журнале (`LocalOpLogRepository`, SharedPreferences).
- Синхронизация (до шага 15): pull/push журнала через Supabase PostgREST; маркеры в `SyncStateRepository`.
- Обмен через пакет `ulsync`: исходящие — `syncOnce` по требованию; входящие в переднем плане — живая лента `UlsyncClient.live()`.
- Supabase — только вход и сессия; Realtime Supabase удалён.

## Стек

| Область | Пакет |
|---------|--------|
| UI | Flutter, Material 3 |
| Состояние | `flutter_riverpod`, `riverpod_annotation`, codegen `*.g.dart` |
| Навигация | `go_router` |
| Auth | `supabase_flutter` |
| Локальный журнал | `shared_preferences` |
| Идентификаторы | `uuid` |
| Логи | `logging` |

Конфигурация запуска: `--dart-define=SU=...` и `--dart-define=SAK=...` для Supabase.

## Codegen

Провайдеры: `@riverpod` / `@Riverpod` в `*_provider.dart` и `*_controller.dart`, рядом `part '*.g.dart'`. Команда:

```bash
dart run build_runner build --delete-conflicting-outputs
```

Суффикс `.cg.dart` и каталог `gen/` в этом репозитории **не используются**.
