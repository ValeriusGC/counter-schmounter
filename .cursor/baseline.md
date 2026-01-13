# Baseline — Auth + Realtime + Account-Scoped State Synchronization (Flutter + Supabase)

**Status:** Canonical / Production-grade

Этот документ является **единственным источником истины** для реализации и переноса механизма **Auth + Realtime Events + State Synchronization** в проектах семейства (включая mft-2).

Документ зафиксирован **по фактическому коду**, а не по теоретическим ожиданиям.

---

## 0. Цели и границы

### Цели

1. Обеспечить **детерминированную, воспроизводимую и масштабируемую** синхронизацию состояния между репликами.
2. Поддержать **local-first** режим с **optional auth**.
3. Зафиксировать **жёсткие архитектурные контракты**, исключающие неявное поведение.
4. Обеспечить перенос решения в mft-2 **без изменения принципов**.

### Нецели

* UI/UX
* CRDT / OT
* Оптимизация storage
* Масштабирование нагрузок

---

## 1. Термины

* **Replica** — экземпляр приложения (устройство / вкладка).
* **Client Identity (`client_id`)** — стабильный UUID реплики, существует всегда.
* **User Identity (`user_id`)** — идентификатор пользователя после auth.
* **Account Scope** — namespace локального состояния, определяемый `user_id` или `anonymous`.
* **Operation (Op)** — атомарное доменное изменение.
* **Op-Log** — append-only журнал операций.
* **Cursor** — временная граница синхронизации.
* **Gate** — логический барьер для realtime.

---

## 2. Базовые инварианты (обязательные)

1. **Append-only**: операции не изменяются и не удаляются.
2. **Idempotency**: повторное применение операции безопасно.
3. **UTC-only**: все сравнения времени выполняются в UTC.
4. **Account-scoped state**: локальное состояние НЕ разделяется между аккаунтами.
5. **Auth switch = teardown**: смена аккаунта уничтожает предыдущий контекст.
6. **Realtime ≠ источник истины**.

---

## 3. Account Scope Model (ключевой раздел)

### 3.1 Определение scope

Account Scope определяется как:

* `user:<user_id>` — авторизованный режим
* `anonymous` — local-only режим

Scope используется для:

* Local Op-Log
* Sync cursors (`lastSyncedAt`, `lastExportedAt`)
* In-memory агрегатов

### 3.2 Запрещено

* Использовать один и тот же Local Op-Log для разных аккаунтов
* Переиспользовать cursors между аккаунтами
* Продолжать pending async-операции после смены scope

---

## 4. Auth Lifecycle Contract (жёсткий)

### 4.1 `null → user_id` (login / signup)

1. Создаётся **новый account-scope**
2. Инициализируется Local Op-Log для scope
3. Выполняется **Initial Sync (B1)**
4. Инвалидируется read-model
5. Открывается Realtime Gate

### 4.2 `user_id → null` (logout)

1. Текущий account-scope **уничтожается**
2. Realtime Gate **закрывается**
3. Pending debounce / sync jobs **отменяются**
4. Создаётся `anonymous` scope
5. UI продолжает работу в local-only режиме

---

## 5. Этапы реализации (A1–A3–B1)

### A1 — Bootstrap

* Инициализация client_id
* Инициализация Local Op-Log (anonymous)
* Realtime Gate закрыт
* Сервер не используется

### A2 — Local-only

* Все изменения пишутся в Local Op-Log
* UI агрегирует состояние из ops

### A3 — Auth (без sync)

* Пользователь авторизуется
* Gate остаётся закрытым
* Local-only поведение сохраняется

---

## 6. B1 — Initial Sync (обязательный)

### 6.1 Общие правила

* Выполняется **один раз на account-scope**
* Realtime запрещён до завершения

### 6.2 PULL (server → client)

1. Прочитать `lastSyncedAt` (scope-specific)
2. SELECT ops:

    * `user_id = current user`
    * `created_at > lastSyncedAt`
3. Сортировка ASC
4. Применение с дедупликацией по `op_id`
5. Обновление cursor

### 6.3 PUSH (client → server)

1. Прочитать `lastExportedAt`
2. Отфильтровать local ops
3. Отправить на сервер
4. Сохранить max(createdAt) как cursor

---

## 7. Cursor Contract (критично)

* Хранится в **microsecondsSinceEpoch (UTC)**
* Cursor **exclusive**
* Старые millis-значения:

    * интерпретируются как UTC
    * сдвигаются на +1 микросекунду

---

## 8. Realtime Events

### Назначение

* Ускорение UX
* Триггер `needSync`

### Правила

1. Payload минимален
2. Потери допустимы
3. При несоответствии — ставится `needSync`

---

## 9. NeedSync Controller

* Debounced
* Account-scoped
* Сбрасывается при auth switch

---

## 10. Интеграционные сценарии (обязательные)

1. Login A → click → logout → login B → значения изолированы
2. Два клиента → realtime + sync
3. Offline → online → reconciliation
4. Повторный sync → no-op

---

## 11. Перенос в mft-2

Разрешено менять:

* доменные операции
* entity model
* conflict rules

Запрещено менять:

* account-scope
* lifecycle auth switch
* UTC контракт
* gate порядок

---

## Статус

**BASELINE ЗАКРЫТ И КАНОНИЗИРОВАН**
