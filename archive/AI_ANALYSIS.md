# AI Brief System - Full Architecture Analysis

## Context

Полный аудит AI-подсистемы проекта Aivus перед рефакторингом. Задача: разобраться, как устроены все AI-процессы создания брифа, где находятся промпты, как проходит data flow, и зафиксировать проблемы.

---

## 1. Инвентарь файлов

| Файл | Строк | Назначение | Статус |
|------|-------|------------|--------|
| `projects/ai_brief_v2.py` | 1528 | Основной AI-движок (LangGraph) | **Активен** |
| `projects/ai_brief.py` | 537 | Legacy AI-движок | **Частично активен** (analyze_comparison используется) |
| `core/llm.py` | ~370 | LLM-абстракция (multi-provider) | **Активен** |
| `core/sanitize.py` | ~60 | HTML-санитизация (nh3) | **Активен** |
| `projects/api/views_brief_v2.py` | ~996 | REST-эндпоинты V2 | **Активен** |
| `projects/tasks.py` | 150 | Celery-задачи | **Активен** |
| `projects/models.py` | ~848 | Django-модели | **Активен** |

---

## 2. LLM-инфраструктура (`core/llm.py`)

### Провайдеры и модели

| Модель | Провайдер | Input $/1M | Output $/1M | Где используется |
|--------|-----------|-----------|-------------|------------------|
| `gemini-3.1-flash-lite-preview` | Vertex AI | $0.10 | $0.40 | Router (V2) |
| `gemini-3.1-pro-preview` | Vertex AI | $1.25 | $10.00 | Generate + Update (V2), Comparison (V1) |
| `gemini-2.5-flash` | Vertex AI | $0.30 | $2.50 | Chat/Answer/Extract (V2), Chat+Analysis (V1) |
| `claude-sonnet-4-5` | Anthropic | $3.00 | $15.00 | Только как fallback, реально не вызывается |
| `gpt-4o` / `gpt-4o-mini` | OpenAI | $2.50/$0.15 | $10.00/$0.60 | Только как fallback |

### Fallback-цепочки
```
claude-sonnet-4-5 -> gemini-3.1-pro -> gemini-2.5-pro -> gemini-2.5-flash -> gemini-2.5-flash-lite
gemini-3.1-flash-lite -> gemini-2.5-flash-lite
gpt-4o -> gpt-4o-mini
```

### Механика вызовов
- `call_llm()` / `call_llm_json()` - основные функции
- 3 ретрая с экспоненциальным backoff (1s base), потом fallback на следующую модель
- Таймаут: 120s
- `call_llm_json()`: запрашивает json_mode у провайдера, если парсинг падает, пытается вытянуть JSON из markdown-блока
- `LLMResponse` dataclass: content, input_tokens, output_tokens, cost_usd, model_used, latency_ms, request_messages, request_params

---

## 3. LangGraph-архитектура V2 (`ai_brief_v2.py`)

### State

`BriefGraphState` (TypedDict) - 20+ полей. Не персистится в LangGraph, полностью пересобирается из БД на каждый вызов.

Ключевые поля:
- `messages` - история (reducer: append)
- `document_sections` - HTML секций
- `sections_status` - "empty"/"draft"/"complete" для каждой секции
- `archetypes` - список кодов архетипов (1-6)
- `conversation_phase` - "initial"/"questioning"/"refining"/"complete"
- `questions_asked` - треккинг (на деле хранит section keys, не вопросы)
- `document_language` - язык документа
- `traces` - аудит LLM-вызовов (reducer: append)
- Метрики: turn_input_tokens, turn_output_tokens, turn_cost_usd, model_used

### Граф

```
route --> generate (если phase="initial")
      --> update  (если intent="section_answer")
      --> answer  (если intent="question_or_chat")
                          |
                          v
                       persist (no-op) --> END
```

### Ноды

**1. route_message()**
- Если `conversation_phase == "initial"`: сразу возвращает "first_generation" БЕЗ LLM-вызова
- Иначе: вызывает `MODEL_ROUTER` (flash-lite, temp=0.0, max_tokens=200)
- Классифицирует: "first_generation" / "section_answer" / "question_or_chat"
- При ошибке: fallback на "section_answer"

**2. generate_full_brief()**
- Модель: `MODEL_GENERATION` (gemini-3.1-pro, temp=0.7, max_tokens=6000)
- Создает полный бриф из первого сообщения пользователя
- Выход: все 9 секций (HTML), archetypes, sections_status, reply, structured_data
- Post-processing: sanitize HTML, strip wrong language patches, filter scope_photo
- Обработка off-topic: если секции пустые и phase="initial", возвращает пустой бриф + вежливый отказ

