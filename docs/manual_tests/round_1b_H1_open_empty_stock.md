# Ручной тест H1 — пустой открытый склад, hello, плюс на второе устройство

**Дата создания:** 2026-09-15 17:37:58 +0300  
**Последнее обновление:** 2026-09-15 18:19:41 +0300  
**Версия:** 3  
**Вид документа:** инструкция

Круг **1b**, сценарий **H1** из [плана круга 1b](https://github.com/flutter-senior-prep/plan_triad/blob/main/docs/ROUND_1B_TRIAD_PLAN.md) (§5, таблица H1). Проверяет шаг 26 приложения: константа происхождения `kUlsyncOrigin` приручает **открытый** склад (в конфиге сервера нет `origin:`), после чего обычный плюс доезжает на второй эмулятор через live-sync.

Документ **самодостаточен**: не предполагает, что вы читали TEMP, промпт шага 26 или другие сценарии H2–H7.

---

## 1. Что проверяем

| Критерий | Успех | Провал |
|---|---|---|
| Первый обмен с пустым открытым складом | `GET /v1/sync/hello` проходит, плюс с первого эмулятора появляется на втором **сам** (как G1 круга 1a) | Отказ обмена, пустой склад после плюса, `OriginMismatchException` в логе приложения |
| Происхождение в базе | В `server_meta` записана строка приложения | Пусто или другая строка |

**Не проверяем в H1:** защиту от чужого склада (это H4), смену URL (H2), второй процесс сервера (H3).

---

## 2. Словарь переменных и констант

Подставляйте **свои** значения в места `YOUR_*`. Файлы с секретами и `config_h1.yaml` **не коммитить**.

### 2.1. Пути на диске (фиксированные для этого теста)

| Символ | Значение | Назначение |
|---|---|---|
| `APP_ROOT` | `/Users/vvk/AndroidStudioProjects/r/counter_schmounter` | Корень Flutter-приложения |
| `SERVER_ROOT` | `/Users/vvk/AndroidStudioProjects/r/ulsync-server` | Корень Go-сервера ulsync |
| `DB_FILE` | `./data/ulsync_h1.db` (относительно `SERVER_ROOT`) | SQLite-база **только** для H1; перед прогоном удаляется |
| `CONFIG_FILE` | `./config_h1.yaml` (относительно `SERVER_ROOT`) | Конфиг сервера для H1; создаётся вручную, не в git |

### 2.2. Порты и URL

| Имя | Значение | Кто слушает | Кто подключается |
|---|---|---|---|
| `SYNC_PORT` | `8080` | `ulsync-server`, bind `0.0.0.0:8080` | Приложение на Android-эмуляторе → `http://10.0.2.2:8080` |
| `ADMIN_PORT` | `8181` | Админка сервера, bind `127.0.0.1:8181` | Браузер на Mac → `http://127.0.0.1:8181/admin` |
| `EMULATOR_HOST` | `10.0.2.2` | — | Специальный адрес Android Emulator: loopback **Mac-хозяина**, не адрес эмулятора |

Приложение **не** передаёт `--dart-define=ULSYNC_BASE_URL`: для Android по умолчанию берётся `http://10.0.2.2:8080` из `lib/src/infrastructure/sync/ulsync_base_url.dart`.

### 2.3. Происхождение склада (константа приложения)

| Имя | Значение |
|---|---|
| `K_ULSYNC_ORIGIN` | `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f` |

Одна строка на **все** установки этого контура (reverse-DNS пакета + UUID проекта). Зашита в `kUlsyncOrigin` в `ulsync_base_url.dart`. Менять UUID между прогонами круга 1b нельзя.

Открытый склад: в `config_h1.yaml` **нет** ключа `origin:`. Первый успешный hello с заголовком `Ulsync-Origin: K_ULSYNC_ORIGIN` записывает это значение в таблицу `server_meta`.

### 2.4. Секреты Supabase (задаёт оператор)

| Переменная shell | Что подставить | Где используется |
|---|---|---|
| `SU` | `https://YOUR_PROJECT.supabase.co` — URL проекта Supabase | `--dart-define=SU=...` в `flutter run`; `auth.jwks_url` в yaml сервера |
| `SAK` | `YOUR_ANON_KEY` — публичный anon key из Supabase Dashboard → Settings → API | `--dart-define=SAK=...`; заголовок `apikey` при получении токена |
| `EMAIL` | Email тестового пользователя Supabase | Тело запроса `/auth/v1/token`; вход в приложении на обоих эмуляторах |
| `PASSWORD` | Пароль того же пользователя | То же |
| `ACCESS_TOKEN` | JWT, **получается командой** ниже, не копировать из Dashboard | `Authorization: Bearer` в curl whoami; вставка в админку браузера |

`SU` и `SAK` в приложении — compile-time константы (`String.fromEnvironment`). Без них `flutter run` не авторизует пользователя в Supabase.

### 2.4.1. Два разных токена — частая ловушка

| Токен | Откуда | Кто им пользуется |
|---|---|---|
| `ACCESS_TOKEN` из шага C | Свежий запрос `curl` к Supabase **прямо сейчас** | Только curl whoami и админка в браузере |
| Сессия приложения | `SharedPreferences` на эмуляторе после прошлых `flutter run` | ulsync: hello, push, pull, live |

**whoami с `200` не гарантирует**, что приложение шлёт валидный JWT. Если на эмуляторе осталась **просроченная** сессия, сервер пишет:

```json
{"msg":"token rejected","reason":"token has invalid claims: token is expired"}
```

Плюс на экране при этом **всё равно увеличивает локальный журнал** — это не синхронизация. Без успешного push число на втором эмуляторе не вырастет.

Перед каждым прогоном H1 на эмуляторах нужна **чистая сессия** (шаг E0 ниже) или явный выход и повторный вход после `flutter run`.

### 2.5. Эмуляторы Android

| Идентификатор `flutter` | Роль в тесте |
|---|---|
| `emulator-5554` | Первое устройство: нажимает **плюс** |
| `emulator-5556` | Второе устройство: число должно вырасти **без** нажатия плюса здесь |

Имена `emulator-5554` / `emulator-5556` — стандартные serial AVD. Узнать фактические:

```bash
flutter devices
```

В колонке id должны быть `emulator-5554` и `emulator-5556`. Если id другие — во всех командах `flutter run -d ...` подставьте свои id.

### 2.6. Ветки git (на момент написания документа)

| Репозиторий | Ветка |
|---|---|
| `counter_schmounter` | `spike/32-26-origin` (или актуальная ветка шага 26 от `spike/ulsync-test`) |
| `ulsync-server` | `main` с слитыми шагами 24+ (поддержка hello и `server_meta`) |

---

## 3. Предусловия (проверить до начала)

Выполните в **любом** свободном терминале. Каждая строка должна завершиться без ошибки.

**3.1. Инструменты на Mac**

```bash
which flutter go curl sqlite3
```

Ожидание: четыре пути, не пустой вывод.

**3.2. Эмуляторы запущены**

В Android Studio: Device Manager → два AVD в состоянии Running. Затем:

```bash
flutter devices | grep emulator
```

Ожидание: минимум две строки с `emulator-`.

**3.3. Порт 8080 свободен**

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

Ожидание: **пустой** вывод. Если процесс занял порт — остановите его (`Ctrl+C` в том терминале или `kill <pid>`).

**3.4. Нет висящего ulsync-server от другого H***

Если в каком-то терминале ещё крутится `./ulsync-server` — нажмите там `Ctrl+C` и дождитесь выхода процесса.

**3.5. Аккаунт Supabase**

Один пользователь (`EMAIL` / `PASSWORD`) должен существовать в проекте `SU`. Оба эмулятора войдут под **одним** аккаунтом.

---

## 4. Раскладка окон терминала

| Окно | Назначение | Должен ли процесс «висеть» после шага |
|---|---|---|
| **1** | `./ulsync-server` | Да, с момента запуска до шага «Остановка сервера» |
| **2** | Секреты, создание yaml, curl, sqlite3 | Нет (команды завершаются) |
| **3** | `flutter run` на `emulator-5554` | Да, до конца теста |
| **4** | `flutter run` на `emulator-5556` | Да, до конца теста |
| **Браузер** | Админка `http://127.0.0.1:8181/admin` | — |

**Важно:** `export` в одном окне терминала **не** переносится в другое. Если окно 3 использует `$SU`, переменные нужно снова `export` в окне 3.

---

## 5. Пошаговое выполнение

### Шаг A — Окно 2: секреты и конфиг сервера

Скопируйте блок целиком, подставьте свои `YOUR_*`, выполните в окне **2**.

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
export EMAIL='YOUR_EMAIL'
export PASSWORD='YOUR_PASSWORD'
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
mkdir -p ./data
cat > ./config_h1.yaml <<EOF
server:
  bind: "0.0.0.0:8080"
  read_header_timeout: "5s"
  idle_timeout: "120s"
  max_body_bytes: 1048576

storage:
  driver: "sqlite"
  path: "./data/ulsync_h1.db"

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
  bind: "127.0.0.1:8181"
  token: ""
EOF
```

**Разбор блока:**

- `export SU=...` — URL проекта; без кавычек внутри значения не должно быть пробелов.
- `mkdir -p ./data` — каталог для SQLite-файла.
- `cat > ./config_h1.yaml <<EOF` — перезаписывает конфиг; heredoc подставляет `$SU` из shell в `jwks_url`.
- `server.bind: "0.0.0.0:8080"` — HTTP API на всех интерфейсах Mac, порт **8080**.
- `storage.path` — файл базы H1; при каждом прогоне удаляется отдельной командой.
- Ключа **`origin:` нет** — склад **открытый**.
- `auth.jwks_url` — Supabase JWKS; сервер проверяет JWT так же, как приложение.
- `dev_hs256_secret: ""` — локальный HS256 **не** используется; только JWKS Supabase.
- `admin.bind: "127.0.0.1:8181"` — админка только с Mac, порт **8181** (не 8081 из README: у H1 свой порт, чтобы не пересечься с другими сценариями).

Проверка, что файл создан:

```bash
test -f ./config_h1.yaml && echo "config_h1.yaml OK"
```

---

### Шаг B — Окно 1: сборка сервера, чистая база, запуск

Выполните в окне **1**. Последняя команда **не завершится** — это нормально.

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
git checkout main && git pull
go build -o ulsync-server ./cmd/ulsync-server
rm -f ./data/ulsync_h1.db ./data/ulsync_h1.db-wal ./data/ulsync_h1.db-shm
./ulsync-server -config ./config_h1.yaml
```

**Разбор:**

- `git checkout main && git pull` — актуальный код с hello и `server_meta`.
- `go build -o ulsync-server ./cmd/ulsync-server` — бинарник рядом с конфигом.
- `rm -f ...` — гарантированно **пустая** база; без этого H1 невалиден.
- `./ulsync-server -config ./config_h1.yaml` — флаг `-config` задаёт путь к yaml.

**Ожидание в окне 1:** строки вроде `server listening` и упоминание `:8080`. Окно оставить открытым.

---

### Шаг C — Окно 2: получить `ACCESS_TOKEN` и проверить whoami

Переменные `SU`, `SAK`, `EMAIL`, `PASSWORD` уже должны быть в **этом** окне (шаг A).

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
  *) echo "FAIL: access_token нет. Проверь SU, SAK, EMAIL, PASSWORD и сеть."; return 1 ;;
