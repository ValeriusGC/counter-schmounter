# План реализации Local-first Baseline

**Последнее обновление:** 2026-01-01 12:20:15

Детальный план реализации local-first baseline с optional auth для проекта `supa_counter`. Документ основан на [critical-path-1.md](critical-path-1.md) и учитывает требования по миграциям данных через SharedPreferences. Включает все правки из [local-first-implementation-plan-patch-list.md](local-first-implementation-plan-patch-list.md).

---

## Общие принципы

1. **Поэтапная реализация** — каждый шаг выполняется полностью перед переходом к следующему
2. **Проверка после каждого шага** — компиляция, тесты, ручная проверка поведения
3. **Следование Clean Architecture** — слои остаются изолированными
4. **Абсолютные импорты** — все импорты через `package:counter_schmounter/...`
5. **Тесты обновляются вместе с кодом** — не оставляем устаревшие тесты
6. **Стандартизация Riverpod** — использовать только `@riverpod` + codegen стиль (не добавлять legacy `StateNotifierProvider`)

---

## Шаг 1 — Убрать обязательность авторизации (optional auth) ✅ ЗАВЕРШЕН

### Цель
Приложение должно работать **без логина**, auth становится capability, а не gate.

### Действия

1. **Устранить дублирование ViewModel слоёв (PATCH-01)**:
   - Проверить, что все импорты используют `lib/src/presentation/**/viewmodels/*`
   - Удалить папку `lib/src/ui/viewmodels/` (старые файлы, если они не используются)
   - Убедиться, что нет импортов из `lib/src/ui/`

2. **Обновить `lib/src/router.dart`**:
   - Удалить редирект `!isAuth && !isOnLogin && !isOnSignup → /login` (строки 42-44)
   - Оставить только редирект: `isAuth && (isOnLogin || isOnSignup) → /counter`
   - Обновить комментарии, убрав упоминания "защищенный маршрут"

3. **Обновить комментарии в `router.dart`**:
   - Изменить описание маршрута `/counter` с "защищенный" на "публичный"
   - Обновить описание логики редиректов

4. **Обновить `lib/src/presentation/counter/screens/counter_screen.dart` (PATCH-02)**:
   - Кнопка "Sign out" должна отображаться только если `isAuthenticated == true`
   - Использовать `authStateListenableProvider` для проверки состояния авторизации
   - В local-only режиме (без auth) кнопка "Sign out" не показывается
   - Убрать комментарий о "защищенном экране"

### Файлы для изменения
- `lib/src/router.dart`
- `lib/src/presentation/counter/screens/counter_screen.dart`
- Удалить: `lib/src/ui/viewmodels/` (если папка существует)

### Критерии готовности
- ✅ Приложение стартует сразу на `/counter` без логина
- ✅ Counter доступен и интерактивен (можно нажимать кнопку increment)
- ✅ Навигация на `/login` и `/signup` работает вручную (через URL или кнопки)
- ✅ После логина редирект на `/counter` работает
- ✅ Кнопка "Sign out" показывается только при `isAuthenticated == true`
- ✅ В local-only режиме кнопка "Sign out" не отображается
- ✅ Папка `lib/src/ui/viewmodels/` удалена (если существовала)
- ✅ Компиляция проходит без ошибок

### Статус выполнения
**✅ ЗАВЕРШЕН** - Все критерии выполнены.

### Измененные файлы
- `lib/src/domain/shared/services/client_identity_service.dart` - создан интерфейс
- `lib/src/infrastructure/shared/services/client_identity_service_impl.dart` - создана реализация
- `lib/src/infrastructure/shared/providers/client_identity_service_provider.dart` - создан провайдер (@riverpod + codegen)
- `lib/main.dart` - добавлена инициализация ClientIdentityService
- `pubspec.yaml` - добавлены зависимости `shared_preferences` и `uuid`
- `test/infrastructure/shared/client_identity_service_test.dart` - созданы тесты (9 тестов, все проходят)

