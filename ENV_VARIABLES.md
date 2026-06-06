# Environment Variables

Все переменные `~/aivus/.env` на проде. Источник истины — [prod-docker-compose.yml](./prod-docker-compose.yml) и [deployment/env.production.template](./deployment/env.production.template).

Категории:

- **Секрет** — никогда не коммитить, хранить в Vault/1Password плюс `prod.env` локально.
- **Конфиг** — может коммититься в template, но конкретное значение задаётся при деплое.
- **Публичная** — может жить в репо без последствий.

## Домены

| Переменная | Категория | Где | Пример | Комментарий |
|---|---|---|---|---|
| `APP_DOMAIN` | конфиг | traefik, frontend | `go.aivus.co` | Хост frontend и `NEXTAUTH_URL` |
| `SERVICE_DOMAIN` | конфиг | traefik | `aivus.co` | Из неё формируются `api/traefik/flower/pgadmin/databasus.${SERVICE_DOMAIN}` |
| `ACME_EMAIL` | конфиг | traefik | `admin@aivus.co` | Для Let's Encrypt |

## Django core

| Переменная | Категория | Где | Как генерировать / комментарий |
|---|---|---|---|
| `DJANGO_SETTINGS_MODULE` | публичная | django + celery | `config.settings.production` |
| `DJANGO_SECRET_KEY` | секрет | django + celery | `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"` |
| `DJANGO_ALLOWED_HOSTS` | конфиг | django | `${APP_DOMAIN},www.${APP_DOMAIN},api.${SERVICE_DOMAIN},django` |
| `DJANGO_ADMIN_URL` | секрет | django | Нестандартный path вроде `secret-admin-x7k2/`, заменяет дефолтный `admin/` |
| `DJANGO_SECURE_SSL_REDIRECT` | конфиг | django | `True` на проде |
| `DJANGO_DEBUG` | конфиг | django | На проде сейчас `True`, исторически — для удобства, не безопасно для public-facing |

## Database

| Переменная | Категория | Где | Как генерировать |
|---|---|---|---|
| `POSTGRES_DB` | публичная | postgres + django | `aivus` |
| `POSTGRES_USER` | публичная | postgres + django | `aivus` |
| `POSTGRES_PASSWORD` | секрет | postgres + django + celery | `openssl rand -base64 32 \| tr -d '=+/' \| cut -c1-25` |
| `POSTGRES_HOST` | публичная | django | `postgres` (Docker DNS) |
| `POSTGRES_PORT` | публичная | django | `5432` |
| `DATABASE_URL` | конфиг | django + celery | `postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}` |
| `CONN_MAX_AGE` | публичная | django | `60` |
| `PGADMIN_DEFAULT_EMAIL` | конфиг | pgadmin | Любой mail |
| `PGADMIN_DEFAULT_PASSWORD` | секрет | pgadmin | `openssl rand -base64 24` |

## Redis и Celery

| Переменная | Категория | Где |
|---|---|---|
| `REDIS_URL` | публичная | django + celery + flower | `redis://redis:6379/0` |

Дополнительных переменных Celery в env нет — конфиг в [Backend/aivus_backend/config/settings/base.py](../Backend/aivus_backend/config/settings/base.py):338-377.

## HMAC и API

| Переменная | Категория | Где | Как генерировать |
|---|---|---|---|
| `HMAC_SECRET` | секрет | django + celery + frontend | `openssl rand -hex 32` — должен совпадать на django и frontend |
| `API_KEY` | секрет | django + celery | `openssl rand -hex 24` |
| `WIX_WEBHOOK_SECRET` | секрет | django | `openssl rand -hex 32` — общий секрет вебхука Wix-формы (`X-Aivus-Webhook-Secret`); пустой выключает эндпоинт `/api/v1/public/briefs/ai/from-wix` (401) |

## E2E (только staging, НЕ прод)

Включают test-only эндпоинт `/api/v1/auth/e2e-confirmation-token`, который отдаёт последний email-confirmation токен по адресу, чтобы staging E2E подтверждал регистрацию без чтения почты. По умолчанию выключен (404). **Никогда не включать в проде.**

