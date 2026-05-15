# Архитектура Aivus

Состояние на май 2026. Все ссылки на код — относительные пути от корня основного репо.

## Продукт

SaaS для автоматизации RFP в video production. Две роли в MVP:

- **Vendor** — создаёт projects, к ним offers, шарит публичными ссылками, экспортирует XLSX.
- **Client** — создаёт briefs через AI чат, загружает XLSX, сравнивает offers.

Рынок US, английский приоритет. AI must-have. Freelancer-роли в MVP нет.

## Стек

### Backend

| Компонент | Версия | Файл |
|---|---|---|
| Python | 3.13 | [Backend/aivus_backend/pyproject.toml](../Backend/aivus_backend/pyproject.toml) |
| Django | 5.2.7 | pyproject.toml:186-219 |
| Celery | 5.5.3 | pyproject.toml |
| Postgres (prod) | 17 | [prod-docker-compose.yml](./prod-docker-compose.yml):49 |
| Postgres (dev) | 14+ | [Backend/aivus_backend/docker-compose.local.yml](../Backend/aivus_backend/docker-compose.local.yml) |
| Redis | 7-alpine | prod-docker-compose.yml:97 |
| Anthropic SDK | >=0.40.0 | pyproject.toml |
| OpenAI SDK | >=1.0.0 | pyproject.toml |
| Google GenAI SDK | >=1.0.0 | pyproject.toml |

DRF не используется — все views функциональные.

### Frontend

| Компонент | Версия | Файл |
|---|---|---|
| Next.js | 15.2.3 (App Router) | [Frontend/package.json](../Frontend/package.json):48 |
| React | 19 | package.json:52 |
| Redux Toolkit | 2.5.0 | package.json:28 |
| NextAuth | 5.0.0-beta.25 | package.json:49 |
| antd | 5.22.5 | package.json:37 |
| @ant-design/nextjs-registry | 1.0.2 | package.json:26 |
| @ant-design/v5-patch-for-react-19 | 1.0.3 | package.json:27 |
| styled-components | 6.1.13 | package.json:59 |
| TipTap | 3.22.2 | package.json:30-35 |
| TinyMCE | 6.3.0 | package.json:29 |
| Vitest | 4.0.18 | package.json:103 |
| Playwright | 1.58.2 | package.json:67 |

Tailwind не используется. Стили — antd темы (`ConfigProvider` в [Frontend/src/app/layout.tsx](../Frontend/src/app/layout.tsx)) плюс CSS Modules и styled-components для точечной кастомизации.

## Структура

### Backend Django apps

[Backend/aivus_backend/aivus_backend/](../Backend/aivus_backend/aivus_backend/):

- `core/` — `JournalizeModel` (UUID pk + soft-delete + timestamps), HMAC middleware, LLM provider, общие утилиты.
- `users/` — User, Client, Vendor, Team, UserTeam, UserSettings, VendorSettings.
- `catalog/` — Category, Unit, Entry, EntryUnit (общий каталог позиций для смет).
- `projects/` — Brief, Project, Offer, Share, Template, Rate, RateCard, Brief AI (chat, attachments, finalization, prompts), traces, deliverables, schedule.
- `vendors/` — PreVendor (маркетинговые карточки рекомендованных вендоров).

Settings: [Backend/aivus_backend/config/settings/](../Backend/aivus_backend/config/settings/) — base/local/production/test.

### Frontend src

[Frontend/src/](../Frontend/src/):

- `app/` — Next.js App Router. Корневой layout с `ConfigProvider(antd)`, `StyledComponentsRegistry`, `SessionProvider`. Используются параллельные слоты `@client / @vendor / @unknown`.
- `auth/` — NextAuth конфиг ([Frontend/src/auth/auth.ts](../Frontend/src/auth/auth.ts)) и server actions.
- `components/` — переиспользуемые UI (Auth, Modal, Profile, ProjectItem, Search и т.д.).
- `modules/` — фича-модули:
  - `client/` — BriefForm, BriefChat, BriefChatV2, BriefEditorV2, ComparisonTable, PreVendors;
  - `vendor/` — dashboard, estimation, rates, sider, project-details, client-offer, SaveTemplateModal, export, VendorSettingsSection;
  - `shared/` — ProfileForm, SettingsForm;
  - `OfferTabs`, `PublicOffer`, `SharePopup`, `Sidebar`.
