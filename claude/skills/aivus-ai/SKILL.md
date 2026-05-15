---
name: aivus-ai
description: "Use ALWAYS for AI/LLM work in Aivus: modifying core/llm.py, ai_brief_*.py, BriefPrompt model, prompts in DB, multimodal handling (Gemini files), LangGraph code (legacy v2), brief generation/update/finalization flow, OpenAI/Anthropic/Gemini integration, LLM trace logging. Trigger when working with /Backend/aivus_backend/projects/ai_brief*, BriefPrompt admin, or any prompt engineering. Always invoke aivus-base alongside this skill for shared context. Also invoke aivus-backend for adjacent Django code (models, views, tasks)."
---

# Aivus AI — LLM, BriefPrompt, multimodal Gemini

**Перед началом**: если в этой сессии ещё не загружен `aivus-base` — вызови его через Skill tool сейчас.

Если задача затрагивает Django-код (models, views, tasks) — вызови ещё `aivus-backend`.

## Главный контекст — миграция v2 -> v3 в процессе

**Approved 2026-04-17**, breaking change: все существующие briefs будут удалены миграцией.

Что выкидывается:
- LangGraph (router -> generate -> update -> answer -> extract граф)
- 9 hard-coded HTML секций (`BRIEF_SECTION_KEYS`)
- Модель `BriefMethodology`
- Hard-coded промпты в `ai_brief_v2.py`

Что появляется:
- Единый chat endpoint без графа
- `BriefPrompt` модель — slug-based (`main_system_prompt`, `finalization_prompt`, `master_brief_template`, `archetypes_reference`), versioned, редактируется через TinyMCE в Django admin
- `BriefAttachment` — файлы в GCS, multimodal в Gemini через `Part.from_uri()`
- `BriefFinalDocument` — 3 финальных артефакта (Production Brief, Vendor Email, Deliverables Checklist)
- Free-form text вместо HTML секций, структуру задаёт LLM, не код

**Источники истины** (читай при любой AI-задаче):
- `AI_REFACTORING_PLAN.md` — полный план миграции, 6 фаз
- `memory/project_brief_v3.md` — PO decisions (2026-04-17)
- `AI_ANALYSIS.md` — аудит v2 с 15 багами, что НЕ должны повторять в v3

## LLM клиент (`core/llm.py`)

Multi-provider обёртка над:
- OpenAI (текущий прод)
- Anthropic
- Google GenAI (целевой для v3)

Multimodal в v3 через GCS файлы:

```python
from google.genai.types import Part

attachments = [Part.from_uri(file_uri=gcs_url, mime_type="application/pdf")]
response = client.generate(model, messages, attachments=attachments)
```

Модели по умолчанию в `ai_brief_v3.py`:
- `DEFAULT_MODEL = "gemini-3.1-pro-preview"` — генерация
- `TITLE_MODEL = "gemini-2.5-flash"` — заголовки

OPENAI_API_KEY должен быть **во всех Django и Celery контейнерах** на проде (см. `HANDOFF.md`).

## Промпты — в БД, не в коде

Все промпты после v3 — через модель `BriefPrompt`:
- `slug` (например `main_system_prompt`) — стабильный ID
- `body` — TinyMCE в admin
- `version` — versioned, при изменении создаётся новая версия
- Активная версия выбирается по флагу `is_active=True`

**Если пользователь просит "подправить промпт"** — направь его в Django admin (`/admin/projects/briefprompt/`), не редактируй код.

Если правишь логику сбора системного промпта (как промпты склеиваются перед LLM вызовом) — это код, можно править. Но конкретные тексты промптов — только через admin.

## Celery для AI

Tasks в `projects/tasks.py`:
- `persist_message_traces` — асинхронное сохранение трейсов отдельных turns
- `persist_final_document_traces` — трейсы для финализации

Используются для аудита и дебага LLM-вызовов в БД. Не блокируют запрос пользователя.

## Workflow AI

- **No streaming** (PO decision) — polling и sync only
- При изменении модели по умолчанию (Gemini -> новая версия) — менять в `ai_brief_v3.py`, проверять стоимость и качество на репрезентативной выборке
- При изменении конкретного промпта — Django admin, не код
- При изменении структуры `BriefPrompt` модели — миграция Django
- Файлы (вложения к brief) — GCS через django-storages, не локальная FS

## MCP и встроенные skills для AI

- `claude-api` — для prompt caching, Anthropic SDK best practices, миграций между моделями. Вызывай при работе с Anthropic-веткой `core/llm.py` или при оптимизации стоимости и латентности

## V2 баги — НЕ повторять в v3

Из `AI_ANALYSIS.md`:

1. `_persist_traces()` копия в `projects/tasks.py:18` и `projects/api/views_brief_v2.py:54` — в v3 одна функция в одном модуле
2. `_CYRILLIC_RE` определён дважды (lines 781 и 1037) с разными паттернами — одна регулярка в utils
3. `methodology_context` пустой при первой генерации — в v3 BriefPrompt всегда подгружается до вызова
4. Expensive pro-model используется для всех turns (update, answer) — в v3 одна модель по умолчанию, выбираемая в admin
5. `document_language` не фиксируется в БД, пользователь может его перебить — в v3 фиксируется на первом turn, сохраняется в Brief.language
6. Стоимость растёт с длиной conversation (~$0.006-0.010/turn) — в будущем summary, сейчас минимум: не дублировать methodology в каждом turn

## Анти-паттерны AI

- Hard-coded промпты в коде после v3 — всё через `BriefPrompt`
- Игнорирование multimodal через GCS — для v3 это must-have
- Streaming endpoints — PO явно сказал нет
- Использование `BriefMethodology` — удалена в v3
- Hard-coded `BRIEF_SECTION_KEYS` — нет секций, free-form text
- OPENAI_API_KEY только в Django контейнере — Celery тоже его требует
- LLM-вызовы без записи trace в БД — теряется аудит
- Дублирование `_persist_traces`, `_CYRILLIC_RE` и других v2 анти-паттернов
