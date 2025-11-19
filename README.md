# 📚 Aivus Documentation

Центральный каталог документации проекта Aivus.

---

## 📂 Структура

```
Specs/
├── README.md                           # Этот файл (навигация)
├── MVP_ROADMAP_SHORT.md               # Краткий roadmap MVP
├── DEPLOYMENT.md                      # Главный индекс по деплою
├── DEPLOYMENT_SUMMARY.md              # Краткая сводка деплоя
├── DEPLOYMENT_ARCHITECTURE.md         # Архитектура deployment
├── ENV_VARIABLES.md                   # Переменные окружения
├── QUICK_DEPLOY.md                    # Быстрая инструкция
├── GCP_SETUP.md                       # Настройка GCP
└── deployment/                        # Скрипты и конфиги
    ├── README.md                      # Документация по деплою
    ├── docker-compose.production.yml  # Docker Compose для production
    ├── env.production.template        # Шаблон .env
    ├── install.sh                     # Главный скрипт установки
    ├── deploy-backend.sh              # Деплой бекенда (GHA)
    └── deploy-frontend.sh             # Деплой фронтенда (GHA)
```

---

## 🚀 Deployment (Развертывание)

### Главный индекс
**Файл:** [`DEPLOYMENT.md`](./DEPLOYMENT.md)

Начни отсюда! Полная навигация по всей документации по деплою.

---

### Быстрый старт
**Файл:** [`QUICK_DEPLOY.md`](./QUICK_DEPLOY.md)

Пошаговая инструкция для быстрого развертывания:
1. Подготовка сервера
2. Настройка переменных окружения
3. Запуск приложения
4. Проверка и troubleshooting

---

### Скрипты и конфигурация
**Директория:** [`deployment/`](./deployment/)

Все необходимые файлы для деплоя:
- `install.sh` - главный скрипт установки
- `deploy-backend.sh` - деплой бекенда
- `deploy-frontend.sh` - деплой фронтенда
- `docker-compose.production.yml` - Docker Compose
- `env.production.template` - шаблон переменных

**См. [`deployment/README.md`](./deployment/README.md) для деталей.**

---

### Архитектура
**Файл:** [`DEPLOYMENT_ARCHITECTURE.md`](./DEPLOYMENT_ARCHITECTURE.md)

Детальное описание архитектуры:
- Схемы и диаграммы
- Request flow
- Network architecture
- Security layers
- Scaling strategy

---

### Переменные окружения
**Файл:** [`ENV_VARIABLES.md`](./ENV_VARIABLES.md)

Полный справочник по переменным:
- Категоризация (секреты/конфигурация/публичные)
- Описание каждой переменной
- Как генерировать секреты
- Рекомендации по безопасности
- FAQ

---

### Настройка GCP
**Файл:** [`GCP_SETUP.md`](./GCP_SETUP.md)

Инструкция по настройке Google Cloud Platform:
- Создание Service Account
- Настройка Workload Identity Federation
- Конфигурация GitHub Secrets
- Artifact Registry

---

### Краткая сводка
**Файл:** [`DEPLOYMENT_SUMMARY.md`](./DEPLOYMENT_SUMMARY.md)

Краткая сводка того, что сделано:
- Список созданных файлов
- Описание сервисов
- Checklist перед деплоем
- Следующие шаги

---

## 🎯 Roadmap

### MVP Roadmap
**Файл:** [`MVP_ROADMAP_SHORT.md`](./MVP_ROADMAP_SHORT.md)

Краткий план развития MVP.

---

## 🔧 Как использовать эту документацию

### Для первого деплоя:
1. Прочитай [`DEPLOYMENT.md`](./DEPLOYMENT.md) - главный индекс
2. Изучи [`QUICK_DEPLOY.md`](./QUICK_DEPLOY.md) - пошаговая инструкция
3. Настрой GCP по [`GCP_SETUP.md`](./GCP_SETUP.md)
4. Используй скрипты из [`deployment/`](./deployment/)

### Для понимания архитектуры:
1. Прочитай [`DEPLOYMENT_ARCHITECTURE.md`](./DEPLOYMENT_ARCHITECTURE.md)
2. Изучи [`docker-compose.production.yml`](./deployment/docker-compose.production.yml)
3. Просмотри [`ENV_VARIABLES.md`](./ENV_VARIABLES.md)

### Для обновления приложения:
1. Используй [`deploy-backend.sh`](./deployment/deploy-backend.sh)
2. Используй [`deploy-frontend.sh`](./deployment/deploy-frontend.sh)
3. См. [`deployment/README.md`](./deployment/README.md) для деталей

---

## 📝 Соглашения

### Документация
- Все `.md` файлы используют GitHub Flavored Markdown
- Используй эмодзи для визуальной навигации
- Код оформляй в блоках с указанием языка
- Добавляй примеры использования

### Скрипты
- Все скрипты должны быть исполняемыми (`chmod +x`)
- Используй `set -e` для остановки при ошибках
- Добавляй цветной вывод для лучшей читаемости
- Логируй все важные действия

### Конфигурация
- Секреты только через переменные окружения
- Используй `.env` файлы (не коммитить!)
- Документируй все переменные
- Предоставляй шаблоны (`.template`)

---

## 🔄 Обновление документации

При внесении изменений:
1. Обнови соответствующий `.md` файл
2. Обнови этот `README.md` если добавлены новые файлы
3. Проверь ссылки на актуальность
4. Закоммить изменения

---

## 📞 Поддержка

При возникновении проблем:
1. Проверь соответствующий раздел документации
2. Используй troubleshooting секции
3. Проверь логи на сервере
4. Обратись к команде разработки

---

**Последнее обновление:** 2024  
**Версия:** 1.0  
**Статус:** ✅ Готово к использованию
