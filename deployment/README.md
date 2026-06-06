# 🚀 Aivus Deployment Scripts

Этот каталог содержит все необходимые файлы для развертывания Aivus в production.

---

## 📂 Файлы

### 1. `docker-compose.production.yml`
Главный файл Docker Compose для production.

**Сервисы:**
- ✅ Traefik (reverse proxy + SSL)
- ✅ PostgreSQL (database)
- ✅ pgAdmin (database management)
- ✅ pgbackups (automated backups)
- ✅ Redis (cache + broker)
- ✅ Django (backend API)
- ✅ Celery Worker (async tasks)
- ✅ Celery Beat (scheduler)
- ✅ Flower (Celery monitoring)
- ✅ Mailpit (email testing)
- ✅ Next.js Frontend

**Особенности:**
- Автоматический SSL через Let's Encrypt
- Volumes в `~/data` (не Docker volumes)
- Автоматические бэкапы PostgreSQL (ежедневно)
- Basic Auth для админ-панелей

---

### 2. `install.sh` ⭐
Главный скрипт установки для нового сервера.

**🔒 БЕЗОПАСЕН ДЛЯ ПОВТОРНОГО ЗАПУСКА!**

**Что делает:**
1. Устанавливает Docker и Docker Compose
2. Создает необходимые директории
3. **Обнаруживает существующую установку**
4. **Сохраняет существующие секреты** (или генерирует новые)
5. Создает `.env` файл (с автоматическим бэкапом)
6. Сохраняет credentials в `CREDENTIALS.txt`
7. Настраивает GCP authentication

**Использование:**
```bash
# Первая установка
ssh user@server
curl -sSL https://raw.githubusercontent.com/.../install.sh | bash

# Повторный запуск (безопасно!)
cd ~/aivus
./install.sh
# Выбери опцию 1: Keep existing secrets (рекомендуется)
```

**Режимы работы:**
- **Опция 1:** Сохранить существующие секреты (SAFE) ✅
- **Опция 2:** Сгенерировать новые секреты (DANGEROUS) ⚠️
- **Опция 3:** Выход для ручного бэкапа

**Что нужно подготовить:**
- Домен с настроенными DNS записями
- Email для Let's Encrypt
- Email для pgAdmin
- (Опционально) Google OAuth credentials
- (Опционально) Brevo API key
- (Опционально) Sentry DSN
- GCP service account JSON файл

**📖 Подробнее:** См. `SAFE_REINSTALL.md`

---

### 3. `deploy-backend.sh`
Скрипт деплоя бекенда (вызывается из GitHub Actions).

**Что делает:**
1. Обновляет `BACKEND_TAG` в `.env`
2. Пуллит новые образы
3. Пересоздает backend сервисы
4. Запускает миграции
5. Собирает статику

**Использование:**
```bash
# Из GitHub Actions
ssh user@server 'bash -s' < deploy-backend.sh latest

# Вручную на сервере
cd ~/aivus
./deploy-backend.sh v1.2.3
```

---

### 4. `deploy-frontend.sh`
Скрипт деплоя фронтенда (вызывается из GitHub Actions).

**Что делает:**
1. Обновляет `FRONTEND_TAG` в `.env`
2. Пуллит новый образ
3. Пересоздает frontend сервис

**Использование:**
```bash
# Из GitHub Actions
ssh user@server 'bash -s' < deploy-frontend.sh latest

# Вручную на сервере
cd ~/aivus
./deploy-frontend.sh v1.2.3
```

---

## 🚀 Быстрый старт

### Первоначальная установка

#### 1. Подготовка
```bash
# На локальной машине
cd Specs/deployment

# Скопируй файлы на сервер
scp install.sh user@server:~/
scp docker-compose.production.yml user@server:~/
scp deploy-backend.sh user@server:~/
scp deploy-frontend.sh user@server:~/
```

#### 2. Запуск установки
```bash
# На сервере
ssh user@server

# Запусти установку
chmod +x install.sh
./install.sh

# Следуй инструкциям скрипта
```

#### 3. Копирование GCP credentials
```bash
# На локальной машине
scp gcp-credentials.json user@server:~/data/

# На сервере
chmod 600 ~/data/gcp-credentials.json
```

