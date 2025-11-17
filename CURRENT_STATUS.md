# ✅ Текущий статус разработки AIVUS

**Дата обновления:** 15 ноября 2025

---

## 🎯 Общий прогресс

| Компонент | Статус | Прогресс |
|-----------|--------|----------|
| **Backend (Django)** | ✅ Работает | 70% |
| **Frontend (Next.js)** | ✅ Работает | 60% |
| **Authentication** | ✅ Работает | 100% |
| **Vendor Cabinet** | 🔄 В разработке | 50% |
| **Client Cabinet** | ⏳ Не начато | 0% |

---

## ✅ Что реализовано

### Backend (Django)

#### ✅ Инфраструктура
- [x] Django 5.1 проект с правильной структурой
- [x] PostgreSQL подключение
- [x] Docker + Docker Compose для локальной разработки
- [x] HMAC аутентификация (middleware)
- [x] Role-based permissions (`@require_groups`)
- [x] CORS настройки для Next.js

#### ✅ Модели данных
- [x] `User` (пользователи с группами)
- [x] `Vendor` (вендоры)
- [x] `Client` (клиенты)
- [x] `Brief` (брифы/ТЗ)
- [x] `Project` (проекты вендоров)
- [x] `Offer` (оферы/сметы)
- [x] `Category` (категории каталога)
- [x] `Entry` (позиции каталога)
- [x] `Unit` (единицы измерения)
- [x] `EntryUnit` (связь Entry-Unit с ценами)
- [x] `Team` (команды, пока не используется)

#### ✅ API Endpoints

**Authentication:**
- [x] `POST /api/v1/auth/register`
- [x] `POST /api/v1/auth/login`
- [x] `GET /api/v1/auth/confirm-email`
- [x] `POST /api/v1/auth/forgot-password`
- [x] `POST /api/v1/auth/reset-password`
- [x] `POST /api/v1/auth/check-email`

**Users:**
- [x] `GET /api/v1/users/me`
- [x] `PATCH /api/v1/users/:id/change-group`

**Catalog:**
- [x] `GET /api/v1/categories`
- [x] `GET /api/v1/entries`
- [x] `GET /api/v1/entries?full=true`

**Projects:**
- [x] `GET /api/v1/projects`
- [x] `POST /api/v1/projects`
- [x] `GET /api/v1/projects/:id`
- [x] `PATCH /api/v1/projects/:id`
- [x] `DELETE /api/v1/projects/:id`

**Briefs:**
- [x] `GET /api/v1/briefs`
- [x] `POST /api/v1/briefs`
- [x] `GET /api/v1/briefs/:id`
- [x] `PATCH /api/v1/briefs/:id`

**Offers:**
- [x] `GET /api/v1/offers`
- [x] `POST /api/v1/offers`
- [x] `GET /api/v1/offers/:id`
- [x] `PATCH /api/v1/offers/:id`
- [x] `GET /api/v1/offers/project/:projectId`

#### ✅ Seed данные
- [x] Категории (Pre-production, Production, Post-production, etc.)
- [x] Единицы измерения (hour, day, piece, etc.)
- [x] Позиции каталога (~100+ entries)

---

### Frontend (Next.js)

#### ✅ Инфраструктура
- [x] Next.js 14 (App Router)
- [x] TypeScript
- [x] Redux Toolkit + RTK Query
- [x] NextAuth.js (JWT sessions)
- [x] Middleware для роутинга и авторизации
- [x] HMAC подпись запросов к backend

#### ✅ Authentication Flow
- [x] Регистрация (email/password)
- [x] Вход (email/password)
- [x] Google OAuth
- [x] Email подтверждение
- [x] Сброс пароля
- [x] Выбор роли (VENDOR/CLIENT)

#### ✅ Routing & Access Control
- [x] Публичные роуты (`/auth/*`)
- [x] Защищенные роуты (`/app/*`)
- [x] Роутинг по группам:
  - `UNCONFIRMED` → `/app/confirm`
  - `CONFIRMED` → `/app/group`
  - `VENDOR` → `/app/dashboard`
  - `CLIENT` → `/app/dashboard` (пока не реализовано)

#### ✅ Vendor Cabinet

**Dashboard:**
- [x] Список проектов (Project List)
- [x] Карточки проектов с базовой информацией
- [x] Кнопка "New Estimation"
- [x] Навигация к деталям проекта

**Project Details:**
- [x] Форма брифа (Brief Form)
  - [x] Initial Parameters
  - [x] Client Info
  - [x] Project Description
- [x] Сохранение/обновление брифа
- [x] Создание Brief → Project → Offer flow

**Estimation (Смета):**
- [x] Autocomplete для поиска позиций каталога
- [x] Добавление категорий и позиций
- [x] Иерархия категорий (parent-child)
- [x] Редактирование позиций:
  - [x] Название
  - [x] Количество и единицы измерения
  - [x] Цена (внутренняя и клиентская)
  - [x] Расходы
- [x] Автоматический расчет:
  - [x] Стоимость позиции
  - [x] Стоимость категории
  - [x] Общая стоимость
  - [x] Непредвиденные расходы (%)
- [x] Sidebar для редактирования позиции
- [x] Redux store для состояния офера
- [x] Автосохранение изменений

#### ✅ RTK Query APIs
- [x] `briefApi` - CRUD для брифов
- [x] `projectsApi` - CRUD для проектов
- [x] `offersApi` - CRUD для оферов
- [x] Cache invalidation (tags)

#### ✅ Custom Hooks
- [x] `useBrief()` - загрузка брифа через проект
- [x] `useProjects()` - список проектов
- [x] `useMutateBrief()` - создание/обновление брифа + проекта + офера
- [x] `useOnce()` / `useOnceAsync()` - защита от дублирования в Strict Mode

