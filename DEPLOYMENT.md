# Production Deployment

Aivus прод живёт на одном Linux VPS, запускается через `docker compose`. Стек, переменные и операции описаны ниже. Настоящие текущие значения — на сервере `~/aivus/.env` и в [prod-docker-compose.yml](./prod-docker-compose.yml) (snapshot).

## Текущий прод

- Хост: `go.aivus.co` (root SSH)
- IP: `34.28.176.245`
- Каталог: `~/aivus/`
- Compose: `~/aivus/docker-compose.production.yml`
- Образы: `ghcr.io/aivus-tools/backend-py`, `ghcr.io/aivus-tools/frontend` (private GHCR, нужен `docker login`)

## Сервисы

Все контейнеры в одной docker network `aivus`. Traefik публикует наружу 80/443.

| Контейнер | Образ | Назначение |
|---|---|---|
| `aivus_traefik` | traefik:v2.11 | Reverse proxy + Let's Encrypt |
| `aivus_postgres` | postgres:17 | Основная БД |
| `aivus_pgadmin` | dpage/pgadmin4:latest | DB UI |
| `aivus_redis` | redis:7-alpine | Cache + Celery broker |
| `aivus_django` | ghcr.io/aivus-tools/backend-py | Django API (`/start`, port 5000) |
| `aivus_celeryworker` | то же | Celery worker (`/start-celeryworker`) |
| `aivus_celerybeat` | то же | Beat scheduler (`/start-celerybeat`) |
| `aivus_flower` | то же | Celery monitoring (`/start-flower`, port 5555) |
| `aivus_databasus` | databasus/databasus:v3.32.2 | Postgres backups → GCS + локальный volume |
| `aivus_frontend` | ghcr.io/aivus-tools/frontend | Next.js (port 3000) |

Persistent named volumes: `postgres_data`, `redis_data`, `traefik_acme`, `pgadmin_data`, `databasus_data`. Mailpit и BREVO выпилены — почта через Resend (`RESEND_API_KEY`), бэкапы через Databasus.

## Домены и роутинг

Traefik labels в [prod-docker-compose.yml](./prod-docker-compose.yml). Хосты подставляются из env: `APP_DOMAIN` для приложения, `SERVICE_DOMAIN` для админок.

| URL | Сервис | Auth |
|---|---|---|
| `https://${APP_DOMAIN}` (`go.aivus.co`) | frontend | NextAuth |
| `https://api.${SERVICE_DOMAIN}` (`api.aivus.co`) | django | HMAC middleware |
| `https://traefik.${SERVICE_DOMAIN}` | Traefik dashboard | `TRAEFIK_BASIC_AUTH` |
| `https://flower.${SERVICE_DOMAIN}` | Celery monitoring | `FLOWER_BASIC_AUTH` |
| `https://pgadmin.${SERVICE_DOMAIN}` | pgAdmin | через UI pgAdmin |
| `https://databasus.${SERVICE_DOMAIN}` | Databasus | через UI Databasus |

## Установка с нуля

Чек-лист DR — [DISASTER_RECOVERY.md](./DISASTER_RECOVERY.md). Здесь — happy path для нового сервера.

### Pre-requisites

- VPS Debian/Ubuntu, минимум 4 GB RAM, 40 GB SSD, root SSH.
- DNS A-записи всех поддоменов `go / api / traefik / flower / pgadmin / databasus.aivus.co` на IP сервера (TTL 60-300).
- `gcp-credentials.json` (CI SA) и `vertex-credentials.json` (runtime SA) — см. [GCP_SETUP.md](./GCP_SETUP.md).
- GHCR PAT с scope `read:packages` (для pull `ghcr.io/aivus-tools/*`).

### Шаги

1. Загрузить креды на сервер:
   ```bash
   scp gcp-credentials.json vertex-credentials.json root@server:~/
   ```

