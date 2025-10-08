# 🚀 AIVUS MVP - Дорожная карта разработки

**Дата начала:** 9 октября 2025 (четверг)  
**Дата завершения MVP:** 8 января 2026 (четверг)  
**Длительность:** 13 недель (3 месяца)

**График работы:** 5 дней в неделю × 3.5 часа/день = 17.5 часов/неделю

---

## 📊 ОБЩАЯ СТАТИСТИКА

| Этап | Недели | Часы | Даты | Статус |
|------|--------|------|------|--------|
| **Этап 0: Архитектура** | 4 недели | 50 часов | 9 окт - 6 ноя | 🔜 Старт |
| **Этап 1: Кабинет Вендора** | 3 недели | 30 часов | 7 ноя - 27 ноя | ⏳ Ожидание |
| **Этап 2: Кабинет Клиента** | 4 недели | 40 часов | 28 ноя - 25 дек | ⏳ Ожидание |
| **Этап 3: Финализация** | 2 недели | 30 часов | 26 дек - 8 янв | ⏳ Ожидание |
| **ИТОГО** | **13 недель** | **150 часов** | **9 окт - 8 янв** | |

---

# 🏗️ ЭТАП 0: АРХИТЕКТУРА И МИГРАЦИЯ BACKEND
**📅 Даты:** 9 октября - 6 ноября 2025 (4 недели)  
**⏱️ Время:** 50 часов  
**🎯 Результат:** Работающий Django backend на серверах с текущим фронтендом

## Что будет сделано:

### 1. Django Backend (30 часов)
#### 1.1 Базовая инфраструктура
- ✅ Создание Django проекта с правильной структурой
- ✅ Настройка PostgreSQL подключения
- ✅ Docker контейнеризация
- ✅ Переменные окружения (dev/staging/prod)

#### 1.2 База данных
- ✅ Создание всех моделей Django (Users, Vendors, Clients, Briefs, Offers, Categories, Entries, Units, Rates)
- ✅ Миграции базы данных
- ✅ Seed скрипт для тестовых данных

#### 1.3 API Endpoints (точная копия текущих)
**Authentication:**
- ✅ `POST /api/v1/auth/register` - регистрация пользователя
- ✅ `POST /api/v1/auth/login` - вход (email/password + Google OAuth)
- ✅ `POST /api/v1/auth/check-email` - проверка существования email
- ✅ `POST /api/v1/auth/forgot-password` - запрос сброса пароля
- ✅ `POST /api/v1/auth/reset-password` - сброс пароля

**Users:**
- ✅ `GET /api/v1/users` - список пользователей
- ✅ `GET /api/v1/users/me` - текущий пользователь
- ✅ `GET /api/v1/users/:id` - пользователь по ID
- ✅ `POST /api/v1/users` - создать пользователя
- ✅ `PUT /api/v1/users/:id` - обновить пользователя
- ✅ `DELETE /api/v1/users/:id` - удалить пользователя
- ✅ `PATCH /api/v1/users/:id/change-group` - сменить группу (CLIENT/VENDOR)

**Vendors & Clients:**
- ✅ `GET /api/v1/vendors` - список вендоров
- ✅ `GET /api/v1/vendors/:id` - вендор по ID
- ✅ `GET /api/v1/clients` - список клиентов
- ✅ `GET /api/v1/clients/:id` - клиент по ID

**Categories:**
- ✅ `GET /api/v1/categories` - список категорий (иерархия)
- ✅ `GET /api/v1/categories/:id` - категория по ID
- ✅ `POST /api/v1/categories` - создать категорию
- ✅ `PATCH /api/v1/categories/:id` - обновить категорию
- ✅ `DELETE /api/v1/categories/:id` - удалить категорию

**Entries:**
- ✅ `GET /api/v1/entries` - список позиций сметы
- ✅ `GET /api/v1/entries/:id` - позиция по ID

**Briefs:**
- ✅ `GET /api/v1/briefs` - список брифов
- ✅ `GET /api/v1/briefs/:id` - бриф по ID
- ✅ `POST /api/v1/briefs` - создать бриф
- ✅ `PATCH /api/v1/briefs/:id` - обновить бриф
- ✅ `DELETE /api/v1/briefs/:id` - удалить бриф

