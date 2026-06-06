# Brief flow — архитектурный долг и план рефакторинга

> СТАТУС (закрыто): P0-P2 закрыты в ветках `brief-refactor` (Frontend и Backend). Итоги и заложенные roadmap-швы — в разделе «Результат рефакторинга и roadmap-швы» в конце документа. Этот документ оставлен как карта исходного долга.

> Документ-хэндофф для отдельной сессии. Собран в конце большой серии правок по фиче «Wix-форма → публичный бриф → claim к залогиненному клиенту». Все фиксы из этой серии уже выкачены в код (см. раздел «Текущее состояние»). Задача следующей сессии — закрыть архитектурный долг.

## Контекст

Брифовая фича прошла несколько итераций за две недели:
- Добавили публичный вебхук `/api/v1/public/briefs/ai/from-wix` для Wix Velo-формы (с опциональными `email`/`name`/`files`).
- Сделали авто-claim для залогиненного клиента при заходе на `/public-brief/{id}`.
- Починили несколько гонок: `transaction.on_commit` для Celery задач (ATOMIC_REQUESTS), polling first reply через RTK `pollingInterval` (auth) и `setInterval` (public), `thinking_budget=0` для `gemini-2.5*`, нормализацию `contact_email`, перенос `claim` из `/public/` в `/client/` для корректной HMAC-подписи.
- Добавили `contact_rule` в системный промпт при `finalize`: имя/email клиента берётся из `Brief.contact_*` или fallback на `brief.client.owner.*`.

Каждая итерация добавляла слои поверх существующей архитектуры. Накопился долг, который при следующем серьёзном изменении грозит выстрелить регрессиями. Этот документ — точка опоры для одного целевого рефакторинга, который закроет долг разом.

## Что уже сделано (короткий чек-лист, не для повторения)

Список нужен как карта «откуда есть пошёл код», чтобы следующая сессия не дублировала фиксы.

**Backend:**
- `projects/models.py:Brief` — поля `contact_email`, `contact_name` (миграция `0034_brief_contact_email_brief_contact_name`).
- `projects/attachments.py` (новый модуль) — `ALLOWED_MIME_TYPES`, `MAX_ATTACHMENT_SIZE_BYTES`, `WIX_FILE_HOST_SUFFIXES`, `sniff_mime`, `download_remote_file` (SSRF-guard через urllib без редиректов, libmagic-проверка MIME). Импортируется и из `views_brief_v3.py`, и из `tasks.py`.
- `projects/api/views_brief_v3.py`:
  - `public_brief_ai_from_wix` (вебхук, `@public_endpoint`, секрет в заголовке `X-Aivus-Webhook-Secret`, rate-limit 30/h по IP).
  - `_extract_wix_payload` — поддерживает компактный Velo-контракт и automation-shape Wix.
  - `client_brief_ai_claim` (переименован из `public_brief_ai_claim`, URL переехал на `/api/v1/client/briefs/ai/<id>/claim`).
  - `contact_email` нормализуется `.strip().lower()[:254]` при сохранении.
  - Enqueue через `transaction.on_commit(signature.apply_async)` с pre-generated `task_id = uuid.uuid4()`. Это лечит гонку с ATOMIC_REQUESTS=True (без этого worker подхватывал задачу до commit и видел `Brief not found`).
- `projects/tasks.py`:
  - `import_wix_attachments_task(brief_id, file_specs)` — качает с whitelist-хостов через `download_remote_file`, прикрепляет к первому user-message. Failure одного файла не валит таску.
  - `generate_first_reply_task` — без изменений.
- `projects/ai_brief_v3.py`:
  - `_build_contact_rule(brief)` — приоритет `Brief.contact_*` → `brief.client.owner.*`. Используется только в `generate_final_documents` (finalize), не в `process_brief_turn`.
  - `_build_system_prompt(..., contact_rule="")` принимает новый kwarg.
- `core/llm.py:227` — `thinking_budget=0` теперь и для `gemini-2.5*`, не только `gemini-3*` (баг с пустым auto-title).
- `projects/api/serializers.py` — `serialize_brief_v3` отдаёт `contactEmail` и `contactName`.
- `config/settings/base.py` — `WIX_WEBHOOK_SECRET = env("WIX_WEBHOOK_SECRET", default="")`. Пустой = эндпоинт 401 by default (safe-by-default).
- `Specs/ENV_VARIABLES.md` — задокументирован `WIX_WEBHOOK_SECRET`.

