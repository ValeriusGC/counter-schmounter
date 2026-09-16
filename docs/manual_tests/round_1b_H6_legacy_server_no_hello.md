# Ручной тест H6 — старый сервер без hello, приложение работает

**Дата создания:** 2026-09-16 12:25:47 +0300  
**Последнее обновление:** 2026-09-16 12:45:39 +0300  
**Версия:** 2  
**Вид документа:** инструкция

Круг **1b**, сценарий **H6** из [плана круга 1b](https://github.com/flutter-senior-prep/plan_triad/blob/main/docs/ROUND_1B_TRIAD_PLAN.md) (§5, таблица H6). Проверяет **обратную совместимость**: приложение шага 26 с константой `kUlsyncOrigin` ходит на сервер тега **`pre-round-1b`** (круг 1a есть, **`GET /v1/sync/hello` нет**). Клиент **не падает**, обмен идёт как в **G6 круга 1a** — hello считается «недоступным» (`404`/`405`), sync продолжается без imprint origin.

Документ **полностью самодостаточен**: не требует прогона H1–H5, TEMP или сценария H7.

---

## 1. Что проверяем

| Критерий | Успех H6 | Провал H6 |
|---|---|---|
| Бинарник сервера из тега **`pre-round-1b`** | `curl` hello → **HTTP:404** (маршрута нет) | hello → **HTTP:200** — собран **`main`**, не legacy |
| Приложение с `K_ULSYNC_ORIGIN` на порту **8085** | Нет краша; плюс растёт; **«На связи»** | Краш при входе/плюсе; «Нет связи» без причины |
| База после плюса | `SELECT COUNT(*) FROM envelopes` **≥ 1** | `0` при растущем локальном счётчике |
| Origin-затвор 1b | **Нет** `OriginMismatchException`; нет отказа как в H4 | Отказ обмена из-за origin на legacy-сервере |

### 1.1. Чем H6 отличается от соседних сценариев

| | H1 (main, hello) | H4/H5 (origin-затвор) | H6 (legacy) |
|---|---|---|---|
| Сервер | `main`, есть `/v1/sync/hello` | `main`, authored/open + hello | **`pre-round-1b`**, hello **нет** |
| Клиент | Flutter + `K_ULSYNC_ORIGIN` | Flutter или curl | Flutter + `K_ULSYNC_ORIGIN` |
| hello | `200`, imprint на открытом складе | `409` при чужом origin | **`404`** — «недоступен», не mismatch |
| Успех | Плюс на 2-й эмулятор | envelopes **0**, отказ | envelopes **≥ 1**, обмен как 1a |
| Аналог в 1a | G1 | — | **G6** (старый `pre-round-1a`) |

**Не проверяем в H6:** второй эмулятор (достаточно одного), imprint `server_meta.origin` (таблицы нет на `pre-round-1b`), конфликт yaml/база (H7).

### 1.2. Что делает клиент при 404 на hello (для понимания, не шаг теста)

Библиотека `ulsync-dart`: `GET /v1/sync/hello` с кодами **404** или **405** → hello **«недоступен»**, не ошибка origin → флаг «hello пройден» выставляется → дальше обычные `push`/`pull`/`live`. Это и есть совместимость с деплоем до круга 1b.

---

## 2. Словарь переменных и констант

Подставляйте **свои** значения в `YOUR_*`. `config_h6.yaml` **не коммитить**.

### 2.1. Пути на диске (фиксированные для H6)

| Символ | Значение | Назначение |
|---|---|---|
| `APP_ROOT` | `/Users/vvk/AndroidStudioProjects/r/counter_schmounter` | Корень Flutter-приложения |
| `SERVER_ROOT` | `/Users/vvk/AndroidStudioProjects/r/ulsync-server` | Основной клон (для `git worktree`) |
| `LEGACY_WORKTREE` | `/tmp/ulsync-pre-1b` | Отдельный worktree на теге `pre-round-1b` |
| `DB_FILE` | `./data/ulsync_h6.db` (внутри `LEGACY_WORKTREE`) | SQLite **только** для H6 |
| `CONFIG_FILE` | `/tmp/ulsync-pre-1b/config_h6.yaml` | Конфиг legacy-сервера |
| `GIT_TAG` | `pre-round-1b` | Точка возврата **после** закрытого круга 1a, **до** hello в сервере |

### 2.2. Порты и URL

| Имя | Значение | Назначение |
|---|---|---|
| `SYNC_PORT` | `8085` | HTTP API legacy-сервера |
| `ADMIN_PORT` | `8186` | Админка: `http://127.0.0.1:8186/admin` |
| `ULSYNC_BASE_URL` | `http://10.0.2.2:8085` | **Обязательно** в `flutter run` |
| `HELLO_URL` | `http://127.0.0.1:8085/v1/sync/hello` | Контроль: должен отсутствовать (`404`) |
| `WHOAMI_URL` | `http://127.0.0.1:8085/v1/whoami` | Контроль auth |

### 2.3. Происхождение приложения

| Имя | Значение | Где |
|---|---|---|
| `K_ULSYNC_ORIGIN` | `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f` | `kUlsyncOrigin` в `ulsync_base_url.dart`; заголовок с клиента |

В `config_h6.yaml` ключа **`origin:` нет** — на legacy-сервере imprint через hello **не поддерживается**. Строка origin уходит в заголовке, но сервер её **не сверяет** (нет middleware hello).

### 2.4. Секреты Supabase

| Переменная | Что подставить | Где |
|---|---|---|
| `SU` | `https://YOUR_PROJECT.supabase.co` | `jwks_url` в yaml; `--dart-define=SU` |
| `SAK` | `YOUR_ANON_KEY` | `--dart-define=SAK`; `apikey` в curl |
| `EMAIL` | Email тестового пользователя | curl и вход в приложении |
| `PASSWORD` | Пароль | То же |
| `ACCESS_TOKEN` | JWT из curl (шаг C) | whoami, hello-контроль, админка |

Dev HS256 из H5 **не** используется — legacy-конфиг с **JWKS Supabase**, как в H1/H3.

### 2.4.1. Два разных токена

| Токен | Откуда | Кто использует |
|---|---|---|
| `ACCESS_TOKEN` (curl) | Свежий запрос Supabase в шаге C | whoami/hello с Mac |
| Сессия приложения | Хранилище эмулятора | ulsync с эмулятора |

whoami `200` **не гарантирует** валидную сессию на эмуляторе. Перед прогоном — **E0** (`pm clear`), если гоняли H1–H5.

### 2.5. Эмулятор

| Идентификатор | Роль |
|---|---|
| `emulator-5554` | Единственное устройство в H6 |

Второй эмулятор **не обязателен** — достаточно локального плюса и `envelopes ≥ 1` на сервере.

### 2.6. Ветки git

| Репозиторий | Что нужно для H6 |
|---|---|
| `ulsync-server` | Тег **`pre-round-1b`** на `origin` (worktree в `/tmp/ulsync-pre-1b`) |
| `counter_schmounter` | `spike/32-26-origin` (шаг 26, константа origin) |

**Не** собирать сервер из `main` в каталоге `SERVER_ROOT` — только из `LEGACY_WORKTREE`.

### 2.7. Мониторинг

Админка `http://127.0.0.1:8186/admin`:

| Поле | Успех H6 |
|---|---|
| **Envelopes** | **≥ 1** после входа и плюса |
| **Store origin** | Поля **может не быть** (UI `pre-round-1b`) — это норма |
| **Last error** | Не должно быть устойчивого `origin_mismatch` |
| **4xx** | Единичные 404 на hello допустимы при контрольном curl |

Терминал сервера (окно 1) может молчать — смотрите админку, `curl` и UI эмулятора.

---

## 3. Предусловия (проверить до начала)

### 3.1. Инструменты в PATH

```bash
which flutter go curl sqlite3 adb git
```

**Успех:** пять строк с путями.

**Ошибка:** `... not found` — установить / добавить в `PATH`.

### 3.2. Тег `pre-round-1b` существует

```bash
git -C /Users/vvk/AndroidStudioProjects/r/ulsync-server tag --list pre-round-1b
```

**Успех:** одна строка `pre-round-1b`.

**Ошибка:** пусто — тег не поставлен после закрытия круга 1a; см. `ROUND_1B_OPERATOR.md`, раздел про теги точки возврата. **Стоп** — без тега H6 невалиден.

Удалённо (опционально):

```bash
git -C /Users/vvk/AndroidStudioProjects/r/ulsync-server ls-remote --tags origin | grep pre-round-1b
```

### 3.3. Эмулятор `emulator-5554` запущен

```bash
flutter devices | grep emulator-5554
```

**Успех:** одна строка с `emulator-5554`.

### 3.4. Порт 8085 свободен

```bash
lsof -nP -iTCP:8085 -sTCP:LISTEN
```

**Успех:** **пустой** вывод.

---

## 4. Раскладка окон

| Окно | Назначение | Процесс висит |
|---|---|---|
| **1** | Legacy `ulsync-server` из `LEGACY_WORKTREE` | Да, до шага F |
| **2** | Секреты, worktree, yaml, curl | Нет |
| **3** | `flutter run` на `emulator-5554` | Да, до шага F |
| **Браузер** | `http://127.0.0.1:8186/admin` | — |

`export` из окна 2 **не** переносится в окно 3 — в шаге E секреты задать снова.

---

## 5. Пошаговое выполнение

### Шаг A — Окно 2: секреты, worktree, конфиг

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
export EMAIL='YOUR_EMAIL'
export PASSWORD='YOUR_PASSWORD'
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
git fetch --tags origin
if [ ! -d /tmp/ulsync-pre-1b ]; then
  git worktree add /tmp/ulsync-pre-1b pre-round-1b
else
  git -C /tmp/ulsync-pre-1b checkout pre-round-1b
fi
mkdir -p /tmp/ulsync-pre-1b/data
cat > /tmp/ulsync-pre-1b/config_h6.yaml <<EOF
server:
  bind: "0.0.0.0:8085"
  read_header_timeout: "5s"
  idle_timeout: "120s"
  max_body_bytes: 1048576

storage:
  driver: "sqlite"
  path: "./data/ulsync_h6.db"

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
  bind: "127.0.0.1:8186"
  token: ""
EOF
```

**Разбор:**

| Поле | Значение | Зачем |
|---|---|---|
| `server.bind` | `0.0.0.0:8085` | Порт H6 |
| Ключа `origin:` | **нет** | Legacy open store |
| `storage.path` | `./data/ulsync_h6.db` | Отдельный файл в worktree |
| `admin.bind` | `127.0.0.1:8186` | Админка на Mac |

**Успех:**

```bash
test -f /tmp/ulsync-pre-1b/config_h6.yaml && echo "config_h6.yaml OK"
git -C /tmp/ulsync-pre-1b rev-parse --short HEAD
git -C /tmp/ulsync-pre-1b describe --tags --exact-match HEAD 2>/dev/null || git -C /tmp/ulsync-pre-1b log -1 --oneline
```

Ожидание: конфиг OK; коммит соответствует тегу **`pre-round-1b`** (или его потомку без шага hello).

---

### Шаг B — Окно 1: сборка и запуск **legacy**-бинарника

**Новый** терминал. Рабочий каталог — **только** worktree:

```bash
cd /tmp/ulsync-pre-1b
go build -o ulsync-server ./cmd/ulsync-server
rm -f ./data/ulsync_h6.db ./data/ulsync_h6.db-wal ./data/ulsync_h6.db-shm
./ulsync-server -config ./config_h6.yaml
```

**Успех:** `server listening` на `:8085`; процесс не падает.

**Ошибка:** `bind: address already in use` — §3.4.

**Провал H6 (частый):** собрали из `SERVER_ROOT` на ветке `main` — в логе позже появится hello `200`. Пересобрать из `/tmp/ulsync-pre-1b`.

---

### Шаг C — Окно 2: `ACCESS_TOKEN` и whoami

Переменные `SU`, `SAK`, `EMAIL`, `PASSWORD` — в **этом** окне.

**Блок 1 — токен:**

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

**Блок 2 — срок JWT (нужен `python3`):**

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

**Блок 3 — whoami (одной строкой):**

```bash
curl -sS -w '\nHTTP:%{http_code}\n' -H "Authorization: Bearer $ACCESS_TOKEN" http://127.0.0.1:8085/v1/whoami
```

| Блок | Успех | Ошибка |
|---|---|---|
| 1 | `ACCESS_TOKEN получен` | `FAIL: access_token нет` |
| 2 | `OK: ACCESS_TOKEN действителен` | `FAIL: просрочен` |
| 3 | `HTTP:200` | `connection refused` — сервер не на 8085 |
| 3 | | `curl: (2) no URL` — скопировать блок целиком |

---

### Шаг D — Окно 2: контроль — hello **отсутствует** (`404`)

Доказывает, что поднят **legacy**-бинарник, а не `main`.

```bash
curl -sS -w '\nHTTP:%{http_code}\n' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Ulsync-Origin: com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f' \
  http://127.0.0.1:8085/v1/sync/hello
```

| HTTP | Интерпретация |
|---|---|
| **404** (или **405**) | **Успех контроля** — маршрута hello нет |
| **200** с JSON `origin` | **Провал** — это сервер с `main`, не H6 |
| **409** | **Провал** — включён origin-затвор; не legacy |

**Стоп-условие:** только **404/405** перед шагом E.

---

### Шаг E0 — Сброс сессии (рекомендуется)

```bash
adb -s emulator-5554 shell pm clear com.gdetotuta.vfx.counter_schmounter
```

**Успех:** `Success`.

---

### Шаг E — Окно 3: приложение на legacy-сервер

**Новый** терминал:

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
cd /Users/vvk/AndroidStudioProjects/r/counter_schmounter
flutter run -d emulator-5554 \
  --dart-define=SU="$SU" \
  --dart-define=SAK="$SAK" \
  --dart-define=ULSYNC_BASE_URL=http://10.0.2.2:8085
```

**На эмуляторе:**

1. Войти `EMAIL` / `PASSWORD`.
2. Дождаться обмена (несколько секунд).
3. Иконка **«На связи»** — ожидаемый успех H6 (как G6 в 1a).
4. Нажать **плюс** 2–3 раза: локальный счётчик растёт.

**Контроль в окне 3:** приложение **не** крашится; нет красного экрана; нет устойчивого «Нет связи» после успешного входа.

**Контроль в окне 1 (лог сервера):**

| Наблюдение | Вердикт |
|---|---|
| Есть `push` / `pull` / `live` | Норма — обмен идёт |
| **Нет** ответа **`200`** на `GET /v1/sync/hello` | Норма для legacy |
| Есть **`200`** на `/v1/sync/hello` | **Провал** — не тот бинарник |

Клиент **может** слать hello и получать **404** — это не провал. Провал — когда сервер **обрабатывает** hello как в круге 1b (`200`/`409`).

**Контроль в админке:**

| Поле | Ожидание H6 |
|---|---|
| Envelopes | **≥ 1** после плюса |
| Users | Может оставаться **0** (как в H4) — смотрите Envelopes |

---

### Шаг F — Окно 1: остановка сервера

`Ctrl+C` в окне 1. Окно 3: `q` — остановить `flutter run`.

---

### Шаг G — Окно 2: финальная проверка базы

```bash
cd /tmp/ulsync-pre-1b
sqlite3 ./data/ulsync_h6.db "SELECT COUNT(*) FROM envelopes;"
```

| Результат | Вердикт |
|---|---|
| `0` | **Провал** — push не дошёл |
| `≥ 1` | **Успех H6** |

Таблицы `server_meta` с ключом `origin` на `pre-round-1b` **нет** — проверять imprint в SQLite не нужно.

---

## 6. Итоговые критерии

### Успех H6

- [ ] Worktree `/tmp/ulsync-pre-1b` на теге **`pre-round-1b`**.
- [ ] whoami (шаг C): `HTTP:200` на **8085**.
- [ ] Контрольный hello (шаг D): `HTTP:404` или `405`.
- [ ] Приложение: `ULSYNC_BASE_URL=http://10.0.2.2:8085`; нет краша.
- [ ] UI: **«На связи»**; плюс увеличивает счётчик.
- [ ] Админка: **Envelopes ≥ 1**.
- [ ] sqlite3 (шаг G): `COUNT(*) ≥ 1`.
- [ ] В логе сервера **нет** успешного hello `200`.

### Провал H6

- Краш Flutter при входе или плюсе.
- hello (шаг D) → `200` или `409`.
- envelopes остаётся `0` при растущем локальном счётчике.
- Поведение как H4: устойчивое «Нет связи», отказ origin.

---

## 7. Частые сбои

| Симптом | Что проверить |
|---|---|
| hello `200` в шаге D | Собран **`main`**, не worktree — `cd /tmp/ulsync-pre-1b` и пересборка |
| «Нет связи», envelopes 0 | Порт не **8085**; просроченная сессия → E0 + новый вход |
| `token rejected` в логе сервера | E0; новый `flutter run` и вход |
| `curl: (2) no URL specified` | URL не попал при вставке — копировать команду целиком |
| Путают с H4 | H4: `main` + чужой pin → отказ; H6: legacy без hello → обмен |
| Путают с H1 | H1: `main` + hello `200`; H6: legacy + hello `404` |
| Нет тега `pre-round-1b` | §3.2 — стоп, поставить тег по операторскому гайду |
| worktree уже существует с другой веткой | `git -C /tmp/ulsync-pre-1b checkout pre-round-1b` |

---

## 8. Восстановление после сбоя

1. Окно 3: `q`; окно 1: `Ctrl+C`.
2. E0 (`pm clear`).
3. Шаг B: `rm` базы + сервер из **`/tmp/ulsync-pre-1b`**.
4. Шаг C — whoami `200`.
5. Шаг D — hello **`404`**.
6. Шаг E — `flutter run` с `ULSYNC_BASE_URL=http://10.0.2.2:8085`, вход, плюс.
7. Шаг G — `COUNT(*) ≥ 1`.

---

## 9. Уборка

```bash
# Окна 1 и 3: Ctrl+C / q
rm -f /tmp/ulsync-pre-1b/config_h6.yaml
# rm -f /tmp/ulsync-pre-1b/data/ulsync_h6.db*
# Опционально удалить worktree:
# cd /Users/vvk/AndroidStudioProjects/r/ulsync-server && git worktree remove /tmp/ulsync-pre-1b
```

Следующий сценарий: **H7** — `docs/manual_tests/round_1b_H7_yaml_db_origin_conflict_refuse_start.md`.

---

## 10. Связанные артефакты

| Файл | Содержание |
|---|---|
| `lib/src/infrastructure/sync/ulsync_base_url.dart` | `K_ULSYNC_ORIGIN` |
| `ulsync-dart` `http_sync_transport.dart` | `404`/`405` на hello → legacy |
| План 1a, G6 | Аналог для `pre-round-1a` |
| План 1b §5, H6 | Обратная совместимость приложения 26 |
| `docs/manual_tests/round_1b_H1_open_empty_stock.md` | Тот же клиент, но сервер `main` с hello |