---

## 🔄 В процессе разработки

### Vendor Cabinet

#### 🔄 Estimation (доработки)
- [ ] Complex Units (часы × ролики)
- [ ] Custom Options (варианты оборудования)
- [ ] Tax & Commission расчеты
- [ ] Surcharge на категории (UI)
- [ ] Валидация данных
- [ ] Error handling

#### 🔄 UI/UX
- [ ] Responsive design
- [ ] Loading states
- [ ] Error boundaries
- [ ] Toast notifications (улучшение)

---

## ⏳ Запланировано

### Vendor Cabinet (Этап 1)

#### Rate Cards
- [ ] CRUD для тарифных карточек
- [ ] Форкинг тарифов
- [ ] Связывание с позициями
- [ ] История изменений

#### Templates
- [ ] Сохранение estimation как шаблон
- [ ] Применение шаблона к новому offer
- [ ] Список шаблонов
- [ ] Редактирование шаблонов

#### Export & Sharing
- [ ] Excel export
- [ ] Публичные ссылки (public links)
- [ ] Копирование ссылок
- [ ] Счетчик просмотров

---

### Client Cabinet (Этап 2)

#### Dashboard
- [ ] Список брифов клиента
- [ ] Статусы проектов
- [ ] Количество полученных предложений

#### Brief Creation
- [ ] Форма создания брифа
- [ ] AI генерация брифа из текста
- [ ] Редактирование брифа

#### Vendor Management
- [ ] Поиск вендоров
- [ ] Приглашение вендоров к брифу
- [ ] Список приглашений (статусы)
- [ ] Email уведомления

#### Comparison
- [ ] Side-by-side таблица оферов
- [ ] Цветовая индикация (лучшие цены)
- [ ] AI сравнение и рекомендации
- [ ] Выбор лучшего предложения

---

### Integrations (Этап 3)

#### AI
- [ ] OpenAI integration
- [ ] AI brief generation
- [ ] AI comparison summary
- [ ] Prompt templates

#### Email
- [ ] SendGrid/SMTP настройка
- [ ] HTML email templates
- [ ] Celery + Redis для асинхронной отправки
- [ ] Уведомления о событиях

#### File Storage
- [ ] S3-compatible storage
- [ ] Upload/download API
- [ ] Валидация файлов

#### Excel Import
- [ ] Парсинг Excel файлов
- [ ] Извлечение offerId
- [ ] Linking клиента к офферу

---

## 🐛 Известные проблемы

### Backend
- [ ] Нет валидации JSON полей (`details`)
- [ ] Нет версионирования брифов
- [ ] Нет soft delete (используется `deleted_at`, но не везде)

### Frontend
- [ ] Dashboard показывает пустые данные (TODO: расчет из офера)
- [ ] Нет обработки ошибок сети
- [ ] Нет оптимистичных обновлений
- [ ] Redux selectors могут падать на `undefined` (частично исправлено)

---

## 🔧 Технический долг

1. **Frontend:**
   - Рефакторинг estimation компонентов (слишком большие файлы)
   - Типизация Redux state (улучшить)
   - Вынести константы в отдельные файлы
   - Добавить unit тесты

2. **Backend:**
   - Добавить E2E тесты для новых endpoints
   - Улучшить error handling
   - Добавить rate limiting
   - Настроить Sentry для мониторинга

3. **DevOps:**
   - CI/CD pipeline (GitHub Actions)
   - Staging environment
   - Production deployment
   - SSL сертификаты

---

## 📊 Метрики

### Backend
- **Endpoints:** 25+
- **Models:** 11
- **Migrations:** 5
- **Test coverage:** ~40%

### Frontend
- **Pages:** 15+
- **Components:** 50+
- **Redux slices:** 2
- **RTK Query APIs:** 4
- **Custom hooks:** 10+

---

## 🎯 Ближайшие задачи (Next Sprint)

1. **Доработать Estimation:**
   - [ ] Исправить все баги с `undefined` в селекторах
   - [ ] Добавить Complex Units
   - [ ] Добавить Custom Options
   - [ ] Улучшить UI/UX

2. **Rate Cards:**
   - [ ] Создать модель на backend
   - [ ] CRUD API endpoints
   - [ ] UI для управления тарифами

3. **Templates:**
   - [ ] Создать модель на backend
   - [ ] API для сохранения/применения шаблонов
   - [ ] UI для списка шаблонов

4. **Excel Export:**
   - [ ] Backend генерация Excel
   - [ ] Форматирование таблиц
   - [ ] Кнопка экспорта на frontend

---

## 📝 Заметки

### Архитектурные решения
- **Brief → Project → Offer:** Промежуточная модель `Project` позволяет вендору работать над брифом клиента
- **JSON details:** Гибкость для быстрой разработки, миграция на реляционную структуру позже
- **UUID ID:** Безопасность и совместимость с распределенными системами
- **Nullable relations:** Поддержка разных флоу (vendor-first, client-first)

### Lessons Learned
- React Strict Mode вызывает дублирование эффектов → использовать `useRef` для one-time операций
- NextAuth session обновляется только при `update()` → нужен явный вызов после изменений на backend
- HMAC signature должна включать query string → добавлено в middleware
- RTK Query tags упрощают cache invalidation → использовать везде

---

## 🚀 Следующие вехи

| Дата | Веха | Описание |
|------|------|----------|
| **19 ноября 2025** | Этап 1 | Vendor Cabinet полностью готов |
| **10 декабря 2025** | Этап 2 | Client Cabinet полностью готов |
| **24 декабря 2025** | Этап 3 | Все интеграции готовы |
| **16 января 2026** | MVP | Готовый продукт к запуску |

