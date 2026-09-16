# Ручной тест H3 — пустой открытый склад принимает заливку с телефона

**Дата создания:** 2026-09-16 11:55:00 +0300  
**Последнее обновление:** 2026-09-16 11:55:00 +0300  
**Версия:** 1  
**Вид документа:** инструкция

Круг **1b**, сценарий **H3** из [плана круга 1b](https://github.com/flutter-senior-prep/plan_triad/blob/main/docs/ROUND_1B_TRIAD_PLAN.md) (§5, таблица H3). Проверяет **цену открытого склада**: новый пустой процесс сервера (другой порт, другой файл базы, **без** `origin:` в yaml) при первом hello **приручается** константой приложения и **принимает конверты** с устройства (заливка локальных данных).

Документ **полностью самодостаточен**: не требует прогона H1, H2, TEMP или других сценариев H4–H7.

---

## 1. Что проверяем

| Критерий | Успех H3 | Провал H3 |
|---|---|---|
| Новый пустой открытый склад на порту **8082** | Первый hello записывает `K_ULSYNC_ORIGIN` в `server_meta` | `origin` пустой или другая строка |
| То же приложение, тот же аккаунт | После входа и плюса в таблице `envelopes` **≥ 1** | `COUNT(*) = 0` после входа и плюса |
| Отказ по origin | Обмен идёт, **нет** `OriginMismatchException` | HTTP `409` / `origin_mismatch`, `OriginMismatchException` в логе приложения |

### 1.1. Что H3 доказывает (и что — нет)

**Доказывает:** если пользователь (или ошибка конфигурации) указал приложению **другой пустой** открытый склад, первое корректное hello **привяжет** этот том к происхождению приложения, и `selfCheck` / push **зальют** локальные данные на сервер. Это **штатное** поведение открытого режима, не дефект.

**Не доказывает:** защиту от чужого склада — это **H4** (авторский `origin:` в yaml). H3 намеренно показывает «дыру» открытого склада, чтобы зафиксировать её в приёмке.

**Не проверяем в H3:** второй эмулятор (H1), смену URL на том же складе (H2), отказ чужому origin (H4).

---

## 2. Словарь переменных и констант

Подставляйте **свои** значения в `YOUR_*`. `config_h3.yaml` **не коммитить**.

### 2.1. Пути на диске (фиксированные для H3)

| Символ | Значение | Назначение |
|---|---|---|
| `APP_ROOT` | `/Users/vvk/AndroidStudioProjects/r/counter_schmounter` | Корень Flutter-приложения |
| `SERVER_ROOT` | `/Users/vvk/AndroidStudioProjects/r/ulsync-server` | Корень Go-сервера ulsync |
| `DB_FILE` | `./data/ulsync_h3.db` | SQLite **только** для H3; удаляется перед прогоном |
| `CONFIG_FILE` | `./config_h3.yaml` | Конфиг сервера для H3; создаётся вручную |

### 2.2. Порты и URL

| Имя | Значение | Назначение |
|---|---|---|
| `SYNC_PORT` | `8082` | HTTP API sync; **не** 8080 (H1/H2), чтобы не пересечься с другими прогонами |
| `ADMIN_PORT` | `8183` | Админка: `http://127.0.0.1:8183/admin` |
| `ULSYNC_BASE_URL` | `http://10.0.2.2:8082` | **Обязательно** передать в `flutter run` — иначе приложение пойдёт на порт **8080** по умолчанию |

**Почему `10.0.2.2:8082`.** Внутри Android Emulator адрес `10.0.2.2` — это loopback **Mac-хозяина**. Порт **8082** — где слушает сервер H3 (`bind: "0.0.0.0:8082"`). Полная строка:

```text
ULSYNC_BASE_URL=http://10.0.2.2:8082
```

Без `--dart-define=ULSYNC_BASE_URL=...` приложение для Android возьмёт `http://10.0.2.2:8080` из `ulsync_base_url.dart` — это **чужой** склад (H1/H2), не H3.

### 2.3. Происхождение склада

| Имя | Значение |
|---|---|
| `K_ULSYNC_ORIGIN` | `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f` |

Константа `kUlsyncOrigin` в `lib/src/infrastructure/sync/ulsync_base_url.dart`. Менять UUID между прогонами круга 1b нельзя.

В `config_h3.yaml` **нет** ключа `origin:` — склад **открытый**. Происхождение появится в базе только после первого hello с заголовком `Ulsync-Origin: K_ULSYNC_ORIGIN`.

### 2.4. Секреты Supabase

| Переменная | Что подставить | Где используется |
|---|---|---|
| `SU` | `https://YOUR_PROJECT.supabase.co` | `--dart-define=SU=...`; `jwks_url` в yaml |
| `SAK` | `YOUR_ANON_KEY` | `--dart-define=SAK=...`; заголовок `apikey` в curl |
| `EMAIL` | Email тестового пользователя | curl и вход в приложении |
| `PASSWORD` | Пароль пользователя | То же |
| `ACCESS_TOKEN` | JWT из curl (шаг C) | whoami на порту **8082**; админка |

### 2.4.1. Два разных токена

| Токен | Откуда | Кто использует |
|---|---|---|
| `ACCESS_TOKEN` (curl) | Свежий запрос к Supabase в шаге C | whoami с Mac, Check token в админке |
| Сессия приложения | Хранилище на эмуляторе после прошлых `flutter run` | ulsync с эмулятора |

whoami `200` **не доказывает**, что приложение шлёт валидный JWT. Просроченная сессия → `token rejected` в логе сервера; локальный плюс без push; `envelopes` остаётся `0`.

Перед прогоном — шаг **E0** (`pm clear`), особенно если только что гоняли H1/H2.

### 2.5. Эмулятор

| Идентификатор | Роль |
|---|---|
| `emulator-5554` | Единственное устройство в H3 |

Проверка id: `flutter devices` — в колонке id должна быть строка `emulator-5554` (или подставьте свой id во все команды `-d ...`).

### 2.6. Ветки git

| Репозиторий | Ветка |
|---|---|
| `counter_schmounter` | `spike/32-26-origin` (или ветка шага 26 от `spike/ulsync-test`) |
| `ulsync-server` | `main` после шагов 24+ |

### 2.7. Мониторинг: терминал сервера vs админка

`ulsync-server` **не пишет** каждый успешный запрос в stdout.

Админка `http://127.0.0.1:8183/admin`:

| Поле | На что смотреть в H3 |
|---|---|
| **Store origin** | После обмена — `K_ULSYNC_ORIGIN` |
| **Envelopes** | После плюса — **≥ 1** (заливка — **успех** H3) |
| **Total / 4xx** | Накопительно; всплеск 401 до `pm clear` — не провал, если после входа обмен идёт |
| **Last error** | Не должно быть `origin_mismatch` / `409` |

### 2.8. Отличие H3 от H1 (частая путаница)

| | H1 | H3 |
|---|---|---|
| Порт | `8080` | `8082` |
| База | `ulsync_h1.db` | `ulsync_h3.db` |
| `ULSYNC_BASE_URL` | Не нужен (default `10.0.2.2:8080`) | **Обязателен** `http://10.0.2.2:8082` |
| Эмуляторы | Два (5554 + 5556), sync между ними | Один (5554) |
| Смысл | Зелёный путь hello + live | Пустой **другой** склад принимает заливку |

---

## 3. Предусловия (проверить до начала)

Выполните на Mac. Переходите к шагу A только когда все подпункты зелёные.

### 3.1. Инструменты в PATH

**Зачем:** без утилит шаги H3 не выполнить.

```bash
which flutter go curl sqlite3 adb
```

| Утилита | Назначение в H3 |
|---|---|
| `flutter` | `flutter run` |
| `go` | Сборка `ulsync-server` |
| `curl` | whoami, токен Supabase |
| `sqlite3` | `origin` и `COUNT(*)` в базе |
| `adb` | `pm clear` (шаг E0) |

**Успех:** пять строк с путями.

**Ошибка:** `... not found` — установить недостающую утилиту / добавить в `PATH`.

### 3.2. Эмулятор `emulator-5554` запущен

**Зачем:** H3 — один Android-эмулятор.

```bash
flutter devices | grep emulator-5554
```

**Успех:** одна строка с `emulator-5554`.

**Ошибка:** пустой вывод — запустить AVD в Android Studio Device Manager.

### 3.3. Порт 8082 свободен

**Зачем:** сервер H3 слушает **8082**, не 8080.

```bash
lsof -nP -iTCP:8082 -sTCP:LISTEN
```

**Успех:** **пустой** вывод.

**Ошибка:** строка с процессом — остановить его (`Ctrl+C` в том терминале). Если это старый H3 — можно убить и поднять заново.

**Примечание:** сервер H1/H2 на **8080** может работать параллельно — H3 использует другой порт. Но приложение **обязано** ходить на `8082` через `ULSYNC_BASE_URL`.

### 3.4. Нет конфликта с прошлым `flutter run` на другом порту

**Зачем:** если после H2 приложение всё ещё собрано с `ULSYNC_BASE_URL=http://192.168.1.149:8080`, оно **не** попадёт на склад H3.

Решение: новый `flutter run` в шаге E **с** `--dart-define=ULSYNC_BASE_URL=http://10.0.2.2:8082`. Hot reload URL не меняет.

---

## 4. Раскладка окон

| Окно | Назначение | Процесс висит |
|---|---|---|
| **1** | `./ulsync-server -config ./config_h3.yaml` | Да, до шага G (остановка) |
| **2** | Секреты, yaml, curl, sqlite3 | Нет |
| **3** | `flutter run` на `emulator-5554` | Да, до конца проверки |
| **Браузер** | `http://127.0.0.1:8183/admin` | — |

`export` из окна 2 **не** переносится в окно 3.

---

## 5. Пошаговое выполнение

### Шаг A — Окно 2: секреты и конфиг

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
export EMAIL='YOUR_EMAIL'
export PASSWORD='YOUR_PASSWORD'
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
mkdir -p ./data
cat > ./config_h3.yaml <<EOF
server:
  bind: "0.0.0.0:8082"
  read_header_timeout: "5s"
  idle_timeout: "120s"
  max_body_bytes: 1048576

storage:
  driver: "sqlite"
  path: "./data/ulsync_h3.db"

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
  bind: "127.0.0.1:8183"
  token: ""
EOF
```

**Разбор:**

| Поле | Значение | Зачем |
|---|---|---|
| `server.bind` | `0.0.0.0:8082` | Sync API на порту **8082** |
| `storage.path` | `./data/ulsync_h3.db` | Отдельный файл, не `ulsync_h1.db` / `ulsync_h2.db` |
| Ключа `origin:` | **нет** | Открытый склад |
| `admin.bind` | `127.0.0.1:8183` | Админка только с Mac |

**Успех:** `test -f ./config_h3.yaml && echo "config_h3.yaml OK"` печатает `config_h3.yaml OK`.

---

### Шаг B — Окно 1: сервер с чистой базой

Последняя команда **не завершится** — окно оставить открытым.

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
git checkout main && git pull
go build -o ulsync-server ./cmd/ulsync-server
rm -f ./data/ulsync_h3.db ./data/ulsync_h3.db-wal ./data/ulsync_h3.db-shm
./ulsync-server -config ./config_h3.yaml
```

**Разбор:**

| Команда | Зачем |
|---|---|
| `rm -f ./data/ulsync_h3.db*` | Гарантированно **пустой** склад; без этого H3 невалиден |
| `./ulsync-server -config ./config_h3.yaml` | Запуск на порту **8082** |

**Успех:** в логе `server listening` с `:8082`, `admin listening` с `8183`.

**Ошибка:** `bind: address already in use` — порт 8082 занят (§3.3).

---

### Шаг C — Окно 2: `ACCESS_TOKEN` и whoami на порту 8082

Переменные `SU`, `SAK`, `EMAIL`, `PASSWORD` должны быть в **этом** окне.

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
  *) echo "FAIL: access_token нет."; return 1 ;;