**Frontend:**
- `src/types/briefAi.interface.ts:BriefV3` — `contactEmail?`, `contactName?`.
- `src/app/public-brief/[briefId]/page.tsx`:
  - Token из query → `localStorage` (синхронно через `tokenFromQuery ?? storedToken`), потом `replaceState` чистит URL.
  - Залогиненный client → `router.replace(AppRoute.BRIEF_CLAIM(briefId))` (без модалки — бизнес-решение по итогам обсуждения).
  - Edge-case: client без токена → `router.replace(AppRoute.BRIEF_DETAIL(briefId))` (страховка от спиннер-лока).
  - `handleRegisterClick(briefId, token, email)` → роутит на `/auth` с/без `?email=`.
- `src/app/public-brief/layout.tsx` — `minHeight: '100dvh'` + `background: var(--bg-gray-page)` (фон на весь экран).
- `src/modules/client/BriefEditor/BriefEditorLayout.tsx`:
  - `useLazyGetPublicBriefDetailQuery` для public-mode (вместо авто-подписки — убрана гонка с polling).
  - Локальные state `contactEmail`, `publicHasHydrated` (для skeleton).
  - `awaitingFirstReply = stage==='chat' && !isChatLoading && conversationStatus==='in_progress' && lastMessage?.role==='user' && !lastMessage.id.startsWith('local-')`.
  - Для auth: `useGetBriefAiDetailQuery({ pollingInterval: isAuth && awaitingFirstReply ? 1500 : 0 })`.
  - Для public: явный `setInterval(1500ms)` с `triggerFetchPublicDetail` пока `awaitingFirstReply`.
- `src/modules/client/BriefChat/BriefChatPanel.tsx` — две кнопки регистрации (`Register with email` / `Register with another email`) если `registrationEmail` truthy, иначе одна `Sign up`.
- `src/helpers/checkEmail.ts` — общий helper для check-email (вынесен из `EmailForm.tsx`).
- `src/app/auth/.../ManageAuth.tsx` — читает `?email=` из query, авто-`checkEmail` → routing на register/signin step.
- `src/middleware.ts` — простое условие `!auth/* && !public/*` подписывает HMAC (без частных исключений; claim теперь под `/client/*`, подписывается автоматически).
- `src/constants/apiRoute.ts` — `CLIENT_BRIEF_AI_CLAIM` (`/service/client/briefs/ai/<id>/claim`).
- `src/services/client/publicBriefApi.ts` — `claimPublicBrief` ходит на новый URL.

**Wix-сторона (вне репозитория, в Velo):**
- Backend web method `aivusBrief.web.js` шлёт payload на наш вебхук, через `mediaManager.getDownloadUrl()` конвертирует `wix:document://...` в публичный signed URL.
- Page code на каждой Wix-форме сабмитит `{message, files, [email, name]}` через эту функцию и редиректит на `briefUrl`.
- Секрет `AIVUS_WEBHOOK_SECRET` в Wix Secrets Manager (per-site).

**Тесты:**
- Backend `pytest`: 583 проходит. Ключевые файлы — `tests/test_wix_webhook.py`, `tests/test_wix_import_task.py`, `tests/test_finalize_contact_rule.py`, `tests/test_brief_v3_api.py`, `tests/test_brief_v3_transcribe.py`.
- Frontend `vitest`: 377 проходит.

---

## Архитектурный долг

Приоритеты: **P0** — закрывать в первую очередь, болезненно при следующих изменениях. **P1** — желательно вместе с P0. **P2** — nice to have, можно отдельной серией.

### P0-1. `BriefEditorLayout` — монолит ~1100 строк, два mode в одной компоненте

**Файл:** `Frontend/src/modules/client/BriefEditor/BriefEditorLayout.tsx`.