- `services/client/` — RTK Query endpoints (16 файлов `*Api.ts`).
- `services/server/` — server-side actions.
- `store/` — Redux store, rootReducer, slices (`project/`, `offer/`, `vendor.ts`, `sidebar.ts`).
- `lib/` — `i18n.ts`, `themeConfig.ts`, `hmac.ts`, `logger.ts`, `listenerMiddleware.ts`.
- `locales/` — `en.ts`, `ru.ts`, `index.ts`.
- `constants/` — `apiRoute.ts`, `appRoute.ts`, `constants.ts`.

Алиас импортов: `@/*` -> `./src/*` ([Frontend/tsconfig.json](../Frontend/tsconfig.json):24).

## Модели данных

Полные определения — [Backend/aivus_backend/aivus_backend/](../Backend/aivus_backend/aivus_backend/). Здесь только ключевые поля и связи.

### users/models.py

| Модель | Ключевые поля |
|---|---|
| `User` (line 18) | UUID pk, email-only auth, group (UNCONFIRMED/CONFIRMED/VENDOR/CLIENT/SYSTEM), name, position, avatar, auth_type, pending_brief_id, pending_brief_token |
| `Client` (line 170) | name, ein, owner FK→User |
| `Vendor` (line 193) | name, owner FK→User |
| `Team` (line 215) | name (зарезервировано под коллаборацию) |
| `UserTeam` (line 232) | user FK, team FK, role |
| `UserSettings` (line 260) | language, nda_accepted, notifications |
| `VendorSettings` (line 283) | logo, company_name, agency_name, fringes_percent, handling_percent (брендинг + проценты надбавок) |

### catalog/models.py

| Модель | Ключевые поля |
|---|---|
| `Category` (line 17) | name, parent_category self-ref, level, tags, code |
| `Unit` (line 59) | name, symbol, dimension, is_default |
| `Entry` (line 89) | name, code, description, is_approved, category FK |
| `EntryUnit` (line 116) | entry FK, unit FK, is_default |

### projects/models.py

Основные:

| Модель | Ключевые поля |
|---|---|
| `Brief` (line 35) | status, details JSON, structured_data JSON, client FK, anonymous_token, token counts, cost tracking |
| `Project` (line 78) | name, vendor FK, brief FK, team FK, status, crm_id, description, client info |
| `ProjectCollaborator` (line 145) | project FK, user FK, name, email, role |
| `ClientManager` (line 184) | name, position |
| `Offer` (line 287) | project_name, parent_offer self-ref (history), project FK, cost, profit, проценты |
| `OfferEntry` (line 356) | offer FK, entry FK, category FK, price, cost, client_price, client_cost, tax, market_range |
| `OfferRate` (line 414) | M2M Offer↔Rate со снимком (name, base_price, total_price, options, quantity) |
| `OfferDeliverable` (line 450) | quantity, duration, duration_unit, notes, sort_order |
| `OfferScheduleEntry` (line 476) | phase_type, days, hours_per_day |
| `Share` (line 502) | offer FK, token unique, is_active, created_by FK |
| `BriefOffer` (line 539) | brief FK, offer FK, linked_by FK |
| `Template` (line 572) | name, vendor FK, source_offer FK, details JSON snapshot |
| `Rate` (line 235) | name, vendor FK, entry FK, base_price, total_price, options JSON |
| `SimpleRate` (line 206) | vendor FK, entry FK, value decimal |
| `RateCard` (line 604) | vendor FK, name |
| `RateCardItem` (line 677) | rate_card FK, entry FK, item_name, price, unit FK |

Brief AI v3 (см. отдельный раздел ниже):

| Модель | Ключевые поля |
|---|---|
| `ChatMessage` (line 626) | brief FK, user FK, anonymous_token, role, kind, content, input/output_tokens, cost_usd, model_used, ready_to_finalize |
| `BriefAttachment` (line 879) | brief FK, message FK, file, filename, mime_type, size_bytes, gemini_file_uri |
| `BriefFinalDocument` (line 908) | brief FK, kind, html, plain_text |
| `BriefShare` (line 787) | brief OneToOne, token unique, is_active, created_by FK |
| `BriefPrompt` (line 827) | slug (BriefPromptSlug enum), title, body, version, is_active, model_name, metadata JSON, created_by FK, unique (slug, version) и одна active per slug |
| `BriefFeedback` (line 715) | brief FK, message FK, rating, comment, user FK |
| `LLMCallTrace` (line 746) | message FK, final_document FK, purpose, model, request_messages/params JSON, response_raw, token counts, cost, latency_ms, sequence |

