# Рефакторинг проекта по Domain-Driven Design

## Текущая структура

Проект имеет плоскую структуру с минимальным разделением ответственности:

- `lib/src/auth/` - смешивает репозитории, провайдеры и инфраструктуру
- `lib/src/ui/` - содержит ViewModels вместе с UI
- Отсутствует явное разделение на Domain, Application, Infrastructure, Presentation

## Классическая DDD структура

### Слои архитектуры

```
lib/
├── domain/              # Доменный слой (бизнес-логика, не зависит от фреймворков)
│   ├── auth/
│   │   ├── entities/           # Доменные сущности (User, Session)
│   │   ├── repositories/       # Интерфейсы репозиториев (абстракции)
│   │   └── value_objects/      # Value Objects (Email, Password)
│   └── counter/
│       └── entities/           # Counter entity
│
├── application/         # Слой приложения (use cases, orchestration)
│   ├── auth/
│   │   └── use_cases/          # SignInUseCase, SignUpUseCase, SignOutUseCase
│   └── counter/
│       └── use_cases/          # IncrementCounterUseCase
│
├── infrastructure/     # Инфраструктурный слой (реализации, внешние зависимости)
│   ├── auth/
│   │   ├── repositories/       # SupabaseAuthRepository (реализация интерфейса)
│   │   └── providers/          # SupabaseClientProvider, AuthStateProvider
│   └── routing/
│       └── router.dart          # GoRouter конфигурация
│
└── presentation/       # Слой представления (UI, ViewModels)
    ├── auth/
    │   ├── screens/            # LoginScreen, SignupScreen
    │   └── viewmodels/         # LoginViewModel, SignupViewModel
    ├── counter/
    │   ├── screens/            # CounterScreen
    │   └── viewmodels/         # CounterViewModel
    └── shared/
        └── navigation/         # NavigationState, navigation helpers
```

### Принципы разделения

1. **Domain** - чистый бизнес-логический слой:
   - Не зависит от Flutter, Riverpod, Supabase
   - Содержит только бизнес-правила и интерфейсы
   - Entities, Value Objects, Repository интерфейсы

2. **Application** - оркестрация бизнес-логики:
   - Использует Domain интерфейсы
   - Содержит Use Cases (команды и запросы)
   - Не зависит от UI фреймворков

3. **Infrastructure** - реализация технических деталей:
   - Реализует Domain интерфейсы (репозитории)
   - Работает с внешними библиотеками (Supabase, GoRouter)
   - Провайдеры для внешних зависимостей

4. **Presentation** - UI и ViewModels:
   - Зависит от Application (Use Cases)
   - Использует Infrastructure провайдеры
   - Только отображение и обработка пользовательского ввода

## План рефакторинга

### Этап 1: Создание Domain слоя

1. **Domain Entities**:
   - `package:counter_schmounter/domain/auth/entities/user.dart` - User entity
   - `package:counter_schmounter/domain/auth/entities/session.dart` - Session entity
   - `package:counter_schmounter/domain/counter/entities/counter.dart` - Counter entity

2. **Domain Value Objects**:
   - `package:counter_schmounter/domain/auth/value_objects/email.dart` - Email value object с валидацией
   - `package:counter_schmounter/domain/auth/value_objects/password.dart` - Password value object

3. **Domain Repository Interfaces**:
   - `package:counter_schmounter/domain/auth/repositories/auth_repository.dart` - интерфейс (abstract class)
   - Определяет методы: `signUp`, `signIn`, `signOut`, `getCurrentUser`, `getCurrentSession`

### Этап 2: Создание Application слоя

1. **Use Cases**:
   - `package:counter_schmounter/application/auth/use_cases/sign_in_use_case.dart`
   - `package:counter_schmounter/application/auth/use_cases/sign_up_use_case.dart`
   - `package:counter_schmounter/application/auth/use_cases/sign_out_use_case.dart`
   - `package:counter_schmounter/application/counter/use_cases/increment_counter_use_case.dart`