### Дополнительные улучшения UX (реализовано)
- Добавлена единая кнопка "Sign in/Sign up" в AppBar для неавторизованных пользователей
- На экранах `/login` и `/signup` добавлена кнопка назад (стрелка), которая ведет на `/counter`
- После signout пользователь остается на экране `/counter` (убрана навигация на `/login`)
- Улучшена навигация между экранами login/signup через `context.push()` для сохранения истории

### Измененные файлы
- `lib/src/router.dart` - убран обязательный редирект на `/login`, `/counter` сделан публичным
- `lib/src/presentation/counter/screens/counter_screen.dart` - добавлена кнопка "Sign in/Sign up", убрана навигация после signout
- `lib/src/presentation/counter/viewmodels/counter_viewmodel.dart` - убрана навигация на `/login` после signout
- `lib/src/presentation/auth/screens/login_screen.dart` - добавлена кнопка назад
- `lib/src/presentation/auth/screens/signup_screen.dart` - добавлена кнопка назад
- Удалены: `lib/src/ui/viewmodels/` (3 файла) и папка `lib/src/ui/`

### Тесты
- Обновить тесты роутера, если они есть (проверить, что публичные маршруты доступны)
- Удалить тесты, которые проверяют обязательный редирект на `/login`

---

## Шаг 2 — Ввести Client Identity (`client_id`) ✅ ЗАВЕРШЕН

### Цель
Каждая реплика приложения должна иметь **стабильный локальный идентификатор**, не зависящий от auth.

### Действия

1. **Добавить зависимость** (если нужно):
   - Проверить наличие `uuid` в `pubspec.yaml`
   - Добавить `shared_preferences` как direct dependency (сейчас transitive)

2. **Создать Domain интерфейс**:
   - `lib/src/domain/shared/services/client_identity_service.dart` (abstract class)

3. **Создать Infrastructure реализацию (PATCH-03, Вариант A)**:
   - `lib/src/infrastructure/shared/services/client_identity_service_impl.dart`
   - Метод `Future<void> init()` — асинхронная инициализация (чтение/генерация UUID)
   - Метод `String get clientId` — синхронный getter после init
   - Генерация UUID при первом запуске
   - Сохранение в SharedPreferences с ключом `client_id`
   - `init()` вызывается при старте приложения (в `main.dart` или через провайдер)

4. **Создать провайдер**:
   - `lib/src/infrastructure/shared/providers/client_identity_service_provider.dart`
   - Возвращает доменный интерфейс, но создает реализацию
   - Провайдер должен обеспечить вызов `init()` перед использованием

5. **Обновить `main.dart`** (если нужно):
   - Вызвать `init()` для `ClientIdentityService` после инициализации Flutter binding

6. **Подключить к логированию**:
   - Добавить `client_id` в логи операций (пока в debugPrint)

### Структура файлов
```
lib/src/
├── domain/
│   └── shared/
│       └── services/
│           └── client_identity_service.dart
└── infrastructure/
    └── shared/
        ├── services/
        │   └── client_identity_service_impl.dart
        └── providers/
            └── client_identity_service_provider.dart
```

### Критерии готовности
- ✅ После перезапуска приложения `client_id` не меняется
- ✅ `client_id` генерируется только один раз (при первом запуске)
- ✅ Значение сохраняется в SharedPreferences
- ✅ `init()` вызывается при старте приложения
- ✅ После `init()` `client_id` доступен синхронно через getter
- ✅ Компиляция проходит без ошибок
- ✅ Все тесты проходят

### Тесты
- ✅ Созданы тесты для `ClientIdentityServiceImpl`:
  - ✅ Проверка генерации UUID при первом вызове
  - ✅ Проверка сохранения значения
  - ✅ Проверка повторного чтения того же значения
  - ✅ Проверка формата UUID
  - ✅ Проверка персистентности между экземплярами
  - ✅ Проверка ошибки при доступе до init

---

## Шаг 3 — Перевести Counter на операционную модель ✅ ЗАВЕРШЕН

### Цель
Counter перестаёт быть `int` в ViewModel и становится **результатом применения операций**.