esac
curl -sS -w '\nHTTP:%{http_code}\n' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  http://127.0.0.1:8080/v1/whoami
```

**Разбор:**

- Первый `curl` — Supabase Auth: `grant_type=password`, логин/пароль в JSON.
- `sed` вытаскивает поле `access_token` из JSON ответа.
- `case ... eyJ*` — JWT всегда начинается с `eyJ`; иначе токен не получен.
- Второй `curl` — ручка `whoami` **сервера** ulsync на `127.0.0.1:8080` (с Mac, не с эмулятора).
- `-w '\nHTTP:%{http_code}\n'` — в конце выводит код ответа.

**Ожидание:** строка `ACCESS_TOKEN получен...`; в конце whoami — `HTTP:200` и в теле JSON поле `user_id` (uuid пользователя).

**Стоп-условие:** пока whoami не `200`, окна 3 и 4 **не открывать** — JWT или сервер настроены неверно.

**Проверка срока действия токена** (в том же окне 2; нужен `python3`):

```bash
python3 - <<'PY'
import base64, json, os, sys, time
t = os.environ.get("ACCESS_TOKEN", "")
if not t.startswith("eyJ"):
    sys.exit("FAIL: ACCESS_TOKEN не задан или не JWT")
payload = t.split(".")[1]
payload += "=" * ((4 - len(payload) % 4) % 4)
claims = json.loads(base64.urlsafe_b64decode(payload))
exp = int(claims.get("exp", 0))
now = int(time.time())
print(f"sub={claims.get('sub')} exp={exp} now={now} ttl_sec={exp - now}")
if exp <= now:
    sys.exit("FAIL: ACCESS_TOKEN уже просрочен — повтори curl выше")
