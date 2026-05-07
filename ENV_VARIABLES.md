# Environment Variables Guide

Этот документ описывает все переменные окружения, необходимые для развертывания Aivus в production.

## 📋 Категории переменных

1. **🔐 Секреты** - должны храниться в GitHub Secrets или безопасном хранилище
2. **⚙️ Конфигурация** - можно определить в деплой-скрипте или `.env` файле
3. **🌐 Публичные** - можно коммитить в репозиторий (не содержат чувствительных данных)

---

## 🔐 СЕКРЕТЫ (GitHub Secrets / Vault)

### 1. Django Secret Key
```bash
DJANGO_SECRET_KEY=<random-50-char-string>
```
**Где:** Django settings  
**Как сгенерировать:**
```bash
python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"
```

### 2. HMAC Secret (для аутентификации Frontend ↔ Backend)
```bash
HMAC_SECRET=<random-64-char-string>
```
**Где:** Django + Next.js  
**Важно:** Должен быть одинаковым на фронте и беке!  
**Как сгенерировать:**
```bash
openssl rand -hex 32
```

### 3. API Key (для внутренних запросов)
```bash
API_KEY=<random-string>
```
**Где:** Django  
**Как сгенерировать:**
```bash
openssl rand -hex 24
```

### 4. NextAuth Secret
```bash
NEXTAUTH_SECRET=<random-string>
```
**Где:** Next.js  
**Как сгенерировать:**
```bash
openssl rand -base64 32
```

### 5. Database Password
```bash
POSTGRES_PASSWORD=<strong-password>
```
**Где:** PostgreSQL + Django  
**Как сгенерировать:**
```bash
openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
```

