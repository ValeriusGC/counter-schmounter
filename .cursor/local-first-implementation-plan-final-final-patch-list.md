# Final Patch: Baseline Cleanup (Blocking Items)

**Timestamp (Europe/Amsterdam): 2026-01-01 16:32**

Документ фиксирует **финальный минимальный патч**, необходимый для полного закрытия baseline. Объём изменений — **5–6 строк кода**, без рефакторинга и изменения поведения.

---

## 1. Закрыть P0-2 — вынести auth UseCase providers из application

**Где сейчас (неправильно):**

```
lib/src/application/auth/use_cases/sign_in_use_case.dart
lib/src/application/auth/use_cases/sign_up_use_case.dart
lib/src/application/auth/use_cases/sign_out_use_case.dart
```

В этих файлах объявлены `Provider<...UseCase>`.

**Правка (2–3 строки на файл):**

* Удалить объявления `Provider<...UseCase>` из application-файлов.
* Создать отдельный файл:

```
lib/src/infrastructure/auth/providers/auth_use_case_providers.dart
```

* Перенести туда провайдеры без изменения их тела.

**Инвариант:** классы UseCase остаются в application, DI — в infrastructure.

**Статус:** ✅ **ВЫПОЛНЕНО** (2026-01-01 12:46:29)
* Создан файл `lib/src/infrastructure/auth/providers/auth_use_case_providers.dart`
* Провайдеры перенесены из application в infrastructure
* Обновлены все импорты в ViewModels и тестах
* Application слой больше не импортирует infrastructure providers

---

## 2. Закрыть P1-3 — убрать blanket try/catch вокруг state update

**Где:**

```
CounterViewModel.signOut()
```

**Было:**

```dart
try {
  state = const AsyncValue.data(null);
} catch (_) {}
```

**Стало (1 строка):**

```dart
if (!ref.mounted) return;
state = const AsyncValue.data(null);
```

**Статус:** ✅ **ВЫПОЛНЕНО** (2026-01-01 12:46:29)
* Удалены blanket try/catch блоки вокруг обновления state
* Добавлена проверка `ref.mounted` перед обновлением state
* Применено как для успешного, так и для ошибочного сценариев

---

## 3. Формально закрыть P1-1 — зафиксировать стандарт env-ключей

**Где:**

```
main.dart (комментарий над String.fromEnvironment)
```

**Добавить 1 строку комментария:**

```dart
// Baseline standard: use SU / SAK (short form) for Supabase credentials
```

**Статус:** ✅ **ВЫПОЛНЕНО** (2026-01-01 12:46:29)
* Добавлен комментарий о стандарте env-ключей в `main.dart`
* Стандарт явно зафиксирован: SU / SAK (short form)

---

## Definition of Done

* ✅ Application слой не импортирует infrastructure providers
* ✅ Нет blanket try/catch вокруг state
* ✅ Стандарт env-ключей зафиксирован явно

**Статус:** ✅ **ВСЕ ЗАДАЧИ ВЫПОЛНЕНЫ** (2026-01-01 12:46:29)

После применения этого патча baseline считается **полностью закрытым и эталонным**.

**Последнее обновление:** 2026-01-01 12:46:29
