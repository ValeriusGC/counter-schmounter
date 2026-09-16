# Ручной тест H7 — конфликт origin в yaml и базе, процесс не стартует

**Дата создания:** 2026-09-16 12:44:41 +0300  
**Последнее обновление:** 2026-09-16 12:44:41 +0300  
**Версия:** 1  
**Вид документа:** инструкция

Круг **1b**, сценарий **H7** из [плана круга 1b](https://github.com/flutter-senior-prep/plan_triad/blob/main/docs/ROUND_1B_TRIAD_PLAN.md) (§5, таблица H7). Проверяет **затвор при старте процесса**: в SQLite уже записано происхождение приложения (`K_ULSYNC_ORIGIN`), в `config.yaml` указан **чужой** pin (`K_FOREIGN_ORIGIN`) → `ulsync-server` **не доходит** до `server listening` и завершается с кодом **≠ 0**.

Документ **полностью самодостаточен**: не требует прогона H1–H6, Flutter, эмулятора, TEMP.

---

## 1. Что проверяем

| Критерий | Успех H7 | Провал H7 |
|---|---|---|
| **Фаза A:** открытый склад, hello с `K_ULSYNC_ORIGIN` | `HTTP:200`; в `server_meta` — строка приложения | hello не `200` или imprint пустой |
| **Фаза B:** тот же файл базы, yaml с `origin: K_FOREIGN_ORIGIN` | Процесс **сразу выходит**; **нет** `server listening` | Процесс **висит** на `:8086` |
| Лог фазы B | Сообщение `authored store origin does not match database` и **обе** строки origin | Старт без ошибки |
| База после фазы B | `server_meta.origin` = `K_ULSYNC_ORIGIN` (не перезаписан) | Стал `K_FOREIGN_ORIGIN` |

### 1.1. Чем H7 отличается от H4/H5

| | H4 / H5 (runtime) | H7 (startup) |
|---|---|---|
| Где конфликт | Запрос vs pin склада **во время** hello | Pin в yaml vs значение **в базе** при **старте** |
| Клиент | Flutter (H4) или curl (H5) | Только **curl** в фазе A; фаза B — **только** сервер |
| Когда отказ | HTTP `409` на hello | **До** `server listening` |
| Что доказывает | Нельзя синхронизировать чужой authored-склад | Нельзя **поднять** процесс на томе другого контура |

**Не проверяем в H7:** imprint через приложение, live-sync, второй эмулятор.

### 1.2. Механизм (для понимания)

При старте `main` вызывает `BindAuthoredOrigin`: если в `config` задан непустой `origin:` и в `server_meta` уже **другое** значение — процесс логирует ошибку и возвращает код `1`. База **не** перезаписывается.

---

## 2. Словарь переменных и констант

Подставляйте **свои** значения в `YOUR_*`. `config_h7a.yaml`, `config_h7b.yaml` **не коммитить**.

### 2.1. Пути на диске (фиксированные для H7)

| Символ | Значение | Назначение |
|---|---|---|
| `SERVER_ROOT` | `/Users/vvk/AndroidStudioProjects/r/ulsync-server` | Сборка с ветки **`main`** (шаги 24+) |
| `DB_FILE` | `./data/ulsync_h7.db` | **Один** файл для обеих фаз; между фазами **не удалять** |
| `CONFIG_A` | `./config_h7a.yaml` | Фаза A: открытый склад (без `origin:`) |
| `CONFIG_B` | `./config_h7b.yaml` | Фаза B: authored с чужим pin |

### 2.2. Порты и URL

| Имя | Значение | Назначение |
|---|---|---|
| `SYNC_PORT` | `8086` | HTTP API (обе фазы — один порт) |
| `ADMIN_PORT` | `8187` | Админка: `http://127.0.0.1:8187/admin` |
| `HELLO_URL` | `http://127.0.0.1:8086/v1/sync/hello` | Imprint в фазе A |
| `WHOAMI_URL` | `http://127.0.0.1:8086/v1/whoami` | Контроль auth |

### 2.3. Две строки происхождения

| Имя | Значение | Где в H7 |
|---|---|---|
| `K_ULSYNC_ORIGIN` | `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f` | Заголовок curl hello (фаза A); ожидаемое значение в `server_meta` |
| `K_FOREIGN_ORIGIN` | `com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee` | Ключ `origin:` в **`config_h7b.yaml`** (фаза B) |

**Условие H7:** после фазы A в базе `K_ULSYNC_ORIGIN`, в фазе B yaml требует `K_FOREIGN_ORIGIN` → конфликт при старте.

### 2.4. Секреты Supabase

| Переменная | Что подставить | Где |
|---|---|---|
| `SU` | `https://YOUR_PROJECT.supabase.co` | `jwks_url` в yaml |
| `SAK` | `YOUR_ANON_KEY` | `apikey` в curl |
| `EMAIL` | Email тестового пользователя | curl |
| `PASSWORD` | Пароль | curl |
| `ACCESS_TOKEN` | JWT из curl (шаг C) | whoami, hello |

Dev HS256 из H5 **не** используется.

### 2.5. Ветки git

| Репозиторий | Ветка |
|---|---|
| `ulsync-server` | `main` после шагов 24+ (`BindAuthoredOrigin`, hello) |

Приложение `counter_schmounter` для H7 **не нужно**.

### 2.6. Мониторинг

| Фаза | Где смотреть |
|---|---|
| A (сервер работает) | Ответ curl; админка `8187` (Envelopes могут остаться 0) |
| B (отказ старта) | **Только** stdout/stderr окна 1 и `echo $?` — админка **не** откроется |

Терминал фазы A после `server listening` может **молчать** — это норма (как в H6).

---

## 3. Предусловия (проверить до начала)

### 3.1. Инструменты в PATH

```bash
which go curl sqlite3 git
```

**Успех:** четыре строки с путями.

### 3.2. Порт 8086 свободен

```bash
lsof -nP -iTCP:8086 -sTCP:LISTEN
```

**Успех:** **пустой** вывод.

### 3.3. Сервер на `main` с origin-затвором

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
git checkout main && git pull
test -f internal/store/origin.go && echo "origin.go OK"
```

**Успех:** `origin.go OK`. **Стоп**, если файла нет — это не код шага 24+.

---

## 4. Раскладка окон

| Окно | Назначение | Процесс висит |
|---|---|---|
| **1** | Фаза A: сервер; фаза B: **попытка** старта (должна сразу завершиться) | A — да; B — **нет** |
| **2** | Секреты, yaml, curl, sqlite3 | Нет |

---

## 5. Пошаговое выполнение

### Шаг A — Окно 2: секреты и **два** конфига

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
export EMAIL='YOUR_EMAIL'
export PASSWORD='YOUR_PASSWORD'
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
mkdir -p ./data
```

**Конфиг фазы A** — открытый склад, **без** `origin:`:

```bash
cat > ./config_h7a.yaml <<EOF
server:
  bind: "0.0.0.0:8086"
  read_header_timeout: "5s"
  idle_timeout: "120s"
  max_body_bytes: 1048576

storage:
  driver: "sqlite"
  path: "./data/ulsync_h7.db"

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
  bind: "127.0.0.1:8187"
  token: ""
EOF
```

**Конфиг фазы B** — тот же `storage.path`, **чужой** `origin:`:

```bash
cat > ./config_h7b.yaml <<EOF
server:
  bind: "0.0.0.0:8086"
  read_header_timeout: "5s"
  idle_timeout: "120s"
  max_body_bytes: 1048576

storage:
  driver: "sqlite"
  path: "./data/ulsync_h7.db"

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
  bind: "127.0.0.1:8187"
  token: ""
EOF
```

**Разбор:**

| Файл | `origin:` | `storage.path` |
|---|---|---|
| `config_h7a.yaml` | **нет** (открытый склад) | `./data/ulsync_h7.db` |
| `config_h7b.yaml` | `K_FOREIGN_ORIGIN` | **тот же** файл |

**Успех:**

```bash
test -f ./config_h7a.yaml && test -f ./config_h7b.yaml && echo "config_h7a.yaml + config_h7b.yaml OK"
```

---

### Шаг B — Окно 1: фаза A — сервер с **чистой** базой

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
go build -o ulsync-server ./cmd/ulsync-server
rm -f ./data/ulsync_h7.db ./data/ulsync_h7.db-wal ./data/ulsync_h7.db-shm
./ulsync-server -config ./config_h7a.yaml
```

**Успех:** `server listening` на `:8086`; процесс **висит**.

**Ошибка:** `bind: address already in use` — §3.2.

---

### Шаг C — Окно 2: `ACCESS_TOKEN`, whoami, hello (imprint)

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
  *) echo "FAIL: access_token нет."; return 1 ;;
esac
```

**Блок 2 — whoami (одной строкой):**

```bash
curl -sS -w '\nHTTP:%{http_code}\n' -H "Authorization: Bearer $ACCESS_TOKEN" http://127.0.0.1:8086/v1/whoami
```

**Блок 3 — hello с `K_ULSYNC_ORIGIN` (imprint в базу):**

```bash
curl -sS -w '\nHTTP:%{http_code}\n' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Ulsync-Origin: com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f' \
  http://127.0.0.1:8086/v1/sync/hello
```

| Блок | Успех фазы A | Ошибка |
|---|---|---|
| 1 | `ACCESS_TOKEN получен` | `FAIL: access_token нет` |
| 2 | `HTTP:200` | `connection refused` — сервер не на 8086 |
| 3 | `HTTP:200`, в теле `"origin": "com.gdetotuta.vfx.counter_schmounter/..."` | `409` / `401` — стоп, фазу B не начинать |

**Стоп-условие:** hello фазы A = **`200`**. Базу **`ulsync_h7.db` не удалять** до конца теста.

---

### Шаг D — Окно 2: проверка imprint в SQLite

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
sqlite3 ./data/ulsync_h7.db "SELECT v FROM server_meta WHERE k='origin';"
```

**Успех — ровно одна строка:**

```text
com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f
```

| Вывод | Действие |
|---|---|
| Строка `K_ULSYNC_ORIGIN` | Идти на фазу B |
| Пусто / другая строка | **Стоп** — повторить фазу A с `rm` базы |

---

### Шаг E — Окно 1: остановить сервер фазы A

`Ctrl+C` в окне 1. Дождаться выхода процесса.

Порт 8086 должен освободиться:

```bash
lsof -nP -iTCP:8086 -sTCP:LISTEN
```

**Успех:** пустой вывод.

---

### Шаг F — Окно 1: фаза B — попытка старта с **чужим** pin

**Тот же** бинарник, **та же** база, **другой** конфиг:

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
./ulsync-server -config ./config_h7b.yaml
echo "exit code: $?"
```

**Успех H7 (фаза B):**

1. Процесс **не** печатает `server listening`.
2. Сразу возвращает управление в shell (или после одной-двух JSON-строк ошибки).
3. `exit code: 1` (или любой **не 0**).

**Пример ожидаемого лога** (поля JSON могут отличаться порядком):

```text
{"level":"ERROR","msg":"authored store origin does not match database","config_origin":"com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee","error":"authored origin \"com.example.other/...\" does not match stored origin \"com.gdetotuta.vfx.counter_schmounter/...\" in server_meta"}
exit code: 1
```

В логе должны присутствовать **обе** строки:

- `com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee` (`config_origin` / authored)
- `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f` (stored)

**Провал H7:**

- Появилось `server listening` — процесс **висит** → `Ctrl+C`, см. шаг G.
- `exit code: 0`.

---

### Шаг G — Окно 2: база **не** перезаписана

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
sqlite3 ./data/ulsync_h7.db "SELECT v FROM server_meta WHERE k='origin';"
```

| Результат | Вердикт |
|---|---|
| `K_ULSYNC_ORIGIN` | **Успех H7** — чужой pin не применился |
| `K_FOREIGN_ORIGIN` | **Провал** — база перезаписана |

---

## 6. Итоговые критерии

### Успех H7

- [ ] Фаза A: whoami `200`; hello `200` с `K_ULSYNC_ORIGIN`.
- [ ] После фазы A: sqlite3 → `K_ULSYNC_ORIGIN`.
- [ ] Фаза B: **нет** `server listening`; `exit code ≠ 0`.
- [ ] Лог фазы B: `authored store origin does not match database` + обе строки origin.
- [ ] После фазы B: sqlite3 → по-прежнему `K_ULSYNC_ORIGIN`.
- [ ] Flutter **не** запускался.

### Провал H7

- Фаза B: сервер слушает `:8086`.
- `server_meta.origin` стал `K_FOREIGN_ORIGIN`.
- Фаза A: imprint не записался.

---

## 7. Частые сбои

| Симптим | Что проверить |
|---|---|
| Фаза B: `server listening` | Собран старый бинарник без `BindAuthoredOrigin`; `go build` на `main` |
| Фаза A hello не `200` | JWKS / токен; сервер на `config_h7a.yaml` |
| sqlite пустой после A | hello не прошёл; не переходить к B |
| Удалили базу между фазами | H7 невалиден — начать с шага B (`rm` + фаза A) |
| `curl: (2) no URL` | URL не попал при вставке — копировать блок целиком |
| Путают с H4 | H4: runtime 409 от приложения; H7: отказ **до** listen |
| Путают с H5 | H5: yaml свой, заголовок чужой; H7: **база** своя, yaml чужой |
| WARN JWKS при старте A | Как в H6 — если whoami/hello `200`, продолжать |

---

## 8. Восстановление после сбоя

1. Окно 1: `Ctrl+C`, если процесс завис на фазе B.
2. `rm -f ./data/ulsync_h7.db ./data/ulsync_h7.db-wal ./data/ulsync_h7.db-shm`
3. Шаг B — фаза A заново.
4. Шаг C — hello `200`.
5. Шаг D — imprint в sqlite.
6. Шаг E — остановить A.
7. Шаг F — фаза B, `exit code ≠ 0`.
8. Шаг G — origin не сменился.

---

## 9. Уборка

```bash
rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/config_h7a.yaml
rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/config_h7b.yaml
# rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/data/ulsync_h7.db*
```

Это **последний** ручной сценарий круга 1b (H1–H7). Дальше — автотесты приложения (`flutter analyze`, `flutter test`) по `definition_of_done`.

---

## 10. Связанные артефакты

| Файл | Содержание |
|---|---|
| `ulsync-server/cmd/ulsync-server/main.go` | `BindAuthoredOrigin` при старте |
| `ulsync-server/internal/store/origin.go` | Сравнение yaml vs `server_meta` |
| План 1b §5, H7 | Затвор «не поднять процесс на чужом томе» |
| `docs/manual_tests/round_1b_H4_authored_foreign_origin_refuse.md` | Runtime-отказ (противоположный момент жизненного цикла) |
| `docs/manual_tests/round_1b_H5_curl_foreign_origin_refuse.md` | Runtime 409 на hello через curl |
