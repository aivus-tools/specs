# 🚀 Quick Deploy Guide

Краткая инструкция по развертыванию Aivus в production.

## 📋 Предварительные требования

- Сервер с Docker и Docker Compose
- Домен с настроенными DNS записями
- GCP Service Account с доступом к Artifact Registry
- Настроенные GitHub Actions (см. `GCP_SETUP.md`)

---

## 🔧 Шаг 1: Подготовка сервера

### 1.1 Установка Docker
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
```

### 1.2 Создание директорий
```bash
sudo mkdir -p /opt/aivus/{secrets,backups}
sudo chown -R $USER:$USER /opt/aivus
cd /opt/aivus
```

### 1.3 Аутентификация в GCP Artifact Registry
```bash
# Скопируй service account key на сервер
scp gcp-credentials.json user@server:/opt/aivus/secrets/

# Настрой Docker для GCP
gcloud auth activate-service-account --key-file=/opt/aivus/secrets/gcp-credentials.json
gcloud auth configure-docker us-central1-docker.pkg.dev
```

---

## 🔐 Шаг 2: Настройка переменных окружения

### 2.1 Генерация секретов
```bash
# Скачай репозиторий (или только нужные файлы)
git clone <repo-url> /opt/aivus/config
cd /opt/aivus/config

# Сгенерируй секреты
./scripts/generate-secrets.sh > /opt/aivus/secrets/generated-secrets.env

# Просмотри сгенерированные секреты
cat /opt/aivus/secrets/generated-secrets.env
```

### 2.2 Создание .env файла
```bash
# Скопируй шаблон
cp env.production.template /opt/aivus/.env

# Добавь сгенерированные секреты
cat /opt/aivus/secrets/generated-secrets.env >> /opt/aivus/.env

# Отредактируй .env, заполни оставшиеся переменные
nano /opt/aivus/.env
```

**Обязательно заполни:**
- `DOMAIN` - твой домен
- `ACME_EMAIL` - email для Let's Encrypt
- `AUTH_GOOGLE_ID` и `AUTH_GOOGLE_SECRET` - Google OAuth
- `BREVO_API_KEY` - API ключ Brevo
- `SENTRY_DSN` - Sentry DSN (опционально)
- `DJANGO_ADMIN_URL` - измени на что-то уникальное (например, `secret-admin-panel-xyz/`)

### 2.3 Установка прав
```bash
chmod 600 /opt/aivus/.env
chmod 600 /opt/aivus/secrets/gcp-credentials.json
```

---

## 📦 Шаг 3: Запуск приложения

### 3.1 Скачивание docker-compose.yml
```bash
# Если еще не скачал репозиторий
cd /opt/aivus
wget https://raw.githubusercontent.com/<your-repo>/docker-compose.production.yml

# Или скопируй из репозитория
cp /opt/aivus/config/docker-compose.production.yml /opt/aivus/
```

### 3.2 Первый запуск
```bash
cd /opt/aivus

# Проверь конфигурацию
docker-compose -f docker-compose.production.yml config

# Запусти сервисы
docker-compose -f docker-compose.production.yml up -d

# Проверь логи
docker-compose -f docker-compose.production.yml logs -f
```

### 3.3 Инициализация Django
```bash
# Применение миграций
docker-compose -f docker-compose.production.yml exec django python manage.py migrate

# Создание суперпользователя
docker-compose -f docker-compose.production.yml exec django python manage.py createsuperuser

# Сбор статики (если не используется GCS)
docker-compose -f docker-compose.production.yml exec django python manage.py collectstatic --noinput
```

---

## ✅ Шаг 4: Проверка

### 4.1 Проверка сервисов
```bash
# Статус контейнеров
docker-compose -f docker-compose.production.yml ps

# Должны быть запущены:
# - traefik
# - postgres
# - redis
# - django
# - celeryworker
# - celerybeat
# - flower
# - frontend
```

### 4.2 Проверка доступности

| Сервис | URL | Описание |
|--------|-----|----------|
| Frontend | `https://your-domain.com` | Главная страница |
| Django Admin | `https://your-domain.com/admin/` | Админка Django |
| API | `https://your-domain.com/api/v1/` | REST API |
| Flower | `https://flower.your-domain.com` | Celery monitoring |
| Traefik Dashboard | `https://traefik.your-domain.com` | Traefik UI |

### 4.3 Проверка SSL
```bash
# Проверь, что сертификат получен
docker-compose -f docker-compose.production.yml exec traefik cat /letsencrypt/acme.json

# Проверь SSL в браузере или через curl
curl -I https://your-domain.com
```