#### 4. Настройка GCP authentication
```bash
# На сервере
gcloud auth activate-service-account --key-file=~/data/gcp-credentials.json
gcloud auth configure-docker us-central1-docker.pkg.dev
```

#### 5. Копирование docker-compose.yml
```bash
# На сервере
cp ~/docker-compose.production.yml ~/aivus/
cd ~/aivus
```

#### 6. Запуск сервисов
```bash
# На сервере
cd ~/aivus
docker compose -f docker-compose.production.yml up -d

# Проверка статуса
docker compose -f docker-compose.production.yml ps

# Логи
docker compose -f docker-compose.production.yml logs -f
```

#### 7. Инициализация Django
```bash
# Миграции
docker compose -f docker-compose.production.yml exec django python manage.py migrate

# Создание суперпользователя
docker compose -f docker-compose.production.yml exec django python manage.py createsuperuser

# Сбор статики (если нужно)
docker compose -f docker-compose.production.yml exec django python manage.py collectstatic --noinput
```

---

## 🔄 Обновление приложения

### Автоматическое (через GitHub Actions)

#### Backend
```bash
# В репозитории Backend запусти GitHub Action
# Actions → Build and Push Backend → Run workflow

# На сервере автоматически запустится deploy-backend.sh
```

#### Frontend
```bash
# В репозитории Frontend запусти GitHub Action
# Actions → Build and Push Frontend → Run workflow

# На сервере автоматически запустится deploy-frontend.sh
```

### Ручное

#### Backend
```bash
cd ~/aivus
./deploy-backend.sh v1.2.3
```

#### Frontend
```bash
cd ~/aivus
./deploy-frontend.sh v1.2.3
```

---

## 📊 Мониторинг

### Доступные endpoints

| URL | Сервис | Credentials |
|-----|--------|-------------|
| `https://your-domain.com` | Frontend | - |
| `https://your-domain.com/api/v1/` | Django API | - |
| `https://your-domain.com/admin/` | Django Admin | Superuser |
| `https://pgadmin.your-domain.com` | pgAdmin | См. CREDENTIALS.txt |
| `https://flower.your-domain.com` | Flower | Basic Auth |
| `https://mailpit.your-domain.com` | Mailpit | Basic Auth |
| `https://traefik.your-domain.com` | Traefik | Basic Auth |

### Логи
```bash
# Все сервисы
docker compose -f docker-compose.production.yml logs -f

# Конкретный сервис
docker compose -f docker-compose.production.yml logs -f django
docker compose -f docker-compose.production.yml logs -f frontend
docker compose -f docker-compose.production.yml logs -f celeryworker
```

### Статус
```bash
docker compose -f docker-compose.production.yml ps
```

---

## 💾 Backup & Restore

### Автоматические бэкапы
Бэкапы PostgreSQL создаются автоматически:
- **Расписание:** Ежедневно
- **Хранение:** 
  - 7 дней (daily)
  - 4 недели (weekly)
  - 6 месяцев (monthly)
- **Локация:** `~/data/pgbackups/`

### Ручной бэкап
```bash
# Создать бэкап
docker compose -f docker-compose.production.yml exec postgres \
  pg_dump -U aivus aivus > ~/data/pgbackups/manual-$(date +%Y%m%d-%H%M%S).sql

# Сжать
gzip ~/data/pgbackups/manual-*.sql
```

### Восстановление
```bash
# Из автоматического бэкапа
docker compose -f docker-compose.production.yml exec -T postgres \
  psql -U aivus aivus < ~/data/pgbackups/daily/aivus-YYYYMMDD.sql

# Из ручного бэкапа
gunzip -c ~/data/pgbackups/manual-20240101-120000.sql.gz | \
  docker compose -f docker-compose.production.yml exec -T postgres psql -U aivus aivus
```

---

## 🛠️ Полезные команды

### Управление сервисами
```bash
# Запуск
docker compose -f docker-compose.production.yml up -d

# Остановка
docker compose -f docker-compose.production.yml down

# Перезапуск
docker compose -f docker-compose.production.yml restart

# Перезапуск конкретного сервиса
docker compose -f docker-compose.production.yml restart django
```

