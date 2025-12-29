# Скорректированный план рефакторинга проекта (production-реалистичный)

> Основано строго на текущем коде и именах проекта `supa_counter` (пакет `supa_counter`) и фактических файлах `lib/`.
> Источник текущего состояния: `lib/src/auth/*`, `lib/src/ui/*`, `lib/src/router.dart`, `lib/src/app.dart`, `lib/main.dart`.

## 0. Цель рефакторинга (в терминах реального выигрыша)

1. Устранить прямую зависимость `ViewModel → AuthRepository` (и любых инфраструктурных деталей).
2. Ввести слой **Application** (Use Cases) как единственную точку оркестрации бизнес-намерений.
3. Развести контракты (interfaces) и реализации (Supabase) так, чтобы:

    * ViewModels тестировались без Supabase;
    * Supabase оставался заменяемым адаптером;
    * Router продолжал реагировать на auth state без проникновения в Domain.
4. Сделать изменения минимальными по объёму, без «академического» домена.

## 1. Принципы и правила зависимостей (фиксируем до действий)

* **Presentation** зависит только от **Application** (и от Riverpod/Flutter как UI-фреймворков).
* **Application** зависит только от **Domain**.
* **Infrastructure** зависит от **Domain** и от внешних SDK (Supabase).
* **Domain** не зависит ни от Flutter, ни от Riverpod, ни от Supabase.

Отдельно:

* `GoRouter` остаётся в инфраструктуре/композиции приложения, но не затягивает Domain внутрь.
* Entities не создаём «ради структуры». Добавляем только то, что реально нужно для контрактов.

## 2. Целевая структура каталогов (минимально необходимая)

```
lib/
├── main.dart
├── src/
│   ├── app.dart
│   ├── router.dart
│   │
│   ├── domain/
│   │   └── auth/
│   │       ├── repositories/
│   │       │   └── auth_repository.dart
│   │       └── value_objects/           # опционально, см. этап 3
│   │
│   ├── application/
│   │   └── auth/
│   │       └── use_cases/
│   │           ├── sign_in_use_case.dart
│   │           ├── sign_up_use_case.dart
│   │           └── sign_out_use_case.dart
│   │
│   ├── infrastructure/
│   │   └── auth/
│   │       ├── repositories/
│   │       │   └── supabase_auth_repository.dart
│   │       └── providers/
│   │           ├── supabase_client_provider.dart
│   │           ├── auth_repository_provider.dart
│   │           └── auth_state_listenable_provider.dart
│   │
│   └── presentation/
│       ├── auth/
│       │   ├── screens/
│       │   │   ├── login_screen.dart
│       │   │   └── signup_screen.dart
│       │   └── viewmodels/
│       │       ├── login_viewmodel.dart
│       │       └── signup_viewmodel.dart
│       ├── counter/
│       │   ├── screens/
│       │   │   └── counter_screen.dart
│       │   └── viewmodels/
│       │       └── counter_viewmodel.dart
│       └── shared/
│           └── navigation/
│               └── navigation_state.dart
```

Примечание: `src/app.dart` и `src/router.dart` можно оставить в `src/` как композиционный слой (composition root) — это production-практика для небольшого приложения.

## 3. Этапы работ (строго по порядку, с контролем компиляции)

### Этап 1 — Ввести Domain-контракт без сущностей

**Задача:** создать интерфейс репозитория, который уже существует фактически (`AuthRepository`), но сейчас привязан к Supabase.

1. Создать файл:

    * `lib/src/domain/auth/repositories/auth_repository.dart`

2. Определить интерфейс (abstract class) с теми методами, которые реально используются в UI сейчас:

    * `signUp({required String email, required String password})`
    * `signIn({required String email, required String password})`
    * `signOut()`

> Не добавлять `getCurrentUser/getCurrentSession` до момента, пока они реально не используются. Сейчас в проекте авторизация проверяется через `SupabaseClient.auth.currentSession` в `AuthStateListenable`.

### Этап 2 — Перевести текущий Supabase-репозиторий в Infrastructure (как адаптер)

**Задача:** заменить текущий `lib/src/auth/auth_repository.dart` на инфраструктурную реализацию доменного интерфейса.

1. Создать файл:

    * `lib/src/infrastructure/auth/repositories/supabase_auth_repository.dart`

2. Перенести логику из текущего `lib/src/auth/auth_repository.dart` в новый файл, но:

    * класс назвать `SupabaseAuthRepository`;
    * он реализует `domain.auth.repositories.AuthRepository`;
    * принимает `SupabaseClient` в конструкторе.

3. Старый файл `lib/src/auth/auth_repository.dart` удалить/заменить (после миграции импортов).

### Этап 3 — Вынести провайдеры Supabase/Auth в Infrastructure

**Задача:** оставить внешние SDK и их провайдеры в одном месте.

Перенос/создание файлов:

1. `supabaseClientProvider`

    * из: `lib/src/auth/auth_providers.dart`
    * в: `lib/src/infrastructure/auth/providers/supabase_client_provider.dart`