print("OK: ACCESS_TOKEN действителен")
PY
```

Если `FAIL: ACCESS_TOKEN уже просрочен` — снова выполните блок получения `ACCESS_TOKEN` из начала шага C.

---

### Шаг D — Браузер: проверка токена в админке

1. На Mac откройте `http://127.0.0.1:8181/admin`.
2. В окне **2** выполните:

```bash
echo "$ACCESS_TOKEN"
```

3. Скопируйте **весь** вывод (одна длинная строка `eyJ...`).
4. Вставьте в поле Check token на странице админки, нажмите **Check**.

**Ожидание:** статус **valid**. Если invalid — не переходите к приложению; исправьте `SU`/`SAK` или конфиг `jwks_url`.

---

### Шаг E0 — Сброс сессии на обоих эмуляторах (обязательно перед каждым прогоном)

Выполните **до** `flutter run`, пока эмуляторы запущены. Команда удаляет данные приложения, в том числе просроченную Supabase-сессию.

```bash
adb -s emulator-5554 shell pm clear com.gdetotuta.vfx.counter_schmounter
adb -s emulator-5556 shell pm clear com.gdetotuta.vfx.counter_schmounter
```

**Разбор:**

- `adb` — Android Debug Bridge с Mac.
- `-s emulator-5554` — serial устройства (как в `flutter devices`).
- `pm clear com.gdetotuta.vfx.counter_schmounter` — обнуляет хранилище пакета приложения.