**3. update_and_respond()**
- Модель: `MODEL_GENERATION` (gemini-3.1-pro, temp=0.7, max_tokens=3000)
- Отправляет ВСЕ непустые секции + полную историю сообщений
- Возвращает section_patches (только изменившиеся секции)
- Мержит патчи в существующие секции
- Post-processing: sanitize, language guard, scope_photo filter
- Проверяет blocking fields -> может выставить phase="complete"

**4. answer_or_chat()**
- Модель: `MODEL_CHAT` (gemini-2.5-flash, temp=0.7, max_tokens=500)
- Отправляет ТОЛЬКО текущее сообщение пользователя (без истории)
- Отвечает на сторонний вопрос и возвращает к брифу
- Не меняет секции

**5. extract_structured()**
- Модель: `MODEL_CHAT` (gemini-2.5-flash, temp=0.0, max_tokens=1000)
- Вызывается только при finalize (не через граф, напрямую)
- Извлекает structured_data из HTML-секций

**6. persist()** - no-op

---

## 4. Промпты V2 - полный каталог

### GENERATE_SYSTEM_PROMPT (строки 128-462, ~334 строк)
**Назначение:** Первый ход - генерация полного брифа из начального описания проекта
**Модель:** gemini-3.1-pro-preview
**Динамические переменные:** `{language_rule}`, `{market_rule}`, `{methodology_context}`, `{feedback_context}` (все 4 ПРОДУБЛИРОВАНЫ, см. баг #1)
**Содержит:**
- ROLE: experienced agency producer, warm & human
- GOAL: industry-grade brief для vendor estimation
- VOICE & TONE: natural conversational, filler words (ru/en), no corporate fluff
- CLIENT EXPERTISE AWARENESS: adapt to client's level
- SUGGEST & EDIT: core mechanic - generate hypotheses, present as "sounds about right?"
- BUNDLING: multi-archetype projects, shared questions once
- OPENING REPLY FORMAT: greeting + restatement + time estimate + topic bullets + first question
- QUESTION RULES: one per turn, explain WHY, provide 2-4 options
- BUDGET THRESHOLD METHOD: "which number feels unacceptable?"
- LOCALIZATION: RU/US market specifics, currencies, vendors
- OFF-TOPIC GUARD: email capture for non-video requests
- SECTION_TEMPLATE: 9 sections schema (appended)
- ARCHETYPE CLASSIFICATION: 6 archетипов с маркерами
- ADAPTIVE BLOCKING-FIELDS LOGIC: project-specific, not fixed checklist
- SCOPE_PHOTO RULE: only for archetypes 5/6
- CLOSING FLOW: auto-complete if all blocking fields filled
- Hard cap: max 3 questions total across conversation
**JSON output:** `{sections, sections_status, archetypes, reply, structured_data}`

### UPDATE_SYSTEM_PROMPT (строки 464-649, ~185 строк)
**Назначение:** Последующие ходы - обновление брифа по ответам пользователя
**Модель:** gemini-3.1-pro-preview
**Динамические переменные:** `{language_rule}`, `{market_rule}`, `{methodology_context}`, `{feedback_context}`, `{current_sections_html}`, `{sections_status_json}`, `{questions_asked}`
**Дополнительно:** language reminder как второе system-сообщение; полная история как messages
**Ключевые отличия от GENERATE:**
- Возвращает только section_patches (не все секции)
- CRITICAL: при патче секции - включать ВСЕ существующие поля, не дропать
- Handling "I don't know" / skip: fill with industry defaults, mark "draft"
- BUDGET-SCOPE CALIBRATION: explain realism at given budget
- Та же CLOSING FLOW и blocking fields logic
**JSON output:** `{section_patches, sections_status, reply, conversation_phase, structured_data_updates}`

### ANSWER_SYSTEM_PROMPT (строки 651-701, ~50 строк)
**Назначение:** Off-topic вопросы и сторонние комментарии
**Модель:** gemini-2.5-flash
**Динамические переменные:** `{conversation_phase}`, `{incomplete_sections}`, `{language_rule}`, `{market_rule}`
**Суть:** ответить кратко (2-4 предложения), предложить 2-4 варианта для следующего вопроса, плавно вернуть к брифу
**JSON output:** `{reply}`

### ROUTER_SYSTEM_PROMPT (строки 703-731, ~28 строк)
**Назначение:** Классификация интента пользователя
**Модель:** gemini-3.1-flash-lite-preview
**Динамические переменные:** `{conversation_phase}`, `{last_assistant_message}`
**3 интента:**
- "first_generation" (только если phase="initial")
- "section_answer" (ответ на вопрос, обновление брифа)
- "question_or_chat" (сторонний вопрос/чат)
**Bias:** при сомнении -> "section_answer"; "не знаю"/"пропустить" -> "section_answer"
**JSON output:** `{intent, affected_sections}`

### EXTRACT_SYSTEM_PROMPT (строки 733-759, ~26 строк)
**Назначение:** Извлечение structured data из HTML при финализации
**Модель:** gemini-2.5-flash
**Динамические переменные:** нет
**JSON output:** flat key-value (projectName, budget, territory, etc.)

### Shared prompt components

- **SECTION_TEMPLATE** (строки 79-126): схема 9 секций с полями, аппендится к GENERATE и UPDATE
- **_build_language_rule()**: правило "два языка" - язык документа заморожен, язык ответа следует за пользователем
- **_build_language_reminder()**: дополнительное напоминание как второе system-сообщение
- **_build_market_rule()**: контекст рынка (RU=рубли/RF, EN=USD/US)
- **_build_methodology_context()**: загружает BriefMethodology из БД по архетипам и секциям
- **_build_feedback_context()**: последние 15 негативных отзывов как "KNOWN ISSUES TO AVOID"

---

## 5. Промпты V1 (legacy, `ai_brief.py`)

| Промпт | Строки | Назначение |
|--------|--------|------------|
| `SYSTEM_PROMPT` | 74-161 | Базовый чат, 2-3 вопроса за раз, извлечение полей |
| `ANALYSIS_SYSTEM_PROMPT` | 163-174 | Анализ брифа + предложения по улучшению |
| `COMPARISON_SYSTEM_PROMPT` | 176-205 | Сравнение офферов вендоров (стоимостной анализ) |

---

## 6. Data flow

### 6.1 Создание брифа (Start)

```
POST /briefs/ai/start {message}
  -> Create Brief (DRAFT) + ChatMessage (user)
  -> Resolve document_language
  -> Celery: generate_brief_task.delay()
  -> Return {briefId, taskId}

Celery worker:
  -> process_brief_message(phase="initial")
  -> Graph: route (shortcut, no LLM) -> generate (pro model) -> persist
  -> Save: Brief fields + ChatMessage (assistant) + LLMCallTrace
  -> Return serialized Brief

Frontend polls GET /status?taskId=... every 1500ms (max 120s)
```

### 6.2 Чат (Chat turn)

```
POST /briefs/ai/{id}/chat {message, documentHtml?}
  -> Load Brief + chat history
  -> Create ChatMessage (user)
  -> Parse documentHtml from frontend OR use brief.document_sections
  -> СИНХРОННО: process_brief_message(full state)
  -> Graph: route (flash-lite) -> update (pro) OR answer (flash)
  -> Save: Brief update + ChatMessage (assistant) + LLMCallTrace
  -> Return {reply, documentHtml, sectionPatches, sectionsChanged, ...}
```

### 6.3 Финализация

```
POST /briefs/ai/{id}/finalize
  -> Celery: finalize_brief_task.delay()
  -> Set status=COMPLETED
  -> extract_structured() (flash, temp=0)
  -> Save structured_data, phase="complete"
  -> On failure: rollback to DRAFT
```

---

## 7. Django-модели (AI-related)

- **Brief**: document_sections (JSON/HTML), structured_data (JSON), sections_status, archetypes, conversation_phase, questions_asked, version, token/cost tracking, anonymous_token
- **ChatMessage**: brief FK, role, content, token/cost per message, model_used, sections_changed
- **LLMCallTrace**: message FK, purpose, model, request_messages, request_params, response_raw, tokens, cost, latency_ms, sequence
- **BriefMethodology**: archetype_code, section_key, title, content, priority, is_active
- **BriefFeedback**: brief FK, message FK, section_key, rating (up/down), comment

---

## 8. Архетипы и секции

### 6 архетипов
1. Creative Development & Concepting
2. High-End / Premium Production
3. Content Production / Social Media
4. Post-Production & VFX
5. Photography & Design
6. Key Visual / Design Campaign

### 9 секций брифа
1. `project_header` - Title, Client, Brand, Agency, Contact, NDA
2. `budget_timeline` - Budget, Comfort Zone, Vendor Visibility, Dates, Payment Terms
3. `strategic_foundation` - Objective, Target Audience, Insight, SMP, Tone
4. `creative_direction` - Visual Style, References, Color, Typography, Music
5. `scope_video` - Format, Duration, Deliverables, Talent, Locations, Crew
6. `scope_photo` - Subject/Style, Usage, Resolution, Quantity, KV Scope (ТОЛЬКО для архетипов 5/6)
7. `post_production` - Task Type, Source, VFX, Color Grading, Sound
8. `usage_rights` - Media Types, Territories, Term, Talent Usage, Music
9. `deliverables` - Asset List, Durations, Aspect Ratios, Tech Specs, Source Files

---

## 9. Найденные проблемы

### Баги

**#1. Дублирование переменных в GENERATE_SYSTEM_PROMPT (строки 260-276)**
`{language_rule}`, `{market_rule}`, `{methodology_context}`, `{feedback_context}` рендерятся дважды. LLM видит одни и те же инструкции два раза - тратит токены впустую, может путать модель.

**#2. `_CYRILLIC_RE` определен дважды с разными паттернами (строки 781 и 1037)**
Второе определение перезаписывает первое на уровне модуля. Разные regex-паттерны для разных целей, но итоговый результат одинаковый для обоих мест использования. Потенциальный источник subtle-багов.

**#3. `_persist_traces` скопирован в два файла**
Идентичная функция в `tasks.py:18` и `views_brief_v2.py:54`. Фикс в одном месте не применяется к другому.

### Архитектурные проблемы

**#4. `document_language` не сохраняется в БД**
Язык документа вычисляется заново на каждый вызов. Для анонимных пользователей, если `documentLanguage` не передан в запросе, fallback на regex-детекцию текущего сообщения. Пользователь, переключивший язык, может случайно "перевернуть" язык контекста.

**#5. `methodology_context` всегда пуст при первой генерации**
В `generate_full_brief()` строка 1096: `methodology = ""`. Архетипы еще не известны, поэтому methodology не загружается. Самый критичный ход (первая генерация) не использует admin-managed инструкции.

**#6. Update использует дорогую pro-модель**
`update_and_respond()` использует `MODEL_GENERATION` (gemini-3.1-pro) - ту же модель, что и для генерации. С учетом полной истории + все секции HTML, input tokens растут. Дешевая модель могла бы справиться с инкрементальными патчами.

**#7. `questions_asked` трекает section keys вместо реальных вопросов**
Строка 1282: `new_questions_asked.extend(changed_keys)`. Модель видит "Already asked about: project_header, budget_timeline", но это не вопросы, а измененные секции. Модель может избегать важных вопросов по секциям, которые уже были изменены.

**#8. Граф-синглтон без thread safety (V2)**
Строки 1406-1413: нет lock при инициализации графа. V1 имеет proper double-checked locking. Для V2 - race condition при параллельных запросах. На практике не критично (граф stateless), но некорректно.

**#9. Нет стриминга**
Chat turns блокируют web worker до полного ответа LLM. Для gemini-3.1-pro с max_tokens=6000 латенция может быть 5-15 секунд.

**#10. История обрезается до 20 сообщений без суммаризации**
Строка 1433: `history[-20:]`. Ранние решения теряются. Нет компрессии/суммаризации.

**#11. answer_or_chat не видит историю**
Нода answer отправляет только system prompt + текущее сообщение. Модель не может сослаться на предыдущее обсуждение при ответе на сторонний вопрос.

**#12. Frontend может перезаписать серверные секции через documentHtml**
Сервер доверяет HTML от клиента. Нет стратегии merge, нет защиты от race condition (AI-ответ в полете + пользователь редактирует).

**#13. V1 все еще используется**
`analyze_brief()` и `analyze_comparison()` из `ai_brief.py` используются в `views.py`. При удалении V1 надо мигрировать эти функции.

### Стоимость

**#14. Каждый chat turn = 2 LLM-вызова для section_answer**
Router (flash-lite, ~200 tokens) + Update (pro, ~3000 tokens). Router дешевый, но update на pro-модели дорогой.

**#15. Рост стоимости с разговором**
Update prompt включает полную историю + все секции. К 5-6 ходу input может дорасти до 5000-8000 tokens ($0.006-0.010/turn input + $0.010-0.030 output на pro-модели).

---

## 10. Ключевые архитектурные решения

1. **LangGraph как оркестратор** - по факту glorified if/else. Нет checkpointing, persistence, tool use, parallel branches. State пересобирается из БД.

2. **HTML-секции как формат документа** - LLM генерирует raw HTML, frontend рендерит через TipTap. Плюс: rich formatting. Минус: хрупко, LLM может сгенерировать невалидный HTML.

3. **Монолитные промпты** - GENERATE 334 строки, все в одном месте. Сложно тестировать, A/B-тестить, эволюционировать отдельные аспекты.

4. **Нет стриминга** - полный JSON-ответ за один раз. Проще парсить, но плохой UX по латенции.

5. **Optimistic concurrency** (version field) - защищает ручные правки, но нет merge-стратегии для конфликтов AI/user.

6. **Дуальный API** (auth + anonymous) - логика продублирована, разные лимиты (50/20 сообщений, разные rate limits).

7. **Celery только для start и finalize** - chat turns синхронные, блокируют web worker.
