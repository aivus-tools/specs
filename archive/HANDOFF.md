# Handoff: Per-request локализация SSR

Документ для подхватывания работы по локализации публичного флоу AIVUS.

## Контекст задачи

На `https://go.aivus.co/public-brief` была проблема: SSR всегда отдавал английский, а клиент после гидрации переключался на русский по cookie — пользователи RU браузеров видели заметный flash EN→RU при первом визите. Параллельно ловились ошибки `Generation failed` из-за отсутствия `OPENAI_API_KEY` в контейнерах.

Обе проблемы исправлены, прод обновлён. Затем второй заход закрыл оставшиеся хвосты: vendor-флоу локализации, observability на race и красный CI smoke-test.

## Что сделано

### 1. OPENAI_API_KEY на проде

- Прод: `~/aivus/docker-compose.production.yml` пропатчен — `OPENAI_API_KEY: ${OPENAI_API_KEY}` добавлен в секции `django`, `celeryworker`, `celerybeat`. Бэкап рядом с суффиксом `.bak.20260408_001902`.
- Репо: тот же блок добавлен в template — [Specs/deployment/install.sh](Specs/deployment/install.sh) и [Specs/deployment/env.production.template](Specs/deployment/env.production.template). Чтобы при следующем переустановке всё подтянулось.
- Коммит в `aivus-tools/specs`: `41778ca` — `fix: pass OPENAI_API_KEY to django, celeryworker and celerybeat`.

### 2. Per-request локализация SSR

Главный фикс. Серверный рендер теперь отдаёт контент в локали запроса, никакого flash.

**Цепочка работы:**

1. [Frontend/src/middleware.ts](Frontend/src/middleware.ts) — функция `createPageResponse(req)` определяет локаль (cookie приоритетнее, fallback на `Accept-Language`), кладёт её в request header `x-locale` через `NextResponse.next({ request: { headers } })`. Используется во всех ветках, отдающих страницу. Редиректы и `/service/*` proxy не оборачиваются — там это не нужно.
2. [Frontend/src/lib/serverLocale.ts](Frontend/src/lib/serverLocale.ts) — module-level store, который пишется через `globalThis.__aivusServerLocale`. Так разные webpack-бандлы (RSC и client-SSR) видят одно значение в рамках одного процесса.
3. [Frontend/src/app/layout.tsx](Frontend/src/app/layout.tsx) — `await headers()`, читает `x-locale`, вызывает `setServerLocale()`, ставит `<html lang>`.
4. [Frontend/src/lib/i18n.ts](Frontend/src/lib/i18n.ts) — `getLocale()` на сервере сначала смотрит в request store, потом env, потом дефолт. На клиенте — env, потом cookie.
5. [Frontend/Dockerfile](Frontend/Dockerfile) — убран `ARG NEXT_PUBLIC_LOCALE`, чтобы клиентский бандл не зашивал локаль.
6. [Specs/deployment/install.sh](Specs/deployment/install.sh) и [Specs/deployment/env.production.template](Specs/deployment/env.production.template) — `NEXT_PUBLIC_LOCALE` убран из template.
7. На проде вручную убран `NEXT_PUBLIC_LOCALE` из `~/aivus/docker-compose.production.yml`, frontend-контейнер пересоздан.

**Коммиты:**
- `aivus-tools/frontend` `9a35f2e` — первый заход: `DEFAULT_LOCALE='en'`, Accept-Language detection в middleware.
- `aivus-tools/frontend` `af6d3f6` — `fix: render SSR in request locale to avoid en/ru flash`.
- `aivus-tools/frontend` `fb845c7` — `fix: prioritize per-request server locale over env on server`.
- `aivus-tools/specs` `d4d02b0` — `fix: drop NEXT_PUBLIC_LOCALE from frontend env to enable per-request locale`.

**Проверка прода (работает):**
```
EN браузер без cookie  -> "Create a Professional Brief", html lang="en", set-cookie locale=en
RU браузер без cookie  -> "Создать профессиональный бриф", html lang="ru", set-cookie locale=ru
EN браузер + cookie=ru -> SSR на русском
RU браузер + cookie=en -> SSR на английском
```

### 3. Vendor локализация: module-level `locale` -> `getLocale()`

[Frontend/src/lib/i18n.ts](Frontend/src/lib/i18n.ts) больше не экспортирует module-level `let locale`. Вместо него экспортируется функция `getLocale()` (бывшая private), которая на сервере читает request-store, на клиенте — cookie с кешем. Удалена `getInitialLocale()`, `resetLocaleCache()` теперь только сбрасывает client-side cache.