**Ожидание:** на каждую команду строка `Success`. Если `device not found` — проверьте `flutter devices` и подставьте свои id.

Альтернатива без `adb`: после `flutter run` нажать **Выйти** на экране счётчика и войти заново — менее надёжно, если сессия «залипла».

---

### Шаг E — Окно 3: приложение на первом эмуляторе

**Новый** терминал. `$SU` из окна 2 сюда **не** попал — экспортируйте снова.

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
cd /Users/vvk/AndroidStudioProjects/r/counter_schmounter
flutter run -d emulator-5554 --dart-define=SU="$SU" --dart-define=SAK="$SAK"
```

**Разбор:**

- `-d emulator-5554` — целевое устройство (первый эмулятор).
- `--dart-define=SU="$SU"` — compile-time константа для Supabase URL в приложении.
- `--dart-define=SAK="$SAK"` — anon key.
- `ULSYNC_BASE_URL` **не** передаём: Android → `http://10.0.2.2:8080`.
- `ULSYNC_ORIGIN` **не** передаём: используется default `K_ULSYNC_ORIGIN`.

Дождитесь сборки. Процесс `flutter run` **висит** — не закрывайте окно.

**На эмуляторе 5554:**

1. Войти email `EMAIL` и пароль `PASSWORD` (те же, что в шаге C) — после шага E0 форма входа обязательна.
2. Дождаться иконки связи **«На связи»** (успешный sync + live).

**Контроль в окне 1 (сервер)** в первые 30 с после входа: должны появиться строки запросов (`hello`, `push` или `live`). **Не должно** быть `token rejected`. Если есть `token is expired` — на эмуляторе **Выйти**, снова шаг E0 для этого устройства, новый `flutter run`, вход заново.

