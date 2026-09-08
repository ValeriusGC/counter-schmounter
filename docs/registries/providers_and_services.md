# Реестр: провайдеры и сервисы

**Дата создания:** 2026-09-08 15:08:08 +0300  
**Последнее обновление:** 2026-09-08 15:08:08 +0300  
**Версия:** 1

Перед новым переиспользуемым провайдером или сервисом — проверить таблицу и grep по `lib/`.

| Имя | Путь | Назначение | Когда использовать |
|-----|------|------------|-------------------|
| `supabaseClientProvider` | `lib/src/infrastructure/auth/providers/supabase_client_provider.dart` | Клиент Supabase после инициализации | Инфраструктура auth, не из presentation напрямую |
| `authRepositoryProvider` | `lib/src/infrastructure/auth/providers/auth_repository_provider.dart` | Реализация `AuthRepository` | Use cases входа/регистрации |
| `signInUseCaseProvider` и др. | `lib/src/infrastructure/auth/providers/auth_use_case_providers.dart` | Use cases auth | ViewModels экранов входа |
| `supabaseUserIdProvider` | `lib/src/infrastructure/auth/providers/supabase_user_id_provider.dart` | Stream id текущего пользователя | Scope данных, sync, realtime gate |
| `authStateListenableProvider` | `lib/src/infrastructure/auth/providers/auth_state_listenable_provider.dart` | Listenable для go_router refresh | Роутер при смене сессии |
| `clientIdentityServiceProvider` | `lib/src/infrastructure/shared/providers/client_identity_service_provider.dart` | Стабильный `clientId` установки | Операции счётчика, будущий ulsync `sourceId` |
| `localOpLogRepositoryProvider` | `lib/src/infrastructure/counter/providers/local_op_log_repository_provider.dart` | Локальный журнал операций | Инкремент, sync, адаптер ulsync |
| `remoteOpLogRepositoryProvider` | `lib/src/infrastructure/counter/providers/remote_op_log_repository_provider.dart` | Pull из Supabase (удаляется в шаге 15) | Только до миграции на ulsync |
| `remoteOpLogExportRepositoryProvider` | `lib/src/infrastructure/counter/providers/remote_op_log_export_repository_provider.dart` | Push в Supabase (удаляется в шаге 15) | Только до миграции на ulsync |
| `counterStateProvider` | `lib/src/infrastructure/counter/providers/counter_state_provider.dart` | Агрегированное значение счётчика для UI | Экран счётчика |
| `incrementCounterUseCaseProvider` | `lib/src/infrastructure/counter/providers/increment_counter_use_case_provider.dart` | Use case инкремента | ViewModel счётчика |
| `syncCounterUseCaseProvider` | `lib/src/application/counter/providers/sync_counter_use_case_provider.dart` | Обмен с удалённым журналом | NeedSync, initial sync |
| `exportLocalOperationsUseCaseProvider` | `lib/src/application/counter/providers/export_local_operations_use_case_provider.dart` | Export в Supabase (удаляется в шаге 15) | Только до миграции |
| `syncStateRepositoryProvider` | `lib/src/infrastructure/sync/providers/sync_state_repository_provider.dart` | Маркеры lastSynced/lastExported | До шага 15 — счётчик; далее без вызовов из счётчика |
| `needSyncControllerProvider` | `lib/src/infrastructure/sync/controllers/need_sync_controller.dart` | Debounce sync после инкремента | После плюса на экране |
| `counterInitialSyncControllerProvider` | `lib/src/infrastructure/sync/controllers/counter_initial_sync_controller.dart` | Initial sync при старте/логине | Холодный старт с сессией |
| `realtimeGateControllerProvider` | `lib/src/infrastructure/realtime/controllers/realtime_gate_controller.dart` | Включает Realtime после initial sync | Шаг 16 не трогать в 15 |
| `counterRealtimeEventsServiceProvider` | `lib/src/infrastructure/realtime/services/counter_realtime_events_service.dart` | Подписка Realtime на таблицу | Шаг 16 |
| `infrastructureInitProvider` | `lib/src/infrastructure/bootstrap/infrastructure_init_provider.dart` | Инициализация SharedPreferences и др. | `main.dart`, bootstrap |
| `loginViewModelProvider` | `lib/src/presentation/auth/viewmodels/login_viewmodel.dart` | Состояние экрана входа | Login screen |
| `signupViewModelProvider` | `lib/src/presentation/auth/viewmodels/signup_viewmodel.dart` | Состояние регистрации | Signup screen |
| `counterViewModelProvider` | `lib/src/presentation/counter/viewmodels/counter_viewmodel.dart` | Состояние экрана счётчика | Counter screen |
| `routerProvider` | `lib/src/router.dart` | Конфигурация go_router | `MaterialApp.router` |