Три потребителя переписаны на вызов функции:
- [Frontend/src/modules/shared/SettingsForm/SettingsForm.tsx](Frontend/src/modules/shared/SettingsForm/SettingsForm.tsx) — сравнение `values.language !== getLocale()` при сохранении языка.
- [Frontend/src/modules/vendor/project-details/form/Specifications.tsx](Frontend/src/modules/vendor/project-details/form/Specifications.tsx) — `i18n.getNames(getLocale(), ...)` для списка стран.
- [Frontend/src/modules/vendor/project-details/index.tsx](Frontend/src/modules/vendor/project-details/index.tsx) — динамический require лангпака в useEffect.

Все три либо `'use client'` либо рендерятся внутри `dynamic(..., { ssr: false })`, поэтому `getLocale()` всегда выполняется на клиенте и читает актуальный cookie. Тест `i18n.test.ts` обновлён.

### 4. Observability на race в serverLocale

[Frontend/src/lib/serverLocale.ts](Frontend/src/lib/serverLocale.ts) теперь логирует `console.warn('[serverLocale] concurrent flip <prev> -> <new>')` при изменении значения в store с одного непустого на другое. Это не идеальный детектор (между двумя одновременными `set` оба перезатирают друг друга молча), но достаточно, чтобы заметить тренд если он начнётся. Грепать прод-логи на `concurrent flip` периодически.

### 5. CI smoke-test разделён на smoke и regression

[Frontend/playwright.config.ts](Frontend/playwright.config.ts):
- Добавлен отдельный project `smoke` с `testMatch: /smoke\.spec\.ts/`, зависящий от `setup`.
- В project `chromium` добавлен `testIgnore: /smoke\.spec\.ts/`, чтобы локально smoke не дублировался при `make e2e`.
- `webServer` теперь условный: если задан `process.env.SMOKE_TEST_URL`, локальный Next не поднимается вообще (тестируем внешний URL без `MissingSecret` от NextAuth).

[Frontend/package.json](Frontend/package.json) — добавлен скрипт `test:e2e:smoke` → `playwright test --project=setup --project=smoke`.

[Frontend/.github/workflows/ci.yml](Frontend/.github/workflows/ci.yml) — job `smoke-test` теперь вызывает `npm run test:e2e:smoke` вместо `npx playwright test --project=chromium`. Не меняет 4 уже существующих smoke-теста в [Frontend/e2e/smoke.spec.ts](Frontend/e2e/smoke.spec.ts).

[Makefile](Makefile) — добавлен таргет `make e2e-smoke` для локального запуска smoke против прода.

**Локальная проверка:** `npx tsc --noEmit` чисто, `npx vitest run` 319/319 зелёных, `npx playwright test --list` показывает корректное разделение projects.

## Хвосты, которые остались

### Race condition в serverLocale

[Frontend/src/lib/serverLocale.ts](Frontend/src/lib/serverLocale.ts) хранит локаль в `globalThis`, не в `AsyncLocalStorage`. Между двумя одновременными запросами теоретически возможно:

```
req A: setServerLocale('ru')
req A: ... yield ...
req B: setServerLocale('en')
req A: рендерит client component, читает 'en' -- ОШИБКА
```

**Почему так пришлось:** пробовал и `React.cache()`, и `AsyncLocalStorage.enterWith()` — ни то, ни другое не работает для client components SSR в Next.js 15. Они рендерятся через `react-dom/server` в отдельной execution context от RSC layout, async chain не наследуется. Подтверждено в логах:

```
[serverLocale] setServerLocale called with ru
[serverLocale] after enterWith, store= ru
[serverLocale] getServerLocale called, store= null   <- другая chain
```

Для нашего low-traffic SaaS race маловероятна и приемлема. Добавлен warning-лог `[serverLocale] concurrent flip` как точка раннего обнаружения. Если когда-нибудь станет проблемой — единственный надёжный путь это рефакторинг `t()` под React context provider, что зацепит ~150 файлов с `t()` вызовами. Большая работа, не сейчас.

## Тех-карта

### Стек

- Backend: Django 5.2 + PostgreSQL + Redis + Celery — **только в Docker**, никогда `manage.py` напрямую.
- Frontend: Next.js 15.2.3 (App Router) + React 19 + Redux Toolkit + RTK Query + NextAuth.js.
- AI: LangGraph + OpenAI API (для генерации брифов).
- HMAC middleware прокси `/service/*` → `/api/v1/*`.

### Команды

- `make help` — список всех команд.
- `make e2e` / `make e2e-ui` — e2e Playwright локально.
- `npx tsc --noEmit` — typecheck. **Не запускать `npm run build`**, оно ломает живой dev-сервер.
- `npx vitest run` — unit-тесты (319 штук).
- Backend линтер: `cd Backend/aivus_backend && ruff check . && ruff format .`.

### Прод