### 6. Google OAuth Credentials
```bash
AUTH_GOOGLE_ID=<your-google-client-id>
AUTH_GOOGLE_SECRET=<your-google-client-secret>
```
**Где:** Next.js  
**Как получить:** [Google Cloud Console](https://console.cloud.google.com/apis/credentials)

### 7. Brevo API Key (Email)
```bash
BREVO_API_KEY=<your-brevo-api-key>
```
**Где:** Django  
**Как получить:** [Brevo Dashboard](https://app.brevo.com/settings/keys/api)

### 8. Sentry DSN (Error Tracking)
```bash
SENTRY_DSN=<your-sentry-dsn>
```
**Где:** Django  
**Как получить:** [Sentry Project Settings](https://sentry.io/)

### 9. GCP Service Account Credentials
```bash
# JSON ключи runtime сервис-аккаунта sa-for-vertex-ai@pioneering-flag-476313-u2.iam.gserviceaccount.com
VERTEX_CREDENTIALS_PATH=/app/vertex-credentials.json   # Vertex Gemini + Speech-to-Text
GOOGLE_APPLICATION_CREDENTIALS=/app/gcs-credentials.json  # GCS (аттачменты, финальные документы)
GOOGLE_CLOUD_PROJECT=pioneering-flag-476313-u2
GOOGLE_CLOUD_LOCATION=us-central1                       # для Vertex Gemini
GOOGLE_CLOUD_SPEECH_LOCATION=global                     # опционально, дефолт global
```
**Где:** Django, Celery worker, Celery beat (все три контейнера должны видеть креденшалы)
**Как получить:** См. `GCP_SETUP.md`. Для STT — отдельный раздел "Runtime: APIs и роли" в том же файле.

**Минимум для голосового ввода работает:**
- API `speech.googleapis.com` включён в проекте.
- На SA назначена роль `roles/speech.client` (даёт `speech.recognizers.recognize`).
- `STT_DEV_FAKE=1` чтобы вернуть фейковый текст без вызова GCP (полезно для CI и локальной разработки без креденшалов).

### 10. Basic Auth для админ-панелей
```bash
# Traefik Dashboard
TRAEFIK_BASIC_AUTH=admin:$apr1$xyz...  # htpasswd format

# Flower (Celery monitoring)
FLOWER_BASIC_AUTH=admin:$apr1$xyz...

# Mailpit (staging only)
MAILPIT_BASIC_AUTH=admin:$apr1$xyz...
```
**Как сгенерировать:**
```bash
# Установить htpasswd (если нет)
# Ubuntu: apt-get install apache2-utils
# macOS: brew install httpd

# Создать пароль
htpasswd -nb admin your-password
# Результат: admin:$apr1$xyz...
```

---

## ⚙️ КОНФИГУРАЦИЯ (можно в деплой-скрипте)

### 1. Домен и SSL
```bash
DOMAIN=aivus.co
ACME_EMAIL=admin@aivus.co
```

### 2. Docker Registry (GCP Artifact Registry)
```bash
GCP_REGISTRY=us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus
BACKEND_TAG=latest
FRONTEND_TAG=latest
```

### 3. Database
```bash
POSTGRES_DB=aivus
POSTGRES_USER=aivus
```

### 4. Django Settings
```bash
DJANGO_ALLOWED_HOSTS=aivus.co,www.aivus.co,api.aivus.co
DJANGO_ADMIN_URL=admin/  # Рекомендуется изменить на что-то уникальное
DJANGO_SECURE_SSL_REDIRECT=True
```

### 5. Email Settings
```bash
DJANGO_DEFAULT_FROM_EMAIL=noreply@aivus.co
DJANGO_SERVER_EMAIL=server@aivus.co
BREVO_API_URL=https://api.brevo.com/v3/
```

### 6. GCP Storage
```bash
DJANGO_GCP_STORAGE_BUCKET_NAME=aivus-production-media
```

### 7. Sentry
```bash
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.1  # 10% трейсов для performance monitoring
```

### 8. Frontend
```bash
NEXT_PUBLIC_LOCALE=en  # или ru
FRONTEND_DEBUG=false
```

---

## 🌐 ПУБЛИЧНЫЕ (можно коммитить)

Эти переменные не содержат чувствительных данных и могут быть в репозитории:

```bash
# Node environment
NODE_ENV=production

# Django settings module
DJANGO_SETTINGS_MODULE=config.settings.production

# Database connection max age
CONN_MAX_AGE=60

# Redis URL (internal Docker network)
REDIS_URL=redis://redis:6379/0

# API URL (internal Docker network)
API_URL=http://django:5000

# NextAuth
AUTH_TRUST_HOST=true
```

---

## 📝 Пример `.env` файла для production

Создай файл `.env` на сервере:

```bash
# ===========================================
# DOMAIN & SSL
# ===========================================
DOMAIN=aivus.co
ACME_EMAIL=admin@aivus.co

# ===========================================
# DOCKER REGISTRY
# ===========================================
GCP_REGISTRY=us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus
BACKEND_TAG=latest
FRONTEND_TAG=latest

# ===========================================
# DATABASE
# ===========================================
POSTGRES_DB=aivus
POSTGRES_USER=aivus
POSTGRES_PASSWORD=<CHANGE_ME>

# ===========================================
# DJANGO SECRETS
# ===========================================
DJANGO_SECRET_KEY=<CHANGE_ME>
HMAC_SECRET=<CHANGE_ME>
API_KEY=<CHANGE_ME>

# ===========================================
# DJANGO CONFIGURATION
# ===========================================
DJANGO_ALLOWED_HOSTS=aivus.co,www.aivus.co
DJANGO_ADMIN_URL=secret-admin-url/
DJANGO_SECURE_SSL_REDIRECT=True

# ===========================================
# EMAIL (BREVO)
# ===========================================
BREVO_API_KEY=<CHANGE_ME>
BREVO_API_URL=https://api.brevo.com/v3/
DJANGO_DEFAULT_FROM_EMAIL=noreply@aivus.co
DJANGO_SERVER_EMAIL=server@aivus.co

# ===========================================
# GCP STORAGE
# ===========================================
DJANGO_GCP_STORAGE_BUCKET_NAME=aivus-production-media
GCP_CREDENTIALS_PATH=/path/to/service-account-key.json

# ===========================================
# SENTRY
# ===========================================
SENTRY_DSN=<CHANGE_ME>
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.1

# ===========================================
# NEXTAUTH
# ===========================================
NEXTAUTH_SECRET=<CHANGE_ME>
AUTH_GOOGLE_ID=<CHANGE_ME>
AUTH_GOOGLE_SECRET=<CHANGE_ME>

# ===========================================
# FRONTEND
# ===========================================
NEXT_PUBLIC_LOCALE=en
FRONTEND_DEBUG=false

# ===========================================
# BASIC AUTH (htpasswd format)
# ===========================================
TRAEFIK_BASIC_AUTH=admin:$apr1$...
FLOWER_BASIC_AUTH=admin:$apr1$...
MAILPIT_BASIC_AUTH=admin:$apr1$...
```

---

## 🔒 Рекомендации по безопасности

### 1. Генерация секретов
```bash
# Создай скрипт для генерации всех секретов
cat > generate-secrets.sh << 'EOF'
#!/bin/bash
echo "DJANGO_SECRET_KEY=$(python3 -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())')"
echo "HMAC_SECRET=$(openssl rand -hex 32)"
echo "API_KEY=$(openssl rand -hex 24)"
echo "NEXTAUTH_SECRET=$(openssl rand -base64 32)"
echo "POSTGRES_PASSWORD=$(openssl rand -base64 32 | tr -d '=+/' | cut -c1-25)"
EOF

chmod +x generate-secrets.sh
./generate-secrets.sh
```

### 2. Хранение секретов

**Вариант A: GitHub Secrets (для CI/CD)**
- Settings → Secrets and variables → Actions → New repository secret
- Добавь все секреты из раздела "🔐 СЕКРЕТЫ"

**Вариант B: `.env` файл на сервере**
- Создай `.env` на сервере
- Установи права: `chmod 600 .env`
- Добавь в `.gitignore` (уже добавлен)

**Вариант C: Vault (для enterprise)**
- HashiCorp Vault
- AWS Secrets Manager
- GCP Secret Manager

### 3. Ротация секретов

Регулярно меняй:
- `DJANGO_SECRET_KEY` (раз в год)
- `HMAC_SECRET` (раз в год, координируй с фронтом!)
- `API_KEY` (раз в квартал)
- `POSTGRES_PASSWORD` (раз в год)
- `NEXTAUTH_SECRET` (раз в год)

---

## 🚀 Быстрый старт

### 1. Скопируй шаблон
```bash
cp ENV_VARIABLES.md .env
```

### 2. Сгенерируй секреты
```bash
./generate-secrets.sh >> .env
```

### 3. Заполни остальные переменные
- Google OAuth credentials
- Brevo API key
- Sentry DSN
- GCP credentials path

### 4. Проверь `.env`
```bash
# Убедись, что все <CHANGE_ME> заменены
grep -n "CHANGE_ME" .env
```

### 5. Запусти
```bash
docker-compose -f docker-compose.production.yml up -d
```

---

## 📊 Таблица переменных по сервисам

| Переменная | Django | Frontend | Postgres | Redis | Traefik | Секрет? |
|-----------|--------|----------|----------|-------|---------|---------|
| `DOMAIN` | ✅ | ✅ | ❌ | ❌ | ✅ | ❌ |
| `DJANGO_SECRET_KEY` | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `HMAC_SECRET` | ✅ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `NEXTAUTH_SECRET` | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `POSTGRES_PASSWORD` | ✅ | ❌ | ✅ | ❌ | ❌ | ✅ |
| `AUTH_GOOGLE_ID` | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `AUTH_GOOGLE_SECRET` | ❌ | ✅ | ❌ | ❌ | ❌ | ✅ |
| `BREVO_API_KEY` | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `SENTRY_DSN` | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `GCP_CREDENTIALS_PATH` | ✅ | ❌ | ❌ | ❌ | ❌ | ✅ |
| `TRAEFIK_BASIC_AUTH` | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |

---

## ❓ FAQ

### Q: Как изменить HMAC_SECRET без даунтайма?
A: 
1. Добавь новый секрет как `HMAC_SECRET_NEW`
2. Обнови Django для поддержки обоих секретов
3. Обнови Frontend на новый секрет
4. Удали старый секрет из Django

### Q: Нужно ли менять секреты при каждом деплое?
A: Нет, секреты меняются только при ротации или компрометации.

### Q: Где хранить GCP credentials JSON?
A: 
- **Локально:** В `.gitignore`-файле
- **На сервере:** В `/opt/aivus/secrets/gcp-credentials.json` с правами 600
- **В CI/CD:** В GitHub Secrets как base64-encoded строка

### Q: Как тестировать production конфигурацию локально?
A: 
```bash
# Создай .env.production.local
cp .env .env.production.local

# Измени домен на localhost
DOMAIN=localhost

# Отключи SSL redirect
DJANGO_SECURE_SSL_REDIRECT=False

# Запусти
docker-compose -f docker-compose.production.yml --env-file .env.production.local up
```

---

## 📚 Дополнительные ресурсы

- [Django Environment Variables](https://docs.djangoproject.com/en/stable/topics/settings/)
- [Next.js Environment Variables](https://nextjs.org/docs/app/building-your-application/configuring/environment-variables)
- [Docker Compose Environment Variables](https://docs.docker.com/compose/environment-variables/)
- [Traefik Configuration](https://doc.traefik.io/traefik/)
- [Let's Encrypt Rate Limits](https://letsencrypt.org/docs/rate-limits/)