2. **Use Case Providers** (Riverpod):
   - `package:counter_schmounter/application/auth/use_cases/sign_in_use_case_provider.dart`
   - Аналогично для остальных use cases

### Этап 3: Рефакторинг Infrastructure слоя

1. **Repository Implementation**:
   - Переместить `lib/src/auth/auth_repository.dart` → `package:counter_schmounter/infrastructure/auth/repositories/supabase_auth_repository.dart`
   - Реализовать интерфейс из Domain
   - Использовать Domain entities/value objects

2. **Providers**:
   - `package:counter_schmounter/infrastructure/auth/providers/supabase_client_provider.dart`
   - `package:counter_schmounter/infrastructure/auth/providers/auth_repository_provider.dart` - возвращает реализацию интерфейса
   - `package:counter_schmounter/infrastructure/auth/providers/auth_state_provider.dart`

3. **Routing**:
   - `package:counter_schmounter/infrastructure/routing/router.dart` - GoRouter конфигурация

### Этап 4: Рефакторинг Presentation слоя

1. **ViewModels**:
   - `package:counter_schmounter/presentation/auth/viewmodels/login_viewmodel.dart` - использует SignInUseCase
   - `package:counter_schmounter/presentation/auth/viewmodels/signup_viewmodel.dart` - использует SignUpUseCase
   - `package:counter_schmounter/presentation/counter/viewmodels/counter_viewmodel.dart` - использует IncrementCounterUseCase

2. **Screens**:
   - `package:counter_schmounter/presentation/auth/screens/login_screen.dart`
   - `package:counter_schmounter/presentation/auth/screens/signup_screen.dart`
   - `package:counter_schmounter/presentation/counter/screens/counter_screen.dart`

3. **Shared**:
   - `package:counter_schmounter/presentation/shared/navigation/navigation_state.dart`

### Этап 5: Обновление корневых файлов

1. **main.dart**:
   - Импорты через `package:counter_schmounter/...`
   - Инициализация остается в main

2. **app.dart**:
   - `package:counter_schmounter/presentation/app.dart`
   - Импорты через абсолютные пути

## Критическое требование: Абсолютные пути в импортах

**ВСЕ импорты должны использовать абсолютные пути через `package:` префикс:**

```dart
// ✅ Правильно
import 'package:counter_schmounter/domain/auth/repositories/auth_repository.dart';
import 'package:counter_schmounter/application/auth/use_cases/sign_in_use_case.dart';
import 'package:counter_schmounter/infrastructure/auth/repositories/supabase_auth_repository.dart';
import 'package:counter_schmounter/presentation/auth/viewmodels/login_viewmodel.dart';

// ❌ Неправильно (относительные пути)
import '../../auth/auth_repository.dart';
import '../viewmodels/login_viewmodel.dart';
```

### Преимущества абсолютных путей:
- Ясность зависимостей между слоями
- Легче рефакторить (перемещение файлов не ломает импорты)
- Понятная структура проекта
- Соответствие best practices Dart/Flutter

## Миграция ViewModels

ViewModels будут использовать Use Cases вместо прямого обращения к репозиториям:

```dart
// Было (прямой доступ к репозиторию)
final authRepository = ref.read(authRepositoryProvider);
await authRepository.signIn(...);

// Станет (через Use Case)
final signInUseCase = ref.read(signInUseCaseProvider);
await signInUseCase.execute(email: email, password: password);
```

## Порядок выполнения

1. Создать структуру папок Domain → Application → Infrastructure → Presentation
2. Создать Domain слой (entities, value objects, repository interfaces)
3. Создать Application слой (use cases)
4. Рефакторить Infrastructure (реализации репозиториев)
5. Рефакторить Presentation (ViewModels используют Use Cases)
6. Обновить все импорты на абсолютные пути
7. Запустить `flutter pub get` и `dart run build_runner build`
8. Проверить работоспособность

## Файлы для изменения

- Все существующие файлы будут перемещены в новую структуру
- Все импорты будут обновлены на абсолютные пути


