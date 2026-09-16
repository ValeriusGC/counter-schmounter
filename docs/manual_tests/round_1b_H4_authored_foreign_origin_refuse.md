# Ручной тест H4 — авторский склад с чужим origin, приложение отказывает

**Дата создания:** 2026-09-16 12:08:13 +0300  
**Последнее обновление:** 2026-09-16 12:20:42 +0300  
**Версия:** 2  
**Вид документа:** инструкция

Круг **1b**, сценарий **H4** из [плана круга 1b](https://github.com/flutter-senior-prep/plan_triad/blob/main/docs/ROUND_1B_TRIAD_PLAN.md) (§5, таблица H4). Проверяет **затвор круга 1b**: склад заранее подписан **чужим** происхождением в `config.yaml` (авторский режим), приложение со своей константой `kUlsyncOrigin` **отказывается до записи конвертов** (`OriginMismatchException`, HTTP `409` на hello).

Документ **полностью самодостаточен**: не требует прогона H1–H3, TEMP или других сценариев H5–H7.

---

## 1. Что проверяем

| Критерий | Успех H4 | Провал H4 |
|---|---|---|
| Авторский склад на порту **8083** с `K_SERVER_ORIGIN` ≠ `K_ULSYNC_ORIGIN` | JWT валиден (whoami `200`), но sync **не** идёт | whoami не `200` — проблема auth, не origin |
| Приложение с `K_ULSYNC_ORIGIN` | В логе `flutter run`: **`OriginMismatchException`** | Нет исключения; обмен как на открытом складе |
| База после попытки | `SELECT COUNT(*) FROM envelopes` = **0** | В `envelopes` появились строки |
| UI | **«Нет связи»** — норма для H4 | «На связи» и плюс уехал на сервер |

### 1.1. Что H4 доказывает (и чем отличается от H3)

| | H3 (открытый склад) | H4 (авторский склад) |
|---|---|---|
| `origin:` в yaml | **Нет** | **Есть**, чужая строка `K_SERVER_ORIGIN` |
| Первый hello приложения | Приручает склад, заливает данные | **Отказ** `409 origin_mismatch` |
| `envelopes` после плюса | **≥ 1** (успех H3) | **0** (успех H4) |
| Защита | Нет — цена открытого режима | **Да** — замок на пустой ящик |

**Не проверяем в H4:** curl без приложения (H5), старый сервер без hello (H6), конфликт yaml vs база (H7).

---

## 2. Словарь переменных и констант

Подставляйте **свои** значения в `YOUR_*`. `config_h4.yaml` **не коммитить**.

### 2.1. Пути на диске (фиксированные для H4)

| Символ | Значение | Назначение |
|---|---|---|
| `APP_ROOT` | `/Users/vvk/AndroidStudioProjects/r/counter_schmounter` | Корень Flutter-приложения |
| `SERVER_ROOT` | `/Users/vvk/AndroidStudioProjects/r/ulsync-server` | Корень Go-сервера ulsync |
| `DB_FILE` | `./data/ulsync_h4.db` | SQLite **только** для H4; удаляется перед прогоном |
| `CONFIG_FILE` | `./config_h4.yaml` | Конфиг сервера для H4; создаётся вручную |

### 2.2. Порты и URL

| Имя | Значение | Назначение |
|---|---|---|
| `SYNC_PORT` | `8083` | HTTP API sync |
| `ADMIN_PORT` | `8184` | Админка: `http://127.0.0.1:8184/admin` |
| `ULSYNC_BASE_URL` | `http://10.0.2.2:8083` | **Обязательно** в `flutter run` — иначе default `:8080` |

Полная строка для приложения:

```text
ULSYNC_BASE_URL=http://10.0.2.2:8083
```

Внутри Android Emulator `10.0.2.2` — loopback Mac-хозяина. Порт **8083** — процесс `ulsync-server` из `config_h4.yaml`.

### 2.3. Две строки происхождения — сердце H4

| Имя | Значение | Где задаётся |
|---|---|---|
| `K_ULSYNC_ORIGIN` | `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f` | Константа приложения `kUlsyncOrigin` в `ulsync_base_url.dart`; заголовок `Ulsync-Origin` с эмулятора |
| `K_SERVER_ORIGIN` | `com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee` | Ключ `origin:` в `config_h4.yaml`; при старте сервер пишет это в `server_meta` |

**Условие H4:** `K_ULSYNC_ORIGIN` ≠ `K_SERVER_ORIGIN`. Обе строки — валидный формат SPEC (reverse-DNS + UUID). Третий выдуманный UUID в этом круге **не** использовать — только эти два литерала.

При hello сервер сравнивает заголовок приложения с `K_SERVER_ORIGIN` → **409** → библиотека бросает `OriginMismatchException` **до** push/pull.

### 2.4. Секреты Supabase

| Переменная | Что подставить | Где используется |
|---|---|---|
| `SU` | `https://YOUR_PROJECT.supabase.co` | `--dart-define=SU=...`; `jwks_url` в yaml |
| `SAK` | `YOUR_ANON_KEY` | `--dart-define=SAK=...`; `apikey` в curl |
| `EMAIL` | Email тестового пользователя | curl и вход в приложении |
| `PASSWORD` | Пароль пользователя | То же |
| `ACCESS_TOKEN` | JWT из curl (шаг C) | whoami на порту **8083**; админка |

### 2.4.1. Два разных токена

| Токен | Откуда | Кто использует |
|---|---|---|
| `ACCESS_TOKEN` (curl) | Свежий запрос к Supabase в шаге C | whoami с Mac |
| Сессия приложения | Хранилище на эмуляторе | ulsync с эмулятора |

whoami `200` означает: **авторизация** на сервере работает. Отказ H4 — **только** по origin, не по JWT.

Перед прогоном — шаг **E0** (`pm clear`), если гоняли H1–H3.

### 2.5. Эмулятор

| Идентификатор | Роль |
|---|---|
| `emulator-5554` | Единственное устройство в H4 |

### 2.6. Ветки git

| Репозиторий | Ветка |
|---|---|
| `counter_schmounter` | `spike/32-26-origin` (или ветка шага 26) |
| `ulsync-server` | `main` после шагов 24+ |

### 2.7. Мониторинг

Админка `http://127.0.0.1:8184/admin`:

| Поле | Успех H4 |
|---|---|
| **Store origin** | `K_SERVER_ORIGIN` (чужая строка из yaml), **не** `K_ULSYNC_ORIGIN` |
| **Envelopes** | **0** после входа и плюса |
| **Last error** | Может быть `origin_mismatch` / `409` — это **ожидаемо** |

Терминал сервера (окно 1) может молчать — смотрите админку и лог `flutter run`.

---

## 3. Предусловия (проверить до начала)

### 3.1. Инструменты в PATH

**Зачем:** без утилит шаги H4 не выполнить.

```bash
which flutter go curl sqlite3 adb
```

**Успех:** пять строк с путями (`/opt/homebrew/bin/flutter` и т.д.).

**Ошибка:** `... not found` — установить / добавить в `PATH`.

### 3.2. Эмулятор `emulator-5554` запущен

```bash
flutter devices | grep emulator-5554
```

**Успех:** одна строка с `emulator-5554`.

**Ошибка:** пусто — запустить AVD в Android Studio.

### 3.3. Порт 8083 свободен

```bash
lsof -nP -iTCP:8083 -sTCP:LISTEN
```

**Успех:** **пустой** вывод.

**Ошибка:** процесс слушает 8083 — `Ctrl+C` в том терминале или `kill <pid>`.

Серверы H1/H2/H3 на других портах (8080, 8082) могут работать параллельно — H4 использует **только 8083**.

---

## 4. Раскладка окон

| Окно | Назначение | Процесс висит |
|---|---|---|
| **1** | `./ulsync-server -config ./config_h4.yaml` | Да, до шага F |
| **2** | Секреты, yaml, curl, sqlite3 | Нет |
| **3** | `flutter run` на `emulator-5554` | Да, до шага F |
| **Браузер** | `http://127.0.0.1:8184/admin` | — |

`export` из окна 2 **не** переносится в окно 3.

---

## 5. Пошаговое выполнение

### Шаг A — Окно 2: секреты и конфиг с чужим `origin:`

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
export EMAIL='YOUR_EMAIL'
export PASSWORD='YOUR_PASSWORD'
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
mkdir -p ./data
cat > ./config_h4.yaml <<EOF
server:
  bind: "0.0.0.0:8083"
  read_header_timeout: "5s"
  idle_timeout: "120s"
  max_body_bytes: 1048576

storage:
  driver: "sqlite"
  path: "./data/ulsync_h4.db"

origin: "com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"

auth:
  jwks_url: "${SU}/auth/v1/.well-known/jwks.json"
  jwks_file: ""
  jwks_cache_ttl: "10m"
  allowed_algs: ["ES256", "RS256"]
  audience: []
  issuer: ""
  dev_hs256_secret: ""

sync:
  max_envelopes_per_push: 1
  pull_limit_default: 100
  pull_limit_max: 500
  live_poll_timeout: "55s"
  live_heartbeat: "15s"

admin:
  bind: "127.0.0.1:8184"
  token: ""
EOF
```

**Разбор ключевых полей:**

| Поле | Значение | Зачем |
|---|---|---|
| `server.bind` | `0.0.0.0:8083` | Sync на порту H4 |
| `origin:` | `K_SERVER_ORIGIN` | **Авторский** склад — чужой контур |
| `storage.path` | `./data/ulsync_h4.db` | Отдельный файл |
| `admin.bind` | `127.0.0.1:8184` | Админка на Mac |

**Успех:** файл существует:

```bash
test -f ./config_h4.yaml && echo "config_h4.yaml OK"
```

---

### Шаг B — Окно 1: сервер с чистой базой

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
git checkout main && git pull
go build -o ulsync-server ./cmd/ulsync-server
rm -f ./data/ulsync_h4.db ./data/ulsync_h4.db-wal ./data/ulsync_h4.db-shm
./ulsync-server -config ./config_h4.yaml
```

**Успех:** `server listening` на `:8083`; процесс **не** падает при старте (конфликт origin yaml/база — это H7, не H4).

**Ошибка при старте** с текстом про конфликт origin — база не чистая или битый yaml; повторите `rm` файлов `ulsync_h4.db*`.

---

### Шаг C — Окно 2: `ACCESS_TOKEN` и whoami на порту 8083

Переменные `SU`, `SAK`, `EMAIL`, `PASSWORD` — в **этом** окне.

**Блок 1 — получить токен:**

```bash
export ACCESS_TOKEN="$(
  curl -sS "$SU/auth/v1/token?grant_type=password" \
    -H "apikey: $SAK" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" \
  | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p'
)"
case "$ACCESS_TOKEN" in
  eyJ*) echo "ACCESS_TOKEN получен, длина ${#ACCESS_TOKEN}" ;;
  *) echo "FAIL: access_token нет. Проверь SU, SAK, EMAIL, PASSWORD."; return 1 ;;
esac
```

**Блок 2 — проверить срок (нужен `python3`):**

```bash
python3 - <<'PY'
import base64, json, os, sys, time
t = os.environ.get("ACCESS_TOKEN", "")
if not t.startswith("eyJ"):
    sys.exit("FAIL: ACCESS_TOKEN не JWT")
payload = t.split(".")[1]
payload += "=" * ((4 - len(payload) % 4) % 4)
claims = json.loads(base64.urlsafe_b64decode(payload))
exp = int(claims.get("exp", 0))
now = int(time.time())
print(f"sub={claims.get('sub')} ttl_sec={exp - now}")
if exp <= now:
    sys.exit("FAIL: ACCESS_TOKEN просрочен")
print("OK: ACCESS_TOKEN действителен")
PY
```

**Блок 3 — whoami (выполнить отдельно, одной командой — меньше шансов сломать вставку):**

```bash
curl -sS -w '\nHTTP:%{http_code}\n' -H "Authorization: Bearer $ACCESS_TOKEN" http://127.0.0.1:8083/v1/whoami
```

| Блок | Успех | Ошибка |
|---|---|---|
| 1 | `ACCESS_TOKEN получен, длина ...` | `FAIL: access_token нет` |
| 2 | `OK: ACCESS_TOKEN действителен` | `FAIL: ACCESS_TOKEN просрочен` |
| 3 | `HTTP:200`, в теле `user_id` | `curl: (2) no URL` — URL не попал в команду; скопируйте блок 3 целиком |
| 3 | | `connection refused` — сервер H4 не на 8083 |
| 3 | | `401` — проблема JWT / `jwks_url`, не origin |

**Стоп-условие:** whoami должен быть `200` **до** окна 3. Если auth красный — чините auth; H4 про origin не валиден.

---

### Шаг D — Браузер: админка (рекомендуется)

1. `http://127.0.0.1:8184/admin`
2. `echo "$ACCESS_TOKEN"` → Check token → **valid**
3. **Store origin** уже должен показывать `K_SERVER_ORIGIN` (авторский pin при старте)

---

### Шаг E0 — Сброс сессии (рекомендуется)

```bash
adb -s emulator-5554 shell pm clear com.gdetotuta.vfx.counter_schmounter
```

**Успех:** `Success`. После clear — обязательный новый вход в шаге E.

---

### Шаг E — Окно 3: приложение на порт 8083

**Новый** терминал:

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
cd /Users/vvk/AndroidStudioProjects/r/counter_schmounter
flutter run -d emulator-5554 \
  --dart-define=SU="$SU" \
  --dart-define=SAK="$SAK" \
  --dart-define=ULSYNC_BASE_URL=http://10.0.2.2:8083
```

**На эмуляторе:**

1. Войти `EMAIL` / `PASSWORD`.
2. Дождаться попытки обмена (несколько секунд).
3. Иконка **«Нет связи»** — **норма** для успешного H4.
4. Нажать **плюс** один раз: локальный счётчик **может** вырасти; на сервер **не** должен.

**Контроль в окне 3 (`flutter run`):**

Ищите строку с **`OriginMismatchException`** (полное имя класса из пакета `ulsync`). Может появиться после входа или после плюса.

Пример ожидаемого фрагмента (текст рядом может отличаться):

```text
OriginMismatchException
```

**Не путать с успехом H3:** отсутствие исключения при «Нет связи» — **провал** H4, если `envelopes` > 0.

**Контроль в админке** (пока сервер крутится):

| Поле | Ожидание H4 |
|---|---|
| Store origin | `com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee` |
| Envelopes | **0** |

---

### Шаг F — Окно 1: остановка сервера

`Ctrl+C` в окне 1.

---

### Шаг G — Окно 2: финальная проверка базы

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
sqlite3 ./data/ulsync_h4.db "SELECT v FROM server_meta WHERE k='origin';"
sqlite3 ./data/ulsync_h4.db "SELECT COUNT(*) FROM envelopes;"
```

| Запрос | Успех H4 |
|---|---|
| `origin` | `com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee` |
| `COUNT(*)` | `0` |

---

## 6. Итоговые критерии

### Успех H4

- [ ] whoami (шаг C, блок 3): `HTTP:200` на порту **8083**.
- [ ] Приложение с `ULSYNC_BASE_URL=http://10.0.2.2:8083`.
- [ ] В логе `flutter run`: **`OriginMismatchException`**.
- [ ] Админка: **Envelopes** = **0**; **Store origin** = `K_SERVER_ORIGIN`.
- [ ] sqlite3 (шаг G): `COUNT(*) = 0`; origin = `K_SERVER_ORIGIN`.
- [ ] Локальный плюс **не** увеличил `envelopes` на сервере.

### Провал H4

- В `envelopes` есть строки после входа/плюса.
- Нет `OriginMismatchException`, обмен идёт, «На связи».
- `server_meta.origin` стал `K_ULSYNC_ORIGIN` (приручили чужой склад своим именем).

---

## 7. Частые сбои

| Симптом | Что проверить |
|---|---|
| whoami `200`, но нет `OriginMismatchException` | Приложение на **8080** / **8082**, не 8083 — проверить `ULSYNC_BASE_URL` |
| `curl: (2) no URL specified` | whoami скопирован без URL — блок 3 шага C целиком |
| «На связи» и envelopes ≥ 1 | Провал H4 — склад не авторский или origin в yaml не тот |
| `token rejected` в логе сервера | Просроченная сессия; E0 + новый вход (отдельно от origin) |
| Плюс локально растёт, envelopes 0 | **Успех** H4 — локальный журнал работает, сервер отказал |
| Путают с H3 | H3: нет `origin:` в yaml, envelopes ≥ 1; H4: чужой `origin:`, envelopes 0 |
| Сервер не стартует | H7-сценарий (конфликт yaml/база); для H4 база должна быть **пустая** после `rm` |

---

## 8. Восстановление после сбоя

1. Окно 3: `q` — остановить `flutter run`.
2. Окно 1: `Ctrl+C`.
3. E0 (`pm clear`).
4. Шаг B заново (`rm` базы + сервер).
5. Шаг C — три блока, whoami `200` на **8083**.
6. Шаг E — `flutter run` с `ULSYNC_BASE_URL=http://10.0.2.2:8083`, вход, плюс, искать `OriginMismatchException`.
7. Шаг G — `COUNT(*) = 0`.

---

## 9. Уборка

```bash
# Окно 3: Ctrl+C
rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/config_h4.yaml
# rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/data/ulsync_h4.db*
```

Следующий сценарий: **H5** — `docs/manual_tests/round_1b_H5_curl_foreign_origin_refuse.md`.

---

## 10. Связанные артефакты

| Файл | Содержание |
|---|---|
| `lib/src/infrastructure/sync/ulsync_base_url.dart` | `K_ULSYNC_ORIGIN` |
| `lib/src/infrastructure/sync/sync_failure_logging.dart` | Логирование `OriginMismatchException` |
| План 1b §5, H4 | «Затвор круга 1b» |
| `docs/manual_tests/round_1b_H3_open_stock_accepts_fill.md` | Противоположный сценарий (открытый склад) |