**Offers:**
- ✅ `GET /api/v1/offers` - список офферов
- ✅ `GET /api/v1/offers/:id` - оффер по ID
- ✅ `GET /api/v1/offers/brief/:briefId` - офферы по брифу
- ✅ `POST /api/v1/offers` - создать оффер
- ✅ `PUT /api/v1/offers/:id` - обновить оффер
- ✅ `DELETE /api/v1/offers/:id` - удалить оффер

**Rates:**
- ✅ `GET /api/v1/rates` - список тарифов
- ✅ `GET /api/v1/rates/:id` - тариф по ID
- ✅ `POST /api/v1/rates` - создать тариф
- ✅ `POST /api/v1/rates/fork` - форкнуть тариф (создать копию)
- ✅ `PATCH /api/v1/rates/:id` - обновить тариф
- ✅ `DELETE /api/v1/rates/:id` - удалить тариф

#### 1.4 Безопасность
- ✅ HMAC аутентификация (точно как в текущем NestJS)
- ✅ API Key fallback для разработки
- ✅ Role-based permissions (CLIENT/VENDOR/ADMIN)
- ✅ Timestamp validation (защита от replay атак)

### 2. Deployment Infrastructure (12 часов)
- ✅ Dockerfile для Django backend
- ✅ Helm Charts для Kubernetes
- ✅ CI/CD pipeline (GitHub Actions):
  - Автоматический build при push
  - Запуск тестов
  - Deploy на staging
  - Deploy на production (manual approval)