| Переменная | Категория | Где | Как генерировать |
|---|---|---|---|
| `E2E_CONFIRMATION_TOKEN_ENABLED` | флаг | django | `True` только на staging; по умолчанию `False`. Включает эндпоинт |
| `E2E_CONFIRMATION_TOKEN_SECRET` | секрет | django | `openssl rand -hex 32` — проверяется заголовком `X-E2E-Token-Secret`; пустой даёт 403 даже при включённом флаге |

Изменение этих env требует пересоздания контейнера (`docker compose up -d django`), не `docker restart` (тот не перечитывает env_file). На фронте E2E переключается `E2E_TOKEN_SOURCE=endpoint` + тот же `E2E_CONFIRMATION_TOKEN_SECRET`; по умолчанию `mailpit`.

## NextAuth (frontend)

| Переменная | Категория | Где | Как генерировать |
|---|---|---|---|
| `NEXTAUTH_SECRET` (он же `AUTH_SECRET`) | секрет | frontend | `openssl rand -base64 32` |
| `NEXTAUTH_URL` | конфиг | frontend | `https://${APP_DOMAIN}` |
| `AUTH_TRUST_HOST` | публичная | frontend | `true` |
| `AUTH_GOOGLE_ID` | секрет | frontend | Google Cloud Console → OAuth credentials |
| `AUTH_GOOGLE_SECRET` | секрет | frontend | Google Cloud Console → OAuth credentials |

`NEXT_PUBLIC_LOCALE` **выпилен**. Locale работает per-request через cookie + middleware.

## Frontend (прочее)

| Переменная | Категория | Где |
|---|---|---|
| `NODE_ENV` | публичная | frontend | На проде `development` (исторически, не меняется) |
| `API_URL` | публичная | frontend | `http://django:5000` (Docker DNS) |
| `CALLBACK_URL` | конфиг | frontend | `https://${APP_DOMAIN}` |
| `FRONTEND_URL` | конфиг | django + celery | `https://${APP_DOMAIN}` (для emails и share-ссылок) |
| `FRONTEND_DEBUG` | публичная | frontend | `false` на проде |

## LLM (Brief AI v3)

Реальные модели и fallback chains — [ARCHITECTURE.md](./ARCHITECTURE.md) → "AI пайплайн".

| Переменная | Категория | Где | Комментарий |
|---|---|---|---|
| `OPENAI_API_KEY` | секрет | django + celery | sk-... ; для GPT-4o |
| `ANTHROPIC_API_KEY` | секрет | django + celery | sk-ant-... ; для Claude Sonnet 4.5 |
| `GOOGLE_CLOUD_PROJECT` | конфиг | django + celery | `pioneering-flag-476313-u2` |
| `GOOGLE_CLOUD_LOCATION` | конфиг | django + celery | `us-central1` (для Vertex Gemini) |
| `VERTEX_CREDENTIALS_PATH` | конфиг | django + celery | `/app/vertex-credentials.json` (mount от runtime SA) |

OpenAI и Anthropic ключи опциональны — без них fallback на Gemini. Без Vertex credentials Brief AI не работает (Gemini — основная модель по умолчанию).

## Speech-to-Text

| Переменная | Категория | Где | Default |
|---|---|---|---|
| `STT_MODEL` | конфиг | django + celery | `short` |
| `GOOGLE_CLOUD_SPEECH_LOCATION` | конфиг | django + celery | `global` |
| `STT_DEV_FAKE` | публичная | django (dev/CI) | `1` для фейкового ответа без вызова GCP |

Подробности про модели/локации — [GCP_SETUP.md](./GCP_SETUP.md) → "Speech-to-Text: location, recognizer и модель".

## GCP Storage и креды

| Переменная | Категория | Где | Комментарий |
|---|---|---|---|
| `GOOGLE_APPLICATION_CREDENTIALS` | конфиг | django + celery | `/app/gcp-credentials.json` (CI SA: GCS, Databasus HMAC) |
| `GCP_CREDENTIALS_PATH` | конфиг | host | Хостовый путь к `gcp-credentials.json` для bind-mount |
| `VERTEX_CREDENTIALS_PATH` (host) | конфиг | host | Хостовый путь к `vertex-credentials.json` |
| `DJANGO_GCP_STORAGE_BUCKET_NAME` | конфиг | django + celery | `aivus-production-media` |