2. Запустить установщик:
   ```bash
   curl -sSL https://raw.githubusercontent.com/<repo>/main/Specs/deployment/install.sh | bash
   ```
   [deployment/install.sh](./deployment/install.sh) ставит Docker (>=24.0.0), создаёт `~/aivus/`, генерирует или сохраняет секреты (`CREDENTIALS.txt`), пишет `docker-compose.production.yml` и `traefik.yml`.

3. Логин в GHCR:
   ```bash
   echo $GHCR_PAT | docker login ghcr.io -u <user> --password-stdin
   ```

4. Поднять стек:
   ```bash
   cd ~/aivus
   docker compose -f docker-compose.production.yml up -d
   ```
   Дождаться `aivus_postgres healthy`.

5. Миграции и суперпользователь:
   ```bash
   docker compose -f docker-compose.production.yml exec django python manage.py migrate
   docker compose -f docker-compose.production.yml exec django python manage.py createsuperuser
   ```

6. Настроить бэкапы в Databasus UI (`https://databasus.aivus.co`): подключить storage (GCS bucket `aivus-db-backups` через S3 HMAC) и database (`postgres:5432`), создать ежедневный job.

### Restore с нуля

При миграции или DR — следовать [DISASTER_RECOVERY.md](./DISASTER_RECOVERY.md), сценарий 1. Главное: перед `up -d` залить **старый** `prod.env` вместо сгенерированного `install.sh` — иначе `POSTGRES_PASSWORD` не подойдёт к существующему дампу.

## CI/CD

GitHub Actions собирают и пушат образы в **GHCR**, затем деплоят на сервер по SSH. Backend pipeline — `backend-py/.github/workflows/ci.yml` (деплоит с `main`), frontend — `frontend/.github/workflows/ci.yml` (деплоит с `master`). Оба: `lint` → `test` → `build-and-push` → `deploy` (SSH + `docker rollout`).

### Zero-downtime backend deploy

Раньше деплой давал 5+ минут 502: контейнер django стартовал командой `/start`, которая до запуска gunicorn гоняла `migrate` и `collectstatic` (статика в GCS, сотни сетевых обращений). Контейнер был `Up`, но порт 5000 не слушал, а Traefik уже слал в него трафик. Сейчас:

- `/start` запускает только gunicorn (`--preload`), без migrate и collectstatic. Cold-start — секунды;
- migrate и collectstatic вынесены в **условные one-shot шаги** деплоя. Job `changes` через `dorny/paths-filter` смотрит diff коммита: `migrate` гоняется только если в коммите есть `**/migrations/*.py`, `collectstatic` — только если менялись `**/static/**`, `pyproject.toml` или `uv.lock`. На `workflow_dispatch` оба шага форсятся (нет базы для diff);
- swap контейнера django — через `docker rollout -t 180 --wait-after-healthy 10`: новый контейнер поднимается рядом со старым, Traefik по active healthcheck (`/healthz`) не пускает трафик в неготовый, старый гасится только через 10с после `healthy` (запас, чтобы Traefik успел подхватить новый бэкенд). Downtime для внешнего трафика через Traefik (`api.aivus.co`) — ноль;
- ВАЖНО: rollout работает без простоя только когда у старого и нового контейнера **одинаковый набор Traefik-лейблов**. Если лейблы разошлись (например, в этом релизе добавили `healthcheck`, а старый контейнер был создан до этого), Traefik увидит "Service defined multiple times with different configurations" и временно уронит сервис в 404. Поэтому любой релиз, меняющий Traefik-лейблы django, даёт одноразовый блип на самом cutover; следующие релизы с уже совпадающими лейблами идут в ноль;
- одно-шаговые контейнеры migrate/collectstatic запускаются с `--label traefik.enable=false`, чтобы Traefik не подхватил их как backend.

Health-точка — `GET /healthz` (liveness, без БД), помечена `@public_endpoint` и обходит HMAC.

