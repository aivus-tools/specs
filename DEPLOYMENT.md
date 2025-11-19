# 🚀 Aivus Deployment Guide

Полное руководство по развертыванию Aivus в production.

---

## 📚 Документация

### 🎯 Быстрый старт
**Файл:** [`QUICK_DEPLOY.md`](./QUICK_DEPLOY.md)

Пошаговая инструкция для быстрого развертывания:
- Подготовка сервера
- Настройка переменных окружения
- Запуск приложения
- Проверка и troubleshooting

**Начни отсюда, если хочешь быстро задеплоить!**

---

### 🏗️ Архитектура
**Файл:** [`DEPLOYMENT_ARCHITECTURE.md`](./DEPLOYMENT_ARCHITECTURE.md)

Детальное описание архитектуры:
- Схемы и диаграммы
- Request flow
- Network architecture
- Security layers
- Scaling strategy

**Читай, если хочешь понять, как все устроено.**

---

### 🔐 Переменные окружения
**Файл:** [`ENV_VARIABLES.md`](./ENV_VARIABLES.md)

Полный справочник по переменным:
- Категоризация (секреты/конфигурация/публичные)
- Описание каждой переменной
- Как генерировать секреты
- Рекомендации по безопасности
- FAQ

**Обязательно прочитай перед настройкой .env файла!**

---

### ☁️ Настройка GCP
**Файл:** [`GCP_SETUP.md`](./GCP_SETUP.md)

Инструкция по настройке Google Cloud Platform:
- Создание Service Account
- Настройка Workload Identity Federation
- Конфигурация GitHub Secrets
- Artifact Registry

**Выполни эти шаги перед первым деплоем.**

---

### 📋 Сводка
**Файл:** [`DEPLOYMENT_SUMMARY.md`](./DEPLOYMENT_SUMMARY.md)

Краткая сводка того, что сделано:
- Список созданных файлов
- Описание сервисов
- Checklist перед деплоем
- Следующие шаги

**Используй как чеклист.**

---

## 📦 Файлы конфигурации

### Docker Compose
**Файл:** [`docker-compose.production.yml`](./docker-compose.production.yml)

Главный файл для развертывания всех сервисов:
```bash
docker-compose -f docker-compose.production.yml up -d
```

**Сервисы:**
- Traefik (reverse proxy + SSL)
- PostgreSQL (database)
- Redis (cache + broker)
- Django (backend API)
- Celery Worker (async tasks)
- Celery Beat (scheduler)
- Flower (Celery monitoring)
- Next.js Frontend
- Mailpit (email testing, staging only)

---

### Шаблон переменных
**Файл:** [`env.production.template`](./env.production.template)

Шаблон для создания `.env` файла:
```bash
cp env.production.template .env
nano .env  # Заполни все <CHANGE_ME>
```

---

### Генератор секретов
**Файл:** [`scripts/generate-secrets.sh`](./scripts/generate-secrets.sh)

Скрипт для автоматической генерации секретов:
```bash
chmod +x scripts/generate-secrets.sh
./scripts/generate-secrets.sh > secrets.env
```

Генерирует:
- `DJANGO_SECRET_KEY`
- `HMAC_SECRET`
- `API_KEY`
- `NEXTAUTH_SECRET`
- `POSTGRES_PASSWORD`
- Basic Auth пароли

---

## 🚀 Быстрый старт (TL;DR)

### 1. Подготовка (один раз)
```bash
# Настрой GCP (см. GCP_SETUP.md)
# Запусти GitHub Actions для сборки образов

# На сервере:
# Установи Docker
curl -fsSL https://get.docker.com | sh

# Создай директории
sudo mkdir -p /opt/aivus/{secrets,backups}
cd /opt/aivus

# Скопируй файлы
scp docker-compose.production.yml user@server:/opt/aivus/
scp env.production.template user@server:/opt/aivus/
scp gcp-credentials.json user@server:/opt/aivus/secrets/
```

### 2. Настройка переменных
```bash
# Сгенерируй секреты
./scripts/generate-secrets.sh > secrets.env

# Создай .env
cp env.production.template .env
cat secrets.env >> .env
nano .env  # Заполни оставшиеся переменные

# Установи права
chmod 600 .env
chmod 600 secrets/gcp-credentials.json
```

