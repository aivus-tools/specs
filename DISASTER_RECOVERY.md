# Disaster Recovery — Aivus production

Что делать, если прод-сервер `go-aivus-vm` (IP `34.28.176.245`) недоступен, разрушен или нужно мигрировать на новый VPS. Ориентировочное время полного восстановления при наличии всех артефактов: **30-60 минут**.

## Что нужно иметь под рукой

Все эти файлы лежат в корне репо локально и не коммитятся (см. `.gitignore`). Дублируй их в 1Password/Bitwarden и/или в отдельный приватный GCS bucket — на одну машину полагаться нельзя.

| Файл | Что внутри | Нужен для |
|---|---|---|
| `prod.env` | 38 переменных, секреты (`POSTGRES_PASSWORD`, `DJANGO_SECRET_KEY`, `HMAC_SECRET`, `NEXTAUTH_SECRET`, OAuth, Brevo, Sentry...) | новый сервер не подымется без идентичных секретов |
| `gcp-credentials.json` | GCP service account `gha-service-account@pioneering-flag-476313-u2` | GCS storage для медиа, Databasus HMAC-ключи |
| `vertex-credentials.json` | GCP SA `sa-for-vertex-ai@pioneering-flag-476313-u2` для Vertex AI / Gemini / Speech-to-Text | Brief AI v3 чат + голосовой ввод. На SA должны быть включены: API `aiplatform.googleapis.com` + `speech.googleapis.com`, роли `roles/aiplatform.user` + `roles/speech.client`. Подробности в `Specs/GCP_SETUP.md` → "Runtime: APIs и роли". |
| `docker-config.ghcr.json` | GHCR PAT для pull `ghcr.io/aivus-tools/*` | образы backend/frontend приватные |
| `CREDENTIALS.txt` | человекочитаемые URL и логины | удобно подсмотреть пароли pgAdmin/Flower |

В дополнение нужны:
- доступ к DNS-провайдеру для смены A-записей всех поддоменов;
- SSH-ключ, который пускают на новый VPS под root;
- последний бэкап Postgres из Databasus (S3 bucket `aivus-db-backups` в проекте `pioneering-flag-476313-u2` + локальная копия в databasus_data volume).

## Состояние стека на проде

Все persistent-данные — в named docker-volumes:
- `aivus_postgres_data` — основная БД приложения. **Главный приз** при потере;
- `aivus_databasus_data` — конфиг Databasus (jobs, storage, notifiers) + его внутренний postgres. Терять можно, но придётся пересоздавать backup-jobs руками;
- `aivus_redis_data` — Celery broker / cache. Можно терять, очереди восстанавливаются;
- `aivus_pgadmin_data` — настройки pgAdmin. Косметика;
- `aivus_traefik_acme` — Let's Encrypt сертификаты. Можно терять — traefik перевыпустит при первом HTTPS-запросе после смены DNS, но **осторожно с rate-limit** (5 сертификатов на одно имя в неделю).

Бэкапы БД делает Databasus в две точки:
- **GCS** bucket `aivus-db-backups` через S3 API (HMAC-ключ для `gha-service-account@...`);
- **Local** в volume `aivus_databasus_data` (на том же диске, что и сама БД — это резерв на случай быстрой ошибки, но не disaster).

Ежедневное расписание + retention настраиваются в UI Databasus на `https://databasus.aivus.co`.

## Сценарий 1: новый сервер с нуля

### 1. Поднять VPS

Любой провайдер (GCP, Hetzner, DigitalOcean, AWS), Debian/Ubuntu, минимум 4 GB RAM, 40 GB SSD, root SSH.

### 2. Перенаправить DNS

A-записи всех поддоменов на новый IP (TTL 60-300 секунд):

```
go.aivus.co
api.aivus.co
pgadmin.aivus.co
flower.aivus.co
databasus.aivus.co
traefik.aivus.co
```

### 3. Запустить install.sh

На новом сервере под root:

```bash
curl -sSL https://raw.githubusercontent.com/<repo>/main/Specs/deployment/install.sh -o install.sh
bash install.sh
```

Скрипт поставит Docker, создаст `~/aivus/`, `~/data/`, сгенерирует compose, traefik.yml. Когда он сгенерирует **новый** `.env` с **новыми** секретами — это нам не годится, потому что DB зашифрована старыми. Поэтому сразу после install.sh:

### 4. Перезаписать .env старыми секретами

```bash
scp local/prod.env root@<new-ip>:/root/aivus/.env
chmod 600 /root/aivus/.env
```

Это критично для:
- `POSTGRES_PASSWORD` — должен совпадать с тем, под которым жила БД;
- `HMAC_SECRET` — общий секрет между frontend и backend, иначе все запросы 401;
- `DJANGO_SECRET_KEY` — расшифровывает сессии (старые тут же станут невалидны, придётся всем перелогиниться, не критично);
- `NEXTAUTH_SECRET`, OAuth-credentials, API_KEY — иначе авторизация и интеграции лежат.

### 5. Восстановить credentials.json

```bash
scp local/gcp-credentials.json root@<new-ip>:/root/data/gcp-credentials.json
scp local/vertex-credentials.json root@<new-ip>:/root/data/vertex-credentials.json
chmod 644 /root/data/gcp-credentials.json /root/data/vertex-credentials.json
```

Без них media (GCS) и Brief AI (Vertex) не работают.

### 6. Логин в GHCR

```bash
mkdir -p /root/.docker
scp local/docker-config.ghcr.json root@<new-ip>:/root/.docker/config.json
```

Проверка:

```bash
docker pull ghcr.io/aivus-tools/backend-py:latest
```