### vendors/models.py

| Модель | Ключевые поля |
|---|---|
| `PreVendor` (line 12) | logo, portfolio_url, title, short_description, language, address, email, rank_label, category_label, sort_order |

## Auth

### NextAuth (Frontend)

Конфиг — [Frontend/src/auth/auth.ts](../Frontend/src/auth/auth.ts).

- Провайдеры: Google OAuth (lines 13-27), Credentials (email/password + briefId/briefToken для anonymous flow, lines 30-64).
- Session/JWT maxAge: 24 часа (lines 69-74).
- `signIn` callback различает Google (checkEmail → login или register) и Credentials login (lines 80-149).
- `jwt` callback сохраняет group, id, vendorId, clientId, isStaff в токен (lines 151-188).
- `authorized` callback: публичные пути `/auth, /external, /public, /shared-brief, /public-brief`, остальное требует auth (lines 198-211).
- Pages: signIn `/auth`, error `/auth`.

### HMAC middleware (Backend)

[Backend/aivus_backend/aivus_backend/core/middleware.py](../Backend/aivus_backend/aivus_backend/core/middleware.py):

- `HMACAuthenticationMiddleware` подключена в `MIDDLEWARE` (line 162).
- Заголовки запроса: `x-timestamp`, `x-user-id`, `x-user-group`, `x-vendor-id`, `x-signature`.
- Сообщение для подписи: `{METHOD}:{PATH}:{TIMESTAMP}:{USER_ID}:{USER_GROUP}` (HMAC-SHA256 от `HMAC_SECRET`).
- `TIMESTAMP_TOLERANCE_SECONDS = 60` (line 23).
- Frontend проксирует `/service/*` → `/api/v1/*` через middleware [Frontend/src/middleware.ts](../Frontend/src/middleware.ts), подписывая запросы на лету.

## API endpoints

Корневой include — [Backend/aivus_backend/config/urls.py](../Backend/aivus_backend/config/urls.py).

### Auth и users

`/api/v1/auth/*` подключены через [Backend/aivus_backend/aivus_backend/users/api/urls.py](../Backend/aivus_backend/aivus_backend/users/api/urls.py).

| Метод | Путь |
|---|---|
| GET | `/api/v1/users/me` |
| GET | `/api/v1/users` |
| PATCH | `/api/v1/users/<uuid>/change-group` |
| GET/PATCH | `/api/v1/users/profile`, `/profile/avatar`, `/settings` |
| POST | `/api/v1/users/change-password` |

### Catalog

Подключение через [Backend/aivus_backend/aivus_backend/catalog/api/urls.py](../Backend/aivus_backend/aivus_backend/catalog/api/urls.py): GET категорий/entries/units/(`?full=true`).

### Projects (vendor flow)

[Backend/aivus_backend/aivus_backend/projects/api/urls.py](../Backend/aivus_backend/aivus_backend/projects/api/urls.py).

**Projects:**
- `GET/POST /api/v1/projects`, `GET /api/v1/projects/archived`
- `GET/PATCH/DELETE /api/v1/projects/<uuid>`, `POST /restore`, `POST /thumbnail`

**Briefs (legacy):**
- `GET /api/v1/briefs`, `GET /api/v1/briefs/<uuid>`

**Offers:**
- `GET/POST /api/v1/offers`, `GET/PATCH/DELETE /api/v1/offers/<uuid>`
- `GET /api/v1/offers/project/<uuid>`
- `PUT /api/v1/offers/<uuid>/status`, `POST /copy`, `GET /export-data`

**Shares:**
- `POST /api/v1/shares`
- `GET /api/v1/shares/<token>`
- `GET/POST /api/v1/shares/<token>/manage`
- `POST /api/v1/shares/<token>/link`
- `GET /api/v1/shares/<token>/export-data`

