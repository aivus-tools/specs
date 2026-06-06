# E2E brief flows (live-LLM)

Сквозные E2E-сценарии Brief AI v3, которые гоняют реальный пайплайн (Gemini через Vertex). Медленные (1-5 минут на сценарий) и стоят денег, поэтому вынесены в отдельный opt-in Playwright project `brief-flows` и не входят ни в дефолтный `test:e2e`, ни в прод-смоук.

Код: `Frontend/e2e/brief-flows/`, хелперы `Frontend/e2e/helpers/`. Backend test-only эндпоинт: `Backend/aivus_backend/aivus_backend/users/api/auth_views.py` (`e2e_confirmation_token`).

## Сценарии

1. `anon-create.spec.ts` - публичный бриф: стартовый экран, прикрепление файла, проверка кнопки записи голоса (работает, форму не сабмитит), переход в чат, два хода диалога, призыв к регистрации.
2. `anon-register.spec.ts` - продолжение: регистрация по призыву, подтверждение почты, сборка финального пакета, кабинет с документами, имя и почта в тексте брифа.
3. `logged-in.spec.ts` - залогиненный клиент: `/public-brief` редиректит на `/app/brief/create`, тот же флоу без призыва к регистрации, авто-финализация.
4. `wix-webhook.spec.ts` - входящий Wix webhook отдаёт URL брифа, два кейса: открытие анонимом и claim залогиненным клиентом.

## Предусловия

Всё локально, бэкенд в Docker:

```bash
make dev   # поднимает backend (docker) + dev server на :3000
```

Нужны:
- backend-контейнеры подняты (`aivus_backend_local_*`), включая `aivus_backend_local_mailpit` (HTTP API на :8025);
- `RESEND_API_KEY` пустой - тогда письма уходят в Mailpit, откуда тест достаёт ссылку подтверждения;
- Vertex/Gemini настроен (бриф реально генерируется);
- клиентский аккаунт для логина: по умолчанию `a@a.aa` / `iiiijjjj` (CREDENTIALS, group CLIENT).

## Локальный запуск

```bash
make e2e-flows                 # все сценарии последовательно (workers=1)
```

Один сценарий:

```bash
cd Frontend && npx playwright test brief-flows/wix-webhook.spec.ts --project=brief-flows
```

Через Claude Code: команда `/e2e-flows` (опционально с аргументом - имя сценария, `endpoint` или `all`).

## Источник токена подтверждения

Тест регистрации достаёт ссылку `/auth/confirm-email?token=...` через абстракцию `Frontend/e2e/helpers/tokenSource.ts`, режим выбирается `E2E_TOKEN_SOURCE`:

- `mailpit` (по умолчанию) - читает Mailpit API, для локали и staging-с-Mailpit;
- `endpoint` - читает hard-gated backend-эндпоинт, для staging с реальным Resend без Mailpit.

### Прогон в режиме endpoint локально

1. Включить эндпоинт в `Backend/aivus_backend/.envs/.local/.django`:
   ```
   E2E_CONFIRMATION_TOKEN_ENABLED=True
   E2E_CONFIRMATION_TOKEN_SECRET=local-e2e-token-secret
   ```
2. Пересоздать контейнер (env_file читается при создании, не при рестарте):
   ```bash
   cd Backend/aivus_backend && docker compose -f docker-compose.local.yml up -d django
   ```
3. Запустить:
   ```bash
   E2E_CONFIRMATION_TOKEN_SECRET=local-e2e-token-secret make e2e-flows-endpoint
   ```
4. После проверки вернуть эндпоинт в выключенное состояние (убрать строки и пересоздать контейнер).

## Переменные окружения

| Переменная | По умолчанию | Назначение |
|---|---|---|
| `MAILPIT_URL` | `http://localhost:8025` | Mailpit API для режима mailpit |
| `BACKEND_URL` | `http://localhost:8000` | Wix webhook и confirmation-token эндпоинт |
| `WIX_WEBHOOK_SECRET` | `local-dev-wix-secret` | заголовок `X-Aivus-Webhook-Secret` |
| `E2E_CLIENT_EMAIL` / `E2E_CLIENT_PASSWORD` | `a@a.aa` / `iiiijjjj` | логин клиента для logged-in и claim |
| `SMOKE_TEST_URL` | `http://localhost:3000` | baseURL фронта (для staging) |
| `E2E_TOKEN_SOURCE` | `mailpit` | `mailpit` или `endpoint` |
| `E2E_CONFIRMATION_TOKEN_SECRET` | пусто | секрет для режима endpoint (см. `ENV_VARIABLES.md`) |

Backend-флаги `E2E_CONFIRMATION_TOKEN_ENABLED` и `E2E_CONFIRMATION_TOKEN_SECRET` описаны в `Specs/ENV_VARIABLES.md`. Эндпоинт выключен по умолчанию и НИКОГДА не включается в проде.

## CI/CD

Workflow `Frontend/.github/workflows/e2e-flows.yml`, только `workflow_dispatch` (плюс закомментированный ночной `schedule`). Авто-триггера нет, чтобы не жечь Gemini и не мусорить данными.

В прод-смоук это не встраивается осознанно: прогон против прода означал бы реальные брифы в прод-БД, реальные письма и включённый токен-эндпоинт в проде. Прод-смоук остаётся лёгким (`smoke` project, рендер страниц).

Целевая форма пайплайна при появлении staging:

```
build -> deploy-staging -> e2e-flows (staging) -> deploy-prod -> smoke (prod, лёгкий)
```

На staging confirm-флоу работает либо через Mailpit (пустой `RESEND_API_KEY`), либо через `E2E_TOKEN_SOURCE=endpoint` с включённым на staging эндпоинтом - тогда раннеру достаточно HTTPS и заголовка с секретом, Mailpit наружу светить не нужно.

Секреты для workflow: `STAGING_URL`, `STAGING_BACKEND_URL`, `STAGING_WIX_SECRET`, `STAGING_CLIENT_EMAIL`, `STAGING_CLIENT_PASSWORD`, `STAGING_E2E_TOKEN_SECRET`.

Backend-pytest (`users/tests/test_e2e_confirmation_token.py`) едет в backend-CI автоматически через `uv run pytest`, отдельной настройки не требует.

## Траблшутинг

- Зависает на `Reading your brief...` - проверить celery worker и Vertex-креды; невалидное вложение (мелкая или битая картинка) Gemini отвергает, в тестах вложение это текстовый файл.
- `Project "brief-flows" not found` - запускать из `Frontend/` локальным бинарём (`./node_modules/.bin/playwright`) или через `npm run`/`make`, не через свежий `npx`.
- Письмо не приходит в Mailpit - проверить, что `RESEND_API_KEY` пустой и контейнер `aivus_backend_local_mailpit` healthy.
- В режиме endpoint 404 - эндпоинт выключен (`E2E_CONFIRMATION_TOKEN_ENABLED`), 403 - не совпал секрет.