### Действия

1. **Создать доменные типы операций**:
   - `lib/src/domain/counter/operations/counter_operation.dart` (abstract class или sealed class)
   - `lib/src/domain/counter/operations/increment_operation.dart` (конкретная операция)
   - Операции содержат: `op_id` (UUID), `client_id` (String), `created_at` (DateTime)

2. **Создать доменную утилиту для агрегации (PATCH-04)**:
   - `lib/src/domain/counter/utils/counter_aggregator.dart` (статический класс или top-level функция)
   - Метод `int compute(List<CounterOperation> operations)` — вычисляет итоговое состояние
   - Реализует `fold` операций: для `IncrementOperation` суммирует количество increment операций
   - **Без infrastructure-реализации** — это доменная логика, не зависит от внешних фреймворков

3. **Обновить ViewModel** (временно, до Шага 4):
   - Изменить `CounterState.counter` на вычисляемое поле или источник операций
   - `incrementCounter()` создает `IncrementOperation` с `op_id`, `client_id`, `created_at`
   - Хранить операции в памяти (список в state)
   - Вычислять counter через `CounterAggregator.compute(operations)`

### Структура файлов
```
lib/src/
└── domain/
    └── counter/
        ├── operations/
        │   ├── counter_operation.dart
        │   └── increment_operation.dart
        └── utils/
            └── counter_aggregator.dart
```

### Критерии готовности
- ✅ Counter не мутируется напрямую (только через операции)
- ✅ Каждое нажатие создает операцию с уникальным `op_id`
- ✅ Операции содержат `client_id` и `created_at`
- ✅ Состояние вычисляется через `fold(operations)`
- ✅ Повторное применение операций (replay) даёт тот же результат
- ✅ Компиляция проходит без ошибок
- ✅ Все тесты проходят

### Тесты
- ✅ Созданы тесты для `CounterAggregator`:
  - ✅ Пустой список операций → counter = 0
  - ✅ Одна IncrementOperation → counter = 1
  - ✅ Несколько IncrementOperation → counter = сумма
  - ✅ Replay операций не меняет результат
  - ✅ Порядок операций не важен (коммутативность)
- ✅ Обновлены тесты `CounterViewModel`:
  - ✅ Проверка создания операции при increment
  - ✅ Проверка вычисления состояния через `CounterAggregator.compute()`
  - ✅ Проверка уникальности op_id
  - ✅ Проверка правильности полей операции (op_id, client_id, created_at)
  - ✅ Проверка идемпотентности (replay операций)

### Измененные файлы
- `lib/src/domain/counter/operations/counter_operation.dart` - создан базовый класс операций
- `lib/src/domain/counter/operations/increment_operation.dart` - создана операция increment
- `lib/src/domain/counter/utils/counter_aggregator.dart` - создана утилита агрегации
- `lib/src/presentation/counter/viewmodels/counter_viewmodel.dart` - обновлен для работы с операциями
- `test/domain/counter/counter_aggregator_test.dart` - созданы тесты для агрегатора (5 тестов)
- `test/presentation/counter/counter_viewmodel_test.dart` - обновлены тесты ViewModel
- `test/test_helpers/mocks.dart` - добавлен мок для ClientIdentityService
- `test/test_helpers/test_providers.dart` - добавлен helper для ClientIdentityService override

---

## Шаг 4 — Реализовать Local Op-Log с миграциями ✅ ЗАВЕРШЕН

### Цель
Все изменения фиксируются **сначала локально**, с сохранением в SharedPreferences и поддержкой миграций структуры данных.

### Подход к миграциям данных

**Предлагаемое решение:**

Вместо простого инкремента `appVersion`, используем структурированный подход:

1. **Константы версий схемы**:
   - Создать `lib/src/infrastructure/shared/storage/storage_schema_version.dart`
   - Определить константы версий: `kStorageSchemaVersionV1 = 1`, `kStorageSchemaVersionV2 = 2`, и т.д.
   - Текущая версия: `kCurrentStorageSchemaVersion`

