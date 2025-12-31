# Diff Plan: Move Operation Creation from ViewModel to UseCase

**Timestamp (Europe/Amsterdam): 2025-12-31 14:10**

Цель документа — зафиксировать **минимальный и безопасный план изменений**, позволяющий перенести создание `CounterOperation` из `ViewModel` в `UseCase` **без лома текущей логики**, без регрессий и без каскадных правок.

Документ предназначен для исполнения **как diff-план**: шаги выполняются последовательно, каждый шаг компилируется и проходит тесты.

---

## Контекст проблемы (кратко)

На текущем этапе (Шаг 3):

* `CounterViewModel`:

    * создаёт `IncrementOperation`;
    * генерирует `op_id`, `created_at`, использует `client_id`.

Это допустимо временно, но **нарушает целевую архитектуру**:

* ViewModel содержит доменную бизнес-логику;
* Шаг 5 требует, чтобы ViewModel только вызывала UseCase.

Задача — **перенести creation операции в UseCase**, не меняя внешнее поведение.

---

## Шаг 0 — Инварианты (что НЕ меняем)

Перед началом зафиксировать:

* ❌ не меняем UI
* ❌ не меняем доменные типы (`CounterOperation`, `IncrementOperation`)
* ❌ не меняем `CounterAggregator`
* ❌ не меняем поведение счётчика
* ❌ не добавляем LocalOpLog (он будет в Шаге 4)

---

## Шаг 1 — Создать IncrementCounterUseCase

### Действие

Создать файл:

```
lib/src/application/counter/use_cases/increment_counter_use_case.dart
```

### Ответственность UseCase

* принимать зависимости:

    * `ClientIdentityService`
* при вызове:

    * генерировать `op_id` (UUID v4),
    * устанавливать `created_at = DateTime.now()`,
    * создавать `IncrementOperation`,
    * возвращать созданную операцию.

> ❗ На этом этапе UseCase **не пишет никуда**, только создаёт операцию.

### Контракт (концептуально)

```
IncrementOperation execute();
```

---

## Шаг 2 — Добавить провайдер UseCase

### Действие

Создать провайдер (codegen стиль):

```
incrementCounterUseCaseProvider
```

### Требования

* Использовать `@riverpod`.
* Инжектить `ClientIdentityService`.
* Возвращать готовый `IncrementCounterUseCase`.

---

## Шаг 3 — Переподключить ViewModel

### Текущее состояние

`CounterViewModel.incrementCounter()`:

* генерирует `op_id`, `created_at`;
* создаёт `IncrementOperation` напрямую.

### Изменение

1. Удалить из ViewModel:

    * генерацию UUID;
    * `DateTime.now()`;
    * прямое создание `IncrementOperation`.
2. Внедрить UseCase через провайдер.
3. Вызов:

   ```
   final operation = incrementCounterUseCase.execute();
   ```
4. Добавить операцию в текущий in-memory список операций (как и раньше).

### Важно

* Сигнатура `incrementCounter()` **не меняется**.
* Поведение UI **идентично** текущему.

---

## Шаг 4 — Обновить тесты ViewModel

### Действие

1. Заменить проверки:

    * вместо проверки генерации `op_id` внутри ViewModel
    * проверять, что:

        * UseCase вызван,
        * возвращённая операция добавлена в state.

2. Замокать:

    * `IncrementCounterUseCase`,
    * вернуть фиксированную `IncrementOperation`.

### Инвариант

* Все существующие тесты должны либо:

    * пройти без изменений,
    * либо быть обновлены минимально (без изменения смысла).

---

## Шаг 5 — Удалить остаточную бизнес-логику из ViewModel

### Финальная проверка

Убедиться, что в `CounterViewModel`:

* ❌ нет `Uuid()`
* ❌ нет `DateTime.now()`
* ❌ нет создания доменных операций

ViewModel должна:

* только дергать UseCase,
* только обновлять state.

---

## Критерии готовности (Definition of Done)

* ✅ Counter работает как раньше
* ✅ Все тесты проходят
* ✅ ViewModel не содержит доменной логики
* ✅ UseCase — единственная точка создания операций
* ✅ Архитектура готова к Шагу 4 (LocalOpLog)

---

## Почему этот план безопасен

* Нет изменения поведения
* Нет каскадных рефакторингов
* Нет преждевременной интеграции с LocalOpLog
* Логика переносится **один к одному**

---

## Статус документа

**Status:** ✅ ЗАВЕРШЕН (2025-12-31 13:48:36)

Все шаги выполнены, все критерии готовности выполнены. Рефакторинг завершен успешно.

### Выполненные шаги:
- ✅ Шаг 1 — Создан IncrementCounterUseCase
- ✅ Шаг 2 — Добавлен провайдер UseCase (@riverpod)
- ✅ Шаг 3 — ViewModel переподключен к UseCase
- ✅ Шаг 4 — Тесты ViewModel обновлены
- ✅ Шаг 5 — Бизнес-логика удалена из ViewModel

### Измененные файлы:
- `lib/src/application/counter/use_cases/increment_counter_use_case.dart` (создан)
- `lib/src/presentation/counter/viewmodels/counter_viewmodel.dart` (обновлен)
- `test/application/counter/increment_counter_use_case_test.dart` (создан, 5 тестов)
- `test/presentation/counter/counter_viewmodel_test.dart` (обновлен)
- `test/test_helpers/mocks.dart` (добавлен MockIncrementCounterUseCase)
- `test/test_helpers/test_providers.dart` (добавлен helper для override)

### Результаты:
- ✅ Все 98 тестов проходят
- ✅ ViewModel не содержит доменной логики (нет Uuid, DateTime.now, создания IncrementOperation)
- ✅ UseCase — единственная точка создания операций
- ✅ Архитектура готова к Шагу 4 (LocalOpLog)