**Проблема:**
- Один компонент обслуживает и `mode='authenticated'`, и `mode='anonymous'`. ~30 useState, ~10 useEffect, дублированные мутации (`createDraftAuth` + `createDraftPublic`, `sendChatAuth` + `sendChatPublic`, и т.д.).
- Каждый useEffect и каждая ветка условно проверяет `isAuth`. Любое изменение в логике потока (например, новое условие polling) требует править ветки в двух местах.
- Локальный state `messages` дублирует RTK Query cache (для auth) и lazy detail (для public). При polling RTK создаёт новый объект `authDetail` на каждый refetch → useEffect перевнечает `setMessages` → ререндер `BriefChatPanel` со всем списком сообщений. При длинном чате (100+ messages) это заметно.

**Решение:**
1. Разделить на два компонента: `AnonymousBriefEditor` и `AuthenticatedBriefEditor`. Каждый — со своим набором mutation/query hooks, без условных веток `isAuth`.
2. Вынести shared UI в `BriefChat` (внутренняя композиция, ChatPanel + Sidebar). Это уже отдельный компонент `BriefChatPanel`, надо просто чище передать `mode`-агностичный API.
3. Вытащить общую логику poll/hydrate в кастомный hook (см. **P0-2**).
4. Локальный state `messages` заменить на чтение из RTK Query cache (через `useGetBriefAiDetailQuery` для auth, `useGetPublicBriefDetailQuery` для public). Optimistic update для send-message — через `briefAiApi.util.updateQueryData(...)` (паттерн уже использован в `pollFinalDocuments`, см. `BriefEditorLayout.tsx:414-421`).

**Эффект:** уменьшает количество ререндеров, снимает дубли, делает добавление новой фичи (например, voice-input) в одно место, не в два.

### P0-2. Два механизма поллинга — `pollingRef` + RTK `pollingInterval`

**Где:**
- `pollFirstReply` / `pollFinalDocuments` через `setInterval` + `pollingRef` — `BriefEditorLayout.tsx:299-352, 375-449`.
- RTK `pollingInterval: isAuth && awaitingFirstReply ? 1500 : 0` — `BriefEditorLayout.tsx:218`.
- Явный `setInterval` для public-side polling — `BriefEditorLayout.tsx:295-306`.

**Проблема:**
- Три разных способа поллинга в одной компоненте. Логика «когда поллить» размазана: `pollFirstReply` запускается при `initialTaskId` (Wix-flow), RTK `pollingInterval` — при `awaitingFirstReply` computed-условии, public-setInterval — при том же условии но через явный `setInterval` (т.к. для public используем `useLazyGetPublicBriefDetailQuery`).
- `pollingRef` — singleton: если бы pollFirstReply и pollFinalDocuments сработали одновременно, второй затёр бы первый. Сейчас этого не бывает (разные stage), но хрупко.

**Решение:**
1. Кастомный hook `useBriefPolling({ briefId, taskId, isAuth, token })` с понятным контрактом:
   - принимает `taskId` (если есть — поллит конкретную задачу через status-endpoint и `AsyncResult`);
   - принимает `awaitingFirstReply` или сам его вычисляет;
   - возвращает `{ status: 'idle' | 'polling' | 'done' | 'failed' | 'timeout', stop }`;
   - внутри один setInterval, один cleanup, один таймаут (3 минуты).
2. Удалить `pollingRef` и оба `pollFirstReply` / `pollFinalDocuments` в их текущем виде. Использовать новый hook + явные state-машины.

**Зависимость:** заводится одновременно с P0-1 (после разделения на mode-компоненты hook вписывается чище).

### P0-3. Локальный `messages`-state дублирует RTK cache → ререндеры на каждый poll

**Файл:** `BriefEditorLayout.tsx:191, 240-250, 261-266`.

**Проблема:**
- `useState<ChatMessageV3[]>([])` для messages.
- `useEffect([authDetail, ...])` — при каждом RTK refetch ставит `setMessages(detail.messages)`.
- RTK refetch (через `pollingInterval=1500`) возвращает **новый объект** даже если данные идентичны. useEffect срабатывает каждые 1.5с → setMessages → React не делает deep-сравнение массивов → ререндер BriefChatPanel со всеми сообщениями.