- ✅ Nginx reverse proxy настройка
- ✅ SSL сертификаты (Let's Encrypt)
- ✅ Environment management (dev/staging/prod)

### 3. File Storage (4 часа)
- ✅ S3/MinIO интеграция для загрузки файлов
- ✅ API endpoints для upload/download файлов
- ✅ Валидация типов и размеров файлов

### 4. Testing & Quality (4 часа)
- ✅ Pytest setup с fixtures
- ✅ Unit тесты для критических endpoints
- ✅ E2E тесты для auth flow
- ✅ Сравнение ответов Django vs NestJS (проверка совместимости)

---

## ✅ Критерии приемки Этапа 0:
1. ✅ Django backend развернут на production серверах
2. ✅ Текущий фронтенд работает с новым backend без изменений
3. ✅ Все существующие функции работают (создание брифов, офферов, estimation table)
4. ✅ Аутентификация работает (email/password + Google OAuth)
5. ✅ CI/CD pipeline настроен и работает
6. ✅ Документация API актуализирована
7. ✅ Мониторинг и логирование настроены

---

# 🛠️ ЭТАП 1: КАБИНЕТ ВЕНДОРА (ДОРАБОТКА)
**📅 Даты:** 7 ноября - 27 ноября 2025 (3 недели)  
**⏱️ Время:** 30 часов  
**🎯 Результат:** Полнофункциональная estimation table с опциями, шаблонами и экспортом

## Что будет сделано:

### 1. Custom Options в Estimation Table (10 часов)

#### 1.1 Backend (5 часов)
**Модель данных:**
- ✅ Таблица `EntryOption` (кастомные опции для позиций)
  - Название опции (например: "Sony A7R IV", "Canon EOS R5")
  - Цена опции
  - Связь с Entry (позицией сметы)
  - Описание

**API Endpoints:**
- ✅ `GET /api/v1/entries/:id/options` - список опций для позиции
- ✅ `POST /api/v1/entries/:id/options` - создать опцию
- ✅ `PUT /api/v1/entries/:id/options/:optionId` - обновить опцию
- ✅ `DELETE /api/v1/entries/:id/options/:optionId` - удалить опцию

#### 1.2 Frontend (5 часов)
**Функциональность:**
- ✅ Кнопка "Добавить опцию" в каждой позиции estimation table
- ✅ Модальное окно для создания/редактирования опции:
  - Название
  - Базовая цена
  - Описание
- ✅ Dropdown выбор опции в строке estimation
- ✅ Автоматический пересчет стоимости при выборе опции
- ✅ Отображение выбранной опции в сводке (summary)

**Пример использования:**
```
Позиция: Камера
Опции:
  - Sony A7R IV (базовая цена: $3000)
  - Canon EOS R5 (базовая цена: $3900)
  - GoPro Hero 11 (базовая цена: $500)

При выборе → цена позиции обновляется автоматически
```

### 2. Templates (Шаблоны смет) (10 часов)

#### 2.1 Backend (5 часов)
**Модель данных:**
- ✅ Таблица `OfferTemplate`
  - Название шаблона
  - Описание
  - Vendor ID
  - JSON с структурой estimation (все категории, позиции, цены, surcharges)

**API Endpoints:**
- ✅ `GET /api/v1/templates` - список шаблонов вендора
- ✅ `GET /api/v1/templates/:id` - шаблон по ID
- ✅ `POST /api/v1/templates` - создать шаблон из текущего offer
- ✅ `POST /api/v1/templates/:id/apply` - применить шаблон к новому offer
- ✅ `PUT /api/v1/templates/:id` - обновить шаблон
- ✅ `DELETE /api/v1/templates/:id` - удалить шаблон

#### 2.2 Frontend (5 часов)
**Функциональность:**
- ✅ Страница "Templates" в кабинете вендора
- ✅ Список всех шаблонов (карточки):
  - Название
  - Количество категорий
  - Общая стоимость (примерная)
  - Дата создания
- ✅ Кнопка "Сохранить как шаблон" в estimation table
- ✅ Кнопка "Применить шаблон" при создании нового offer
- ✅ Preview шаблона перед применением
- ✅ Возможность редактировать шаблон

**Пример использования:**
```
1. Вендор создал estimation для проекта "Рекламный ролик"
2. Нажал "Сохранить как шаблон" → "Стандартный ролик 30 сек"
3. При следующем проекте → "Применить шаблон" → выбирает "Стандартный ролик 30 сек"
4. Все категории, позиции, цены автоматически загружаются
5. Вендор делает корректировки под конкретный проект
```

### 3. Excel Export (6 часов)

#### 3.1 Backend (4 часа)
**Библиотека:** `openpyxl` или `xlsxwriter`

**API Endpoint:**
- ✅ `GET /api/v1/offers/:id/export/excel` - скачать estimation в Excel

**Формат Excel файла:**
- ✅ Лист "Estimation":
  - Таблица со всеми категориями и позициями
  - Колонки: Категория, Позиция, Единица измерения, Количество, Цена за единицу, Итого
  - Группировка по категориям
  - Сводка внизу (Total Cost, Surcharges, Final Price)
- ✅ Лист "Summary":
  - Project Name
  - Deadline
  - Vendor info
  - Total Cost
  - Profit
  - Final Price

#### 3.2 Frontend (2 часа)
**Функциональность:**
- ✅ Кнопка "Export to Excel" в estimation table (справа вверху)
- ✅ Диалог с опциями экспорта:
  - Включить внутренние цены (vendor view)
  - Только клиентские цены (client view)
  - Включить заметки
- ✅ Автоматическое скачивание файла
- ✅ Название файла: `{projectName}_estimation_{date}.xlsx`

### 4. Public Links (Публичные ссылки) (4 часа)

#### 4.1 Backend (2 часа)
**Модель данных:**
- ✅ Таблица `PublicLink`
  - Token (UUID)
  - Offer ID
  - Expiration date (опционально)
  - View count (счетчик просмотров)

**API Endpoints:**
- ✅ `POST /api/v1/offers/:id/share` - создать публичную ссылку
- ✅ `GET /api/v1/public/:token` - получить offer по публичной ссылке (без auth)
- ✅ `DELETE /api/v1/offers/:id/share/:linkId` - удалить ссылку

#### 4.2 Frontend (2 часа)
**Функциональность:**
- ✅ Кнопка "Share" в estimation table
- ✅ Модальное окно с:
  - Сгенерированной ссылкой
  - Кнопкой "Copy link"
  - Опцией "Set expiration date"
  - Счетчиком просмотров
- ✅ Публичная страница просмотра estimation (read-only):
  - Без возможности редактирования
  - Только клиентские цены (internal prices скрыты)
  - Красивый дизайн для презентации клиенту

---

## ✅ Критерии приемки Этапа 1:
1. ✅ Вендор может создавать кастомные опции для позиций estimation
2. ✅ Опции правильно влияют на расчет стоимости
3. ✅ Вендор может сохранять estimation как шаблон
4. ✅ Шаблоны можно применять к новым offers
5. ✅ Excel export работает и генерирует корректный файл
6. ✅ Публичные ссылки создаются и работают
7. ✅ Публичная страница корректно отображает estimation

---

# 👔 ЭТАП 2: КАБИНЕТ КЛИЕНТА (СОЗДАНИЕ)
**📅 Даты:** 28 ноября - 25 декабря 2025 (4 недели)  
**⏱️ Время:** 40 часов  
**🎯 Результат:** Полнофункциональный кабинет клиента с созданием брифов, получением предложений и сравнением смет

## Что будет сделано:

### 1. Client Dashboard (8 часов)

#### 1.1 Backend (3 часа)
**API Endpoints:**
- ✅ `GET /api/v1/client/dashboard` - статистика для дашборда
  - Количество активных проектов
  - Количество полученных предложений
  - Средняя стоимость предложений
  - Проекты требующие внимания

#### 1.2 Frontend (5 часов)
**Главная страница клиента:**
- ✅ Карточки статистики:
  - "Активные проекты" (количество)
  - "Ожидают предложений" (количество брифов без offers)
  - "Получено предложений" (общее количество)
  - "В работе" (проекты со статусом ONGOING)

- ✅ Список проектов (краткий):
  - Название проекта
  - Дата создания
  - Статус (Draft, RFP, Reviewing, Ongoing)
  - Количество полученных предложений
  - Кнопка "Посмотреть предложения"

- ✅ Кнопка "Создать новый бриф" (главная CTA)

### 2. Brief Creation for Client (10 часов)

#### 2.1 Backend (4 часа)
**Расширение модели Brief:**
- ✅ Добавление полей:
  - Project description
  - Requirements (JSON - список требований)
  - Budget range (min/max)
  - Timeline/Deadline
  - Deliverables (JSON - что должно быть в результате)
  - Target audience

**API Endpoints:**
- ✅ `POST /api/v1/client/briefs` - создать бриф от клиента
- ✅ `PUT /api/v1/client/briefs/:id` - обновить бриф
- ✅ `POST /api/v1/client/briefs/:id/invite-vendors` - пригласить вендоров

#### 2.2 Frontend (6 часов)
**Форма создания брифа:**

**Шаг 1: Основная информация**
- ✅ Название проекта
- ✅ Описание проекта (rich text editor)
- ✅ Deadline
- ✅ Бюджетный диапазон (от - до)

**Шаг 2: Требования**
- ✅ Список требований (можно добавлять/удалять):
  - Тип требования (выбор из списка)
  - Описание
  - Приоритет (обязательно/желательно)
- ✅ Примеры:
  - "Видео 30 секунд"
  - "Full HD качество"
  - "3 варианта монтажа"

**Шаг 3: Deliverables (что нужно получить)**
- ✅ Чеклист deliverables:
  - [ ] Исходники
  - [ ] Finalized video files
  - [ ] Storyboard
  - [ ] Script
  - [ ] Music licensing
  - Другое (custom input)

**Шаг 4: Приглашение вендоров**
- ✅ Поиск вендоров по названию
- ✅ Список вендоров (checkbox selection)
- ✅ Отправка приглашений

**После создания:**
- ✅ Бриф сохраняется со статусом "RFP"
- ✅ Вендоры получают уведомление (email)
- ✅ Клиент переходит на страницу "Ожидание предложений"

### 3. Vendor Invitation Flow (4 часа)

#### 3.1 Backend (2 часа)
**Модель данных:**
- ✅ Таблица `BriefInvitation`
  - Brief ID
  - Vendor ID
  - Status (Pending, Accepted, Declined)
  - Invitation token (UUID для ссылки)

**API Endpoints:**
- ✅ `POST /api/v1/client/briefs/:id/invite` - пригласить вендоров
- ✅ `GET /api/v1/vendor/invitations` - список приглашений для вендора
- ✅ `POST /api/v1/vendor/invitations/:id/accept` - принять приглашение
- ✅ `POST /api/v1/vendor/invitations/:id/decline` - отклонить приглашение

#### 3.2 Frontend (2 часа)
**Для клиента:**
- ✅ Список приглашенных вендоров:
  - Название вендора
  - Статус приглашения (Pending/Accepted/Declined)
  - Дата отправки
  - Дата ответа

**Для вендора:**
- ✅ Уведомление о новом приглашении (badge на иконке)
- ✅ Страница "Приглашения":
  - Информация о брифе
  - Кнопки "Принять" / "Отклонить"
- ✅ После принятия → автоматически создается offer для этого brief

### 4. Comparison Table (14 часов)

#### 4.1 Backend (6 часов)
**API Endpoints:**
- ✅ `GET /api/v1/client/briefs/:id/compare` - данные для сравнения предложений

**Логика обработки:**
- ✅ Получить все offers по brief ID
- ✅ Нормализовать данные (привести к единой структуре)
- ✅ Выровнять категории (matching по названиям)
- ✅ Рассчитать:
  - Min/Max/Average цену по каждой категории
  - Total min/max/average
  - Outliers (слишком дорогие/дешевые)

**Формат ответа:**
```json
{
  "brief": { "id": 1, "name": "Рекламный ролик" },
  "offers": [
    {
      "id": 1,
      "vendorName": "Studio A",
      "totalPrice": 50000,
      "categories": [
        { "name": "Pre-production", "price": 10000, "items": 5 },
        { "name": "Production", "price": 30000, "items": 10 },
        { "name": "Post-production", "price": 10000, "items": 8 }
      ]
    },
    {
      "id": 2,
      "vendorName": "Studio B",
      "totalPrice": 45000,
      "categories": [...]
    }
  ],
  "analysis": {
    "minPrice": 45000,
    "maxPrice": 55000,
    "avgPrice": 50000,
    "categoryComparison": [
      {
        "category": "Pre-production",
        "minPrice": 8000,
        "maxPrice": 12000,
        "avgPrice": 10000
      }
    ]
  }
}
```

#### 4.2 Frontend (8 часов)
**Страница сравнения предложений:**

**Header:**
- ✅ Название брифа
- ✅ Количество предложений
- ✅ Диапазон цен (min - max)
- ✅ Фильтры:
  - По вендорам (checkbox)
  - По ценовому диапазону (slider)
  - Сортировка (по цене, по дате, по рейтингу)

**Таблица сравнения (side-by-side):**
```
┌──────────────────┬─────────────┬─────────────┬─────────────┐
│ Категория/Позиция│  Studio A   │  Studio B   │  Studio C   │
├──────────────────┼─────────────┼─────────────┼─────────────┤
│ Pre-production   │             │             │             │
│   Scripting      │   $2,000 ✓  │   $1,800    │   $2,200    │
│   Storyboard     │   $1,500    │   $1,200 ✓  │   $1,500    │
│   Casting        │   $3,000    │   $2,500 ✓  │   $3,500    │
├──────────────────┼─────────────┼─────────────┼─────────────┤
│ Production       │             │             │             │
│   Filming        │  $15,000    │  $14,000 ✓  │  $16,000    │
│   Equipment      │   $5,000 ✓  │   $6,000    │   $5,500    │
├──────────────────┼─────────────┼─────────────┼─────────────┤
│ TOTAL            │  $50,000    │  $45,000 ✓  │  $55,000    │
└──────────────────┴─────────────┴─────────────┴─────────────┘

✓ = лучшая цена в категории
```

**Функциональность:**
- ✅ Горизонтальный скролл для большого количества вендоров
- ✅ Sticky header (категории и вендоры видны при скролле)
- ✅ Цветовая индикация:
  - Зеленый = лучшая цена
  - Желтый = средняя цена
  - Красный = выше среднего
- ✅ Клик на позицию → детали (описание, unit, quantity)
- ✅ Collapse/expand категорий

**Summary карточки по каждому вендору:**
- ✅ Общая стоимость
- ✅ Количество позиций
- ✅ Deadline
- ✅ Рейтинг (сколько категорий с лучшей ценой)
- ✅ Кнопка "Посмотреть детали" → полный estimation view
- ✅ Кнопка "Выбрать" → пометить как выбранное предложение

### 5. Simple Price Analysis (4 часа)

#### 5.1 Backend (2 часа)
**Добавить в `/api/v1/client/briefs/:id/compare` анализ:**
- ✅ Outlier detection (позиции с ценой > 2x от средней)
- ✅ Best value score для каждого вендора:
  - Price/quality ratio
  - Coverage (сколько позиций включено)
  - Timeline feasibility

#### 5.2 Frontend (2 часа)
**Виджеты анализа над таблицей:**

**"Price Insights":**
- ✅ "Average market price: $50,000"
- ✅ "Studio B offers 10% below average ⬇️"
- ✅ "Studio C is 15% above average ⬆️"

**"Category Analysis":**
- ✅ График по категориям (bar chart):
  - X-axis: категории
  - Y-axis: цена
  - Bars: цены от разных вендоров
  - Показывает где какой вендор дешевле

**"Best Value":**
- ✅ Карточка с рекомендацией:
  - "Studio B offers the best value"
  - "Reasons: Competitive price, good coverage, realistic timeline"

---

## ✅ Критерии приемки Этапа 2:
1. ✅ Клиент видит dashboard с проектами и статистикой
2. ✅ Клиент может создать детальный бриф
3. ✅ Клиент может пригласить вендоров к брифу
4. ✅ Вендор получает приглашение и может принять/отклонить
5. ✅ Клиент видит список полученных предложений
6. ✅ Таблица сравнения корректно отображает все предложения side-by-side
7. ✅ Цветовая индикация и best price маркеры работают
8. ✅ Аналитика (insights) показывает полезную информацию
9. ✅ Клиент может выбрать предложение и пометить его

---

# 🔗 ЭТАП 3: ИНТЕГРАЦИИ И ФИНАЛИЗАЦИЯ
**📅 Даты:** 26 декабря 2025 - 8 января 2026 (2 недели)  
**⏱️ Время:** 30 часов  
**🎯 Результат:** Полностью готовый MVP с AI, linking, notifications и polish

## Что будет сделано:

### 1. Linking Flow (Связывание проектов) (8 часов)

#### 1.1 Backend (4 часа)
**Модель данных:**
- ✅ Таблица `Project` (связка client brief + vendor offers)
  - Client Brief ID
  - List of linked Offer IDs
  - Status (Active, Completed, Cancelled)

**Логика связывания:**
- ✅ Автоматическое связывание:
  - Когда вендор принимает приглашение → создается связь
  - Когда вендор создает offer для brief → создается связь

**API Endpoints:**
- ✅ `GET /api/v1/projects` - список всех проектов (для клиента или вендора)
- ✅ `GET /api/v1/projects/:id` - детали проекта с brief + offers
- ✅ `POST /api/v1/projects/:id/link-offer` - вручную привязать offer к brief
- ✅ `DELETE /api/v1/projects/:id/unlink-offer/:offerId` - отвязать offer

#### 1.2 Frontend (4 часа)
**Для клиента:**
- ✅ Страница "Projects":
  - Список всех проектов
  - Статус (сколько вендоров откликнулись)
  - Быстрый доступ к comparison table
- ✅ Возможность вручную добавить offer к проекту (если вендор отправил Excel)

**Для вендора:**
- ✅ Страница "Projects":
  - Список проектов с offers
  - Статус каждого offer (Draft, Sent, Accepted, Rejected)
  - Быстрый доступ к estimation editing

### 2. AI Integration (Basic) (10 часов)

#### 2.1 Backend (6 часов)
**Библиотека:** `openai` Python SDK

**AI Services:**
- ✅ Brief Generation от текста:
  - Input: неструктурированный текст от клиента
  - Output: структурированный brief (JSON)
  - Endpoint: `POST /api/v1/ai/generate-brief`

**Пример:**
```
Input: "Нужен рекламный ролик 30 секунд для Instagram, 
        Full HD, 3 варианта монтажа, бюджет $50k, срок 2 недели"

Output: {
  "projectName": "Instagram Ad 30s",
  "description": "Рекламный ролик для Instagram",
  "deadline": "2025-11-20",
  "budgetMin": 45000,
  "budgetMax": 55000,
  "requirements": [
    { "type": "Duration", "value": "30 seconds", "priority": "required" },
    { "type": "Quality", "value": "Full HD", "priority": "required" },
    { "type": "Variations", "value": "3 edit versions", "priority": "required" }
  ],
  "deliverables": ["Finalized video", "Raw footage", "3 edit versions"]
}
```

- ✅ Brief Summary (резюме брифа):
  - Input: brief JSON
  - Output: краткое описание для вендора
  - Endpoint: `GET /api/v1/briefs/:id/summary`

- ✅ Comparison Summary:
  - Input: comparison data (все offers)
  - Output: текстовое резюме сравнения
  - Endpoint: `GET /api/v1/client/briefs/:id/ai-summary`

**Пример:**
```
"Получено 3 предложения с диапазоном цен $45k-$55k. 
Studio B предлагает лучшее соотношение цена/качество ($45k) 
с полным покрытием требований. Studio A ($50k) включает 
дополнительные услуги post-production. Studio C ($55k) 
предлагает премиум оборудование и faster turnaround."
```

#### 2.2 Frontend (4 часа)
**Brief Creation с AI:**
- ✅ Кнопка "Generate with AI" на странице создания брифа
- ✅ Textarea для вставки текста
- ✅ "Generate" → AI парсит → заполняет форму автоматически
- ✅ Клиент может редактировать сгенерированные данные

**AI Summary в Comparison:**
- ✅ Блок "AI Analysis" над comparison table
- ✅ Текстовое резюме от AI
- ✅ Ключевые рекомендации выделены

### 3. Notifications (6 часов)

#### 3.1 Backend (4 часа)
**Email Service Setup:**
- ✅ SendGrid интеграция
- ✅ Email templates (HTML):
  - New invitation для вендора
  - New offer для клиента
  - Offer accepted/rejected
  - Brief status changed

**Celery для async emails:**
- ✅ Celery + Redis setup
- ✅ Task для отправки email
- ✅ Retry logic

**Триггеры уведомлений:**
- ✅ Клиент создал brief → вендоры получают email
- ✅ Вендор отправил offer → клиент получает email
- ✅ Клиент выбрал offer → вендор получает email
- ✅ Brief status changed → все участники получают email

#### 3.2 Frontend (2 часа)
**In-app notifications (опционально, упрощенно):**
- ✅ Badge на navbar с количеством непрочитанных
- ✅ Dropdown list с последними notifications
- ✅ Клик → переход на соответствующую страницу

### 4. Excel Import (для клиента) (3 часа)

#### 4.1 Backend (2 часа)
**Endpoint:**
- ✅ `POST /api/v1/client/briefs/import-excel` - импорт брифа из Excel

**Логика:**
- ✅ Парсинг Excel файла (определенный формат)
- ✅ Извлечение:
  - Project name
  - Requirements list
  - Budget
  - Deadline
- ✅ Создание brief с imported data

#### 4.2 Frontend (1 час)
**Функциональность:**
- ✅ Кнопка "Import from Excel" на странице создания брифа
- ✅ File upload (drag & drop или click)
- ✅ Preview импортированных данных
- ✅ "Confirm import" → brief создан

### 5. Polish & Bug Fixes (3 часа)
- ✅ UI/UX улучшения по всем страницам
- ✅ Responsive design checks (mobile/tablet)
- ✅ Loading states и error handling
- ✅ Form validation improvements
- ✅ Performance optimization (кэширование, lazy loading)
- ✅ Browser compatibility testing
- ✅ Security audit
- ✅ Final bug fixes

---

## ✅ Критерии приемки Этапа 3:
1. ✅ Проекты автоматически связывают briefs и offers
2. ✅ AI может генерировать brief из текста
3. ✅ AI предоставляет резюме сравнения предложений
4. ✅ Email уведомления работают для всех ключевых событий
5. ✅ Excel импорт брифов работает
6. ✅ Все UI элементы responsive и работают на всех устройствах
7. ✅ Нет критических багов
8. ✅ Performance в пределах нормы (загрузка страниц < 2 сек)

---

# 📝 ИТОГОВЫЙ РЕЗУЛЬТАТ MVP

## Что будет реализовано:

### ✅ Для ВЕНДОРА:
1. **Dashboard** - обзор всех проектов
2. **Project Management** - создание и управление проектами
3. **Brief Creation** - создание детальных брифов
4. **Estimation Table** - полнофункциональная смета с:
   - Custom options для позиций
   - Automatic calculations
   - Surcharge management
   - Summary view
5. **Rate Cards** - управление тарифами и форкинг
6. **Templates** - сохранение и использование шаблонов смет
7. **Excel Export** - экспорт смет в Excel
8. **Public Links** - шаринг смет через публичные ссылки
9. **Invitations** - получение и обработка приглашений от клиентов

### ✅ Для КЛИЕНТА:
1. **Dashboard** - обзор проектов и статистика
2. **Brief Creation** - создание детальных брифов с AI помощью
3. **Vendor Invitation** - приглашение вендоров к проектам
4. **Offers Review** - просмотр полученных предложений
5. **Comparison Table** - side-by-side сравнение предложений
6. **Price Analysis** - AI анализ и рекомендации
7. **Excel Import** - импорт брифов из Excel
8. **Notifications** - уведомления о новых предложениях

### ✅ Общее:
1. **Authentication** - вход через email/password или Google OAuth
2. **Role Management** - разделение CLIENT/VENDOR
3. **Projects Linking** - автоматическое связывание брифов и предложений
4. **AI Integration** - генерация брифов и анализ предложений
5. **Email Notifications** - уведомления на email
6. **File Storage** - загрузка и хранение файлов (S3/MinIO)
7. **API Documentation** - актуальная документация API
8. **CI/CD** - автоматический deploy на production

---

# 🚫 ЧТО НЕ ВХОДИТ В MVP

Следующие функции **намеренно исключены** для ускорения выхода MVP:

### Не реализуется:
- ❌ Complex Units (часы × ролики) - можно добавить позже
- ❌ Tax Calculations - упрощено в estimation
- ❌ Commission Calculations - упрощено
- ❌ Multi-currency Support - только одна валюта
- ❌ File Attachments к позициям estimation - только к брифам
- ❌ Team Management - пока только owner
- ❌ Comments System - будет в v2
- ❌ Real-time Collaboration - будет в v2
- ❌ Advanced AI (deep analysis) - только basic AI
- ❌ Payment Integration - будет в v2
- ❌ Mobile Apps - только web responsive
- ❌ Advanced Analytics - только basic stats
- ❌ Integrations (Slack, etc) - будет в v2

---

# 📅 КЛЮЧЕВЫЕ ДАТЫ (MILESTONES)

| Дата | Milestone | Что можно показать |
|------|-----------|-------------------|
| **6 ноября 2025** | ✅ Этап 0 готов | Работающий сайт на production с текущим функционалом на новом Django backend |
| **27 ноября 2025** | ✅ Этап 1 готов | Estimation с опциями, шаблонами, Excel export, публичными ссылками |
| **25 декабря 2025** | ✅ Этап 2 готов | Полный кабинет клиента с созданием брифов и сравнением предложений |
| **8 января 2026** | ✅ MVP ГОТОВ | Полностью функционирующая платформа с AI и всеми интеграциями |

---

# 💰 РИСКИ И МИТИГАЦИЯ

## Возможные риски:

### 1. **Технические проблемы при миграции** (вероятность: средняя)
- **Риск:** API совместимость, баги в Django backend
- **Митигация:** 
  - Тщательное тестирование на каждом этапе
  - Возможность быстрого отката на NestJS
  - Параллельная работа обоих backends первые 2 недели

### 2. **Превышение времени на этапы** (вероятность: средняя)
- **Риск:** Некоторые задачи могут занять больше времени
- **Митигация:**
  - Заложен буфер времени в оценки
  - Можно упростить некоторые фичи
  - Приоритизация критичных функций

### 3. **Изменение требований** (вероятность: высокая)
- **Риск:** Появление новых требований в процессе
- **Митигация:**
  - Четкая фиксация MVP scope
  - Change request process
  - Новые фичи → backlog для v2

### 4. **AI API лимиты/стоимость** (вероятность: низкая)
- **Риск:** OpenAI API может быть дорогим или медленным
- **Митигация:**
  - Кэширование AI ответов
  - Rate limiting
  - Fallback на simple logic если AI недоступен

---

# 📊 МЕТРИКИ УСПЕХА MVP

После завершения разработки, MVP считается успешным если:

### Технические метрики:
- ✅ Uptime > 99% (менее 7 часов простоя в месяц)
- ✅ Page load time < 2 секунды
- ✅ API response time < 500ms (95th percentile)
- ✅ Zero critical bugs
- ✅ Test coverage > 70%

### Функциональные метрики:
- ✅ Вендор может создать estimation за < 15 минут
- ✅ Клиент может создать brief за < 10 минут
- ✅ Comparison table загружается за < 3 секунды
- ✅ AI генерирует brief за < 10 секунд
- ✅ Excel export работает за < 5 секунд

### Бизнес метрики (для первых пользователей):
- ✅ User registration work
- ✅ Brief creation work
- ✅ Offer creation work
- ✅ Comparison work
- ✅ Положительный feedback от тестовых пользователей

---

# 🎯 ЗАКЛЮЧЕНИЕ

## Что получаем через 3 месяца:

**Полнофункциональная B2B платформа для видео-продакшна**, которая позволяет:
- Клиентам создавать брифы и получать предложения от вендоров
- Вендорам создавать детальные сметы с опциями и шаблонами
- Сравнивать предложения side-by-side с AI анализом
- Управлять проектами от запроса до выбора исполнителя
- Экспортировать/импортировать данные через Excel
- Делиться предложениями через публичные ссылки

## Следующие шаги после MVP:

**Version 2.0** будет включать:
- Complex Units и расширенные расчеты
- Multi-currency support
- Team collaboration
- Advanced AI analysis
- Payment integration
- Mobile apps
- Analytics dashboard

---

**Готовы начинать 9 октября 2025! 🚀**