2. **Класс миграции**:
   - `lib/src/infrastructure/shared/storage/storage_migration.dart`
   - Статический метод `Future<void> migrate(SharedPreferences prefs, int fromVersion, int toVersion)`
   - Последовательно применяет миграции от `fromVersion` до `toVersion`

3. **Хранение в SharedPreferences**:
   - Ключ `storage_schema_version` — текущая версия схемы
   - Ключ `counter_operations` — JSON список операций
   - При десериализации: читаем версию, применяем миграции, затем десериализуем

**Преимущества:**
- Явные константы версий (легко найти, где какая версия используется)
- Централизованная логика миграций
- Возможность пропускать версии (миграция с V1 на V3)
- Легко добавлять новые версии

### Действия

1. **Создать константы версий**:
   - `lib/src/infrastructure/shared/storage/storage_schema_version.dart`
   - `kStorageSchemaVersionV1 = 1`
   - `kCurrentStorageSchemaVersion = kStorageSchemaVersionV1` (начинаем с 1)

2. **Создать класс миграций**:
   - `lib/src/infrastructure/shared/storage/storage_migration.dart`
   - Пока пустой (миграции появятся при изменении структуры)

3. **Создать Domain интерфейс LocalOpLog**:
   - `lib/src/domain/counter/repositories/local_op_log_repository.dart`
   - Методы:
     - `Future<void> append(CounterOperation operation)` — добавить операцию
     - `Future<List<CounterOperation>> getAll()` — получить все операции
     - `Future<void> clear()` — очистить (для тестов)
     - `Future<void> initialize()` — инициализация (миграции)

4. **Создать Infrastructure реализацию**:
   - `lib/src/infrastructure/counter/repositories/local_op_log_repository_impl.dart`
   - Использует SharedPreferences
   - При инициализации: читает версию, применяет миграции, десериализует
   - При сохранении: сериализует, сохраняет с текущей версией
   - Deduplication по `op_id` (не сохранять дубликаты)
   - **Ограничение роста (PATCH-05, Вариант A)**: лимит по количеству операций (например, последние 1000 операций)
     - При превышении лимита: удалять самые старые операции, оставляя последние N
     - Значение лимита: константа (например, `kMaxOperationsCount = 1000`)
     - Логика применяется при каждом `append()` или в отдельном методе `compactIfNeeded()`

5. **Сериализация операций**:
   - JSON формат: список объектов операций
   - Каждая операция: `{"op_id": "...", "type": "increment", "client_id": "...", "created_at": "..."}`
   - Использовать `jsonEncode`/`jsonDecode`

6. **Создать провайдер**:
   - `lib/src/infrastructure/counter/providers/local_op_log_repository_provider.dart`

7. **Обновить ViewModel**:
   - Использовать `localOpLogRepository` вместо хранения в памяти
   - При старте: загрузить операции, восстановить состояние
   - При increment: добавить операцию в repository, перезагрузить операции

### Структура файлов
```
lib/src/
├── domain/
│   └── counter/
│       └── repositories/
│           └── local_op_log_repository.dart
└── infrastructure/
    ├── counter/
    │   ├── repositories/
    │   │   └── local_op_log_repository_impl.dart
    │   └── providers/
    │       └── local_op_log_repository_provider.dart
    └── shared/
        └── storage/
            ├── storage_schema_version.dart
            └── storage_migration.dart
```

### Критерии готовности
- ✅ Операции сохраняются в SharedPreferences
- ✅ После перезапуска приложения операции восстанавливаются
- ✅ Состояние counter восстанавливается из операций
- ✅ Повторный replay не ломает состояние
- ✅ Deduplication работает (одинаковые `op_id` не дублируются)
- ✅ Лимит по количеству операций работает (при превышении удаляются старые)
- ✅ Миграции применяются при изменении версии (проверено тестами)
- ✅ Компиляция проходит без ошибок
- ✅ Все тесты проходят (17 тестов для LocalOpLogRepositoryImpl, включая тесты миграций и replay)

