# Ручной тест H5 — curl с чужим Ulsync-Origin (без приложения)

**Дата создания:** 2026-09-16 12:19:23 +0300  
**Последнее обновление:** 2026-09-16 12:27:00 +0300  
**Версия:** 2  
**Вид документа:** инструкция

Круг **1b**, сценарий **H5** из [плана круга 1b](https://github.com/flutter-senior-prep/plan_triad/blob/main/docs/ROUND_1B_TRIAD_PLAN.md) (§5, таблица H5). Проверяет **отказ на стороне сервера** отдельно от Flutter-клиента: авторский склад с pin `K_ULSYNC_ORIGIN`, `curl` шлёт **чужой** заголовок `Ulsync-Origin` → `GET /v1/sync/hello` отвечает **HTTP 409** `origin_mismatch`, конверты **не** пишутся.

Документ **полностью самодостаточен**: не требует прогона H1–H4, эмулятора, Supabase, TEMP или сценариев H6–H7.

---

## 1. Что проверяем

| Критерий | Успех H5 | Провал H5 |
|---|---|---|
| Авторский склад на порту **8084** с `origin:` = `K_ULSYNC_ORIGIN` | JWT dev-HS256 валиден (whoami `200`) | whoami не `200` — проблема auth/mint, не origin |
| `curl` hello с `Ulsync-Origin: K_FOREIGN_ORIGIN` | **HTTP:409**, тело `origin_mismatch` | **HTTP:200** — склад «принял» чужое имя |
| База после отказа | `SELECT COUNT(*) FROM envelopes` = **0** | В `envelopes` появились строки |
| Flutter | **Не запускать** — не участвует в H5 | Запуск приложения смешивает сценарии H3/H4 |

### 1.1. Чем H5 отличается от H4

| | H4 (приложение) | H5 (curl) |
|---|---|---|
| Клиент | Flutter с `K_ULSYNC_ORIGIN` | Только `curl` с Mac |
| `origin:` в yaml | **Чужой** `K_FOREIGN_ORIGIN` | **Свой** `K_ULSYNC_ORIGIN` |
| Заголовок `Ulsync-Origin` | От приложения (`K_ULSYNC_ORIGIN`) | От curl (**чужой** `K_FOREIGN_ORIGIN`) |
| Auth | Supabase JWT (`jwks_url`) | Dev HS256 (`dev_hs256_secret`) |
| Порт | 8083 / админка 8184 | 8084 / админка 8185 |
| Успех | envelopes 0, «Нет связи» | hello `409`, envelopes 0 |
| Что доказывает | Клиент отказывает до push | **Сервер** отказывает на hello до любой почты |

**Не проверяем в H5:** push/pull с телом конверта, live SSE, старый сервер без hello (H6), конфликт yaml vs база (H7).

---

## 2. Словарь переменных и констант

Подставляйте **свои** значения только где указано `YOUR_*`. `config_h5.yaml` и `/tmp/mint_dev_jwt.go` **не коммитить**.

### 2.1. Пути на диске (фиксированные для H5)

| Символ | Значение | Назначение |
|---|---|---|
| `SERVER_ROOT` | `/Users/vvk/AndroidStudioProjects/r/ulsync-server` | Корень Go-сервера ulsync |
| `DB_FILE` | `./data/ulsync_h5.db` | SQLite **только** для H5; удаляется перед прогоном |
| `CONFIG_FILE` | `./config_h5.yaml` | Конфиг сервера для H5; создаётся вручную |
| `MINT_SCRIPT` | `/tmp/mint_dev_jwt.go` | Одноразовый mint JWT; можно удалить после прогона |

### 2.2. Порты и URL

| Имя | Значение | Назначение |
|---|---|---|
| `SYNC_PORT` | `8084` | HTTP API sync |
| `SYNC_BASE_URL` | `http://127.0.0.1:8084` | Все `curl` с Mac — только loopback |
| `ADMIN_PORT` | `8185` | Админка: `http://127.0.0.1:8185/admin` |
| `HELLO_URL` | `http://127.0.0.1:8084/v1/sync/hello` | Целевой endpoint H5 |
| `WHOAMI_URL` | `http://127.0.0.1:8084/v1/whoami` | Контроль auth без origin |

Эмулятор, `10.0.2.2`, `ULSYNC_BASE_URL` в H5 **не используются**.

### 2.3. Две строки происхождения — сердце H5

| Имя | Значение | Где задаётся |
|---|---|---|
| `K_ULSYNC_ORIGIN` | `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f` | Ключ `origin:` в `config_h5.yaml`; pin авторского склада |
| `K_FOREIGN_ORIGIN` | `com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee` | Заголовок `Ulsync-Origin` в **целевом** curl (шаг E) |

**Условие H5:** `K_ULSYNC_ORIGIN` ≠ `K_FOREIGN_ORIGIN`. Третий выдуманный UUID в этом круге **не** использовать — только эти два литерала.

На authored-складе сервер сравнивает заголовок с pin из yaml → чужой заголовок → **409** до imprint и до push.

### 2.4. Dev-auth (без Supabase)

| Переменная | Значение | Назначение |
|---|---|---|
| `DEV_HS256_SECRET` | `local-dev-only` | Поле `auth.dev_hs256_secret` в yaml; ключ подписи mint |
| `TOKEN` | JWT из `go run` (шаг A) | `Authorization: Bearer` во всех curl |
| `TOKEN_SUB` | `alice` (по умолчанию) | Claim `sub` в mint; виден в whoami |

`SU`, `SAK`, `EMAIL`, `PASSWORD`, эмулятор в H5 **не нужны**.

### 2.5. Ветки git

| Репозиторий | Ветка |
|---|---|
| `ulsync-server` | `main` после шагов 24+ |

Приложение `counter_schmounter` для H5 **не собирать**.

### 2.6. Мониторинг

Админка `http://127.0.0.1:8185/admin`:

| Поле | Успех H5 |
|---|---|
| **Store origin** | `K_ULSYNC_ORIGIN` (из yaml), **не** `K_FOREIGN_ORIGIN` |
| **Envelopes** | **0** |
| **4xx** | Может расти после шага E — это **ожидаемо** (повторные 409) |
| **Last error** | `origin_mismatch` / `409` — норма |

Терминал сервера (окно 1) может молчать — смотрите **ответ curl** и админку.

---

## 3. Предусловия (проверить до начала)

### 3.1. Инструменты в PATH

```bash
which go curl sqlite3
```

**Успех:** три строки с путями.

**Ошибка:** `... not found` — установить / добавить в `PATH`.

### 3.2. Порт 8084 свободен

```bash
lsof -nP -iTCP:8084 -sTCP:LISTEN
```

**Успех:** **пустой** вывод.

**Ошибка:** процесс слушает 8084 — `Ctrl+C` в том терминале или `kill <pid>`.

Серверы H1–H4 на других портах могут работать параллельно — H5 использует **только 8084**.

### 3.3. Flutter и эмулятор **не** запущены для H5

```bash
pgrep -fl "flutter run" || echo "flutter run не найден — OK для H5"
```

**Успех:** нет активного `flutter run` на этом сценарии (или вы сознательно не трогаете H5, пока гоняете другое).

---

## 4. Раскладка окон

| Окно | Назначение | Процесс висит |
|---|---|---|
| **1** | `./ulsync-server -config ./config_h5.yaml` | Да, до шага F |
| **2** | yaml, mint `TOKEN`, curl, sqlite3 | Нет |
| **Браузер** | `http://127.0.0.1:8185/admin` | — |

**Критично:** `TOKEN` mint-ится в окне 2 **до** запуска сервера в окне 1 и остаётся в shell окна 2. Не запускайте сервер в том же окне, где делаете `export TOKEN=...` — иначе переменная «запрётся» в фоне.

---

## 5. Пошаговое выполнение

### Шаг A — Окно 2: конфиг и mint `TOKEN`

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
mkdir -p ./data
cat > ./config_h5.yaml <<'EOF'
server:
  bind: "0.0.0.0:8084"
  read_header_timeout: "5s"
  idle_timeout: "120s"
  max_body_bytes: 1048576

storage:
  driver: "sqlite"
  path: "./data/ulsync_h5.db"

origin: "com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f"

auth:
  jwks_url: ""
  jwks_file: ""
  jwks_cache_ttl: "10m"
  allowed_algs: ["ES256", "RS256", "HS256"]
  audience: []
  issuer: ""
  dev_hs256_secret: "local-dev-only"

sync:
  max_envelopes_per_push: 1
  pull_limit_default: 100
  pull_limit_max: 500
  live_poll_timeout: "55s"
  live_heartbeat: "15s"

admin:
  bind: "127.0.0.1:8185"
  token: ""
EOF
```

**Разбор ключевых полей:**

| Поле | Значение | Зачем |
|---|---|---|
| `server.bind` | `0.0.0.0:8084` | Sync на порту H5 |
| `origin:` | `K_ULSYNC_ORIGIN` | **Авторский** склад — pin приложения |
| `auth.dev_hs256_secret` | `local-dev-only` | Mint JWT без Supabase |
| `auth.jwks_url` | `""` | JWKS отключён |
| `storage.path` | `./data/ulsync_h5.db` | Отдельный файл |
| `admin.bind` | `127.0.0.1:8185` | Админка на Mac |

**Успех конфига:**

```bash
test -f ./config_h5.yaml && echo "config_h5.yaml OK"
```

**Блок mint — создать скрипт и получить `TOKEN`:**

```bash
cat >/tmp/mint_dev_jwt.go <<'EOF'
package main

import (
	"fmt"
	"os"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

func main() {
	sub := "alice"
	if len(os.Args) > 1 {
		sub = os.Args[1]
	}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.RegisteredClaims{
		Subject:   sub,
		ExpiresAt: jwt.NewNumericDate(time.Now().Add(time.Hour)),
		IssuedAt:  jwt.NewNumericDate(time.Now()),
	})
	s, err := t.SignedString([]byte("local-dev-only"))
	if err != nil {
		panic(err)
	}
	fmt.Print(s)
}
EOF
export TOKEN="$(go run /tmp/mint_dev_jwt.go)"
case "$TOKEN" in
  eyJ*) echo "TOKEN получен, длина ${#TOKEN}" ;;
  *) echo "FAIL: mint не дал JWT. Запускай go run из корня ulsync-server (нужен go.mod с jwt/v5)."; return 1 ;;