**Решение:**
- Перевести `messages` на селектор RTK cache (`useSelector` через `useGetBriefAiDetailQuery({ selectFromResult })`) с `useMemo`-сравнением по `messages.length` + `updatedAt`. Тогда новый объект authDetail с тем же контентом не приведёт к новому референсу `messages`.
- Optimistic add user-message через `briefAiApi.util.updateQueryData`, не локальный setState.

**Зависимость:** часть P0-1 (вместе с разделением компонент).

### P0-4. Backend: `Brief.pending_task_id` — единый источник правды о том, что AI ещё работает

**Где:** `Backend/aivus_backend/aivus_backend/projects/models.py:Brief`, `projects/tasks.py`, `projects/api/serializers.py`, фронт `BriefEditorLayout`.

**Проблема:**
- Сейчас фронт «угадывает» нужно ли поллить: смотрит на `messages.last.role === 'user' && conversationStatus === 'in_progress'`. Это эвристика, иногда неточная (например, если задача упала в Celery и `conversation_status` так и остался `in_progress`).
- `task_id` нигде не сохраняется в БД (он только в Redis-результатах Celery). Если webhook вернул `taskId` через URL и юзер не успел открыть страницу за 5 минут (TTL Celery result expires) — `AsyncResult(task_id)` вернёт `PENDING`, и фронт будет поллить таску, которой уже нет.
- На `/app/brief/{id}` (authenticated) `taskId` нигде не приходит — фронт только эвристикой.

**Решение:**
1. Добавить `Brief.pending_task_id = models.CharField(max_length=64, blank=True, default="")`. Set при enqueue (`webhook`, `start`, `chat`, `finalize`), clear при success/failure внутри task'а через `transaction.atomic` (или через post-task hook).
2. `serialize_brief_v3` отдаёт `pendingTaskId`. Если непусто — фронт знает что задача активна и поллит **именно её status**, а не угадывает.
3. На фронте убрать computed `awaitingFirstReply` через эвристику. Заменить на проверку `pendingTaskId != null`. Поллить status-endpoint, не detail.
4. Это снимает архитектурную асимметрию между Wix-flow (taskId в URL) и authenticated-flow (никакого taskId).

**Эффект:** один контракт для фронта, проще на бэке (фронт не должен знать про задачи Celery, только про статус брифа), убирает 3-минутный «висит» если задача потерялась (можно показать ошибку явно).

---

### P1-1. Vendor видит чужой публичный бриф в anonymous-mode

**Файл:** `Frontend/src/app/public-brief/[briefId]/page.tsx`.

**Проблема:** залогиненный vendor открывает `/public-brief/{id}` (например, по ошибочной ссылке от клиента). Условие `group !== CLIENT` пропускает его в `BriefEditorLayout mode='anonymous'`. Vendor может слать сообщения в чужой бриф (claim не получится — бэк блокирует, но сами сообщения уйдут). Это нештатно.

**Решение:** если `session.user.group === 'VENDOR'` → `router.replace(AppRoute.VENDOR_DASHBOARD)` + toast «Brief link is for clients only». Симметрично с client-веткой.

### P1-2. Аноним без токена → пустой чат

**Где:** `BriefEditorLayout.tsx:1027` — `isHydrating = !isAuth && token && !publicHasHydrated`. Если token=null, isHydrating=false, и `BriefChatPanel` рендерится с пустым `messages=[]`.

**Решение:** добавить informative empty-state при `!isAuth && !token`. Например, «Brief link is broken or expired. Start a new brief.» + кнопка «New brief» (`/public-brief` без id → пустой start).

### P1-3. Hydrate-перерендер каждые 1.5с (RTK создаёт новый объект на refetch)

Решается в рамках **P0-3** (переход на селектор RTK cache с мемоизацией).

### P1-4. `import_wix_attachments_task` упал → frontend 3 минуты тишины

**Проблема:** если chain первой задачи (`import_wix_attachments_task`) упал (не должно происходить — taska try/except внутри, но Redis/RAM-fail возможен), `generate_first_reply_task` с предзаданным task_id не запустится. `AsyncResult(task_id)` навсегда PENDING. Фронт ждёт `POLL_TIMEOUT_MS=180000` и показывает «Generation failed».

**Решение:** убирается автоматически с **P0-4** (фронт смотрит на `Brief.pending_task_id`, после fail задача его очищает → `conversation_status` остаётся `in_progress` + `pendingTaskId=null` → фронт показывает «не удалось получить ответ» сразу, без 3 минут).