## Email (Resend)

| Переменная | Категория | Где |
|---|---|---|
| `RESEND_API_KEY` | секрет | django + celery + flower |
| `DJANGO_DEFAULT_FROM_EMAIL` | конфиг | django | `noreply@aivus.co` |
| `DJANGO_SERVER_EMAIL` | конфиг | django | `server@aivus.co` |

Brevo и Mailpit выпилены.

## Sentry

| Переменная | Категория | Где |
|---|---|---|
| `SENTRY_DSN` | секрет | django + celery |
| `SENTRY_ENVIRONMENT` | публичная | django + celery | `production` |
| `SENTRY_TRACES_SAMPLE_RATE` | публичная | django + celery | `0.1` |

## Basic Auth для админок

htpasswd-формат: `htpasswd -nb admin <password>`. На macOS установить через `brew install httpd`.

| Переменная | Категория | Где |
|---|---|---|
| `TRAEFIK_BASIC_AUTH` | секрет | traefik |
| `FLOWER_BASIC_AUTH` | секрет | traefik (flower) |

pgAdmin и Databasus авторизуются через свои UI, отдельных Basic Auth на уровне traefik у них нет.

## GHCR

| Переменная | Категория | Где | Комментарий |
|---|---|---|---|
| `BACKEND_TAG` | конфиг | docker compose | Default `latest`. Лучше пинить SHA-tag. |
| `FRONTEND_TAG` | конфиг | docker compose | То же. |

Сами образы — `ghcr.io/aivus-tools/backend-py` и `ghcr.io/aivus-tools/frontend`. Docker login — отдельный шаг (PAT в `~/.docker/config.json`).

## Что обязательно одновременно совпадает

- `HMAC_SECRET` — django, celery worker, celery beat, frontend.
- `POSTGRES_PASSWORD` — postgres, django, celery worker, celery beat.
- `DJANGO_SECRET_KEY` — django, celery worker, celery beat (иначе сессии и подписанные токены не сходятся).

## Ротация секретов

| Что меняется | Что пересоздать |
|---|---|
| `POSTGRES_PASSWORD` | `psql ALTER USER`, обновить `.env`, recreate django + celery* |
| `HMAC_SECRET` | recreate django + frontend **одновременно** |
| `DJANGO_SECRET_KEY` | recreate django (все сессии инвалидируются) |
| `NEXTAUTH_SECRET` | recreate frontend (все сессии инвалидируются) |
| `AUTH_GOOGLE_SECRET` | новый client secret в Google Cloud Console → recreate frontend |
| GCP service account JSON | revoke в IAM, выпустить новый, перезалить файлы, recreate django + celery + frontend |
| `RESEND_API_KEY` | recreate django + celery |

После смены — обновить локальный `prod.env` и копию в Vault.

## Шаблон

Готовый шаблон с placeholder'ами — [deployment/env.production.template](./deployment/env.production.template). Скопировать на сервер, заполнить `<CHANGE_ME>`, сделать `chmod 600 .env`.

## FAQ

**Q: Где хранить `gcp-credentials.json` и `vertex-credentials.json`?**
A: На сервере — `~/data/*.json` с `chmod 644`, mount в контейнеры через `${GCP_CREDENTIALS_PATH}:/app/gcp-credentials.json:ro`. Локально — рядом с `prod.env`, дублировать в Vault и приватный GCS bucket (см. DR doc).

**Q: Можно ли тестировать prod-конфиг локально?**
A: Скопировать `.env`, выставить `APP_DOMAIN=localhost`, `DJANGO_SECURE_SSL_REDIRECT=False`, поднять через `docker compose -f docker-compose.production.yml --env-file .env.local up`. SSL и Traefik будут ругаться, но django/celery поднимутся.

**Q: Что нельзя оставить дефолтным на проде?**
A: `DJANGO_ADMIN_URL` (заменить на нестандартный), все секреты (генерировать каждый раз), `DJANGO_DEBUG` (хотя сейчас `True`, это техдолг — должен быть `False`).