Если **«Нет связи»** — смотрите лог окна 3; whoami из шага C проверяет только curl-токен, не сессию приложения.

---

### Шаг F — Окно 4: приложение на втором эмуляторе

**Новый** терминал (окно **4**).

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
cd /Users/vvk/AndroidStudioProjects/r/counter_schmounter
flutter run -d emulator-5556 --dart-define=SU="$SU" --dart-define=SAK="$SAK"
```

На эмуляторе **5556** войти **тем же** аккаунтом. Дождаться **«На связи»**.

Оба эмулятора держите в **переднем плане** (live-sync работает только когда приложение на экране).

---

### Шаг G — Действие теста: один плюс на 5554

1. На эмуляторе **5554** один раз нажать кнопку **плюс** (счётчик увеличится локально).
2. Эмулятор **5556 не трогать**.
3. В окнах 3 и 4 **не** нажимать Stop / `q` в `flutter run`.

**Ожидание:**

- На **5556** число счётчика увеличивается на **1** без нажатия плюса (live-sync, как в G1 круга 1a).
- В окне **1** (лог сервера) до или во время обмена есть строка с `GET /v1/sync/hello` (первый обмен с устройства). Не должно быть `token rejected`.

Запомните или сфотографируйте числа на обоих экранах для отчёта.

---

### Шаг H — Остановка сервера

В окне **1** нажмите `Ctrl+C`. Процесс `ulsync-server` должен завершиться.

---

### Шаг I — Окно 2: проверка происхождения в базе

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
sqlite3 ./data/ulsync_h1.db "SELECT v FROM server_meta WHERE k='origin';"
```

**Разбор:**

- `sqlite3` — CLI SQLite.
- Таблица `server_meta`: ключ `k='origin'`, значение в колонке `v`.
- Запрос должен вернуть **ровно одну** строку.

**Ожидание (успех):**

```
com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f
```

---

## 6. Итоговые критерии

### Успех H1

- [ ] whoami (шаг C): `HTTP:200`, в теле `user_id`.
- [ ] Админка (шаг D): токен **valid**.
- [ ] Оба эмулятора: **«На связи»** после входа.
- [ ] Плюс на 5554 → на 5556 число +1 без действий на 5556.
- [ ] Лог сервера (окно 1): был `GET /v1/sync/hello`; не было `token rejected`.
- [ ] sqlite3 (шаг I): строка `K_ULSYNC_ORIGIN` как выше.
- [ ] Логи `flutter run` (окна 3–4): **нет** `OriginMismatchException`.

### Провал H1

- whoami не `200` или `token rejected` в логе сервера.
- Плюс на 5556 не появился в разумное время (десятки секунд при обоих в foreground).
- sqlite3 пустой или другая строка происхождения.
- В логе приложения `OriginMismatchException`.

---

## 7. Частые сбои

| Симптом | Что проверить |
|---|---|
| `FAIL: access_token нет` | `SU`, `SAK`, `EMAIL`, `PASSWORD`; пользователь существует в Supabase; сеть |
| whoami `401` / `403` | Сервер запущен (окно 1); `jwks_url` в yaml совпадает с `SU`; часы Mac |
| `token rejected` + `token is expired` | Просроченная сессия на эмуляторе, не баг origin. Шаг E0 → новый вход → в логе сервера нет rejected |
| whoami `200`, но в логе сервера `token rejected` | Типично: curl-токен свежий, приложение шлёт старый JWT. Шаг E0 на обоих эмуляторах |
| Эмулятор «не видит» сервер, health с Mac `200` | Часто §8.1 (wipe базы) или expired token — не фаервол |
| «Нет связи» при зелёном whoami | §8.1 или §8.2; лог `flutter run`; админка: растут 4xx, `Store origin` пуст |
| Плюс локально растёт, на 5556 нет | Нет sync (§8.1, §8.2 или «Нет связи»), не провал H1 по origin |
| Плюс не на 5556 | Оба в foreground; оба «На связи»; один аккаунт |
| Пустой sqlite3 origin | Hello не прошёл; базу удалили при работающих эмуляторах (§8.1) |
| Перезапуск сервера **без** `rm` — снова «На связи» | Ожидаемо: `origin` в базе сохранился |
| Перезапуск **с** `rm` при работающих эмуляторах | §8.1: нужен новый `flutter run` или E0 |