### P1-5. `logger.debug` для `ThinkingConfig` fallback

**Файл:** `Backend/aivus_backend/aivus_backend/core/llm.py:233`.

**Проблема:** если Vertex AI API когда-нибудь отзовёт `ThinkingConfig` для нашей модели — исключение проглатывается с уровнем `debug`. Pure title-bug снова замаскируется.

**Решение:** одна строка — `logger.debug` → `logger.warning`.

### P1-6. Двойная нормализация email

**Где:** `_extract_wix_payload._wix_str` уже делает `.strip()`, потом в view ещё раз `.strip().lower()[:254]`.

**Решение:** удалить лишний `.strip()` в view (косметика, безвредно сейчас).

### P1-7. Удалить `BriefV3.contactName` если не нужен

Поле `contact_name` на бэке используется только для `_build_contact_rule` (попадает в LLM-контекст). Фронт его не отрисовывает (модалку убрали). `serialize_brief_v3` отдаёт его в JSON. Если решим не возвращать на фронт — убрать из сериализатора и типа TS. Если оставить «на потом» — задокументировать что это metadata-only.

---

### P2-1. Middleware `startsWith('/public')` — будущий риск

**Файл:** `Frontend/src/middleware.ts:97`.

Сейчас условие захватывает всё `/public-...`. Если когда-то появится sensitive `/public-something-private` — он автоматически попадёт под no-auth. Лучше явный whitelist маршрутов.

### P2-2. `PageSpinner` для client без таймаута

Если `router.replace(BRIEF_CLAIM)` завис — пользователь видит спиннер бесконечно. Маловероятно. Не критично, но 10-секундный fallback c toast'ом не помешает.

### P2-3. `--aivus-header-h` undefined в public-brief layout

`OuterWrapper` ставит `height: calc(100dvh - var(--aivus-header-h))`. CSS-переменная задаётся в AppShell, которого на `/public-brief` нет. Сейчас calc даёт `100dvh - 0 = 100dvh`, работает. Но фрагильно: если кто-то задаст global default для `--aivus-header-h`, высота сломается. Решение: явно задать `--aivus-header-h: 0` на root public-brief layout.

### P2-4. Race для `BriefClaimPage` чтения токена в StrictMode/concurrent mode

Теоретический. В проде StrictMode выключен. Запомнить как known caveat, без правки.

---

## Пользовательские сценарии — regression checklist

Любой рефакторинг должен сохранить рабочие сценарии. Перечень для verification:

### Сценарий 1: аноним заполняет Wix-форму с email + сообщением
1. Wix Velo POST → `/api/v1/public/briefs/ai/from-wix` с `{email, name, message, files}`.
2. Backend: 201, `Brief` с `contact_email/name`, первый user-message, `generate_first_reply_task` enqueued через `on_commit`.
3. Wix получает `briefUrl`, `wixLocation.to(briefUrl)`.
4. Браузер на `/public-brief/{id}?token=...&taskId=...` → токен сохраняется в localStorage, query чистится.
5. Через ~12с AI-ответ виден без reload.

### Сценарий 2: аноним без email/name/файлов
1. Wix Velo с `{message: "..."}` (без других полей).
2. Backend: 201, `contact_email=''`, `contact_name=''`.
3. Чат запускается, в чате одна кнопка `Sign up` (не «Register with X»).

### Сценарий 3: аноним с PDF-файлом
1. Wix Velo: `mediaManager.getDownloadUrl()` конвертирует `wix:document://...` в публичный URL.
2. Backend: `import_wix_attachments_task` качает с whitelisted-хоста, прикрепляет к user-message.
3. AI в первом ответе ссылается на содержимое PDF.

### Сценарий 4: залогиненный client заходит на свежий briefUrl
1. `page.tsx` детектит `session.user.group === CLIENT`, `router.replace(AppRoute.BRIEF_CLAIM)`.
2. `BriefClaimPage` читает токен из localStorage, дёргает `claimPublicBrief`, чистит токен.
3. Бриф клеймится: `Brief.client = current_user`, `anonymous_token=null`.
4. Редирект на `AppRoute.BRIEF_DETAIL(briefId)` (`/app/brief/{id}`).
5. Если AI ещё не ответил — `awaitingFirstReply=true` → polling авто-подтянет ответ.

