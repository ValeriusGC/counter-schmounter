# Ручной тест H2 — тот же склад, другой URL, то же происхождение

**Дата создания:** 2026-09-15 18:14:54 +0300  
**Последнее обновление:** 2026-09-15 18:27:16 +0300  
**Версия:** 3  
**Вид документа:** инструкция

Круг **1b**, сценарий **H2** из [плана круга 1b](https://github.com/flutter-senior-prep/plan_triad/blob/main/docs/ROUND_1B_TRIAD_PLAN.md) (§5, таблица H2). Проверяет, что **происхождение склада не зависит от строки URL**: одно и то же приложение с константой `kUlsyncOrigin` ходит на **один** процесс `ulsync-server` и **один** файл базы по двум разным адресам хоста, обмен не ломается и `origin` в `server_meta` не меняется.

Документ **полностью самодостаточен**: не требует прогона H1, TEMP или других сценариев H3–H7. Imprint открытого склада выполняется в **фазе A** этого теста.

---



## 1. Что проверяем


| Критерий                                                                                               | Успех                                                                            | Провал                                                                        |
| ------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------- | ----------------------------------------------------------------------------- |
| Фаза A: URL `http://10.0.2.2:8080`                                                                     | Hello приручает склад, плюс уходит на сервер, в базе верный `origin`             | Пустой `origin`, отказ обмена                                                 |
| Фаза B: URL `http://${HOST_LAN_IP}:8080` (IPv4 Mac в Wi‑Fi/Ethernet, напр. `http://192.168.1.42:8080`) | Тот же сервер и та же база; плюс снова уходит; **нет** `OriginMismatchException` | HTTP `409` / `origin_mismatch`, другая строка в `server_meta`, плюс не уходит |
| Инвариант                                                                                              | `origin` в базе **один и тот же** до и после смены URL                           | В происхождение «попал» адрес или hostname                                    |


**Не проверяем в H2:** второй эмулятор и live между устройствами (это H1), чужой склад (H4), второй процесс сервера (H3).

**Почему два URL.** Фаза A: `http://10.0.2.2:8080` — служебный адрес Android Emulator («достучись до loopback Mac-хозяина»). Фаза B: `http://${HOST_LAN_IP}:8080`, где `HOST_LAN_IP` — IPv4-адрес **вашего Mac** в локальной сети (команда `ipconfig getifaddr en0`; у вас может быть, например, `192.168.1.42`, не копируйте чужой). Другая строка hostname, тот же процесс на `0.0.0.0:8080`. Если при смене URL сервер отвечает `409`, в константу происхождения ошибочно включили сетевой адрес. Подробно — §2.8.

---



## 2. Словарь переменных и констант

Подставляйте **свои** значения в `YOUR_`*. `config_h2.yaml` **не коммитить**.

### 2.1. Пути на диске (фиксированные для H2)


| Символ        | Значение                                                | Назначение                                                 |
| ------------- | ------------------------------------------------------- | ---------------------------------------------------------- |
| `APP_ROOT`    | `/Users/vvk/AndroidStudioProjects/r/counter_schmounter` | Корень Flutter-приложения                                  |
| `SERVER_ROOT` | `/Users/vvk/AndroidStudioProjects/r/ulsync-server`      | Корень Go-сервера ulsync                                   |
| `DB_FILE`     | `./data/ulsync_h2.db`                                   | SQLite **только** для H2; удаляется один раз перед фазой A |
| `CONFIG_FILE` | `./config_h2.yaml`                                      | Конфиг сервера для H2; создаётся вручную                   |




### 2.2. Порты и URL


| Имя           | Значение                     | Назначение                                                                        |
| ------------- | ---------------------------- | --------------------------------------------------------------------------------- |
| `SYNC_PORT`   | `8080`                       | HTTP API sync; bind `0.0.0.0:8080` — слушает все интерфейсы Mac                   |
| `ADMIN_PORT`  | `8182`                       | Админка: `http://127.0.0.1:8182/admin` (порт свой у H2, чтобы не пересечься с H1) |
| `URL_PHASE_A` | `http://10.0.2.2:8080`       | Default для Android-эмулятора без `ULSYNC_BASE_URL`                               |
| `URL_PHASE_B` | `http://${HOST_LAN_IP}:8080` | Явный `--dart-define=ULSYNC_BASE_URL=...`                                         |



| Адрес                                          | Где работает                                                           | В H2                                           |
| ---------------------------------------------- | ---------------------------------------------------------------------- | ---------------------------------------------- |
| `10.0.2.2`                                     | Внутри Android Emulator → Mac loopback                                 | Фаза A                                         |
| `127.0.0.1`                                    | Loopback **внутри** эмулятора (не Mac)                                 | **Запрещён** — не достучится до сервера на Mac |
| `HOST_LAN_IP` (`en0` Wi‑Fi или `en1` Ethernet) | IPv4 Mac в LAN, напр. `192.168.1.42`; URL `http://${HOST_LAN_IP}:8080` | Фаза B                                         |


Подробная схема двух URL — **§2.8** (обязательно прочитать перед фазой B).

### 2.3. Происхождение склада


| Имя               | Значение                                                                    |
| ----------------- | --------------------------------------------------------------------------- |
| `K_ULSYNC_ORIGIN` | `com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f` |


Константа `kUlsyncOrigin` в `lib/src/infrastructure/sync/ulsync_base_url.dart`. Менять UUID между прогонами круга 1b нельзя.

В `config_h2.yaml` **нет** ключа `origin:` — открытый склад.

### 2.4. Секреты Supabase


| Переменная     | Что подставить                                                                       | Где используется                                      |
| -------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------- |
| `SU`           | `https://YOUR_PROJECT.supabase.co`                                                   | `flutter run --dart-define=SU=...`; `jwks_url` в yaml |
| `SAK`          | `YOUR_ANON_KEY`                                                                      | `--dart-define=SAK=...`; заголовок `apikey` в curl    |
| `EMAIL`        | Email тестового пользователя                                                         | curl и вход в приложении                              |
| `PASSWORD`     | Пароль пользователя                                                                  | То же                                                 |
| `ACCESS_TOKEN` | JWT из curl (шаг C)                                                                  | whoami с Mac; админка                                 |
| `HOST_LAN_IP`  | IPv4 Mac в LAN: `ipconfig getifaddr en0` (или `en1`); пример значения `192.168.1.42` | Фаза B → `ULSYNC_BASE_URL=http://${HOST_LAN_IP}:8080` |




### 2.4.1. Два разных токена


| Токен                 | Откуда                                        | Кто использует                |
| --------------------- | --------------------------------------------- | ----------------------------- |
| `ACCESS_TOKEN` (curl) | Свежий запрос к Supabase в шаге C             | whoami, Check token в админке |
| Сессия приложения     | Хранилище на эмуляторе после прошлых запусков | ulsync с эмулятора            |


whoami `200` **не доказывает**, что приложение шлёт валидный JWT. Просроченная сессия → `token rejected` / `token is expired` в логе сервера, локальный плюс без push.

Перед прогоном — шаг **E0** (`pm clear`).

### 2.5. Эмулятор


| Идентификатор   | Роль                         |
| --------------- | ---------------------------- |
| `emulator-5554` | Единственное устройство в H2 |


Проверка id:

```bash
flutter devices
```



### 2.6. Ветки git


| Репозиторий          | Ветка                                                           |
| -------------------- | --------------------------------------------------------------- |
| `counter_schmounter` | `spike/32-26-origin` (или ветка шага 26 от `spike/ulsync-test`) |
| `ulsync-server`      | `main` после шагов 24+                                          |




### 2.7. Мониторинг: терминал сервера vs админка

`ulsync-server` **не пишет** каждый успешный запрос в stdout. Тишина в окне 1 при работающем обмене — норма.

Смотреть админку `http://127.0.0.1:8182/admin`:


| Поле             | На что смотреть в H2                                                                                  |
| ---------------- | ----------------------------------------------------------------------------------------------------- |
| **Store origin** | После фазы A — `K_ULSYNC_ORIGIN`; после фазы B — **та же** строка                                     |
| **Envelopes**    | Растёт после каждого успешного плюса                                                                  |
| **Total / 4xx**  | Накопительно с старта процесса; всплеск 401 до `pm clear` — не провал H2, если после входа обмен идёт |
| **Last error**   | Разовый `pull 400` не равен `origin_mismatch`                                                         |




### 2.8. Два URL — откуда берутся, чему равны, почему это один склад

H2 меняет **только строку хоста** в URL приложения. Порт всегда **8080**. Процесс сервера и файл `./data/ulsync_h2.db` **одни и те же** в обеих фазах.

#### Участники


| Узел                                   | Роль                                                                |
| -------------------------------------- | ------------------------------------------------------------------- |
| **Mac-хозяин**                         | Запущен `./ulsync-server`, bind `0.0.0.0:8080`, база `ulsync_h2.db` |
| **Android Emulator** (`emulator-5554`) | Flutter-приложение; HTTP-клиент ulsync                              |
| **Сервер ulsync**                      | Один процесс, один SQLite-файл                                      |




#### Фаза A — адрес по умолчанию (без `ULSYNC_BASE_URL`)


| Поле                 | Значение                                                                                                                               |
| -------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Имя в документе      | `URL_PHASE_A`                                                                                                                          |
| Строка URL           | `http://10.0.2.2:8080`                                                                                                                 |
| Откуда в приложении  | `kUlsyncBaseUrl` в `ulsync_base_url.dart`: для Android, если `--dart-define=ULSYNC_BASE_URL` **не** передан                            |
| Что такое `10.0.2.2` | **Не** IP Mac в Wi-Fi. Это фиксированный адрес внутри Android Emulator: «перенаправь на loopback машины, на которой крутится эмулятор» |
| Куда попадает пакет  | Эмулятор → виртуальный маршрутизатор → `127.0.0.1:8080` **на Mac** → процесс `ulsync-server`                                           |


Проверка с Mac (это **другой** путь, не из эмулятора):

```bash
curl -sS -w '\nHTTP:%{http_code}\n' http://127.0.0.1:8080/health
```

Ожидание после старта сервера: `HTTP:200`. На фазе A приложение **не** ходит на `127.0.0.1` — только на `10.0.2.2`.

#### Фаза B — альтернативный адрес (явный `ULSYNC_BASE_URL`)


| Поле                    | Значение                                                                                                  |
| ----------------------- | --------------------------------------------------------------------------------------------------------- |
| Имя в документе         | `URL_PHASE_B`                                                                                             |
| Строка URL              | `http://${HOST_LAN_IP}:8080` — подставьте **свой** IPv4                                                   |
| Откуда в приложении     | `--dart-define=ULSYNC_BASE_URL=http://...` при `flutter run`; перекрывает default Android                 |
| Что такое `HOST_LAN_IP` | IPv4-адрес **физического** сетевого интерфейса Mac в локальной сети (Wi-Fi или Ethernet), **не** loopback |


**Как получить** `HOST_LAN_IP` **на Mac:**

```bash
HOST_LAN_IP=$(ipconfig getifaddr en0)
```

- `ipconfig` — утилита macOS для сетевых интерфейсов.
- `getifaddr en0` — IPv4 интерфейса `en0`. На большинстве MacBook **Wi-Fi = en0**.
- Если пусто (нет Wi-Fi / другая схема имён):

```bash
HOST_LAN_IP=$(ipconfig getifaddr en1)
```

- `en1` — часто Ethernet или второй интерфейс.

**Пример (цифры у вас будут другие):**

```text
HOST_LAN_IP=192.168.1.42
URL_PHASE_B=http://192.168.1.42:8080
```

Тогда в фазе B:

```bash
flutter run ... --dart-define=ULSYNC_BASE_URL=http://192.168.1.42:8080
```

**Куда попадает пакет в фазе B:** эмулятор шлёт на `192.168.1.42:8080` → сеть Mac (интерфейс `en0`) → тот же процесс `ulsync-server` на порту 8080 → тот же `ulsync_h2.db`.

#### Почему оба URL — один склад

Сервер слушает `0.0.0.0:8080` — **все** IPv4-интерфейсы Mac, включая loopback (`127.0.0.1`) и LAN (`192.168.x.x`). Запрос через `10.0.2.2` (NAT эмулятора в loopback Mac) и запрос через LAN IPv4 попадают в **один** сокет и **одну** базу.

Меняется только **строка в заголовке Host / URL клиента**. Поле `kUlsyncOrigin` **не** меняется — H2 проверяет, что origin не привязан к hostname.

#### Адреса, которые в H2 **нельзя** путать


| Адрес                                                    | Ошибка                                                                          |
| -------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `http://127.0.0.1:8080` в `ULSYNC_BASE_URL` на эмуляторе | `127.0.0.1` внутри эмулятора — это **сам эмулятор**, не Mac. Сервер не ответит. |
| `http://localhost:8080`                                  | То же: localhost эмулятора, не Mac.                                             |
| Другой порт (8082, 8081)                                 | Другой процесс или админка; это уже не H2.                                      |
| IP телефона / IP эмулятора                               | Нужен IP **Mac-хозяина** в LAN.                                                 |




#### Схема (упрощённо)

```text
Фаза A:  [Эмулятор] --http://10.0.2.2:8080--> [NAT эмулятора] --> 127.0.0.1:8080 [Mac] --> ulsync-server --> ulsync_h2.db

Фаза B:  [Эмулятор] --http://192.168.x.x:8080--> [Wi-Fi en0 Mac] --> ulsync-server --> ulsync_h2.db
                                              \___________________/
                                              тот же процесс и файл
```

---



## 3. Предусловия (проверить до начала)

Выполните в **любом** свободном терминале на Mac. Каждый подпункт — отдельная проверка; переходите к шагу A только когда все зелёные.

### 3.1. Инструменты в PATH

**Зачем:** без этих утилит шаги H2 не выполнить.

```bash
which flutter go curl sqlite3 adb ipconfig
```


| Утилита    | Назначение в H2                     |
| ---------- | ----------------------------------- |
| `flutter`  | Сборка и `flutter run`              |
| `go`       | Сборка `ulsync-server`              |
| `curl`     | whoami, health, токен Supabase      |
| `sqlite3`  | Проверка `server_meta.origin`       |
| `adb`      | `pm clear` на эмуляторе (шаг E0)    |
| `ipconfig` | IPv4 Mac для фазы B (`HOST_LAN_IP`) |


**Успех:** шесть строк с путями, например `/opt/homebrew/bin/flutter`.

**Ошибки:**


| Вывод                | Причина                    | Действие                                                         |
| -------------------- | -------------------------- | ---------------------------------------------------------------- |
| `flutter not found`  | Flutter не в PATH          | Установить Flutter / добавить в `PATH`                           |
| `adb not found`      | Android SDK platform-tools | `brew install android-platform-tools` или PATH из Android Studio |
| `ipconfig not found` | Не macOS                   | H2 в документе рассчитан на Mac-хозяина                          |




### 3.2. Эмулятор `emulator-5554` запущен

**Зачем:** H2 гоняется на **одном** Android-эмуляторе.

В Android Studio: Device Manager → AVD в состоянии **Running**.

```bash
flutter devices | grep emulator-5554
```

**Успех:** одна строка, в ней `emulator-5554`, например:

```text
sdk gphone64 arm64 (mobile) • emulator-5554 • android-arm64 • Android 14 (API 34) (emulator)
```

**Ошибки:**


| Вывод                       | Причина                          | Действие                                                                           |
| --------------------------- | -------------------------------- | ---------------------------------------------------------------------------------- |
| Пусто                       | AVD не запущен или другой serial | Запустить эмулятор; `flutter devices` — подставить свой id во все команды `-d ...` |
| Другой id (`emulator-5556`) | Запущен не тот AVD               | Запустить нужный или заменить id в документе                                       |




### 3.3. Порт 8080 свободен

**Зачем:** H2 использует `SYNC_PORT=8080`. Второй процесс на том же порту не поднимется.

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
```

**Успех:** **пустой** вывод (команда ничего не печатает).

**Ошибки:**


| Вывод                     | Причина                                 | Действие                                                   |
| ------------------------- | --------------------------------------- | ---------------------------------------------------------- |
| Строка с `ulsync-server`  | Старый сервер (H1, H2, dev) ещё слушает | В том терминале `Ctrl+C`; повторить `lsof`                 |
| Строка с другим процессом | Чужое приложение на 8080                | Остановить процесс или сменить порт (для H2 — только 8080) |


Разбор флагов: `-n` — не резолвить имена; `-P` — показать номер порта; `-iTCP:8080` — только TCP 8080; `-sTCP:LISTEN` — только слушающие сокеты.

### 3.4. Нет «висящего» сервера от другого сценария

**Зачем:** если забыли остановить `./ulsync-server` из H1, п. 3.3 покажет занятый порт. Дополнительно: в любом терминале, где раньше крутился сервер, должен быть shell prompt, а не «зависший» лог.

Если сервер ещё работает с **другой** базой (`ulsync_h1.db`) — для H2 его всё равно нужно остановить и поднять заново с `config_h2.yaml` (шаг B).

### 3.5. (Рекомендуется) Узнать будущий `HOST_LAN_IP` заранее

**Зачем:** убедиться, что у Mac есть LAN IPv4 до фазы B; на чистом Wi-Fi/offline фаза B невозможна.

```bash
HOST_LAN_IP=$(ipconfig getifaddr en0)
if [ -z "$HOST_LAN_IP" ]; then
  HOST_LAN_IP=$(ipconfig getifaddr en1)
fi
echo "HOST_LAN_IP=${HOST_LAN_IP:-<пусто>}"
```

**Успех:** напечатано `HOST_LAN_IP=192.168.x.x` (или `10.x.x.x` — любой частный IPv4, не пусто).

**Ошибки:**


| Вывод                 | Причина                             | Действие                                                                                 |
| --------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------- |
| `HOST_LAN_IP=<пусто>` | Нет активного Wi-Fi/Ethernet с IPv4 | Подключить Mac к сети; для H2 offline-only фаза B не пройдёт (фаза A всё равно возможна) |


Это **предпросмотр**. Точное значение пересчитайте в **шаге G** перед фазой B — IP мог смениться (переподключение к Wi-Fi).

---



## 4. Раскладка окон


| Окно        | Назначение                                  | Процесс висит                                           |
| ----------- | ------------------------------------------- | ------------------------------------------------------- |
| **1**       | `./ulsync-server`                           | Да, **обе фазы** (не перезапускать между A и B)         |
| **2**       | Секреты, yaml, curl, `HOST_LAN_IP`, sqlite3 | Нет                                                     |
| **3**       | `flutter run` на `emulator-5554`            | Да; между фазами A→B — **Ctrl+C** и новый `flutter run` |
| **Браузер** | `http://127.0.0.1:8182/admin`               | —                                                       |


`export` из окна 2 **не** переносится в окно 3 — переменные задавайте заново.

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
cat > ./config_h2.yaml <<EOF
server:
  bind: "0.0.0.0:8080"
  read_header_timeout: "5s"
  idle_timeout: "120s"
  max_body_bytes: 1048576

storage:
  driver: "sqlite"
  path: "./data/ulsync_h2.db"

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
  bind: "127.0.0.1:8182"
  token: ""
EOF
```

- `bind: "0.0.0.0:8080"` — обязателен для фазы B: сервер принимает и `10.0.2.2` (через emulator NAT), и IPv4 Mac в LAN.
- `path: "./data/ulsync_h2.db"` — отдельный файл, не `ulsync_h1.db`.

---



### Шаг B — Окно 1: сервер с чистой базой (фаза A)

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
git checkout main && git pull
go build -o ulsync-server ./cmd/ulsync-server
rm -f ./data/ulsync_h2.db ./data/ulsync_h2.db-wal ./data/ulsync_h2.db-shm
./ulsync-server -config ./config_h2.yaml
```

Ожидание: `server listening` на `:8080`, `admin listening` на `8182`. Окно **не закрывать** до конца фазы B.

---



### Шаг C — Окно 2: `ACCESS_TOKEN` и whoami

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
  http://127.0.0.1:8080/v1/whoami
```

Стоп, пока whoami не `HTTP:200`.

---



### Шаг D — Браузер: админка (опционально, но полезно)

Откройте `http://127.0.0.1:8182/admin`. `echo "$ACCESS_TOKEN"` → Check token → **valid**.

---



### Шаг E0 — Сброс сессии на эмуляторе

```bash
adb -s emulator-5554 shell pm clear com.gdetotuta.vfx.counter_schmounter
```

Ожидание: `Success`.

---



## 6. Фаза A — imprint через `10.0.2.2`



### Шаг E — Окно 3: `flutter run` **без** `ULSYNC_BASE_URL`

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
cd /Users/vvk/AndroidStudioProjects/r/counter_schmounter
flutter run -d emulator-5554 --dart-define=SU="$SU" --dart-define=SAK="$SAK"
```

Приложение берёт `URL_PHASE_A` = `http://10.0.2.2:8080` из `ulsync_base_url.dart`.

На эмуляторе: войти `EMAIL` / `PASSWORD` → дождаться **«На связи»** → **один** плюс.

**Контроль:** в админке **Store origin** = `K_ULSYNC_ORIGIN`, **Envelopes** ≥ 1. В логе сервера после входа нет `token rejected`.

### Шаг F — Окно 2: imprint в базе

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
sqlite3 ./data/ulsync_h2.db "SELECT v FROM server_meta WHERE k='origin';"
```

Ожидание:

```
com.gdetotuta.vfx.counter_schmounter/7c3e9a12-4b56-4d8e-9f01-2a3b4c5d6e7f
```

**Стоп-условие:** если пусто или другая строка — **фазу B не начинать**.

Запомните текущее **Envelopes** в админке (например `1`).

**Не останавливайте** окно 1. **Не удаляйте** `ulsync_h2.db`.

---



## 7. Фаза B — тот же сервер, URL = `http://${HOST_LAN_IP}:8080`

Меняется **только** `ULSYNC_BASE_URL` у приложения. Сервер (окно 1), `config_h2.yaml` и `ulsync_h2.db` — **те же**, что после фазы A. См. §2.8.

**Итоговая формула фазы B:**

```text
ULSYNC_BASE_URL = "http://" + HOST_LAN_IP + ":8080"
```

где `HOST_LAN_IP` — IPv4 вашего Mac в LAN (например `192.168.1.42`), **не** `10.0.2.2` и **не** `127.0.0.1`.

### Шаг G — Окно 2: вычислить `HOST_LAN_IP`, проверить health, зафиксировать URL

Выполните блок **целиком** в окне 2. Переменная `HOST_LAN_IP` понадобится в шаге H (окно 3 пересчитает её снова — см. ниже).

```bash
HOST_LAN_IP=$(ipconfig getifaddr en0)
if [ -z "$HOST_LAN_IP" ]; then
  HOST_LAN_IP=$(ipconfig getifaddr en1)
fi
echo "HOST_LAN_IP=$HOST_LAN_IP"
test -n "$HOST_LAN_IP" || { echo "FAIL: нет IPv4 на en0 и en1."; return 1; }
curl -sS -w '\nHTTP:%{http_code}\n' "http://${HOST_LAN_IP}:8080/health"
echo "ULSYNC_BASE_URL=http://${HOST_LAN_IP}:8080"
```

**Разбор по строкам:**


| Команда                                                     | Что делает                                                      | Успех                                     | Ошибка                                            |
| ----------------------------------------------------------- | --------------------------------------------------------------- | ----------------------------------------- | ------------------------------------------------- |
| `HOST_LAN_IP=$(ipconfig getifaddr en0)`                     | Читает IPv4 Wi-Fi (`en0`) в shell-переменную                    | Переменная непустая                       | Пустая строка — Wi-Fi без IPv4 или `en0` не Wi-Fi |
| `if [ -z ... ]; then HOST_LAN_IP=$(ipconfig getifaddr en1)` | Запасной интерфейс (часто Ethernet)                             | Непустой `HOST_LAN_IP`                    | Оба пустые → `FAIL` на следующей строке           |
| `echo "HOST_LAN_IP=..."`                                    | Печатает значение для записи в отчёт                            | `HOST_LAN_IP=192.168.x.x`                 | `HOST_LAN_IP=` пусто                              |
| `test -n "$HOST_LAN_IP"                                     |                                                                 | { echo FAIL...`                           | Стоп, если IP не получен                          |
| `curl ... http://${HOST_LAN_IP}:8080/health`                | С **Mac** проверяет тот же сервер, что увидит эмулятор в фазе B | Тело ответа + `HTTP:200`                  | `connection refused`, таймаут, `HTTP:000`         |
| `echo "ULSYNC_BASE_URL=..."`                                | Готовая строка для `--dart-define` в шаге H                     | `ULSYNC_BASE_URL=http://192.168.x.x:8080` | —                                                 |


**Почему curl с Mac, а не с эмулятора:** если health не `200` с Mac по LAN IP, эмулятор тоже не достучится. Сначала чиним сеть/фаервол на Mac.

**Если health не 200, а** `curl http://127.0.0.1:8080/health` **даёт 200:**

Сервер жив, но **вход на LAN-интерфейс** заблокирован (часто фаервол macOS). Системные настройки → Сеть → Файрвол → разрешить входящие для `ulsync-server` (или временно отключить фаервол для проверки). Повторить curl по `HOST_LAN_IP` до `HTTP:200`.

**Стоп-условие:** пока последний curl не `HTTP:200`, шаг H не начинать.

### Шаг H — Окно 3: остановить фазу A, новый `flutter run` с `ULSYNC_BASE_URL`

В окне 3: **Ctrl+C** (или `q`) — остановить `flutter run` фазы A.

**Hot reload / hot restart недостаточны** — `ULSYNC_BASE_URL` читается из `String.fromEnvironment` при **компиляции**; без полного `flutter run` приложение останется на `http://10.0.2.2:8080`.

```bash
export SU='https://YOUR_PROJECT.supabase.co'
export SAK='YOUR_ANON_KEY'
HOST_LAN_IP=$(ipconfig getifaddr en0)
if [ -z "$HOST_LAN_IP" ]; then
  HOST_LAN_IP=$(ipconfig getifaddr en1)
fi
echo "HOST_LAN_IP=$HOST_LAN_IP"
cd /Users/vvk/AndroidStudioProjects/r/counter_schmounter
flutter run -d emulator-5554 \
  --dart-define=SU="$SU" \
  --dart-define=SAK="$SAK" \
  --dart-define=ULSYNC_BASE_URL=http://${HOST_LAN_IP}:8080
```

**Разбор:**


| Часть                                                      | Смысл                                                                        |
| ---------------------------------------------------------- | ---------------------------------------------------------------------------- |
| `export SU` / `SAK`                                        | Окно 3 — новый shell; секреты из окна 2 сюда **не** попали                   |
| Повторный блок `HOST_LAN_IP=...`                           | Окно 3 не видит переменные окна 2; IP должен совпасть с шагом G              |
| `--dart-define=ULSYNC_BASE_URL=http://${HOST_LAN_IP}:8080` | **Альтернативный URL фазы B** — см. §2.8. Пример: `http://192.168.1.42:8080` |
| Без `--dart-define=ULSYNC_ORIGIN`                          | Происхождение то же: default `K_ULSYNC_ORIGIN`                               |


**Проверка после сборки:** в логе `flutter run` или при отладке URL должен быть LAN IP, не `10.0.2.2`. Если снова `10.0.2.2` — `ULSYNC_BASE_URL` не попал в dart-define (опечатка, не тот терминал).

На эмуляторе: войти тем же аккаунтом → **«На связи»** → **ещё один** плюс.

**Контроль:**

- В логе `flutter run` (окно 3) **нет** `OriginMismatchException`.
- В админке **Envelopes** выросло (было N → стало N+1).
- **Store origin** — **без изменений**, та же строка `K_ULSYNC_ORIGIN`.



### Шаг I — Окно 2: `origin` после фазы B

```bash
cd /Users/vvk/AndroidStudioProjects/r/ulsync-server
sqlite3 ./data/ulsync_h2.db "SELECT v FROM server_meta WHERE k='origin';"
```

Должна быть **та же** строка, что в шаге F.

### Шаг J — Окно 1: остановка сервера

`Ctrl+C` в окне 1.

---



## 8. Итоговые критерии



### Успех H2

- [ ] Фаза A: whoami `200`; imprint в sqlite3 / админке = `K_ULSYNC_ORIGIN`; плюс прошёл; «На связи».
- [ ] Фаза B: health по `HOST_LAN_IP` → `200`; новый `flutter run` с `ULSYNC_BASE_URL`; плюс снова прошёл; «На связи».
- [ ] Фаза B: **нет** `OriginMismatchException` в логе приложения.
- [ ] Фаза B: **нет** HTTP `409` / `origin_mismatch` на сервере (смотреть Last error в админке).
- [ ] Второй sqlite3 (шаг I) = первый (шаг F).



### Провал H2

- Фаза B: `OriginMismatchException` или `409 origin_mismatch`.
- `server_meta.origin` изменился после смены URL.
- Плюс в фазе B не увеличивает **Envelopes** в админке (только локальный счётчик).

---



## 9. Частые сбои


| Симптом                                      | Что делать                                                                                        |
| -------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `token rejected` / expired                   | Шаг E0; новый вход; свежий curl в шаге C                                                          |
| Health по `HOST_LAN_IP` не 200               | Фаервол macOS; `bind` должен быть `0.0.0.0:8080`                                                  |
| Использовали `127.0.0.1` в `ULSYNC_BASE_URL` | Неверно для эмулятора; фаза A: `10.0.2.2`; фаза B: `HOST_LAN_IP` с Mac (`ipconfig getifaddr en0`) |
| Сменили URL через hot reload                 | Не сработает; полный stop + `flutter run` с `--dart-define`                                       |
| `OriginMismatchException` в фазе B           | Дефект привязки origin к URL — провал H2                                                          |
| Терминал сервера пустой                      | Норма; смотреть админку                                                                           |
| Перезапустили сервер между A и B             | Нарушен протокол H2; начать заново с шага B                                                       |
| Удалили `ulsync_h2.db` между фазами          | Нарушен протокол H2; начать заново                                                                |


---



## 10. Уборка

```bash
# Окно 3: Ctrl+C
# Окно 1: уже остановлен на шаге J
rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/config_h2.yaml
# rm -f /Users/vvk/AndroidStudioProjects/r/ulsync-server/data/ulsync_h2.db*  # по желанию
```

Следующий сценарий приёмки круга 1b: **H3** — отдельный документ.

---



## 11. Связанные артефакты


| Файл                                               | Содержание                                                     |
| -------------------------------------------------- | -------------------------------------------------------------- |
| `lib/src/infrastructure/sync/ulsync_base_url.dart` | `kUlsyncBaseUrl`, `kUlsyncOrigin`, приоритет `ULSYNC_BASE_URL` |
| План 1b §5, строка H2                              | Формулировка успеха/провала в штабе                            |


