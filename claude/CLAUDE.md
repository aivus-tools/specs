# Project Rules

## Skills (точка входа для разработки)

Для любой работы в проекте используются project-level скиллы в `.claude/skills/`. Триггер не зависит от рабочей директории — Claude выбирает скиллы по содержанию задачи, опираясь на их `description`. Запуск из корня репозитория - норма.

- `aivus-base` — фундамент: тон, продуктовый контекст, workflow, безопасность, MCP-карта, источники истины. Триггерится на любой Aivus-задаче, в одиночку используется для cross-cutting вопросов (инфра, деплой, общие "как X работает")
- `aivus-frontend` — Next.js/React/RTK Query специфика. Триггерится когда задача касается кода во `Frontend/` (компоненты, RTK Query, slices, стили, vitest, локализация)
- `aivus-backend` — Django function-based views + Celery. Триггерится когда задача касается кода в `Backend/aivus_backend/` (views, models, миграции, Celery tasks, pytest)
- `aivus-ai` — LangGraph -> Gemini рефакторинг, BriefPrompt, multimodal. Триггерится когда задача касается LLM/AI пайплайна (`core/llm.py`, `ai_brief_*.py`, промпты, multimodal)

Специализированные скиллы автоматически подгружают `aivus-base`. Для мультидоменных задач (например "добавь поле в Brief и выведи во frontend") триггерится несколько скиллов одновременно.

Дополнительно подключены инженерные скиллы Мэтта Покока (`mattpocock/skills`): `grill-me`, `grill-with-docs` (сверка плана с доменом, CONTEXT.md, ADR), `zoom-out` (контекст незнакомого кода), `to-prd`, `to-issues` (PRD и нарезка на вертикальные слайсы). Setup-конфиг — `setup-matt-pocock-skills`.

## Agent skills

### Issue tracker

Задачи ведутся в ClickUp, workspace VILKA, только через обёртку `scripts/clickup`. Три рабочих листа: Conceptualization (проработка/PRD), Development (реализация), Bug Tracking (баги). Полный флоу — `Specs/DEV_PROCESS.md`. Конфиг — `docs/agents/issue-tracker.md`.

### Triage labels

Лейблов нет — triage кодируется статусами листа (разные у Dev plan и Bug Tracking). См. `docs/agents/triage-labels.md`.

### Domain docs

Single-context. Источники истины — `Specs/PRODUCT_VISION.md`, `Specs/DEV_PROCESS.md` и `Specs/*`. См. `docs/agents/domain.md`.

## Bash Safety

Bash-команды разрешены без подтверждений, но строго в рамках проекта:
- все файловые операции только внутри `/Users/ipolotsky/Develop/Aivus/`;
- не трогать системные файлы, домашнюю директорию и другие проекты;
- не запускать `rm -rf` на директории выше корня проекта;
- не пушить в git без явной просьбы;
- Docker-команды разрешены, т.к. backend работает только в Docker.

## Ruff

Команды для запуска линтера и форматера:
- `ruff check .` - проверка кода на ошибки;
- `ruff check --fix .` - проверка с автофиксом исправимых ошибок;
- `ruff format .` - форматирование кода.

Запускать из директории `Backend/aivus_backend`.