### Сценарий 5: залогиненный client без токена на голой ссылке
1. `/public-brief/{id}` без query, localStorage пуст.
2. Page детектит client + нет токена → `router.replace(BRIEF_DETAIL)`.
3. Если бриф его — отрисуется. Если чужой — 404 authenticated роута.

### Сценарий 6: аноним возвращается на старый бриф (token в localStorage, без query)
1. Initial-fetch detail подтягивает историю.
2. Если AI не успел ответить — `awaitingFirstReply` → polling завершит.
3. Если ответ был — оба сообщения видны сразу.

### Сценарий 7: чат-сообщение через UI
1. User жмёт Send → `local-{ts}` user-message добавляется оптимистично.
2. `sendChatAuth/Public` mutation — bff ждёт LLM (~10-15с), возвращает `{reply, ...}`.
3. Assistant message с real id заменяет local. Polling не сработал бы из-за `!lastMessage.id.startsWith('local-')` и `!isChatLoading`.

### Сценарий 8: финализация
1. User в чате доходит до `ready_to_finalize`.
2. Нажимает finalize → `client_brief_ai_finalize` (требует CLIENT) → `finalize_brief_task`.
3. `generate_final_documents`: системный промпт собран с `contact_rule` (имя/email из `Brief.contact_*` или `client.owner.*`).
4. Финальные документы появляются. `generate_brief_title` (gemini-2.5-flash с `thinking_budget=0`) генерит title.

### Сценарий 9: регистрация с email из формы
1. В чате две кнопки: «Register with X» и «Register with another email».
2. «Register with X» → `/auth?email=X` → ManageAuth авто-check-email → жмак в `register`/`signin` step.
3. После регистрации → `pendingBrief` cookie + confirm-email flow → `_try_claim_pending_brief` на бэке.

### Сценарий 10: vendor на анонимной ссылке
**Сейчас:** vendor видит чат в anonymous-mode (баг). 
**После P1-1:** редирект на vendor dashboard с toast'ом.

---

## Рекомендуемая последовательность работы

Не строгое требование, но логичный порядок:

1. **P0-4 (backend `Brief.pending_task_id`)** — фундамент. Меняет контракт detail-API. Без этого фронтовый рефакторинг будет содержать ту же эвристику.
2. **P0-2 (custom `useBriefPolling`)** — следующий шаг, опирается на `pendingTaskId` из detail.
3. **P0-1 + P0-3 (разделение `BriefEditorLayout` + RTK cache как источник)** — вместе. Большая правка, идёт после того как poll-логика вынесена.
4. **P1-1 (vendor)**, **P1-2 (empty state)**, **P1-5 (warning)**, **P1-6 (двойной strip)** — мелкие точечные фиксы. Можно вкатить параллельно с P0 или отдельной мини-серией.
5. **P1-7 (`contactName` cleanup)** — после того как фронтовый рефакторинг устаканится.
6. **P2-** — opportunistic, без отдельной задачи.

## Что не делать в рамках этой большой задачи (out of scope)

- Skip подтверждения email + плашка «Подтверди email» на дашборде — отдельная большая задача.
- Жёсткая проверка `contact_email == user.email` при claim — не делаем, ломает легитимные кейсы (юзер с двумя email).
- Прокидывать `contact_name` в форму регистрации (`/auth?name=...`) — UX-полировка, потом.
- Поддержка Wix Automation webhook (fire-and-forget без редиректа) — фронт-парсер уже понимает automation-payload, но динамический редирект там невозможен без Velo. Это решение бизнеса.
- Refactor `core/llm.py` (multi-provider) — не трогаем, риск ломки LLM-вызовов.

## Полезные команды для verification