**Миграции обязаны быть обратно совместимы.** `migrate` выполняется до переключения трафика на новый контейнер и до пересоздания celery, поэтому в окне rollout новая схема БД сосуществует со старым кодом django и старыми celery-воркерами. Деструктивные изменения (drop/rename колонки, NOT NULL без default) разносить на два релиза: сначала задеплоить код, переставший использовать поле, затем отдельным релизом удалить поле. Аддитивные миграции безопасны.

**Остаточный блип внутреннего пути.** Frontend ходит в backend напрямую по `http://django:5000` (SSR-прокси в `middleware.ts`), минуя Traefik. В момент rollout DNS-alias `django` секунды отдаёт оба контейнера round-robin, и часть SSR-запросов может попасть в ещё буутящийся новый контейнер. Это секунды частичных ошибок на страницах с SSR-вызовами, не пятиминутный простой. Проба `api.aivus.co/healthz` этот путь не видит. Полностью закрыть — отдельной задачей: завести внутренний Traefik-роут для django и переключить `API_URL` фронта на него, тогда healthcheck Traefik уберёт неготовый контейнер из ротации и для внутреннего пути.

### Zero-downtime frontend deploy

Frontend (`go.aivus.co`) на том же паттерне: swap через `docker rollout -t 180 --wait-after-healthy 10`, у сервиса `frontend` убран `container_name`, добавлены Docker healthcheck и Traefik active healthcheck на `GET /api/health` (Next.js route handler, вне middleware-matcher, поэтому без NextAuth и SSR-прокси). Миграций и collectstatic у фронта нет — статика собирается в образ на билде, деплой это `pull` + `docker rollout`. Тот же одноразовый блип на первом cutover при смене Traefik-лейблов, дальше ноль.

### Server prerequisites (one-time)

Чтобы новый pipeline работал, на сервере нужно:

1. Поставить плагин docker-rollout (новый `install.sh` ставит автоматически):
   ```bash
   mkdir -p ~/.docker/cli-plugins
   curl -fsSL https://raw.githubusercontent.com/wowu/docker-rollout/master/docker-rollout \
     -o ~/.docker/cli-plugins/docker-rollout
   chmod +x ~/.docker/cli-plugins/docker-rollout
   docker rollout --help    # проверка
   ```
2. Привести `~/aivus/docker-compose.production.yml` к снапшоту [prod-docker-compose.yml](./prod-docker-compose.yml): у сервиса django убрать `container_name`, выключить `DJANGO_DEBUG`, добавить `localhost,127.0.0.1` в `DJANGO_ALLOWED_HOSTS`, добавить `healthcheck` и Traefik-healthcheck labels (`/healthz`). То же для сервиса `frontend`: убрать `container_name`, добавить `healthcheck` и Traefik-healthcheck labels (`/api/health`). Применить через rollout вместе с первым деплоем нового образа.

Если healthcheck в живом compose не применён, деплой не пройдёт: и CI, и `deploy-*.sh` делают precheck (`compose config | grep /healthz` для бэка, `/api/health` для фронта) и падают с явной ошибкой, а не уходят в слепой `docker rollout` fallback (он без healthcheck просто ждёт 10с и гасит старый контейнер, возвращая 502).

Внимание: повторный запуск `install.sh` на живом сервере **перезаписывает** `~/aivus/docker-compose.production.yml` и `.env` из своих шаблонов. Перед перегенерацией сверять результат с текущим живым файлом.

Ручной деплой (без CI) — [deployment/deploy-backend.sh](./deployment/deploy-backend.sh).

### Проверка downtime

Замерить реальный простой при релизе снаружи:

```bash
# в одном терминале
./Specs/deployment/probe-downtime.sh https://api.aivus.co/healthz 0.2
# в другом — триггернуть деплой (push в main или workflow_dispatch), затем Ctrl-C
```

В сводке смотреть "longest outage": цель — 0s. В логах job `deploy` видно тайминг (`rollout took Ns`, `DONE in Ns`) и какие шаги отработали (`migrate=… static=…`).