esac
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
curl -sS -w '\nHTTP:%{http_code}\n' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  http://127.0.0.1:8082/v1/whoami
```

**Важно:** whoami идёт на `127.0.0.1:8082` — порт **8082**, не 8080.

**Успех:** `ACCESS_TOKEN получен...`; `OK: ACCESS_TOKEN действителен`; whoami заканчивается `HTTP:200` и `user_id` в теле.

**Стоп-условие:** пока whoami не `200`, окно 3 не открывать.

---

### Шаг D — Браузер: админка (рекомендуется)

1. Откройте `http://127.0.0.1:8183/admin`.
2. В окне 2: `echo "$ACCESS_TOKEN"` → вставить в Check token → **valid**.

До обмена **Store origin** и **Envelopes** могут быть пустыми / нулевыми — это норма для пустого склада.

---

### Шаг E0 — Сброс сессии на эмуляторе

```bash
adb -s emulator-5554 shell pm clear com.gdetotuta.vfx.counter_schmounter
```

**Зачем:** свежая Supabase-сессия; сброс локального ulsync-клиента с кэшем hello от H1/H2.

**Успех:** `Success`.

**Ошибка:** `device not found` — проверить `flutter devices`.

**Примечание:** после `pm clear` на устройстве могут остаться **локальные** данные счётчика только если clear не затронул их — для H3 достаточно хотя бы одного плюса после входа. Если счётчик 0 — нажмите плюс один раз после «На связи».