```bash
# Backend
cd Backend/aivus_backend && docker compose -f docker-compose.local.yml run --rm django sh -c "ruff check . && pytest -q"
# Сейчас ожидание: 583 passed.

# Frontend
cd Frontend && npx tsc --noEmit && npx vitest run
# Сейчас ожидание: 30 files, 377 tests passed.

# Локальный smoke webhook (без email/name)
curl -X POST http://localhost:8000/api/v1/public/briefs/ai/from-wix \
  -H 'Content-Type: application/json' \
  -H 'X-Aivus-Webhook-Secret: local-dev-wix-secret' \
  -d '{"message":"60s teaser"}'
# Ожидание: 201, briefUrl ведёт на http://localhost:3000/public-brief/{id}?token=...&taskId=...

# Локальный smoke с файлом (через локальный HTTP-сервер на host.docker.internal:8765, см. WIX_EXTRA_ALLOWED_HOSTS в .envs/.local/.django)
curl -X POST http://localhost:8000/api/v1/public/briefs/ai/from-wix \
  -H 'Content-Type: application/json' \
  -H 'X-Aivus-Webhook-Secret: local-dev-wix-secret' \
  -d '{"message":"with pdf","files":[{"url":"http://host.docker.internal:8765/test.pdf","filename":"test.pdf"}]}'
```

## Ссылки на код (актуальные точки входа)

- Webhook view: `Backend/aivus_backend/aivus_backend/projects/api/views_brief_v3.py:1192` (`public_brief_ai_from_wix`).
- Claim view: `Backend/aivus_backend/aivus_backend/projects/api/views_brief_v3.py:1557` (`client_brief_ai_claim`).
- Finalize: `Backend/aivus_backend/aivus_backend/projects/ai_brief_v3.py:741` (`generate_final_documents`), системный промпт собирается через `_build_system_prompt` (строка 268).
- `_build_contact_rule`: `Backend/aivus_backend/aivus_backend/projects/ai_brief_v3.py:226`.
- Public-brief page: `Frontend/src/app/public-brief/[briefId]/page.tsx`.
- BriefEditorLayout: `Frontend/src/modules/client/BriefEditor/BriefEditorLayout.tsx`.
- BriefClaimPage: `Frontend/src/app/app/@client/brief/claim/[briefId]/page.tsx`.
- Middleware: `Frontend/src/middleware.ts:152` (proxy `/service/*` → `/api/v1/*`).
- API constants: `Frontend/src/constants/apiRoute.ts:111` (`CLIENT_BRIEF_AI_CLAIM`).

## Тестовая инфра, которой можно пользоваться

- Локальная Postman-коллекция: `/tmp/aivus-wix-webhook.postman_collection.json` (генерируется командой ниже, при необходимости пересоздать). Содержит compact-контракт, automation-payload, проверки 401/400, status-polling, detail, continue chat.
- Локальный HTTP-сервер для тестов файлов: `python3 -m http.server 8765` в директории с тестовым PDF. В env `.envs/.local/.django` должен быть `WIX_EXTRA_ALLOWED_HOSTS=host.docker.internal`.

---

## Результат рефакторинга и roadmap-швы

Закрыто в ветках `brief-refactor` (Frontend и Backend — отдельные репозитории). Backend: 593 pytest passed, ruff clean. Frontend: tsc чист, 404 vitest passed.

### Единый сигнал «AI работает» — `Brief.pending_task_id`

Поле `Brief.pending_task_id` (миграция `0035_brief_pending_task_id`) — источник правды о незавершённой Celery-задаче, переживает 24h TTL результатов.

- SET во всех точках enqueue (`client_brief_ai_start`, `public_brief_ai_start`, `client_brief_ai_finalize`, `client_brief_ai_claim` auto-finalize, `public_brief_ai_from_wix`) по единому паттерну: pre-gen `task_id = uuid4`, запись `pending_task_id` внутри `transaction.atomic`, enqueue через `transaction.on_commit(... apply_async(task_id=..., link_error=clear_brief_pending_task.si(brief_id)))`. Это попутно вылечило существующую гонку `.delay()` внутри ATOMIC_REQUESTS.
- CLEAR: на успехе — `pending_task_id=""` в терминальном `.update()` задачи; на терминальном failure (включая обрыв wix-chain) — через `link_error`-errback `clear_brief_pending_task` (закрывает P1-4); плюс в defensive early-returns `generate_first_reply_task`.
- Status-эндпоинты (`client_brief_ai_status`, `public_brief_ai_status`) переписаны: authority = `brief.pending_task_id` (пуст → `done`+detail; set+failed → `failed` **HTTP 200**; иначе `pending`). `taskId` GET-параметр опционален. `serialize_brief_v3`/`_list_item` отдают `pendingTaskId`.