esac
```

| Блок | Успех | Ошибка |
|---|---|---|
| Конфиг | `config_h5.yaml OK` | Файл не создан — повторить `cat >` |
| Mint | `TOKEN получен, длина ...` | `FAIL: mint не дал JWT` — нет Go-модуля / нет сети для `go run` |
| Mint | | `cannot find package` — выполнять из `SERVER_ROOT` |

---

### Шаг B — Окно 1: сервер с чистой базой

**Новый** терминал. `TOKEN` здесь **не** нужен.

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
git checkout main && git pull
go build -o ulsync-server ./cmd/ulsync-server
rm -f ./data/ulsync_h5.db ./data/ulsync_h5.db-wal ./data/ulsync_h5.db-shm
./ulsync-server -config ./config_h5.yaml
```

**Успех:** `server listening` на `:8084`; процесс не падает.

**Ошибка:** `bind: address already in use` — §3.2.

---

### Шаг C — Окно 2: whoami (контроль auth)

`TOKEN` должен быть **уже** экспортирован в этом окне (шаг A).

**Выполнить одной командой (URL на той же строке):**

```bash
curl -sS -w '\nHTTP:%{http_code}\n' -H "Authorization: Bearer $TOKEN" http://127.0.0.1:8084/v1/whoami
```

| Результат | Интерпретация |
|---|---|
| `HTTP:200`, в теле `user_id` (напр. `alice`) | Auth OK — можно проверять origin |
| `HTTP:401` | Неверный `TOKEN` или секрет в yaml ≠ `local-dev-only` |
| `connection refused` | Сервер H5 не на 8084 |
| `curl: (2) no URL specified` | URL не попал при вставке — скопировать команду целиком |

