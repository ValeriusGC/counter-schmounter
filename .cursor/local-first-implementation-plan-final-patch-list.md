# Patch List P0/P1: Baseline Cleanup Before Freeze

**Timestamp (Europe/Amsterdam): 2026-01-01 15:50**

Документ фиксирует **обязательные (P0)** и **важные (P1)** правки, выявленные при полном ревью baseline-кода. Цель — довести текущую реализацию до **эталонного состояния**, пригодного для тиражирования в других проектах.

Документ не предполагает переписывания архитектуры — только точечные корректировки.

---

## P0 — ОБЯЗАТЕЛЬНО ИСПРАВИТЬ (нарушение базовых принципов)

### P0-1 — Убрать legacy Riverpod из SignupViewModel

**Проблема**

* `SignupViewModel` реализован через `StateNotifierProvider` и `flutter_riverpod/legacy.dart`.
* Нарушает зафиксированное правило: **использовать только `@riverpod` + codegen**.

**Требуемая правка**

* Переписать `SignupViewModel` на:

  ```dart
  @riverpod
  class SignupViewModel extends _$SignupViewModel { ... }
  ```
* Удалить:

    * `StateNotifierProvider`
    * `flutter_riverpod/legacy.dart`

**Статус**

* ✅ **ВЫПОЛНЕНО** (2026-01-01 12:31:05)
* `SignupViewModel` переписан на `@riverpod` + codegen
* Удалены `StateNotifierProvider` и `flutter_riverpod/legacy.dart`

---

### P0-2 — Разорвать зависимость application use case ↔ infrastructure providers

**Проблема**

* `IncrementCounterUseCase` (application слой) объявляет `@riverpod` provider и импортирует infrastructure providers.
* Смешиваются application и infrastructure слои.

**Требуемая правка (минимальная)**

* Оставить класс `IncrementCounterUseCase` в application.
* Перенести `@riverpod incrementCounterUseCaseProvider` в:

    * `lib/src/infrastructure/di/` **или**
    * `lib/src/infrastructure/counter/providers/`.

**Инвариант**

* Application слой **не должен знать**, откуда берутся зависимости.

**Статус**

* ✅ **ВЫПОЛНЕНО** (2026-01-01 12:31:05)
* Provider перенесен в `lib/src/infrastructure/counter/providers/increment_counter_use_case_provider.dart`
* Класс `IncrementCounterUseCase` остался в application слое без зависимостей от infrastructure

---

## P1 — ВАЖНО ИСПРАВИТЬ (не блокирует, но ухудшает baseline)

### P1-1 — Привести env-keys к одному стандарту

**Проблема**

* В `main.dart` используются `SU` / `SAK`,
* В сообщениях и комментариях фигурируют `SUPABASE_URL` / `SUPABASE_ANON_KEY`.

**Требуемая правка**

* Выбрать **один стандарт** (любой) и использовать его:

    * в `String.fromEnvironment`,
    * в комментариях,
    * в текстах ошибок.

**Статус**

* ✅ **ВЫПОЛНЕНО** (2026-01-01 12:31:05)
* Выбран стандарт `SU` / `SAK`
* Обновлены сообщения об ошибках в `main.dart`

---

### P1-2 — Исправить ложный комментарий о реактивности counterStateProvider

**Проблема**

* Комментарий утверждает, что provider реактивен к изменениям репозитория.
* Фактически обновление происходит через `ref.invalidate()`.

**Требуемая правка**

* Обновить комментарий на честный, отражающий реальный механизм обновления.
* Реализацию **не менять**.

**Статус**

* ✅ **ВЫПОЛНЕНО** (2026-01-01 12:31:05)
* Комментарий обновлен: "Обновляется через `ref.invalidate()` после изменений в op-log"

---

### P1-3 — Убрать try/catch вокруг `state = ...` в LoginViewModel

**Проблема**

* Исключения вокруг обновления state ловятся «на всякий случай».
* Маскирует ошибки жизненного цикла.

**Требуемая правка**

* Убрать blanket try/catch.
* Использовать корректный lifecycle-guard (например, проверку mounted / корректный поток навигации).

**Статус**

* ✅ **ВЫПОЛНЕНО** (2026-01-01 12:31:05)
* Удалены try/catch блоки вокруг обновления `state` в `LoginViewModel.signIn()`

---

## Что НЕ требуется делать

* ❌ Не переписывать LocalOpLog
* ❌ Не оптимизировать storage
* ❌ Не менять data-flow
* ❌ Не трогать auth / sync / realtime

---

## Итог

После выполнения пунктов P0/P1:

* baseline считается **архитектурно чистым**,
* код готов к заморозке и тиражированию,
* дальнейшие шаги (Sync / Realtime) можно начинать без возвратных рефакторингов.

**Статус документа:** ✅ **ВСЕ ЗАДАЧИ ВЫПОЛНЕНЫ** (2026-01-01 12:31:05)

**Последнее обновление:** 2026-01-01 12:31:05