### Frontend: монолит разрезан

`BriefEditorLayout` (1100 строк, два mode) удалён. Вместо него `AuthenticatedBriefEditor` и `AnonymousBriefEditor` без `isAuth`-веток. 4 call-site импортят конкретный компонент. Ключевое:
- `stage` — derived (`lib/deriveStage.ts`) от `detail + pendingTaskId`, не stored. Большинство useState схлопнуто в чтение из RTK cache.
- polling — единый hook `hooks/useBriefPolling.ts` (один interval/timeout/cleanup, идемпотентный терминальный callback). Снял три механизма polling и эвристику `awaitingFirstReply`.
- composer и finalize блокируются при `pendingTaskId` (замена снятой защиты от двойного reply).
- shared: `OuterWrapper`, `GeneratingView`, `FinalizingView`, `BriefStartScreen`, `deriveStage`, `makeLocalUserMessage`, `constants.ts`. Все доменно/source-агностичны.
- P1-1 (vendor → редирект+toast), P1-2 (empty-state `BRIEF_LINK_BROKEN` вместо пустого чата), P2-1 (middleware whitelist `/public/`+`/public-brief` вместо широкого `/public`), P2-2 (claim timeout 10s), P2-3 (`--aivus-header-h: 0` на public-brief layout — чинит живой баг с мёртвой зоной 70px).

### P1-7 — `contact_name`: used, не metadata-only

Не удалять. Читается `_build_contact_rule` (LLM-контекст при finalize) и отдаётся фронту для pre-fill email в registration-флоу.

### Roadmap-швы (заложены, фичи НЕ построены)

Под будущее: (1) мульти-доменные брифы (не только видео-продакшн); (2) вендорские брендированные public-страницы + per-vendor вебхуки/ключи в хедерах + кабинеты ключей.

- `_create_inbound_brief(*, message, contact_email, contact_name, file_specs, source, vendor=None)` вынесен из `public_brief_ai_from_wix`. Wix-view тонкий. Будущий vendor-webhook переиспользует helper. `source`/`vendor` — пока no-op.
- Нормализация контакта — `_normalize_contact_email`/`_normalize_contact_name` (переиспользуемо любым inbound-источником, убран двойной strip — P1-6).
- `_verify_wix_secret` оставлен; будущая замена — `authenticate_inbound_source(request) -> {source, vendor}` (резолв ключ→вендор).
- Frontend shared-слой и `AnonymousBriefEditor` — branding/source/domain-агностичны. Будущая vendor-брендированная страница = новый route/layout, переиспользующий `AnonymousBriefEditor`.

Отложено (не построено, аддитивно позже, не блокеры): vendor-webhook view, кабинет ключей, domain-селектор, поля `Brief.source`/`Brief.origin_vendor`, domain-роутинг AI-промптов. Для мульти-домена проверить, что `BriefFinalPackage` итерирует `documents[]` дженерик по `kind`, а не хардкодит 3 видео-специфичных kind.

### Известный мусор после рефактора

- `Frontend/src/modules/client/BriefEditor/BriefSettings.tsx` — осиротевший компонент (stage `settings` в монолите был недостижим; нового импорта нет). Оставлен нетронутым, при желании удалить отдельно.

### Известное ограничение (кандидат на следующую сессию)

- SIGKILL/OOM-kill воркера в момент выполнения таски: Celery `link_error`-errback не выполняется при жёстком убийстве процесса, поэтому `pending_task_id` останется выставленным, а `AsyncResult(pending_task_id)` вернёт PENDING (не FAILURE) → status-эндпоинт будет вечно отдавать `pending`. Пользовательский UX при этом ограничен фронтовым polling-таймаутом (180s → «generation failed»), но в БД поле залипнет для конкретного брифа (следующий detail-fetch снова поднимет polling → снова 180s). Полная страховка (не делалась, вне scope дока): добавить `Brief.pending_task_started_at` + таймаут в status-эндпоинте при unknown-стейте, либо celerybeat-чистку протухших pending. Рейт-кейс редкий.