Если `unauthorized` — PAT истёк, перевыпусти на github.com → Settings → Developer settings → PAT и обнови файл.

### 7. Поднять стек

```bash
cd /root/aivus
docker compose -f docker-compose.production.yml up -d
```

Дождаться `aivus_postgres healthy`. Стек поднимется без БД (postgres увидит пустой volume и инициализирует пустую базу).

### 8. Восстановить Postgres из бэкапа Databasus

Два пути.

**Через UI Databasus** (проще):

1. Открыть `https://databasus.aivus.co`, зарегистрировать админа (UI попросит на первом заходе).
2. Подключить storage: GCS bucket `aivus-db-backups`, S3 HMAC от CI SA `gha-service-account@pioneering-flag-476313-u2`. HMAC access/secret keys выписываются в GCP Console → Storage → Settings → Interoperability.
3. Подключить database `postgres:5432` (host=postgres, db/user/password из `.env`).
4. В разделе **Backups** найти последний бэкап → **Restore** → выбрать целевую базу.

**Через psql вручную** (если Databasus не поднимается):

```bash
# скачать дамп из GCS на сервер
gcloud auth activate-service-account --key-file=/root/data/gcp-credentials.json
gcloud storage cp gs://aivus-db-backups/<latest>.dump.gz /tmp/

# распаковать и накатить
gunzip /tmp/<latest>.dump.gz
docker exec -i aivus_postgres pg_restore -U "$POSTGRES_USER" -d "$POSTGRES_DB" --clean --if-exists < /tmp/<latest>.dump

# или, если бэкап в формате plain SQL:
gunzip -c /tmp/<latest>.sql.gz | docker exec -i aivus_postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB"
```

После restore перезапустить django/celery, чтобы они подцепили новую схему:

```bash
docker compose -f docker-compose.production.yml restart django celeryworker celerybeat
```

### 9. Smoke-test

- открыть `https://go.aivus.co`, залогиниться существующим пользователем;
- открыть `https://api.aivus.co/admin/`, проверить что список объектов соответствует ожиданиям;
- создать тестовый бриф — убедиться что Brief AI отвечает (значит Vertex credentials живы);
- открыть `https://databasus.aivus.co`, проверить что job снова идёт по расписанию (если потерян — пересоздать).

## Сценарий 2: тот же сервер, упала только БД

Самый частый кейс. Просто восстанавливаем postgres data volume:

1. Зайти в Databasus UI → последний удачный бэкап → **Restore** в `aivus_postgres`.
2. Перезапустить django/celery.

Если Databasus недоступен — путь через `pg_restore` из шага 8 второго сценария.

## Сценарий 3: ротация ключей и секретов

Если утёк один из секретов:

| Что утекло | Что делать |
|---|---|
| `POSTGRES_PASSWORD` | сменить через `psql ALTER USER`, обновить `.env` на сервере + локально, recreate всех бэкенд-контейнеров (django/celery/flower) |
| `HMAC_SECRET` | сгенерировать новый, обновить в `.env`, recreate django+frontend одновременно (иначе rolling restart разорвёт связь) |
| `DJANGO_SECRET_KEY` | сгенерировать новый, обновить в `.env`, recreate django — все сессии инвалидируются, пользователи перелогинятся |
| `NEXTAUTH_SECRET` | как `DJANGO_SECRET_KEY`, но recreate frontend |
| `AUTH_GOOGLE_SECRET` | новый client secret в Google Cloud Console → обновить `.env` → recreate frontend |
| GCP service account JSON | revoke в GCP IAM, выпустить новый, перезалить `gcp-credentials.json`/`vertex-credentials.json`, recreate django+celery+frontend |
| GHCR PAT | revoke на github, выпустить новый scope `read:packages`, перезалить `~/.docker/config.json` |
| Databasus admin | в UI поменять пароль; basic auth у traefik для этого сервиса не используется — авторизация через сам Databasus |

После любой смены: пересоздать секрет-бэкап локально (`scp .env`, обновить `prod.env`).

## Чего сейчас не хватает (TODO)

Эти пункты не блокируют DR, но их полезно закрыть:

1. **Автосинк секретов в облако.** Сейчас `prod.env`/credentials лежат только на dev-машине. Стоит настроить ежесуточный rclone-sync `~/aivus/.env` + `~/data/*.json` в отдельный приватный GCS bucket `aivus-secrets-backup` под другим SA, чтобы dev-машина не была единственной точкой отказа.
2. **Регулярный restore-drill.** Раз в квартал поднимать копию prod в staging-окружении и проверять, что бэкап действительно восстанавливается. Бэкап без проверенного restore — не бэкап.
3. **Externalized traefik ACME storage.** При смене сервера сертификаты Let's Encrypt перевыпустятся, но если делать это часто, упрёшься в rate-limit. Можно положить acme.json в S3/GCS с шифрованием.
4. **Pin образов до конкретных тэгов.** `ghcr.io/aivus-tools/backend-py:latest` — `latest` плохо для воспроизводимости; на проде стоит зафиксировать `BACKEND_TAG` в `.env` на конкретный SHA-tag.
5. **Runbook ротации DNS.** Если основной домен `aivus.co` меняется или Cloudflare уходит — нужен отдельный документ, как переключить.

## Контакты на случай беды

- Владелец инфры: ipolo.box@gmail.com
- GCP проект: `pioneering-flag-476313-u2`
- GHCR org: `aivus-tools`
- DNS-провайдер: Cloudflare (см. `aivus-cloudflare-import.txt` и `aivus-dns-records.json` в корне репо)