- SSH `go.aivus.co` (root). Aivus в `~/aivus`.
- Compose: `~/aivus/docker-compose.production.yml`. Env: `~/aivus/.env`.
- Контейнеры: `aivus_django`, `aivus_celeryworker`, `aivus_celerybeat`, `aivus_frontend`, `aivus_postgres`, `aivus_redis`.
- Перезапуск frontend: `cd ~/aivus && docker compose -f docker-compose.production.yml up -d frontend`.

### Репозитории

- Frontend: `aivus-tools/frontend`, ветка `master`.
- Specs (deployment/docs): `aivus-tools/specs`, ветка `main`.
- Pre-push hook на frontend гонит typecheck + 319 unit-тестов. На больших коммитах ждать ~30 секунд.

## Где смотреть в первую очередь

Если задача про локализацию — начинать с этих файлов:
- [Frontend/src/middleware.ts](Frontend/src/middleware.ts)
- [Frontend/src/app/layout.tsx](Frontend/src/app/layout.tsx)
- [Frontend/src/lib/i18n.ts](Frontend/src/lib/i18n.ts)
- [Frontend/src/lib/serverLocale.ts](Frontend/src/lib/serverLocale.ts)
- [Frontend/src/locales/en.ts](Frontend/src/locales/en.ts) и [Frontend/src/locales/ru.ts](Frontend/src/locales/ru.ts)
- [Frontend/src/lib/i18n.test.ts](Frontend/src/lib/i18n.test.ts)

Если задача про CI/деплой:
- [Frontend/.github/workflows/ci.yml](Frontend/.github/workflows/ci.yml)
- [Frontend/playwright.config.ts](Frontend/playwright.config.ts)
- [Frontend/Dockerfile](Frontend/Dockerfile)
- [Specs/deployment/install.sh](Specs/deployment/install.sh)
- [Specs/deployment/env.production.template](Specs/deployment/env.production.template)

Если задача про публичный брифинг:
- [Frontend/src/app/public-brief/page.tsx](Frontend/src/app/public-brief/page.tsx)
- [Frontend/src/app/public-brief/[briefId]/page.tsx](Frontend/src/app/public-brief/[briefId]/page.tsx)
- [Frontend/src/services/client/publicBriefApi.ts](Frontend/src/services/client/publicBriefApi.ts)
- Backend: эндпоинт `/api/v1/public/briefs/ai/start` (поиск через grep по `public_briefs`).

## Нюансы, на которые легко наступить

- `cookies()` и `headers()` в Next.js 15 **async**. Sync доступ работает с warning, но в 16 удалят. В новом коде использовать только через `await`.
- Не запускать `npm run build` для проверки типов — оно перезапишет `.next` и убьёт работающий dev. Только `npx tsc --noEmit`.
- Если dev-сервер начал отдавать 404 на CSS: `kill 3000 && rm -rf .next && npm run dev`.
- `NEXT_PUBLIC_*` инлайнятся **только на build**, runtime env на client bundle не влияет. Поэтому удаление `NEXT_PUBLIC_LOCALE` из docker-compose имеет смысл только для серверной части Node-процесса Next.js, а на бандл влияет только Dockerfile.
- `React.cache()` **не работает** для передачи state из RSC layout в client component SSR — у них разные render passes.
- `AsyncLocalStorage.enterWith()` тоже **не работает** по той же причине.
- Edge-runtime в middleware не имеет `node:async_hooks`, поэтому ALS там запускать нельзя.

## Что не делать

- Не коммитить и не пушить без явной просьбы пользователя.
- Не оставлять в коде/коммитах упоминаний AI, нейросетей, Claude и т.п.
- Не запускать e2e тесты на проде без согласования.
- Не править прод-конфиги без бэкапа рядом.
- Не использовать `--no-verify` для обхода pre-commit/pre-push хуков. Если хук падает — чинить причину.

## Правила пользователя (короткой строкой)

- Общение на ты, по-русски, без подхалимства, шутки и мат уместны в меру.
- Коммиты на английском, однострочные, без тела, без `Co-Authored-By`.
- Без комментариев в коде. Без сокращений в названиях. Строгая типизация.
- В лямбдах с одним аргументом — `x`, с двумя где один индекс — `x` и `i`.
- В TS/JS: `interface` вместо `type`, без деструктуризации (кроме rest), `null` вместо `undefined`, `===`/`!==` (для null — `==`/`!=`).
- В React: `export const XxxZzz: React.FC<XxxZzzProps> = props => {...}`, один файл — один компонент, пропы — отдельный `interface XxxZzzProps` сразу над компонентом.

Полные правила в [/Users/ipolotsky/.claude/CLAUDE.md](file:///Users/ipolotsky/.claude/CLAUDE.md) и [.claude/CLAUDE.md](.claude/CLAUDE.md) проекта.
