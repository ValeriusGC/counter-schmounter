---
name: registry-before-create
description: >-
  Перед созданием виджета, диалога, форматтера, утилиты, расширения или провайдера —
  проверить docs/registries/ и codebase. Обязательный DRY-workflow.
paths: lib/**
---
# Registry Before Create

**Дата создания:** 2026-09-08 15:08:08 +0300  
**Последнее обновление:** 2026-09-08 15:08:08 +0300  
**Версия:** 1

Rule: `.cursor/rules/dry-and-registries.mdc`

## Алгоритм

1. **Определи тип** артефакта → открой реестр:

| Создаёшь | Реестр |
|----------|--------|
| Shared-виджет | `docs/registries/widgets.md` |
| Диалог / bottom sheet / alert | `docs/registries/dialogs_and_modals.md` |
| Форматтер | `docs/registries/formatters.md` |
| Extension | `docs/registries/extensions.md` |
| Утилита / helper | `docs/registries/utilities.md` |
| Провайдер / сервис | `docs/registries/providers_and_services.md` |

2. **Прочитай** таблицу реестра — есть ли подходящая запись?

3. **Grep** по `lib/` по ключевым словам (имя, назначение)

4. **Решение:**
   - **Reuse** — использовать существующее
   - **Extend** — расширить существующее (предпочтительно)
   - **Create** — только если нет аналога

5. **При Create** — добавить строку в реестр (формат в `docs/registries/README.md`)

6. **Pub.dev** — если нужен внешний пакет: MCP `pub_dev_search`, не самопис без причины

## Запрещено

- Создавать второй диалог/кнопку/форматтер «потому что не нашёл за 10 секунд»
- Пропускать обновление реестра после создания shared-кода

## Сканирование при setup

При первичной настройке проекта — заполнить реестры из `lib/ui/shared/`, `lib/core/`, `**/ext*.dart`.