**Templates и Rate Cards:**
- `GET/POST /api/v1/templates`, `GET/PATCH/DELETE /api/v1/templates/<uuid>`, `POST /<uuid>/apply`
- `GET/POST /api/v1/rates`, `GET /api/v1/rates/lookup`, `GET/PATCH/DELETE /api/v1/rates/<uuid>`

### Client briefs

- `GET /api/v1/client/briefs`, `GET/PATCH /api/v1/client/briefs/<uuid>`, `GET /<uuid>/offers`
- `POST /api/v1/client/briefs/chat`, `POST /chat/analyze` (legacy chat)
- `GET /api/v1/client/briefs/<uuid>/comparison`, `POST /comparison/analyze`
- `POST /api/v1/client/xlsx-upload`

### Brief AI v3

Все views — [Backend/aivus_backend/aivus_backend/projects/api/views_brief_v3.py](../Backend/aivus_backend/aivus_backend/projects/api/views_brief_v3.py).

**Authenticated client:**
- `GET /api/v1/client/briefs/ai`, `GET /drafts`
- `POST /api/v1/client/briefs/ai/<uuid>/start`, `GET /status`
- `POST /api/v1/client/briefs/ai/<uuid>/chat`, `POST /transcribe`
- `GET /api/v1/client/briefs/ai/<uuid>` (детали)
- `POST/DELETE /api/v1/client/briefs/ai/<uuid>/attachments[/<uuid>]`
- `POST /api/v1/client/briefs/ai/<uuid>/feedback`
- `GET /api/v1/client/briefs/ai/<uuid>/messages/<uuid>/trace`
- `POST /api/v1/client/briefs/ai/<uuid>/finalize`
- `GET/PUT /api/v1/client/briefs/ai/<uuid>/final-documents[/<uuid>][/pdf]`
- `GET/POST /api/v1/client/briefs/ai/<uuid>/share`

**Anonymous (public) flow:**
- `GET /api/v1/public/briefs/ai/drafts`
- `POST /api/v1/public/briefs/ai/<uuid>/start`, `GET /status`, `POST /chat`, `POST /transcribe`
- `POST/DELETE /api/v1/public/briefs/ai/<uuid>/attachments[/<uuid>]`
- `GET /api/v1/public/briefs/ai/<uuid>` (детали)
- `POST /api/v1/public/briefs/ai/<uuid>/claim` — привязать anonymous brief к зарегистрированному пользователю.

**Public brief share:**
- `GET /api/v1/public/brief-shares/<token>`
- `GET /api/v1/public/brief-shares/<token>/documents/<uuid>/pdf`

## AI пайплайн

LangGraph выпилен. Унифицированный chat engine — [Backend/aivus_backend/aivus_backend/projects/ai_brief_v3.py](../Backend/aivus_backend/aivus_backend/projects/ai_brief_v3.py).

### Провайдеры и модели

Конфигурация — [Backend/aivus_backend/aivus_backend/core/llm.py](../Backend/aivus_backend/aivus_backend/core/llm.py):

- **Anthropic**: `claude-sonnet-4-5-20250929` (line 69).
- **OpenAI**: `gpt-4o`, `gpt-4o-mini` (lines 70-71).
- **Google Gemini (Vertex)**: `gemini-3.1-pro-preview`, `gemini-3.1-flash-lite-preview`, `gemini-2.5-pro`, `gemini-2.5-flash`, `gemini-2.5-flash-lite` (lines 72-77).

Env vars (lines 120-155):

- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` — простые ключи.
- `GOOGLE_CLOUD_PROJECT`, `GOOGLE_CLOUD_LOCATION` (default `us-central1`), `VERTEX_CREDENTIALS_PATH` — для Gemini через Vertex AI.

Fallback chain (lines 79-86): claude → gemini-3.1-pro-preview → gemini-2.5-pro → gemini-2.5-flash → gemini-2.5-flash-lite. Для OpenAI: gpt-4o → gpt-4o-mini.

### Brief AI v3 ядро

[Backend/aivus_backend/aivus_backend/projects/ai_brief_v3.py](../Backend/aivus_backend/aivus_backend/projects/ai_brief_v3.py):

- `process_brief_turn` — обработка каждого chat turn (первое сообщение и follow-ups) с system prompt из активной `BriefPrompt` записи.
- `generate_final_documents` — production brief с deliverables и Vendor Outreach Email.
- `generate_brief_title` — заголовок brief после finalization.

Defaults (lines 41-48): `DEFAULT_MODEL=gemini-3.1-pro-preview`, `TITLE_MODEL=gemini-2.5-flash`, `MAIN_MAX_TOKENS=2500`, `FINALIZATION_MAX_TOKENS=6000`, `MAIN_TEMPERATURE=0.7`.

Промпты живут в БД (`BriefPrompt`, version + is_active per slug). Менять — через админку `/admin/projects/briefprompt/`, не из кода.

### Multimodal (Gemini Files)

Реализовано:

- `BriefAttachment.gemini_file_uri` (`projects/models.py:897`) — URI загруженного файла.
- В [core/llm.py](../Backend/aivus_backend/aivus_backend/core/llm.py) поддерживается `file_uri` и `inline_bytes` в content parts (lines 175-186).

### Speech-to-Text

[Backend/aivus_backend/aivus_backend/projects/stt.py](../Backend/aivus_backend/aivus_backend/projects/stt.py):

- Default: synthetic recognizer `_` + локация `global` + модель `short`. Лимит аудио `MAX_AUDIO_DURATION_SEC=60`.
- Env: `STT_MODEL` (default `short`), `GOOGLE_CLOUD_SPEECH_LOCATION` (default `global`).
- `STT_DEV_FAKE=1` — фейковый ответ без вызова GCP (CI / локалка без credentials).
- Полный гайд по моделям и регионам — [GCP_SETUP.md](./GCP_SETUP.md) → "Runtime APIs и роли".

### Трейсинг

`LLMCallTrace` сохраняется по каждому вызову модели (request, response, tokens, cost, latency). Сохранение асинхронное — Celery task `persist_message_traces` / `persist_final_document_traces` ([Backend/aivus_backend/aivus_backend/projects/tasks.py](../Backend/aivus_backend/aivus_backend/projects/tasks.py):22, 44).

## Celery

[Backend/aivus_backend/aivus_backend/projects/tasks.py](../Backend/aivus_backend/aivus_backend/projects/tasks.py):

- `persist_message_traces` (line 22), `persist_final_document_traces` (line 44).
- `generate_first_reply_task` (line 73) — initial AI reply на первое сообщение пользователя.
- `finalize_brief_task` (line 142) — finalization брифа.

[Backend/aivus_backend/aivus_backend/users/tasks.py](../Backend/aivus_backend/aivus_backend/users/tasks.py): `send_templated_email` (line 21, autoretry).

Конфиг — [Backend/aivus_backend/config/settings/base.py](../Backend/aivus_backend/config/settings/base.py):338-377: broker/result backend = `REDIS_URL`, `DatabaseScheduler` от django_celery_beat, `CELERY_TASK_TIME_LIMIT=5*60`, `CELERY_TASK_SOFT_TIME_LIMIT=60`.

## Frontend routing

Корневой layout — [Frontend/src/app/layout.tsx](../Frontend/src/app/layout.tsx). Обёртки (порядок снаружи внутрь): `StyledComponentsRegistry` (`@ant-design/nextjs-registry`) → `ConfigProvider` (тема из [Frontend/src/lib/themeConfig.ts](../Frontend/src/lib/themeConfig.ts)) → `AntdAppProvider` → `SessionProvider`.

### Параллельные слоты

`/app/app/layout.tsx` — слот-роутер с тремя параллельными ветками `@client / @vendor / @unknown`. Selection идёт по `session.user.group`:

- `/app/@client/*` — dashboards, brief flow, comparison, settings.
- `/app/@vendor/*` — dashboards, project details/estimation/offer/timing/presentation/analysis, templates, rates, settings.
- `/app/@unknown/*` — `/confirm` для UNCONFIRMED, `/group` для CONFIRMED (выбор роли).

### Публичные ветки

- `/auth/*` — login, register, confirm-email, forgot/reset password.
- `/public/[token]` — публичный просмотр offer (через `Share`).
- `/public-brief/[briefId]`, `/shared-brief/[token]` — публичные briefs.
- `/external` — внешняя интеграция (XLSX upload).
- `/export/[offerId]` — экспортная страница.

### Locale

[Frontend/src/middleware.ts](../Frontend/src/middleware.ts):13-76:

- Поддерживаемые: `en`, `ru`. Default `en`.
- `resolveLocale` берёт из cookie или `detectLocaleFromHeader()` (Accept-Language).
- Cookie `locale` ставится на 1 год.
- В layout (`app/layout.tsx`) `setServerLocale` пишет server-side locale, на клиенте `getLocale()` читает cookie.
- Per-request, без `NEXT_PUBLIC_LOCALE` (выпилен).

## Frontend state

### Store

[Frontend/src/store/store.ts](../Frontend/src/store/store.ts):1-46 — `configureStore` с `rootReducer` и middleware всех 16 RTK Query API + `listenerMiddleware`.

[Frontend/src/store/rootReducer.ts](../Frontend/src/store/rootReducer.ts):23-44 — четыре slice-редьюсера (project, sidebar, offer, vendor) и 16 `*Api.reducerPath`.

### RTK Query

Все в [Frontend/src/services/client/](../Frontend/src/services/client/):

| API | Что делает |
|---|---|
| `briefApi` | CRUD legacy briefs |
| `projectsApi` | Projects (vendor): CRUD, archived, restore, thumbnail |
| `offersApi` | Offers: CRUD, by project, copy, status update, export-data |
| `userApi` | changeGroup, confirmEmail, resendConfirmation, forgot/resetPassword |
| `categoriesApi` | Categories, Entries (full/lookup), Units |
| `chatApi` | Legacy: sendMessage, analyzeBrief |
| `briefAiApi` | Brief AI v3: 25+ endpoints (drafts/start/status/chat/transcribe/attachments/feedback/trace/finalize/final-documents/share/list/delete/rename/settings) |
| `ratesApi` | Vendor rates |
| `sharesApi` | Share create/get/manage/link/export |
| `templatesApi` | Templates CRUD + apply |
| `comparisonApi` | Comparison briefs/offers |
| `xlsxApi` | XLSX export/import |
| `profileApi` | Profile + settings + change password + avatar |
| `vendorSettingsApi` | Vendor settings |
| `publicBriefApi` | Public brief endpoints |
| `preVendorsApi` | PreVendors list |

### Slices

`store/slices/`:

- `project.ts` (+ folder с тестами) — метаданные текущего проекта.
- `offer/slice.ts` (+ `listener.ts`, `selectors.ts`, тесты) — состояние estimation.
- `vendor.ts` — vendor-scoped стейт.
- `sidebar.ts` — UI стейт sidebar.

## Тесты

### Backend

27 тестовых файлов. Pytest + pytest-django, `--ds=config.settings.test --reuse-db`. Конфиг — [Backend/aivus_backend/pyproject.toml](../Backend/aivus_backend/pyproject.toml):2-14. Coverage — `django_coverage_plugin`.

Линтеры (pre-commit): `ruff check`, `ruff format`, `djLint` (HTML темплейты), `mypy` (с `mypy_django_plugin`).

### Frontend

26 vitest файлов (jsdom). Конфиг — [Frontend/vitest.config.ts](../Frontend/vitest.config.ts):1-29. Setup — [Frontend/src/test/setup.ts](../Frontend/src/test/setup.ts) (jest-dom, моки env vars).

Playwright e2e — [Frontend/e2e/](../Frontend/e2e/), 8 spec-файлов. Проекты в [Frontend/playwright.config.ts](../Frontend/playwright.config.ts):24-55: `setup`, `smoke` (CI), `chromium` (полный набор), `client-no-auth` (anonymous flow).

Pre-push hook гонит typecheck + vitest (~30 сек).

## Источники истины

| Что нужно | Где смотреть |
|---|---|
| Стек, модели, AI | этот файл |
| Production deployment | [DEPLOYMENT.md](./DEPLOYMENT.md) |
| Переменные окружения | [ENV_VARIABLES.md](./ENV_VARIABLES.md) |
| GCP runtime (Vertex/STT/GCS) | [GCP_SETUP.md](./GCP_SETUP.md) |
| Восстановление прода | [DISASTER_RECOVERY.md](./DISASTER_RECOVERY.md) |
| Команды разработки | [../DEVELOPMENT.md](../DEVELOPMENT.md), `make help` |
| Project rules (Claude) | [claude/CLAUDE.md](./claude/CLAUDE.md) |
| Skills (Claude) | [claude/skills/](./claude/skills/) |
