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

GitHub Actions собирают и пушат образы в **GHCR** (не GCP Artifact Registry):

- Backend: [deployment/deploy-backend.sh](./deployment/deploy-backend.sh) — собирается из `Backend/aivus_backend/Dockerfile`, тегается, пушится в `ghcr.io/aivus-tools/backend-py`.
- Frontend: [deployment/deploy-frontend.sh](./deployment/deploy-frontend.sh) — `ghcr.io/aivus-tools/frontend`.

Деплой на сервер — ручной: после успешного билда зайти на сервер и:

```bash
cd ~/aivus
docker compose -f docker-compose.production.yml pull
docker compose -f docker-compose.production.yml up -d
docker compose -f docker-compose.production.yml exec django python manage.py migrate
```

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