**Стоп-условие:** whoami `200` **до** hello. Иначе чините mint/auth, не origin.

---

### Шаг D — Окно 2: контрольный hello со **своим** origin

Проверяет, что authored-склад **живой** и принимает правильный заголовок.

```bash
curl -sS -w '\nHTTP:%{http_code}\n' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Ulsync-Origin: com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f' \
  http://127.0.0.1:8084/v1/sync/hello
```

| Результат | Интерпретация |
|---|---|
| `HTTP:200` | В теле `"origin": "com.gdetotuta.vfx.counter_schmounter/..."` и `"user_id": "alice"` — **норма** |
| `HTTP:409` | Pin в yaml не тот или заголовок опечатан |
| `HTTP:400` `origin_required` | Пустой/битый заголовок |

Этот шаг **не** цель H5, но отделяет «сломан auth» от «сломан отказ чужому origin».

---

### Шаг E — Окно 2: **целевой** hello с **чужим** origin (суть H5)

```bash
curl -sS -w '\nHTTP:%{http_code}\n' \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Ulsync-Origin: com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee' \
  http://127.0.0.1:8084/v1/sync/hello
```

**Успех H5 — ожидаемый ответ:**

```text
{
  "error": "origin_mismatch",
  "store_origin": "com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f",
  "request_origin": "com.example.other/aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee"
}
HTTP:409
```