---

## 🔄 Шаг 5: Обновление приложения

### 5.1 Через GitHub Actions
```bash
# Запусти workflow вручную из GitHub UI
# Actions → Build and Push Frontend/Backend → Run workflow

# На сервере:
cd /opt/aivus
docker-compose -f docker-compose.production.yml pull
docker-compose -f docker-compose.production.yml up -d
```

### 5.2 Ручное обновление
```bash
# Обнови переменные в .env (если нужно)
nano /opt/aivus/.env

# Измени тег образа
export BACKEND_TAG=v1.2.3
export FRONTEND_TAG=v1.2.3

# Перезапусти
docker-compose -f docker-compose.production.yml up -d

# Примени миграции (если есть)
docker-compose -f docker-compose.production.yml exec django python manage.py migrate
```

---

## 🛠️ Полезные команды

### Логи
```bash
# Все сервисы
docker-compose -f docker-compose.production.yml logs -f

# Конкретный сервис
docker-compose -f docker-compose.production.yml logs -f django
docker-compose -f docker-compose.production.yml logs -f frontend
docker-compose -f docker-compose.production.yml logs -f celeryworker
```

### Перезапуск
```bash
# Все сервисы
docker-compose -f docker-compose.production.yml restart

# Конкретный сервис
docker-compose -f docker-compose.production.yml restart django
```

### Остановка
```bash
# Остановить все
docker-compose -f docker-compose.production.yml down

# Остановить с удалением volumes (ОСТОРОЖНО!)
docker-compose -f docker-compose.production.yml down -v
```

### Backup базы данных
```bash
# Создать backup
docker-compose -f docker-compose.production.yml exec postgres pg_dump -U aivus aivus > /opt/aivus/backups/backup-$(date +%Y%m%d-%H%M%S).sql

# Восстановить backup
docker-compose -f docker-compose.production.yml exec -T postgres psql -U aivus aivus < /opt/aivus/backups/backup-20240101-120000.sql
```

### Django shell
```bash
docker-compose -f docker-compose.production.yml exec django python manage.py shell
```

### Celery tasks
```bash
# Список активных задач
docker-compose -f docker-compose.production.yml exec celeryworker celery -A config.celery_app inspect active

# Статистика
docker-compose -f docker-compose.production.yml exec celeryworker celery -A config.celery_app inspect stats
```

---

## 🐛 Troubleshooting

### Проблема: SSL сертификат не получен

**Решение:**
```bash
# Проверь DNS записи
dig your-domain.com

# Проверь логи Traefik
docker-compose -f docker-compose.production.yml logs traefik | grep -i acme

# Убедись, что порты 80 и 443 открыты
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Проблема: Frontend не может подключиться к Backend

**Решение:**
```bash
# Проверь, что Django запущен
docker-compose -f docker-compose.production.yml ps django

# Проверь логи Django
docker-compose -f docker-compose.production.yml logs django

# Проверь HMAC_SECRET (должен быть одинаковым!)
docker-compose -f docker-compose.production.yml exec django env | grep HMAC_SECRET
docker-compose -f docker-compose.production.yml exec frontend env | grep HMAC_SECRET
```

### Проблема: Celery worker не обрабатывает задачи

**Решение:**
```bash
# Проверь подключение к Redis
docker-compose -f docker-compose.production.yml exec redis redis-cli ping

# Проверь логи worker
docker-compose -f docker-compose.production.yml logs celeryworker

# Перезапусти worker
docker-compose -f docker-compose.production.yml restart celeryworker
```

### Проблема: Ошибка 502 Bad Gateway

**Решение:**
```bash
# Проверь, что все сервисы запущены
docker-compose -f docker-compose.production.yml ps

# Проверь логи Traefik
docker-compose -f docker-compose.production.yml logs traefik

# Проверь health checks
docker-compose -f docker-compose.production.yml exec postgres pg_isready
docker-compose -f docker-compose.production.yml exec redis redis-cli ping
```

---

## 📚 Дополнительные ресурсы

- **Полная документация по переменным:** `ENV_VARIABLES.md`
- **Настройка GCP:** `GCP_SETUP.md`
- **Архитектура проекта:** `Specs/PROJECT_ARCHITECTURE.md`
- **Docker Compose reference:** `docker-compose.production.yml`

---

## 🎉 Готово!

Твое приложение должно быть доступно по адресу `https://your-domain.com`

Если возникли проблемы, проверь:
1. DNS записи
2. Firewall правила
3. Логи сервисов
4. Переменные окружения