2. `AuthStateListenable` и его провайдер

    * из: `lib/src/auth/auth_providers.dart`
    * в: `lib/src/infrastructure/auth/providers/auth_state_listenable_provider.dart`

3. Провайдер репозитория

    * заменить текущий `lib/src/auth/auth_repository_provider.dart` на:
    * `lib/src/infrastructure/auth/providers/auth_repository_provider.dart`
      который возвращает **доменный интерфейс** `AuthRepository`, но фактически создаёт `SupabaseAuthRepository`.

> `isAuthenticatedProvider` можно либо оставить рядом с `AuthStateListenable`, либо временно оставить в том же файле — главное, чтобы это была инфраструктура, а не presentation.

### Этап 4 — Ввести Application Use Cases (минимальный набор)

**Задача:** сделать ViewModels зависимыми от use cases, а use cases — от доменного `AuthRepository`.

Создать:

* `lib/src/application/auth/use_cases/sign_in_use_case.dart`
* `lib/src/application/auth/use_cases/sign_up_use_case.dart`
* `lib/src/application/auth/use_cases/sign_out_use_case.dart`

Каждый use case:

* принимает `AuthRepository` (domain interface) в конструкторе;
* имеет метод `execute(...)`;
* не содержит UI/Flutter зависимостей.

Также создать провайдеры use cases (в тех же файлах или рядом), завязанные на `authRepositoryProvider` из infrastructure.

### Этап 5 — Перенести Presentation и переключить ViewModels на Use Cases

**Задача:** реальная польза рефакторинга.

1. Перенести файлы:

* `lib/src/ui/login_screen.dart` → `lib/src/presentation/auth/screens/login_screen.dart`

* `lib/src/ui/signup_screen.dart` → `lib/src/presentation/auth/screens/signup_screen.dart`

* `lib/src/ui/counter_screen.dart` → `lib/src/presentation/counter/screens/counter_screen.dart`

* `lib/src/ui/viewmodels/login_viewmodel.dart` → `lib/src/presentation/auth/viewmodels/login_viewmodel.dart`

* `lib/src/ui/viewmodels/signup_viewmodel.dart` → `lib/src/presentation/auth/viewmodels/signup_viewmodel.dart`

* `lib/src/ui/viewmodels/counter_viewmodel.dart` → `lib/src/presentation/counter/viewmodels/counter_viewmodel.dart`

* `lib/src/ui/viewmodels/navigation_state.dart` → `lib/src/presentation/shared/navigation/navigation_state.dart`

2. Переподключить зависимости:

* `LoginViewModel` вместо `authRepositoryProvider` читает `signInUseCaseProvider`.
* `SignupViewModel` вместо `_authRepository` использует `signUpUseCaseProvider`.
* `CounterViewModel` вместо `authRepositoryProvider` использует `signOutUseCaseProvider`.

> Важно: поведение `AsyncValue`, `navigationAction` и `resetNavigation()` сохраняем без изменений по смыслу.

### Этап 6 — Адаптировать router.dart к новым путям и провайдерам

**Задача:** оставить существующую логику редиректов.

1. Обновить импорты экрана:

* `CounterScreen`, `LoginScreen`, `SignupScreen` из `presentation/...`

2. Обновить импорт listenable:

* `authStateListenableProvider` теперь из `infrastructure/auth/providers/auth_state_listenable_provider.dart`

> Логику редиректа не менять.

### Этап 7 — Обновить app.dart и main.dart только по импортам

* `lib/src/app.dart` остаётся, но импортирует `goRouterProvider` из `lib/src/router.dart` как раньше.
* `lib/main.dart` не меняется по смыслу (Supabase.initialize остаётся в `main`).

### Этап 8 — Консолидация импортов: только `package:counter_schmounter/...`

* Обновить все импорты на абсолютные `package:counter_schmounter/...`.
* После каждого этапа прогонять компиляцию.

### Этап 9 — Генерация кода Riverpod

* `dart run build_runner build --delete-conflicting-outputs`

> Делать после миграции файлов, чтобы не ломать пути `part '*.g.dart';`.

## 4. Что сознательно НЕ делаем на этом рефакторинге

1. Не вводим `User`, `Session`, `Counter` entities — пока нет доменных инвариантов/поведения.
2. Не добавляем `Email` / `Password` value objects, если не вводим строгую валидацию и единый формат ошибок.

    * Если валидация нужна — добавим отдельным этапом после стабилизации слоёв.
3. Не меняем поведение `AuthStateListenable` и редирект-логики GoRouter.
4. Не делаем «унификацию» ViewModels, не переписываем state-модели ради красоты.

## 5. Контрольные критерии готовности

Рефакторинг считается успешным, если:

* ViewModels не импортируют ничего из `infrastructure/*` напрямую, кроме провайдеров use cases.
* Supabase используется только внутри `infrastructure/auth/*`.
* Domain содержит только интерфейс `AuthRepository` (и опционально value objects).
* Компиляция и `build_runner` проходят без ручных фиксов.
* Поведение приложения не меняется (login/signup/counter/redirect работают как раньше).
