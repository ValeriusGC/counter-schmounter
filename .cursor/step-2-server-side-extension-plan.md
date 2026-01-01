# Server-side Extension (Realtime + Sync) поверх baseline — План с чеклистами

> Контекст: baseline local-first (optional auth + client_id + local op-log + aggregated state) уже реализован.
>
> Цель следующего этапа: добавить **Server-side слой** так, чтобы:
>
> * local-only режим продолжал работать без auth;
> * auth включал server capabilities прогрессивно;
> * **Sync — источник истины**, Realtime — ускоритель UX;
> * всё воспроизводимо и дебажится по логам.

---

## Инварианты (не нарушать)

* [ ] **Local-first не ломаем**: UI → UseCase → LocalOpLog → Aggregated State → UI остаётся рабочим без auth.
* [ ] **Auth — capability, не gate**: приложение работает без логина.
* [ ] **Realtime не источник истины**: события могут теряться; корректность обеспечивает Sync.
* [ ] **Идемпотентность операций**: повторное применение/доставка не меняют результат сверх ожидаемого.
* [ ] **Наблюдаемость обязательна**: логи содержат `client_id`, `op_id`, `entity_id`, `user_id?`.

---

## Термины (фиксация)

* **Replica** — экземпляр приложения (устройство/вкладка).
* **client_id** — стабильный UUID реплики.
* **user_id** — появляется только при auth.
* **Operation (op)** — минимальная единица изменений (для стенда: increment).
* **Sync** — pull/apply (в перспективе push/pull).
* **Realtime** — сигнал “произошло” (ускоряет), но не гарантирует доставку.

---

## Порядок внедрения (строго)

1. **Шаг 8 — Server Op-Log (read-only)**
2. **Шаг 9 — Initial Sync при login**
3. **Шаг 10 — Realtime как ускоритель (signal → needSync)**
4. **Шаг 11 — Export локальных операций (push)**

> Принцип: **сначала pull**, потом realtime, потом push.

---

# Шаг 8 — Server Op-Log (read-only сначала)

## Цель

Подключить сервер как **источник операций** (чтение), не меняя local-first data-flow.

## Чеклист: Supabase (DDL + RLS)

### Таблица

* [ ] Создать таблицу `counter_operations`.
* [ ] Поля:

    * [ ] `op_id uuid primary key`
    * [ ] `user_id uuid not null` (владельцем может быть только авторизованный пользователь)
    * [ ] `entity_id text not null` (для стенда константа, напр. `default_counter`)
    * [ ] `type text not null` (для стенда: `increment`)
    * [ ] `client_id text not null`
    * [ ] `created_at timestamptz not null default now()`
* [ ] Индексы:

    * [ ] `(user_id, created_at)`
    * [ ] `(user_id, entity_id, created_at)` (если будем фильтровать по entity)

### RLS (Row Level Security)

* [ ] Включить RLS на таблице.
* [ ] Политика SELECT:

    * [ ] `auth.uid() = user_id`
* [ ] Политика INSERT (понадобится в Шаге 11, но можно подготовить заранее):

    * [ ] `auth.uid() = user_id`
* [ ] Запретить UPDATE/DELETE (на этом этапе):

    * [ ] Убедиться, что нет разрешающих политик.

### Проверка

* [ ] Через Supabase SQL Editor вставить тестовую строку (временно) и убедиться, что SELECT под пользователем возвращает только свои строки.

## Чеклист: Flutter (read-only репозиторий)

### Domain

* [ ] Добавить интерфейс `RemoteOpLogRepository` (только чтение).
* [ ] Убедиться, что domain не импортирует supabase/flutter.

### Infrastructure

* [ ] Реализация `RemoteOpLogRepositoryImpl` через `SupabaseClient`.
* [ ] Запрос: `select` по `user_id`, `order created_at asc`.
* [ ] Фильтрация "после" по маркеру (на первом этапе можно по `created_at > since`).
* [ ] Десериализация в доменные операции.

### Providers

* [ ] Провайдер `remoteOpLogRepositoryProvider` (codegen `@riverpod`).

### Тесты

* [ ] Unit: моки на репозиторий, тесты на маппинг/валидацию payload.
* [ ] Интеграционные тесты с реальным Supabase **не делаем** на этом шаге (если нет отдельного стенда).

---

# Шаг 9 — Initial Sync при login (pull-only)

## Цель

После появления `user_id` реплика делает **pull Sync** и приводит локальное состояние к серверному.

## Чеклист: Storage маркера Sync

* [ ] Добавить локальное хранение `last_synced_at` (SharedPreferences, отдельный ключ).
* [ ] Миграции storage schema: добавить версию, если нужно.

## Чеклист: Application UseCase

* [ ] Создать `SyncCounterUseCase`:

    * [ ] получает `RemoteOpLogRepository`, `LocalOpLogRepository`, `SyncStateRepository` (для маркера).
    * [ ] читает `since`.
    * [ ] делает fetch.
    * [ ] append в local op-log **идемпотентно** (на стороне local уже есть dedup по `op_id`).
    * [ ] обновляет `since`.

## Чеклист: Триггер на auth

* [ ] При переходе `user_id: null → value` вызвать `SyncCounterUseCase`.
* [ ] При logout — **не чистить** локальные данные.

