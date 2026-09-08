---
name: architecture-ui-workflow
description: >-
  Проектировать и рефакторить UI по UI Projection: DDD-слои, dumb widgets,
  Factory/Builder, Controller handlers. Для нового экрана, виджета, рефакторинга UI.
paths: lib/**
---
# UI Projection Workflow

**Дата создания:** 2026-09-08 15:08:08 +0300  
**Последнее обновление:** 2026-09-08 15:08:08 +0300  
**Версия:** 1

Архитектурная документация проекта: см. `AGENTS.md` → раздел «Архитектура».

## Когда применять

- Новый экран, секция, сложный виджет (кнопка, карточка, тайл)
- Рефакторинг UI с логикой в виджетах
- Кастомизация под вариант продукта (Strategy в Factory/Builder)

## Когда НЕ применять

- Статический виджет без ветвлений и derived-данных
- Тривиальный экран: один provider → один виджет

## Каноническая цепочка

```
Domain Data → Controller → ProjectionFactory → Projection → UiModelBuilder → UiModel → Dumb Widget
```

Точки кастомизации: **Factory** и **Builder** (Strategy).

## Куда класть логику

| Тип задачи | Слой |
|---|---|
| Видимость блоков, порядок, intent элемента | **Factory** |
| Локализация, форматирование, привязка onTap к intent | **Builder** |
| Навигация, метрика, бизнес-реакция на tap | **Controller handler** |
| Рендер готовых данных, прокидывание onTap | **Widget** |
| `if/switch` по бизнес-данным | **НЕ Widget** → Factory |

## Intent vs Callback

- **Intent** (sealed class): один tap = разные сценарии
- **Callback(ItemProjection)**: один тип tap, действие зависит от item
- **VoidCallback**: действие известно при сборке UI

## Workflow для нового экрана

1. Найти аналогичный экран в `lib/ui/screens/`
2. **Controller**: состояние, side effects, handlers
3. **Factory**: решения «что показать»
4. **Builder**: Projection → UiModel
5. **Dumb Widget**: `ref.watch(screenCtrlProvider.select(...))`
6. Проверить rule `riverpod-first-reactivity`
7. Локализация — через принятый в проекте механизм (см. `AGENTS.md`), без hardcoded строк

## Ревью-чеклист виджета

- [ ] Нет `if/switch` по бизнес-данным
- [ ] Нет форматирования и локализации (это Builder)
- [ ] Нет навигации и вызовов сервисов (это Controller)
- [ ] Нет «умных» методов на уровне виджета
- [ ] Перед новым shared-виджетом — `/registry-before-create`

## Конфликт с официальными skills

`flutter-apply-architecture-best-practices` — generic layered arch. **Приоритет у UI Projection** проекта.
