# 🏗️ Архитектура AIVUS

## 📊 Основные модели данных

### 1. User (Пользователь)
```python
User
├── id: UUID
├── email: string (unique)
├── name: string
├── group: enum (UNCONFIRMED, CONFIRMED, VENDOR, CLIENT, SYSTEM)
├── auth_type: enum (EMAIL, GOOGLE)
└── Relations:
    ├── → Vendor (owner, 1:1)
    └── → Client (owner, 1:1)
```

**Группы пользователей:**
- `UNCONFIRMED` - зарегистрирован, но email не подтвержден
- `CONFIRMED` - email подтвержден, но роль не выбрана
- `VENDOR` - выбрал роль вендора
- `CLIENT` - выбрал роль клиента
- `SYSTEM` - системный пользователь (admin)

---

### 2. Vendor (Вендор)
```python
Vendor
├── id: UUID
├── name: string
├── owner: FK → User
└── Relations:
    └── → Project[] (vendor, 1:N)
```

---

### 3. Client (Клиент)
```python
Client
├── id: UUID
├── name: string
├── owner: FK → User
└── Relations:
    └── → Brief[] (client, 1:N)
```

---

### 4. Brief (Бриф / ТЗ)
```python
Brief
├── id: UUID
├── status: enum (DRAFT, ACTIVE, COMPLETED)
├── details: JSON (нереляционные данные брифа)
├── client_id: FK → Client (nullable)
├── created_at: datetime
└── updated_at: datetime

Relations:
└── → Project[] (brief, 1:N)
```

**Структура `details` (JSON):**
```typescript
{
  projectName: string;
  deadline: string;
  clientName: string;
  clientEmail: string;
  clientPhone: string;
  // ... другие поля брифа
}
```

**Важно:** `client_id` может быть `null` для вендор-инициированных брифов.

---

### 5. Project (Проект)
```python
Project
├── id: UUID
├── name: string
├── vendor_id: FK → Vendor (required)
├── brief_id: FK → Brief (nullable)
├── team_id: FK → Team (nullable)
├── status: enum (DRAFT, ACTIVE, COMPLETED)
├── created_at: datetime
└── updated_at: datetime

Relations:
└── → Offer[] (project, 1:N)
```

**Назначение:** Промежуточная сущность между `Brief` и `Offer`. Представляет работу конкретного вендора над брифом.

---

### 6. Offer (Оффер / Смета)
```python
Offer
├── id: UUID
├── uuid: UUID (для публичных ссылок)
├── project_name: string
├── project_id: FK → Project (nullable)
├── status: enum (DRAFT)
├── cost: decimal (nullable, автоматически рассчитывается)
├── profit: decimal (nullable, автоматически рассчитывается)
├── details: JSON (нереляционные данные сметы)
├── deadline: datetime
├── source: enum (PLATFORM, EXTERNAL)
├── is_locked: boolean
├── created_at: datetime
└── updated_at: datetime
```

**Структура `details` (JSON):**
```typescript
{
  categories: Category[];      // Корневые категории
  subCategories: Category[];   // Подкатегории
  offers: OfferData[];         // Позиции сметы
  categorySurcharge: Record<string, { surcharge: number; linked: boolean }>;
  unforeseenExpenses: { percent: number; clientPercent: number; isVisible: boolean };
  showCostPerVideo: boolean;
}
```

---

### 7. Category (Категория)
```python
Category
├── id: UUID
├── name: string
├── parent_category_id: FK → Category (nullable)
├── level: int
└── created_at: datetime

Relations:
└── → Entry[] (category, 1:N)
```

**Иерархия:** Категории могут быть вложенными (parent-child).

---

### 8. Entry (Позиция каталога)
```python
Entry
├── id: UUID
├── name: string
├── category_id: FK → Category
├── created_at: datetime
└── Relations:
    └── → EntryUnit[] (entry, 1:N)
```

---