### 3. Запуск
```bash
# Аутентификация в GCP
gcloud auth activate-service-account --key-file=secrets/gcp-credentials.json
gcloud auth configure-docker us-central1-docker.pkg.dev

# Запуск
docker-compose -f docker-compose.production.yml up -d

# Инициализация Django
docker-compose -f docker-compose.production.yml exec django python manage.py migrate
docker-compose -f docker-compose.production.yml exec django python manage.py createsuperuser
```

### 4. Проверка
```bash
# Статус
docker-compose -f docker-compose.production.yml ps

# Логи
docker-compose -f docker-compose.production.yml logs -f

# Открой в браузере
https://your-domain.com
```

---

## 🎯 Этапы развертывания

### ✅ Этап 1: CI/CD (Завершен)
- [x] GitHub Actions для Frontend
- [x] GitHub Actions для Backend
- [x] Push образов в GCP Artifact Registry
- [x] Документация по настройке GCP

### ✅ Этап 2: Docker Compose (Завершен)
- [x] Единый docker-compose.production.yml
- [x] Traefik с автоматическим SSL
- [x] Все сервисы (Django, Frontend, Celery, etc)
- [x] Документация по переменным окружения
- [x] Скрипт генерации секретов
- [x] Шаблон .env файла
- [x] Быстрая инструкция по деплою
- [x] Архитектурная документация

### 🔄 Этап 3: Автоматизация (TODO)
- [ ] Скрипт подготовки сервера
- [ ] Скрипт автоматического деплоя
- [ ] GitHub Actions для деплоя на сервер
- [ ] Rollback механизм

### 📊 Этап 4: Мониторинг (TODO)
- [ ] Prometheus для метрик
- [ ] Grafana для визуализации
- [ ] Alertmanager для уведомлений
- [ ] Loki для централизованных логов

### 💾 Этап 5: Backup (TODO)
- [ ] Автоматические бэкапы PostgreSQL
- [ ] Backup volumes
- [ ] Retention policy
- [ ] Disaster recovery plan

---

## 🔧 Полезные команды

### Управление сервисами
```bash
# Запуск
docker-compose -f docker-compose.production.yml up -d

# Остановка
docker-compose -f docker-compose.production.yml down

# Перезапуск
docker-compose -f docker-compose.production.yml restart

# Статус
docker-compose -f docker-compose.production.yml ps

# Логи
docker-compose -f docker-compose.production.yml logs -f [service]
```

### Обновление
```bash
# Pull новых образов
docker-compose -f docker-compose.production.yml pull

# Обновление с zero downtime
docker-compose -f docker-compose.production.yml up -d

# Миграции
docker-compose -f docker-compose.production.yml exec django python manage.py migrate
```

### Backup
```bash
# Backup базы
docker-compose -f docker-compose.production.yml exec postgres \
  pg_dump -U aivus aivus > backup-$(date +%Y%m%d-%H%M%S).sql

# Restore базы
docker-compose -f docker-compose.production.yml exec -T postgres \
  psql -U aivus aivus < backup-20240101-120000.sql
```

### Debugging
```bash
# Django shell
docker-compose -f docker-compose.production.yml exec django python manage.py shell

# Django logs
docker-compose -f docker-compose.production.yml logs -f django

# Celery tasks
docker-compose -f docker-compose.production.yml exec celeryworker \
  celery -A config.celery_app inspect active
```

---

## 🌐 URL Endpoints

После развертывания доступны следующие endpoints:

| URL | Сервис | Описание |
|-----|--------|----------|
| `https://your-domain.com` | Frontend | Главная страница |
| `https://your-domain.com/api/v1/` | Django API | REST API |
| `https://your-domain.com/admin/` | Django Admin | Админка |
| `https://flower.your-domain.com` | Flower | Celery monitoring |
| `https://traefik.your-domain.com` | Traefik | Traefik dashboard |
| `https://mailpit.your-domain.com` | Mailpit | Email testing (staging) |

---

## 🔐 Безопасность

### Обязательно:
- ✅ Измени `DJANGO_ADMIN_URL` на что-то уникальное
- ✅ Используй сильные пароли для Basic Auth
- ✅ Настрой firewall (разрешить только 80, 443, 22)
- ✅ Регулярно обновляй Docker образы
- ✅ Храни `.env` в безопасном месте (не коммить!)