| Код / поле | Успех H5 | Провал H5 |
|---|---|---|
| HTTP | **409** | **200** |
| `error` | `origin_mismatch` | нет / другое |
| `store_origin` | `K_ULSYNC_ORIGIN` | стал `K_FOREIGN_ORIGIN` |
| `request_origin` | `K_FOREIGN_ORIGIN` | — |

**Контроль в админке** (пока сервер крутится):

| Поле | Ожидание |
|---|---|
| Store origin | `K_ULSYNC_ORIGIN` |
| Envelopes | **0** |
| 4xx | Может быть 1+ после шага E — норма |

Повторные вызовы шага E снова дают **409** — склад **не** приручается чужим именем.

---

### Шаг F — Окно 1: остановка сервера

`Ctrl+C` в окне 1.

---

### Шаг G — Окно 2: финальная проверка базы

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
sqlite3 ./data/ulsync_h5.db "SELECT v FROM server_meta WHERE k='origin';"
sqlite3 ./data/ulsync_h5.db "SELECT COUNT(*) FROM envelopes;"
```

| Запрос | Успех H5 |
|---|---|
| `origin` | `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f` |
| `COUNT(*)` | `0` |

---

## 6. Итоговые критерии

### Успех H5

- [ ] whoami (шаг C): `HTTP:200` на порту **8084**.
- [ ] Контрольный hello (шаг D): `HTTP:200` с `K_ULSYNC_ORIGIN` в теле.
- [ ] Целевой hello (шаг E): `HTTP:409`, `error: origin_mismatch`, `store_origin` = `K_ULSYNC_ORIGIN`, `request_origin` = `K_FOREIGN_ORIGIN`.
- [ ] Админка: **Envelopes** = **0**; **Store origin** = `K_ULSYNC_ORIGIN`.
- [ ] sqlite3 (шаг G): `COUNT(*) = 0`; origin не сменился на `K_FOREIGN_ORIGIN`.
- [ ] Flutter **не** запускался в этом прогоне.

### Провал H5

- Шаг E: `HTTP:200` на чужом `Ulsync-Origin`.
- `server_meta.origin` стал `K_FOREIGN_ORIGIN`.
- В `envelopes` есть строки.

---

## 7. Частые сбои

| Симптом | Что проверить |
|---|---|
| whoami `401` | `dev_hs256_secret` в yaml = `local-dev-only`; mint после правки yaml |
| Шаг D `409`, шаг E не дошли | `origin:` в yaml — должен быть `K_ULSYNC_ORIGIN`, не `K_FOREIGN_ORIGIN` (это H4-раскладка) |
| Шаг E `200` | **Провал H5** — сервер принял чужой origin |
| `curl: (2) no URL specified` | URL не попал при вставке — копировать команду целиком |
| `TOKEN` пустой в окне 2 | Mint делали в другом терминале — повторить шаг A |
| Путают с H4 | H4: чужой pin в yaml + приложение; H5: свой pin + curl с чужим заголовком |
| Путают с H3 | H3: нет `origin:` в yaml, hello приручает; H5: authored, чужой заголовок → 409 |
| Высокий % 4xx в админке | Норма после нескольких hello с чужим origin |

---

## 8. Восстановление после сбоя

1. Окно 1: `Ctrl+C`.
2. Шаг A заново: конфиг + mint `TOKEN` в окне 2.
3. Шаг B: `rm` базы + сервер.
4. Шаг C — whoami `200`.
5. Шаг D — hello свой origin `200`.
6. Шаг E — hello чужой origin `409`.
7. Шаг G — `COUNT(*) = 0`.

---

## 9. Уборка

```bash
# Окно 1: Ctrl+C (если ещё крутится)
rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/config_h5.yaml
rm -f /tmp/mint_dev_jwt.go
# rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/data/ulsync_h5.db*
```

Следующий сценарий: **H6** — `docs/manual_tests/round_1b_H6_legacy_server_no_hello.md`.

---

## 10. Связанные артефакты

| Файл | Содержание |
|---|---|
| `lib/src/infrastructure/sync/ulsync_base_url.dart` | Литерал `K_ULSYNC_ORIGIN` (в H5 только в yaml) |
| `ulsync-server/internal/httpapi/origin.go` | Ответ `409` / `origin_mismatch` |
| План 1b §5, H5 | Отказ сервера без клиента |
| `docs/manual_tests/round_1b_H4_authored_foreign_origin_refuse.md` | Зеркальный сценарий через Flutter |