### Django shell
```bash
docker compose -f docker-compose.production.yml exec django python manage.py shell
```

### Celery tasks
```bash
# Активные задачи
docker compose -f docker-compose.production.yml exec celeryworker \
  celery -A config.celery_app inspect active

# Статистика
docker compose -f docker-compose.production.yml exec celeryworker \
  celery -A config.celery_app inspect stats
```

### Database
```bash
# Подключение к PostgreSQL
docker compose -f docker-compose.production.yml exec postgres \
  psql -U aivus aivus

# Список таблиц
docker compose -f docker-compose.production.yml exec postgres \
  psql -U aivus aivus -c "\dt"
```

---

## 🐛 Troubleshooting

### SSL сертификат не получен
```bash
# Проверь DNS
dig your-domain.com

# Проверь логи Traefik
docker compose -f docker-compose.production.yml logs traefik | grep -i acme

# Проверь firewall
sudo ufw status
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Frontend не подключается к Backend
```bash
# Проверь HMAC_SECRET (должен быть одинаковым!)
docker compose -f docker-compose.production.yml exec django env | grep HMAC_SECRET
docker compose -f docker-compose.production.yml exec frontend env | grep HMAC_SECRET

# Проверь логи
docker compose -f docker-compose.production.yml logs django
docker compose -f docker-compose.production.yml logs frontend
```

### Celery не обрабатывает задачи
```bash
# Проверь Redis
docker compose -f docker-compose.production.yml exec redis redis-cli ping

# Проверь логи
docker compose -f docker-compose.production.yml logs celeryworker

# Перезапусти
docker compose -f docker-compose.production.yml restart celeryworker
```

### Ошибка 502 Bad Gateway
```bash
# Проверь статус всех сервисов
docker compose -f docker-compose.production.yml ps

# Проверь health checks
docker compose -f docker-compose.production.yml exec postgres pg_isready
docker compose -f docker-compose.production.yml exec redis redis-cli ping

# Проверь логи Traefik
docker compose -f docker-compose.production.yml logs traefik
```

---

## 🔐 Безопасность

### Важные файлы
- `~/aivus/.env` - переменные окружения (chmod 600)
- `~/aivus/CREDENTIALS.txt` - credentials (chmod 600)
- `~/data/gcp-credentials.json` - GCP credentials (chmod 600)

### Автоматические бэкапы конфигурации
При повторном запуске `install.sh` создаются бэкапы:
```bash
~/aivus/.env.backup.YYYYMMDD_HHMMSS
~/aivus/CREDENTIALS.txt.backup.YYYYMMDD_HHMMSS
```

### Восстановление из бэкапа
```bash
# Найти последний бэкап
ls -lt ~/aivus/.env.backup* | head -1

# Восстановить
cp ~/aivus/.env.backup.20241120_153045 ~/aivus/.env

# Перезапустить сервисы
docker compose -f docker-compose.production.yml restart
```

### Рекомендации
- ✅ Регулярно обновляй Docker образы
- ✅ Настрой firewall (разрешить только 80, 443, 22)
- ✅ Используй SSH ключи вместо паролей
- ✅ Включи 2FA для GitHub
- ✅ Регулярно проверяй логи
- ✅ Настрой мониторинг и алерты
- ✅ **Скачивай бэкапы `.env` на локальную машину**

---

## 📚 Дополнительные ресурсы

- **Основная документация:** `/Specs/DEPLOYMENT.md`
- **Переменные окружения:** `/Specs/ENV_VARIABLES.md`
- **Архитектура:** `/Specs/ARCHITECTURE.md`
- **GCP Setup:** `/Specs/GCP_SETUP.md`
- **Восстановление прода:** `/Specs/DISASTER_RECOVERY.md`
- **Роутинг (Traefik):** `/Specs/deployment/ROUTING.md`

---

## 📞 Поддержка

При возникновении проблем:
1. Проверь логи: `docker compose logs -f`
2. Проверь статус: `docker compose ps`
3. Проверь конфигурацию: `docker compose config`
4. Обратись к документации в `/Specs/`