### Рекомендуется:
- 🔒 Настрой Fail2ban
- 🔒 Используй SSH ключи вместо паролей
- 🔒 Включи 2FA для GitHub
- 🔒 Регулярно ротируй секреты
- 🔒 Настрой мониторинг и алерты

---

## 📊 Мониторинг

### Логи
```bash
# Все сервисы
docker-compose -f docker-compose.production.yml logs -f

# Конкретный сервис
docker-compose -f docker-compose.production.yml logs -f django
docker-compose -f docker-compose.production.yml logs -f frontend
docker-compose -f docker-compose.production.yml logs -f celeryworker
```

### Метрики (через Flower)
```bash
# Открой в браузере
https://flower.your-domain.com

# Логин/пароль: из FLOWER_BASIC_AUTH
```

### Health Checks
```bash
# PostgreSQL
docker-compose -f docker-compose.production.yml exec postgres pg_isready

# Redis
docker-compose -f docker-compose.production.yml exec redis redis-cli ping

# Django
curl https://your-domain.com/api/v1/health  # (если есть endpoint)
```

---

## 🐛 Troubleshooting

### SSL сертификат не получен
```bash
# Проверь DNS
dig your-domain.com

# Проверь логи Traefik
docker-compose -f docker-compose.production.yml logs traefik | grep -i acme

# Проверь firewall
sudo ufw status
```

### Frontend не подключается к Backend
```bash
# Проверь HMAC_SECRET (должен быть одинаковым!)
docker-compose -f docker-compose.production.yml exec django env | grep HMAC_SECRET
docker-compose -f docker-compose.production.yml exec frontend env | grep HMAC_SECRET

# Проверь логи
docker-compose -f docker-compose.production.yml logs django
docker-compose -f docker-compose.production.yml logs frontend
```

### Celery не обрабатывает задачи
```bash
# Проверь Redis
docker-compose -f docker-compose.production.yml exec redis redis-cli ping

# Проверь логи worker
docker-compose -f docker-compose.production.yml logs celeryworker

# Перезапусти worker
docker-compose -f docker-compose.production.yml restart celeryworker
```

**Больше информации:** См. `QUICK_DEPLOY.md` → Troubleshooting

---

## 📞 Поддержка

При возникновении проблем:

1. **Проверь документацию:**
   - `QUICK_DEPLOY.md` - пошаговая инструкция
   - `ENV_VARIABLES.md` - переменные окружения
   - `DEPLOYMENT_ARCHITECTURE.md` - архитектура

2. **Проверь логи:**
   ```bash
   docker-compose -f docker-compose.production.yml logs -f
   ```

3. **Проверь статус:**
   ```bash
   docker-compose -f docker-compose.production.yml ps
   ```

4. **Проверь конфигурацию:**
   ```bash
   docker-compose -f docker-compose.production.yml config
   ```

---

## 📚 Дополнительные ресурсы

### Внешние ссылки:
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Django Deployment Checklist](https://docs.djangoproject.com/en/stable/howto/deployment/checklist/)
- [Next.js Deployment](https://nextjs.org/docs/deployment)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

### Внутренние документы:
- `Specs/` - спецификации проекта
- `Frontend/docs/` - документация фронтенда
- `Backend/aivus_backend/README.md` - документация бекенда

---

## ✅ Checklist перед деплоем

### Инфраструктура
- [ ] Сервер с Docker установлен
- [ ] DNS записи настроены
- [ ] Firewall настроен (80, 443, 22)
- [ ] GCP Service Account создан

### Конфигурация
- [ ] `.env` файл создан и заполнен
- [ ] Все секреты сгенерированы
- [ ] GCP credentials скопированы
- [ ] Basic Auth пароли установлены

### Сервисы
- [ ] Google OAuth настроен
- [ ] Brevo API key получен
- [ ] Sentry проект создан (опционально)
- [ ] GCS bucket создан

### GitHub
- [ ] GitHub Actions настроены
- [ ] Секреты добавлены в GitHub
- [ ] Образы собраны и загружены в GCP

### Тестирование
- [ ] Локальное тестирование пройдено
- [ ] Миграции проверены
- [ ] SSL сертификат получен
- [ ] Все endpoints доступны

---

**Готов к деплою? Начни с [`QUICK_DEPLOY.md`](./QUICK_DEPLOY.md)! 🚀**

---

**Последнее обновление:** 2024  
**Версия:** 1.0  
**Статус:** ✅ Готово к использованию