### 9. EntryUnit (Единица измерения для позиции)
```python
EntryUnit
├── id: UUID
├── entry_id: FK → Entry
├── unit_id: FK → Unit
├── price: decimal
└── is_default: boolean
```

---

### 10. Unit (Единица измерения)
```python
Unit
├── id: UUID
├── name: string (например: "hour", "day", "piece")
└── created_at: datetime
```

---

### 11. Team (Команда)
```python
Team
├── id: UUID
├── name: string
└── Relations:
    └── → Project[] (team, 1:N)
```

**Статус:** Пока не используется активно, зарезервировано для будущих фич.

---

## 🔗 Связи между сущностями

```
User
 ├─→ Vendor (owner)
 │    └─→ Project (vendor)
 │         ├─→ Brief (brief)
 │         └─→ Offer (project)
 │
 └─→ Client (owner)
      └─→ Brief (client)
           └─→ Project (brief)
                └─→ Offer (project)
```

---

## 🔄 Основные флоу

### Флоу 1: Вендор создает проект (текущая реализация)

1. **Вендор нажимает "New Estimation"**
2. **Backend создает:**
   - `Brief` (без `client_id`)
   - `Project` (связанный с `Brief` и `Vendor`)
   - `Offer` (связанный с `Project`)
3. **Вендор заполняет:**
   - Brief details (ТЗ)
   - Offer details (смета)
4. **Вендор экспортирует:**
   - Excel с `offerId` для клиента

---

### Флоу 2: Клиент создает бриф (планируется)

1. **Клиент создает `Brief`** (с `client_id`)
2. **Клиент приглашает вендоров**
3. **Вендоры создают `Project` и `Offer`** для этого брифа
4. **Клиент сравнивает оферы** в comparison table

---

## 🔐 Аутентификация и авторизация

### NextAuth (Frontend)
- **Session:** JWT-based
- **Providers:** Email/Password, Google OAuth
- **Callbacks:**
  - `jwt` - обновляет токен из backend API
  - `session` - копирует данные из токена в сессию

### HMAC Authentication (Backend)
- **Headers:**
  - `x-timestamp` - Unix timestamp
  - `x-user-id` - ID пользователя
  - `x-user-group` - Группа пользователя
  - `x-vendor-id` - ID вендора (если `group === VENDOR`)
  - `x-signature` - HMAC-SHA256 подпись

- **Message для подписи:**
  ```
  {METHOD}:{PATH}:{TIMESTAMP}:{USER_ID}:{USER_GROUP}
  ```

- **Middleware проверяет:**
  - Валидность подписи
  - Свежесть timestamp (±5 минут)
  - Права доступа по группе

---

## 📡 API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Регистрация
- `POST /api/v1/auth/login` - Вход
- `GET /api/v1/auth/confirm-email` - Подтверждение email
- `POST /api/v1/auth/forgot-password` - Сброс пароля
- `POST /api/v1/auth/reset-password` - Установка нового пароля

### Users
- `GET /api/v1/users/me` - Текущий пользователь
- `PATCH /api/v1/users/:id/change-group` - Смена роли (VENDOR/CLIENT)

### Catalog
- `GET /api/v1/categories` - Список категорий
- `GET /api/v1/entries` - Список позиций каталога
- `GET /api/v1/entries?full=true` - Позиции с единицами измерения

### Projects
- `GET /api/v1/projects` - Список проектов вендора
- `POST /api/v1/projects` - Создание проекта
- `GET /api/v1/projects/:id` - Детали проекта
- `PATCH /api/v1/projects/:id` - Обновление проекта
- `DELETE /api/v1/projects/:id` - Удаление проекта

### Briefs
- `GET /api/v1/briefs` - Список брифов
- `POST /api/v1/briefs` - Создание брифа
- `GET /api/v1/briefs/:id` - Детали брифа
- `PATCH /api/v1/briefs/:id` - Обновление брифа