---

### Шаг E — Окно 3: приложение на порт 8082

**Новый** терминал. `$SU` / `$SAK` экспортировать снова.

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
cd /Users/vvk/AndroidStudioProjects/r/counter_schmounter
flutter run -d emulator-5554 \
  --dart-define=SU="$SU" \
  --dart-define=SAK="$SAK" \
  --dart-define=ULSYNC_BASE_URL=http://10.0.2.2:8082
```

**Разбор `--dart-define`:**

| Параметр | Значение | Зачем |
|---|---|---|
| `SU` / `SAK` | Ваши секреты Supabase | Вход в приложение |
| `ULSYNC_BASE_URL` | `http://10.0.2.2:8082` | Направить клиент на **склад H3**, не на default `:8080` |

**Успех сборки:** `✓ Built ... app-debug.apk`, `Supabase init completed`, нет красных ошибок.

**На эмуляторе:**

1. Войти `EMAIL` / `PASSWORD` (после E0 форма обязательна).
2. Дождаться **«На связи»**.
3. Если счётчик **0** — один **плюс**. Если уже > 0 (редко после clear) — плюс всё равно полезен для явной заливки.

**Контроль в админке** (браузер, порт 8183):

- **Store origin** = `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f`
- **Envelopes** ≥ **1**

**Контроль в логе `flutter run`:** нет `OriginMismatchException`. В логе сервера (окно 1) после входа нет `token rejected`.