---

## 8. Восстановление после сбоя

### 8.1. Перезапуск сервера с `rm` базы при работающих эмуляторах

**Наблюдение:** Ctrl+C и снова `./ulsync-server` **без** удаления `ulsync_h1.db` — эмуляторы подхватывают сервер. После `rm` файлов базы и нового старта — «Нет связи», будто сервер «умер».

**Это не сеть.** `curl http://127.0.0.1:8080/health` с Mac по-прежнему `200`. Ломается цепочка **hello → push** на открытом складе.

**Почему без `rm` работает**

- В SQLite осталась строка `server_meta.origin`.
- Push/pull с заголовком `Ulsync-Origin` проходят: склад уже приручен.

**Почему с `rm` не работает**

1. База пустая → в `server_meta` **нет** `origin`.
2. На открытом складе **только** `GET /v1/sync/hello` может записать происхождение (`imprint=true`). Push/pull с заголовком, но без hello, сервер отвечает **400** `origin_required`.
3. `UlsyncClient` в памяти приложения уже выставил флаг «hello сделан» (`_originChecked`). После wipe базы он **не** шлёт hello снова и сразу идёт в push → 400 → «Нет связи».

**Что делать** (любой из вариантов — нужен **новый** экземпляр клиента):

1. **Рекомендуется для повторного прогона H1:** остановить `flutter run` на обоих эмуляторах → шаг **E0** (`pm clear`) → сервер с чистой базой → заново шаги C, E, F, G.
2. **Быстрый обход:** `q` / Ctrl+C в окнах 3–4 и снова `flutter run` + вход (новый `UlsyncClient` → hello снова).
3. Увести приложение в фон и вернуть: контроллер вызывает `invalidate(ulsyncClientProvider)` — иногда достаточно, но для H1 надёжнее п.1.

**Во время одного прогона H1** не удаляйте `ulsync_h1.db`, пока эмуляторы не остановлены. `rm` базы — только в **шаге B** перед первым стартом или после полной остановки приложений.

### 8.2. Просроченный JWT (`token expired`)

Если уже видели `token is expired` и после перезапуска сервера эмуляторы в «Нет связи»:

1. **Окна 3–4:** `q` или Ctrl+C — остановить `flutter run`.
2. **Шаг E0** — `pm clear` на **обоих** эмуляторах.
3. **Окно 1** — сервер с **чистой** базой (как в шаге B: `rm` файлов `ulsync_h1.db*` и `./ulsync-server -config ./config_h1.yaml`).
4. **Окно 2** — заново шаг C (новый `ACCESS_TOKEN` + whoami `200`).
5. **Окна 3–4** — заново шаги E и F; **обязательно войти** после clear.
6. В логе сервера после входа — запросы без `token rejected`, затем «На связи» на обоих.
7. Только потом шаг G (плюс на 5554).

Повторный прогон H1 **без** E0 после вчерашнего `flutter run` снова приведёт к `token is expired`.

---

## 9. Уборка (после фиксации результата)

```bash
# Окна 3–4: Ctrl+C или q в flutter run
# Окно 1: уже остановлен на шаге H
rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/config_h1.yaml
# Файл ./data/ulsync_h1.db можно оставить для разбора или удалить:
# rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/data/ulsync_h1.db*
```

Следующий сценарий приёмки круга 1b: **H2** (тот же склад, другой URL, то же происхождение) — отдельный документ.

---

## 10. Связанные артефакты

| Документ | Содержание |
|---|---|
| `lib/src/infrastructure/sync/ulsync_base_url.dart` | `kUlsyncBaseUrl`, `kUlsyncOrigin` |
| `README.md` § «Синхронизация» | Обзор портов 8080/8081 и dart-define |
| План 1b §5 | Таблица H1–H7 |