## Операции

### Логи

```bash
# Все сервисы
docker compose -f docker-compose.production.yml logs -f

# Конкретный
docker compose -f docker-compose.production.yml logs -f django celeryworker

# Tail последних 100 строк
docker compose -f docker-compose.production.yml logs --tail=100 django
```

### Перезапуск

```bash
docker compose -f docker-compose.production.yml restart django celeryworker celerybeat
```

### Миграции

```bash
docker compose -f docker-compose.production.yml exec django python manage.py migrate
docker compose -f docker-compose.production.yml exec django python manage.py showmigrations
```

### Django shell

```bash
docker compose -f docker-compose.production.yml exec django python manage.py shell
```

### Бэкапы

Делает Databasus автоматически в две точки:

- GCS bucket `aivus-db-backups` (S3 HMAC через `gha-service-account@...`).
- Локально в volume `aivus_databasus_data`.

Расписание и retention — UI на `https://databasus.aivus.co`. Restore — тоже через UI. Ручной путь через `pg_restore` — в [DISASTER_RECOVERY.md](./DISASTER_RECOVERY.md), сценарий 1, шаг 8.

### Проверки health

```bash
docker compose -f docker-compose.production.yml ps
docker compose -f docker-compose.production.yml exec postgres pg_isready
docker compose -f docker-compose.production.yml exec redis redis-cli ping
```

## Troubleshooting

### SSL не получен

```bash
dig ${APP_DOMAIN} +short                 # должен вернуть IP сервера
docker compose -f docker-compose.production.yml logs traefik | grep -i acme
```

При rate-limit от Let's Encrypt (5 сертификатов на имя в неделю) — подождать или использовать staging-CA для отладки.

### Frontend 401 от backend

`HMAC_SECRET` разный в django и frontend. Проверить:

```bash
docker compose -f docker-compose.production.yml exec django env | grep HMAC_SECRET
docker compose -f docker-compose.production.yml exec frontend env | grep HMAC_SECRET
```

После смены `HMAC_SECRET` recreate **одновременно** django и frontend, иначе rolling restart рвёт связь.

### Celery не обрабатывает задачи

```bash
docker compose -f docker-compose.production.yml exec redis redis-cli ping
docker compose -f docker-compose.production.yml logs celeryworker --tail=200
docker compose -f docker-compose.production.yml restart celeryworker
```

В Flower (`https://flower.aivus.co`) видны очереди и активные задачи.

### Brief AI 500 на чате

Чаще всего — Vertex/GCP credentials. Чек-лист в [GCP_SETUP.md](./GCP_SETUP.md) → "Runtime APIs и роли" (включён ли `aiplatform.googleapis.com`, есть ли `roles/aiplatform.user` на runtime SA).

### Транскрипция голоса (`/transcribe`) 500

`speech.googleapis.com` отключён или нет `roles/speech.client` на SA. Подробности — [GCP_SETUP.md](./GCP_SETUP.md), там же таблица ошибок и валидных моделей по локациям.

## Безопасность

- Менять `DJANGO_ADMIN_URL` на нестандартный путь (не `admin/`).
- Все Basic Auth — htpasswd-формат (`htpasswd -nb admin <password>`), хранить в `.env`, не коммитить.
- `chmod 600 ~/aivus/.env`, `chmod 644 ~/data/*.json`.
- Firewall: открыть только 22, 80, 443.
- `chmod 600` на `gcp-credentials.json` и `vertex-credentials.json`.

## Связанная документация

- [ENV_VARIABLES.md](./ENV_VARIABLES.md) — справочник всех переменных.
- [GCP_SETUP.md](./GCP_SETUP.md) — service accounts, Vertex, STT, GCS, Artifact Registry.
- [DISASTER_RECOVERY.md](./DISASTER_RECOVERY.md) — план восстановления, ротация секретов.
- [deployment/](./deployment/) — `install.sh`, `deploy-*.sh`, `env.production.template`.