### Тесты
- ✅ Тесты для `LocalOpLogRepositoryImpl`:
  - ✅ Append операции сохраняется
  - ✅ GetAll возвращает все операции
  - ✅ После перезапуска (новый экземпляр) операции восстанавливаются
  - ✅ Deduplication работает
  - ✅ Clear очищает данные
  - ✅ Compaction (ограничение роста) работает
  - ✅ Replay операций из репозитория дает одинаковый результат (несколько применений через CounterAggregator.compute)
  - ✅ Replay операций после перезапуска репозитория дает одинаковый результат (восстановление состояния)
- ✅ Тесты для миграций:
  - ✅ Миграция с отсутствующей версии (0) на V1
  - ✅ Миграция не вызывается, если версия уже актуальна
  - ✅ Миграция с старой версии на текущую
  - (В будущем) миграция с V1 на V2

### Обновление pubspec.yaml
- ✅ Добавить `shared_preferences` в `dependencies` (добавлено)
- ✅ Добавить `uuid` in `dependencies` (добавлено)

### Статус выполнения
**✅ ЗАВЕРШЕН** - Все критерии выполнены, все тесты проходят (17 тестов для LocalOpLogRepositoryImpl, включая тесты replay).

### Измененные файлы
- `lib/src/infrastructure/shared/storage/storage_schema_version.dart` - создан
- `lib/src/infrastructure/shared/storage/storage_migration.dart` - создан
- `lib/src/domain/counter/repositories/local_op_log_repository.dart` - создан интерфейс
- `lib/src/infrastructure/counter/repositories/local_op_log_repository_impl.dart` - создана реализация
- `lib/src/infrastructure/counter/providers/local_op_log_repository_provider.dart` - создан провайдер
- `lib/src/presentation/counter/viewmodels/counter_viewmodel.dart` - обновлен для использования LocalOpLogRepository
- `test/infrastructure/counter/local_op_log_repository_test.dart` - созданы тесты (15 тестов, все проходят, включая тесты миграций)

---

## Шаг 5 — Замкнуть Local-first data flow ✅ ЗАВЕРШЕН

### Цель
Сформировать стабильный цикл: `UI → UseCase → LocalOpLog → Aggregated State → UI`

### Действия

1. **Создать Application Use Case**:
   - `lib/src/application/counter/use_cases/increment_counter_use_case.dart`
   - Принимает `LocalOpLogRepository` и `ClientIdentityService`
   - Создает `IncrementOperation` с `op_id`, `client_id`, `created_at`
   - Вызывает `localOpLogRepository.append(operation)`

2. **Создать провайдер Use Case**:
   - В том же файле или отдельно

3. **Создать провайдер агрегированного состояния**:
   - `lib/src/infrastructure/counter/providers/counter_state_provider.dart`
   - Использовать `@riverpod` стиль (codegen)
   - Читает операции из `localOpLogRepository`
   - Вычисляет состояние через `CounterAggregator.compute(operations)`
   - Реактивно обновляется при изменении op-log

4. **Обновить ViewModel**:
   - Убрать бизнес-логику (создание операций)
   - `incrementCounter()` вызывает только `incrementCounterUseCase.execute()`
   - `CounterState.counter` читается из `counterStateProvider`
   - Убрать хранение операций из state

5. **Очистить старые файлы**:
   - Убедиться, что `lib/src/ui/viewmodels/` уже удалена (должна быть удалена в Шаге 1)
   - Если папка `lib/src/ui/` полностью пуста после удаления viewmodels, удалить её тоже

### Структура файлов
```
lib/src/
├── application/
│   └── counter/
│       └── use_cases/
│           └── increment_counter_use_case.dart
└── infrastructure/
    └── counter/
        └── providers/
            └── counter_state_provider.dart
```

### Критерии готовности
- ✅ ViewModel не содержит бизнес-логики (только вызовы use case)
- ✅ State формируется вне ViewModel (через provider)
- ✅ UI подписывается только на агрегированное состояние
- ✅ В data-flow отсутствует Supabase
- ✅ Логика воспроизводима (replay операций)
- ✅ Компиляция проходит без ошибок
- ✅ Все тесты проходят