## Чеклист: Acceptance сценарии

* [ ] Локально нащёлкать increment без auth → counter растёт.
* [ ] Login → counter **не уменьшается**.
* [ ] (С тестовым серверным op-log) после login подтянуть серверные операции → counter корректный.

---

# Шаг 10 — Realtime как ускоритель (signal → needSync)

## Цель

При изменениях на другой реплике текущая реплика быстро узнаёт "нужно синхронизироваться".

## Чеклист: Supabase Realtime

* [ ] Определить канал:

    * [ ] минимум `user_id`.
    * [ ] опционально `entity_id`.
* [ ] Подписка на INSERT в `counter_operations` для текущего `user_id`.

## Чеклист: Flutter сервис

* [ ] `RealtimeEventsService`:

    * [ ] start/stop по auth.
    * [ ] на insert получать `op_id`/`created_at`.
    * [ ] не применять напрямую, а выставлять `needSync`.

## Чеклист: needSync

* [ ] Ввести `NeedSyncController` (простой сервис):

    * [ ] помечает `entity_id` как требующий sync.
    * [ ] дебаунс/троттлинг, чтобы не спамить sync.
* [ ] При `needSync` запускать `SyncCounterUseCase`.

## Чеклист: Acceptance сценарии

* [ ] Две вкладки (A и B), один пользователь:

    * [ ] increment в A → B получает realtime сигнал.
    * [ ] B делает sync → counter обновляется.
* [ ] Потеря realtime (отключить подписку) → B всё равно догонит через ручной/стартовый sync.

---

# Шаг 11 — Export локальных операций (push)

## Цель

После login выгружать накопленные локальные операции на сервер идемпотентно.

## Чеклист: Supabase (INSERT)

* [ ] Разрешить INSERT политикой RLS (если не сделали ранее).
* [ ] Убедиться, что PK по `op_id` обеспечивает идемпотентность.

## Чеклист: Local отметка "synced"

* [ ] Определить, как помечаем локальные ops как отправленные:

    * [ ] Вариант A (рекомендованный): хранить `last_exported_at` и экспортировать ops по `created_at > marker`.
    * [ ] Вариант B: хранить `synced_op_ids` (дорого при росте).
* [ ] Для стенда выбрать вариант A.

## Чеклист: Application UseCase

* [ ] `ExportLocalOpsUseCase`:

    * [ ] читает marker.
    * [ ] берёт ops из local.
    * [ ] upsert/insert на сервер.
    * [ ] обновляет marker.

## Чеклист: Оркестрация

* [ ] После login:

    * [ ] сначала `SyncCounterUseCase` (pull),
    * [ ] потом `ExportLocalOpsUseCase` (push),
    * [ ] потом включить realtime.

## Чеклист: Acceptance сценарии

* [ ] Offline increments → login → export → сервер содержит ops.
* [ ] Вторая вкладка login → sync → видит ops.
* [ ] Повторный export не создаёт дублей (PK `op_id`).

---

# Наблюдаемость и диагностика (обязательно)

## Чеклист: логирование

* [ ] Все сетевые операции логируются через единый helper (не `print`).
* [ ] Формат лога фиксирован и одинаков во всех слоях.
* [ ] Каждый лог содержит:

    * [ ] `component` (SYNC / REALTIME / EXPORT / LOCAL_OPLOG)
    * [ ] `client_id`
    * [ ] `user_id` (если авторизован)
    * [ ] `entity_id`
    * [ ] `op_id` (если применимо)
    * [ ] `created_at` / `timestamp`
* [ ] Для ошибок логируется stacktrace.
* [ ] Логи читаемы в Web (console) и Mobile (adb / Xcode).

---

## Чеклист: воспроизводимые сценарии

* [ ] Две вкладки (A и B), один пользователь, online:

    * [ ] increment в A → B получает обновление через realtime.

* [ ] Потеря realtime:

    * [ ] отключить подписку в B,
    * [ ] increment в A,
    * [ ] B делает sync → состояние корректно.

* [ ] Долгий офлайн:

    * [ ] закрыть B,
    * [ ] на A сделать несколько increment,
    * [ ] открыть B → initial sync догоняет состояние.

* [ ] Идемпотентность:

    * [ ] повторно применить одни и те же ops,
    * [ ] итоговое состояние не изменилось сверх ожидаемого.

* [ ] Две вкладки, один пользователь, realtime on.

* [ ] Realtime off → только sync.

* [ ] Долгий офлайн → догон по sync.

* [ ] Повторное получение тех же ops → идемпотентность.

---

# Стоп-критерии (если срабатывают — не идём дальше)

* [ ] Любой login/logout сбрасывает local counter.
* [ ] После sync появляются дубликаты (увеличение счётчика больше ожидаемого).
* [ ] Без auth приложение перестало работать.
* [ ] Невозможно объяснить состояние по логам (нет корреляционных id).

---

# Итоговая точка готовности шага 8–11

* [ ] Local-only режим полностью рабочий.
* [ ] После login выполняется initial sync.
* [ ] Realtime ускоряет обновление, но при отключении всё догоняется через sync.
* [ ] Локальные ops экспортируются на сервер идемпотентно.
* [ ] Все сценарии воспроизводимы и логируемы.