---

### Шаг F — Окно 1: остановка сервера

`Ctrl+C` в окне 1. Дождаться `server stopped`.

**Зачем:** перед sqlite3 удобнее, чтобы WAL сбросился; не обязательно, но рекомендуется.

---

### Шаг G — Окно 2: проверка базы

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
sqlite3 ./data/ulsync_h3.db "SELECT v FROM server_meta WHERE k='origin';"
sqlite3 ./data/ulsync_h3.db "SELECT COUNT(*) FROM envelopes;"
```

**Разбор:**

| Запрос | Успех H3 |
|---|---|
| Первый (`origin`) | Одна строка: `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f` |
| Второй (`COUNT(*)`) | Целое число **≥ 1** |

Пустой первый запрос или `0` во втором — **провал** H3 (см. §8).

---

## 6. Итоговые критерии

### Успех H3

- [ ] whoami (шаг C): `HTTP:200` на порту **8082**.
- [ ] Приложение запущено с `ULSYNC_BASE_URL=http://10.0.2.2:8082`.
- [ ] После входа: **«На связи»**.
- [ ] Админка: **Store origin** = `K_ULSYNC_ORIGIN`; **Envelopes** ≥ 1.
- [ ] sqlite3 (шаг G): тот же `origin`; `COUNT(*) ≥ 1`.
- [ ] Нет `OriginMismatchException` в логе приложения.

**Интерпретация:** заливка пустого открытого склада — **ожидаемый результат**, не баг. В отчёте H3 пишут: «приручение + заливка подтверждены».

### Провал H3

- `409` / `OriginMismatchException`.
- `origin` пустой или другая строка.
- `envelopes` = 0 после входа и плюса.
- Приложение ходило на **8080** (забыли `ULSYNC_BASE_URL`) — проверка не про H3.

---

## 7. Частые сбои

| Симптом | Что проверить |
|---|---|
| whoami на 8080 OK, на 8082 fail | Сервер H3 не запущен или слушает не тот порт |
| «На связи», но `envelopes` = 0 | Просроченный JWT (§2.4.1); шаг E0 + новый вход |
| `envelopes` = 0, плюс локально растёт | Sync не доходит до сервера 8082 — проверить `ULSYNC_BASE_URL` |
| `OriginMismatchException` | Не тот склад или конфликт origin — для H3 на пустом открытом не должно быть |
| Админка 8183 не открывается | Сервер H3 не запущен или другой `admin.bind` |
| Путают с H1 | H1 — два эмулятора, порт 8080; H3 — один эмулятор, порт **8082**, заливка на **новый** том |
| `rm` базы при работающем приложении | См. H1 §8.1: нужен новый `flutter run` / E0 |

---

## 8. Восстановление после сбоя

1. Окно 3: `q` — остановить `flutter run`.
2. Окно 1: `Ctrl+C` — остановить сервер.
3. Шаг **E0** (`pm clear`).
4. Шаг **B** заново (`rm` базы + `./ulsync-server`).
5. Шаг **C** — свежий `ACCESS_TOKEN`, whoami `200` на **8082**.
6. Шаг **E** — `flutter run` с `ULSYNC_BASE_URL=http://10.0.2.2:8082`, вход, плюс.
7. Шаг **G** — sqlite3.

---

## 9. Уборка

```bash
# Окно 3: Ctrl+C
# Окно 1: остановлен на шаге F
rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/config_h3.yaml
# rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/data/ulsync_h3.db*  # по желанию
```

Следующий сценарий приёмки круга 1b: **H4** (авторский склад с чужим `origin:` — приложение отказывает) — отдельный документ.

---

## 10. Связанные артефакты

| Файл | Содержание |
|---|---|
| `lib/src/infrastructure/sync/ulsync_base_url.dart` | `kUlsyncBaseUrl`, приоритет `ULSYNC_BASE_URL` |
| План 1b §5, строка H3 | «Первый hello приручает второй склад и зальёт его — не провал H3» |
| `docs/manual_tests/round_1b_H1_open_empty_stock.md` | Два эмулятора, порт 8080 — другой сценарий |