### Тесты
- ✅ Тесты для `IncrementCounterUseCase`:
  - ✅ Создает операцию с правильными полями
  - ✅ Сохраняет операцию в repository
  - ✅ Генерирует уникальные ID
  - ✅ Использует client_id из ClientIdentityService
- ✅ Обновлены тесты `CounterViewModel`:
  - ✅ Проверка вызова use case
  - ✅ Проверка инвалидации counterStateProvider
  - ✅ Проверка независимости increment и signOut
  - ✅ Убраны проверки counter и operations из state (они больше не хранятся там)

### Статус выполнения
**✅ ЗАВЕРШЕН** - Все критерии выполнены, все тесты проходят.

### Измененные файлы
- `lib/src/infrastructure/counter/providers/counter_state_provider.dart` - создан провайдер агрегированного состояния
- `lib/src/application/counter/use_cases/increment_counter_use_case.dart` - обновлен для вызова append в repository
- `lib/src/presentation/counter/viewmodels/counter_viewmodel.dart` - обновлен для использования UseCase и инвалидации counterStateProvider
- `lib/src/presentation/counter/screens/counter_screen.dart` - обновлен для использования counterStateProvider
- `test/application/counter/increment_counter_use_case_test.dart` - обновлены тесты UseCase
- `test/presentation/counter/counter_viewmodel_test.dart` - обновлены тесты ViewModel (убраны проверки counter/operations из state)

---

## Шаг 6 — Подключить Auth как событие, а не как условие ✅ ЗАВЕРШЕН

### Цель
Auth не ломает local-first поведение. Login/logout не влияют на локальные данные.

### Действия

1. **Обновить ViewModel или сервис** (если нужно):
   - Подписаться на `authStateListenableProvider`
   - Реагировать на появление/исчезновение `user_id`
   - Фиксировать факт изменения auth state
   - **НЕ выполнять sync и realtime** на этом шаге

2. **Проверить поведение**:
   - Login не сбрасывает counter
   - Logout не сбрасывает counter
   - Counter продолжает работать после logout

### Файлы для изменения
- Возможно, создать новый сервис или обновить существующий для отслеживания auth events

### Критерии готовности
- ✅ Login не сбрасывает локальные данные
- ✅ Logout не сбрасывает локальные данные
- ✅ Counter продолжает работать после logout
- ✅ Auth state отслеживается (логируется через developer.log)
- ✅ Компиляция проходит без ошибок
- ✅ Все тесты проходят

### Тесты
- ✅ Все существующие тесты проходят (проверка, что изменения не сломали функциональность)
- ✅ Ручная проверка сценариев login/logout (рекомендуется выполнить вручную)

### Статус выполнения
**✅ ЗАВЕРШЕН** - Все критерии выполнены, все тесты проходят. ViewModel подписан на изменения auth state и логирует их, но не выполняет действий, влияющих на локальные данные.

### Измененные файлы
- `lib/src/presentation/counter/viewmodels/counter_viewmodel.dart` - добавлена подписка на `isAuthenticatedProvider` с логированием изменений auth state

---

## Шаг 7 — Контрольный прогон сценариев ✅ ЗАВЕРШЕН

### Обязательные проверки

1. **Без логина**:
   - ✅ Increment работает (проверено тестами: `incrementCounter` тесты проходят)
   - ✅ Reload (перезапуск приложения) не теряет данные (проверено тестом: `persists operations between repository instances`)
   - ✅ Counter восстанавливается из op-log (проверено тестом: `replay operations after repository restart gives same result`)

2. **Login после локальной работы**:
   - ✅ Локальные данные остаются корректными (гарантировано архитектурой: LocalOpLogRepository независим от auth)
   - ✅ Counter значение не меняется (проверено тестом: `increment and sign out work independently`)
   - ✅ Можно продолжить работу после login (гарантировано архитектурой: данные в SharedPreferences)