### Offers
- `GET /api/v1/offers` - Список оферов
- `POST /api/v1/offers` - Создание офера
- `GET /api/v1/offers/:id` - Детали офера
- `PATCH /api/v1/offers/:id` - Обновление офера
- `GET /api/v1/offers/project/:projectId` - Оферы по проекту

---

## 🎨 Frontend Architecture

### Routing (Next.js App Router)
```
/app
├── /auth
│   ├── /login
│   ├── /register
│   └── /confirm-email
│
└── /app
    ├── /@unconfirmed (группа UNCONFIRMED)
    │   └── /confirm
    │
    ├── /@confirmed (группа CONFIRMED)
    │   └── /group (выбор роли)
    │
    ├── /@vendor (группа VENDOR)
    │   ├── /dashboard (список проектов)
    │   └── /project/:id
    │       ├── /details (бриф)
    │       └── /estimation (смета)
    │
    └── /@client (группа CLIENT)
        └── /dashboard (список брифов)
```

### State Management (Redux Toolkit)

**Slices:**
- `offer` - состояние текущего офера (estimation)
- `project` - метаданные проекта (ID, режим редактирования)

**RTK Query APIs:**
- `briefApi` - CRUD для брифов
- `projectsApi` - CRUD для проектов
- `offersApi` - CRUD для оферов
- `catalogApi` - Категории и позиции

**Cache Invalidation:**
```typescript
// При создании/обновлении Brief → инвалидируется тег 'Brief'
// При создании/обновлении Project → инвалидируется тег 'Project'
// При создании/обновлении Offer → инвалидируется тег 'Offer'
```

---

## 🔑 Ключевые особенности

### 1. Hybrid Data Storage
- **Реляционные поля:** `id`, `status`, `created_at`, связи (FK)
- **JSON поля:** `details` для гибких данных (Brief, Offer)

**Преимущества:**
- Гибкость структуры данных
- Быстрая разработка
- Возможность миграции на реляционную структуру позже

### 2. UUID для всех ID
- Все ID - это UUID (строки)
- Безопасность (не угадать ID)
- Совместимость с распределенными системами

### 3. Nullable Relations
- `Brief.client_id` - может быть `null` (вендор-инициированный бриф)
- `Project.brief_id` - может быть `null` (проект без брифа)
- `Project.team_id` - может быть `null` (проект без команды)
- `Offer.project_id` - может быть `null` (старые оферы)

---

## 🚧 Известные ограничения

1. **Один офер на проект** - пока что `Project` → `Offer` это 1:1, хотя модель поддерживает 1:N
2. **Team не используется** - зарезервировано для будущих фич
3. **JSON details** - нет валидации на уровне БД, только в коде
4. **Нет версионирования брифов** - при редактировании старая версия теряется

---

## 📝 Соглашения

### Naming
- **Backend (Python):** `snake_case`
- **Frontend (TypeScript):** `camelCase`
- **API (JSON):** `camelCase`

### ID Format
- **Separator:** `:` (двоеточие) для составных ключей
- **Example:** `categoryId:entryId` → `"abc-123:def-456"`

### Status Values
- `DRAFT` - черновик
- `ACTIVE` - активный
- `COMPLETED` - завершенный

---

## 🔄 Миграции

### Выполненные:
- `0001_initial` - Создание базовых моделей
- `0002_add_vendor_client_models` - Добавление Vendor, Client
- `0003_remove_brief_team_remove_offer_brief_and_more` - Создание Project, рефакторинг связей
- `0004_alter_project_team` - Team стал nullable
- `0003_seed_initial_catalog_data` - Seed данных для Categories, Entries, Units

---

## 📚 Дополнительные ресурсы

- **Figma:** `/Design` - UI/UX дизайны
- **Old Backend:** `/JSBackend` - старый NestJS backend (для справки)
- **Tests:** `/Backend/aivus_backend/test` - E2E тесты