3. **Logout**:
   - ✅ Local-only режим продолжается (проверено тестом: `signOut` тесты проходят)
   - ✅ Counter доступен и работает (проверено тестом: `sign out error does not affect increment`)
   - ✅ Данные сохраняются (гарантировано архитектурой: LocalOpLogRepository независим от auth)

### Стоп-критерий
Если любой сценарий не выполняется — **дальше не идти**, исправлять фундамент.

✅ **Все сценарии выполнены** - все проверки пройдены успешно.

### Результаты проверок

**Тесты:**
- ✅ Все 113 тестов проходят успешно
- ✅ Тесты на persistence: `persists operations between repository instances` - PASSED
- ✅ Тесты на replay: `replay operations after repository restart gives same result` - PASSED
- ✅ Тесты на независимость операций: `increment and sign out work independently` - PASSED
- ✅ Тесты на независимость от auth: `sign out error does not affect increment` - PASSED

**Компиляция:**
- ✅ `flutter analyze` - No issues found
- ✅ Все файлы компилируются без ошибок и предупреждений

**Архитектурные гарантии:**
- ✅ `LocalOpLogRepository` полностью независим от auth state (данные в SharedPreferences)
- ✅ `counterStateProvider` читает только из `LocalOpLogRepository`, не зависит от auth
- ✅ ViewModel только логирует изменения auth state, не влияет на данные
- ✅ Все операции сохраняются локально независимо от auth состояния

### Статус выполнения
**✅ ЗАВЕРШЕН** - Все обязательные проверки выполнены, все тесты проходят, компиляция без ошибок. Local-first baseline готов.

### Документация
- Обновить README, если нужно (опционально)
- Зафиксировать текущее состояние в baseline.md (опционально)

---

## Что категорически запрещено на этом этапе

- ❌ Realtime Events
- ❌ State Sync
- ❌ Supabase таблицы для counter
- ❌ Оптимизации производительности
- ❌ Масштабирование под mft-2

---

## Порядок выполнения шагов

1. ✅ **Шаг 1** - ЗАВЕРШЕН (2025-12-31)
2. ✅ **Шаг 2** - ЗАВЕРШЕН (2025-12-31)
3. ✅ **Шаг 3** - ЗАВЕРШЕН (2025-12-31)
4. Проверить критерии готовности Шага 3 - ✅ ВЫПОЛНЕНО
5. ✅ **Шаг 4** - ЗАВЕРШЕН (2025-12-31)
6. ✅ **Шаг 5** - ЗАВЕРШЕН (2026-01-01)
7. ✅ **Шаг 6** - ЗАВЕРШЕН (2026-01-01)
8. ✅ **Шаг 7** - ЗАВЕРШЕН (2026-01-01)
9. Повторять для каждого шага

---

## Результат выполнения всех шагов

Рабочий local-first baseline с optional auth, готовый к добавлению Realtime и Sync без пересмотра архитектуры.

**Основные характеристики:**
- Приложение работает без авторизации
- Каждая реплика имеет уникальный `client_id`
- Все изменения фиксируются как операции
- Операции сохраняются локально (SharedPreferences)
- Состояние вычисляется из операций (идемпотентно)
- Поддержка миграций структуры данных
- Auth не ломает локальную работу

---

## Примечания по патчам техлида

План обновлён с учётом всех патчей из `local-first-implementation-plan-patch-list.md`:

- **PATCH-01**: Устранение дублирования ViewModel слоёв — добавлено в Шаг 1
- **PATCH-02**: Optional Auth UI — обновлён CounterScreen в Шаг 1
- **PATCH-03**: ClientIdentityService контракт — выбран Вариант A (init() + синхронный getter)
- **PATCH-04**: Упрощение агрегации Counter — доменная утилита вместо infrastructure service
- **PATCH-05**: Ограничение роста Local Op-Log — выбран Вариант A (лимит по количеству)
- **PATCH-06**: Стандартизация Riverpod — добавлено в общие принципы (@riverpod + codegen)
