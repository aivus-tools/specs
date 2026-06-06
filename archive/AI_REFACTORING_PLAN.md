# AI Brief System - Refactoring Plan (v2 → v3)

## Context

Заказчик провёл эксперименты с Gemini-ботом, построенным по продуманному flow, и получил результаты с wow-эффектом. Наша текущая реализация (ai_brief_v2) генерирует полный бриф из 9 жёстких HTML-секций за один вызов, что ощущается как механическая форма, а не беседа с продюсером.

Задача - переделать AI-флоу так, чтобы:
1. Первым ответом AI давал короткое человеческое приветствие + один вопрос (не полный бриф).
2. Бриф формировался постепенно в ходе диалога, как это делал бы живой продюсер.
3. В финале пользователь получал 3 документа: Production Brief, Vendor Outreach Email, Deliverables Checklist.
4. Основной промпт заказчика хранился в БД и редактировался через админку.
5. Пользователь мог прикреплять файлы (PDF, изображения) к первому сообщению - они передаются в LLM как multimodal вход.
6. Master Brief Template использовался как внутренний reference, а не жёсткая структура.

Подтверждённые решения (PO, 2026-04-17):
- Существующие briefs удаляем (breaking change).
- Файлы храним в Google Cloud Storage (django-storages уже в зависимостях).
- Стриминг не делаем, остаётся polling/sync как сейчас.
- Связь Brief→Offer (structured_data) отложена, решаем позже.

---

## 1. Принципы новой архитектуры

1. **Один unified chat-endpoint вместо router/generate/update/answer.** Новый флоу - это ровно одна LLM-беседа с одним системным промптом. LangGraph убираем.
2. **Промпт - это данные, не код.** Системный промпт, правила локализации, market context хранятся в БД и редактируются в админке. Версионируются.
3. **Бриф - это свободный текст, который LLM пишет/переписывает каждый ход.** Нет фиксированных 9 секций на уровне бэкенда. Структура возникает из промпта и Master Brief Template, переданных LLM.
4. **Финализация - отдельный шаг**, который генерирует 3 документа одним LLM-вызовом. Не пробрасываем structured_data как side-goal каждого хода.
5. **Multimodal с первого сообщения.** Файлы загружаются на GCS, регистрируются в БД, передаются в Gemini через `Part.from_uri` или `Part.from_bytes`.
6. **Polling остаётся**, но только для тяжёлых операций (первая генерация, финализация). Chat-turns синхронные.

---

## 2. Что удаляем

### Код
- `Backend/aivus_backend/aivus_backend/projects/ai_brief.py` - V1 целиком. Если `analyze_comparison`/`analyze_brief` где-то используются, мигрируем в `ai_brief_comparison.py` (comparison остаётся feature, не трогаем).
- `Backend/aivus_backend/aivus_backend/projects/ai_brief_v2.py` - целиком, заменяем новым модулем `ai_brief_v3.py`.
- Константа `BRIEF_SECTION_KEYS` и связанная логика (sections_status, sections_changed, section_patches) - уходит вместе с v2.
- `strip_wrong_language_patches`, `filter_scope_photo`, `_build_language_reminder` - постпроцессинг под HTML-секции больше не нужен.
- Жёстко закодированные промпты `GENERATE_SYSTEM_PROMPT`, `UPDATE_SYSTEM_PROMPT`, `ANSWER_SYSTEM_PROMPT`, `ROUTER_SYSTEM_PROMPT`, `EXTRACT_SYSTEM_PROMPT`, `SECTION_TEMPLATE` - удаляются.
- `BriefMethodology` модель - удаляется, её заменяют `BriefPrompt` и `BriefPromptBlock` (см. §4).

### Данные
- `Brief`, `ChatMessage`, `LLMCallTrace`, `BriefFeedback`, `BriefMethodology`, `BriefShare` - **все записи удаляются миграцией** (breaking change). Модели остаются, но структура `Brief` сильно меняется - проще всего написать миграцию, которая `DELETE FROM brief` + `ALTER TABLE`. Это ок для MVP, пользовательских данных в продакшене с этим флоу почти нет.
- Поля `document_sections`, `structured_data`, `archetypes`, `sections_status`, `questions_asked`, `conversation_phase` - удаляются с `Brief`.

### Frontend
- `BriefEditor.tsx` как primary канвас - остаётся только в режиме read-only preview на финальном экране. В процессе чата никакого TipTap-редактора не видно.
- Подхода с `documentHtml` в запросе `/chat` больше нет.
- Optimistic locking по version и `PATCH /section` - уходит, потому что нет inline-редактирования секций.

---

## 3. Что сохраняем

- `ChatMessage` (с лёгкими правками полей).
- `LLMCallTrace` - для аудита и отображения в админке/LLMTraceDrawer. Не трогаем.
- `BriefFeedback` - за одним изменением: привязка к message, не к section_key (он уходит).
- `core/llm.py` - расширяем multimodal-поддержкой, не переписываем.
- HMAC middleware, Celery, retry/fallback цепочки моделей.
- Frontend: `BriefChatPanel` (возможно с правками под аттачменты), `BriefReadOnlyView`, `BriefToolbar`, `LLMTraceDrawer`, `FileUpload`-примитивы по образу `ProfileForm` и `projectsApi.uploadThumbnail` в [Backend/aivus_backend/aivus_backend/projects/api/views.py](Backend/aivus_backend/aivus_backend/projects/api/views.py#L438-L474).

---

## 4. Новая модель данных

### 4.1 `Brief` (переписываем)

Критические файлы: [Backend/aivus_backend/aivus_backend/projects/models.py](Backend/aivus_backend/aivus_backend/projects/models.py#L42).

```
Brief
├── id: UUID (pk)
├── client: FK(Client)
├── status: enum {DRAFT, COMPLETED}
├── title: str                          # человеко-читаемое имя (вычисляется из брифа)
├── document_language: str (2 chars)    # FROZEN после первого хода (#4 из старого анализа)
├── conversation_status: enum {IN_PROGRESS, READY_TO_FINALIZE, FINALIZED}
├── anonymous_token: str (nullable)
├── claimed_at, created_at, updated_at, deleted_at
│
├── total_input_tokens, total_output_tokens, total_cost_usd
└── message_count
```

Убираем всё связанное с HTML-секциями и архетипами. Архетип определяется LLM внутренне, нам хранить его не нужно - для отладки достаточно сохранить его в метаданных ChatMessage при первом ходе.

### 4.2 `BriefPrompt` (новое)

Основной системный промпт, редактируемый в админке. Версионируется.

```
BriefPrompt
├── id: UUID
├── slug: str unique                    # "main_system_prompt", "finalization_prompt"
├── title: str
├── body: TextField                     # большой текст, редактируется через TinyMCE
├── version: int                        # автоинкремент при каждом сохранении
├── is_active: bool                     # может быть активна только одна версия на slug
├── created_at, updated_at, created_by (FK User)
```

Slug'и в MVP:
- `main_system_prompt` - мастер-промпт заказчика, применяется к каждому chat-turn'у.
- `finalization_prompt` - промпт для генерации 3 финальных документов.
- `master_brief_template` - содержимое MASTER BRIEF TEMPLATE, инжектится как контекст в main_system_prompt.
- `archetypes_reference` - описание 6 архетипов из PDF "Логика работы ИИ для Брифа", инжектится в main_system_prompt.

### 4.3 `BriefAttachment` (новое)

```
BriefAttachment
├── id: UUID
├── brief: FK(Brief, related_name="attachments")
├── message: FK(ChatMessage, nullable)  # к какому сообщению прикреплён
├── file: FileField(storage=GCS)        # в GCS
├── filename: str
├── mime_type: str
├── size_bytes: int
├── gemini_file_uri: str (nullable)     # URI после upload в Gemini Files API (если используем)
├── created_at
```

### 4.4 `ChatMessage` (правки)

Удаляем: `sections_changed`, `section_key` (в feedback, см. ниже).
Оставляем: всё остальное.
Добавляем: `attachments: M2M(BriefAttachment)` или используем `BriefAttachment.message` FK.

### 4.5 `BriefFinalDocument` (новое)

Три документа, сгенерированные при финализации.

```
BriefFinalDocument
├── id: UUID
├── brief: FK(Brief, related_name="final_documents")
├── kind: enum {PRODUCTION_BRIEF, VENDOR_EMAIL, DELIVERABLES_CHECKLIST}
├── html: TextField                     # готовый HTML, copy-paste в Word
├── plain_text: TextField                # для Email - текстовая версия
├── trace: FK(LLMCallTrace, nullable)
├── created_at
├── unique(brief, kind)
```

### 4.6 `BriefFeedback` (правки)

- Убрать `section_key`.
- `message` FK остаётся обязательным.
- Добавить `kind` enum (THUMBS_UP / THUMBS_DOWN), `comment` остаётся.

---

## 5. Бэкенд: новый AI-флоу

### 5.1 Модуль `projects/ai_brief_v3.py`

Никакого LangGraph. Один класс/набор функций:

```python
def process_brief_turn(
    brief: Brief,
    user_message: str,
    attachments: list[BriefAttachment],
    history: list[ChatMessage],
) -> ChatTurnResult:
    """
    Один chat-turn.
    1. Резолвит/замораживает document_language.
    2. Собирает system prompt из BriefPrompt.active(slug='main_system_prompt')
       + подставляет master_brief_template + archetypes_reference.
    3. Строит messages[] из всей истории + текущее сообщение.
    4. Для первого хода добавляет attachments как multimodal Parts.
    5. Один вызов call_llm с моделью из settings.
    6. Возвращает (reply, tokens, cost, trace).
    """

def generate_final_documents(brief: Brief) -> list[BriefFinalDocument]:
    """
    Один LLM-вызов с finalization_prompt + вся история чата.
    Ожидает JSON вида:
      { "production_brief_html": "...", "vendor_email_html": "...",
        "vendor_email_text": "...", "deliverables_checklist_html": "..." }
    Создаёт 3 BriefFinalDocument, помечает brief.status=COMPLETED.
    """
```

### 5.2 Модель

Одна модель на все chat-turns. По умолчанию `gemini-3.1-pro-preview` - заказчик делал свои эксперименты в Gemini, этот промпт на ней работает. Модель прописываем в `BriefPrompt.metadata` (JSONField) или в settings, а не хардкодом - чтобы заказчик мог менять из админки.

### 5.3 Промпт-сборка

```
system:
  {main_system_prompt.body}

  === MASTER BRIEF TEMPLATE (reference) ===
  {master_brief_template.body}

  === ARCHETYPES REFERENCE (internal) ===
  {archetypes_reference.body}

  === LANGUAGE & MARKET ===
  Document language: {brief.document_language}
  Market conventions: {ru: рубли/РФ | en: USD/US}

user: [первое сообщение + attachments]
assistant: [ответ AI 1]
user: [ответ клиента 1]
...
```

`document_language` замораживается на первом ходе по regex-детекту (как уже есть в `_detect_language_from_text` - перенести в новый модуль) и сохраняется в `Brief.document_language`. Это закрывает баг #4 из старого анализа.

### 5.4 Multimodal в `core/llm.py`

Надо расширить `_call_gemini()` чтобы `messages` могли содержать не только `{"role","content":str}`, но и `{"role","parts":[{"type":"text",...},{"type":"file_uri",...}]}`. Маппить на `google.genai.types.Part`:

- text → `Part.from_text(text=...)`
- file_uri → `Part.from_uri(file_uri=uri, mime_type=...)` (для файлов, уже загруженных в GCS, ссылка вида `gs://bucket/path` работает напрямую, Vertex читает их сам)
- inline_bytes → `Part.from_bytes(data=..., mime_type=...)` (для маленьких картинок; не использовать для PDF)

Обновить сигнатуру `call_llm`, `call_llm_json` и везде, где они используются - переход обратно совместимый, если `content: str` обработать как один text-part.

### 5.5 API endpoints (v3)

Все под префиксом `/api/v1/client/briefs/ai/` (оставляем тот же префикс, т.к. старые ломаем).

| Метод | Путь | Назначение |
|-------|------|-----------|
| `POST` | `/start` | Создаёт Brief, принимает первое сообщение + attachment ids. Дёргает Celery `generate_first_reply_task`. Возвращает `{briefId, taskId}`. |
| `GET` | `/{id}/status` | Polling первого ответа (как сейчас). |
| `POST` | `/{id}/chat` | Синхронный chat-turn. Принимает `{message, attachmentIds?}`. Возвращает `{reply, messageId, readyToFinalize, tokens, cost}`. |
| `GET` | `/{id}` | Детали брифа + все сообщения + прикреплённые файлы. |
| `POST` | `/{id}/attachments` | Multipart-upload файла. Возвращает `{attachmentId, url, mimeType, size}`. |
| `DELETE` | `/{id}/attachments/{attachmentId}` | Удалить аттачмент (до первого ответа AI). |
| `POST` | `/{id}/finalize` | Дёргает Celery `finalize_brief_task`. Возвращает `{taskId}`. |
| `GET` | `/{id}/final-documents` | Возвращает 3 сгенерированных документа. |
| `GET` | `/{id}/messages/{messageId}/trace` | LLM trace (как сейчас, для staff). |
| `POST` | `/{id}/feedback` | Feedback на сообщение (без section_key). |

Публичные зеркала (`/public/briefs/ai/*`) - как сейчас, с теми же ограничениями. Дубликат логики вынести в helpers, чтобы не копировать два раза (это частично закроет баг #3).

### 5.6 Валидация файлов

Принимаем в `POST /attachments`:
- MIME types: `application/pdf`, `image/jpeg`, `image/png`, `image/webp`, `image/gif`, `text/plain`.
- Лимит на файл: 10 MB.
- Лимит на бриф: 10 файлов.
- Валидация: проверка MIME по `python-magic` (а не на Content-Type), проверка расширения.
- Sanitize имени файла, rename в GCS в `briefs/{brief_id}/{uuid}.{ext}`.

Загружаем сразу в GCS через django-storages. Параллельно (или лениво при первом LLM-вызове) оформляем файл в Gemini Files API, если это нужно - для прод-ready сразу лучше использовать GCS URI и не дублировать (Vertex читает gs:// напрямую).

### 5.7 Celery tasks

- `generate_first_reply_task(brief_id)` - вызывает `process_brief_turn` для первого хода (там может быть несколько MB attachments). Остаётся асинхронным из-за потенциально больших файлов.
- `finalize_brief_task(brief_id)` - вызывает `generate_final_documents`.
- Остальные chat-turns - синхронные в request-handler, как сейчас.

### 5.8 История чата

Полная история без обрезки до 20 (баг #10). Если разговор растёт > 100 ходов - суммаризация отдельной задачей, не в MVP. Для бага #11 - история всегда целиком идёт в промпт, т.к. нода answer уходит, и один и тот же путь обрабатывает всё.

### 5.9 Фиксы остальных багов из старого анализа

- #1 (дублирование переменных в GENERATE_SYSTEM_PROMPT) - неактуально, промпт переписывается.
- #2 (дубль `_CYRILLIC_RE`) - оставить один regex в utils модуле.
- #3 (`_persist_traces` дублирован) - вынести в `core/llm.py` или `projects/utils.py`.
- #5 (methodology_context пуст при генерации) - неактуально, нет methodology_context.
- #6 (дорогая модель на update) - одна модель для всех ходов, заказчик выбирает через админку.
- #7 (questions_asked с section keys) - неактуально, questions_asked уходит, контекст - вся история.
- #8 (граф singleton без thread safety) - неактуально, графа нет.
- #9 (нет стриминга) - подтверждено оставить polling/sync.
- #11 (answer без истории) - одна нода, всегда с историей.
- #12 (documentHtml перезапись с фронта) - неактуально, frontend не шлёт HTML.
- #13 (V1 analyze_comparison) - вынести в отдельный модуль `ai_brief_comparison.py` до начала работы, ничего не ломать.
- #14 (2 LLM-вызова на turn) - неактуально, один вызов.
- #15 (рост стоимости) - остаётся, но частично смягчается: нет дублирования промпта, нет методологии и фидбека на каждый ход. Если будет остро - добавим суммаризацию.

---

## 6. Админка

Критические файлы: [Backend/aivus_backend/aivus_backend/projects/admin.py](Backend/aivus_backend/aivus_backend/projects/admin.py#L476).

### 6.1 `BriefPromptAdmin`

- TinyMCE для `body` (пример в `OfferAdminForm`, [admin.py:183-191](Backend/aivus_backend/aivus_backend/projects/admin.py#L183)).
- `list_display = [slug, title, version, is_active, updated_at]`.
- `list_filter = [is_active, slug]`.
- `search_fields = [slug, title, body]`.
- Save-hook: при `is_active=True` выключает старые активные версии с тем же slug и создаёт новую запись с `version += 1` (иначе версионирование не работает).
- Forbid edit `body` у неактивных версий (read-only), чтобы не терять историю.

### 6.2 `BriefAttachmentAdmin`, `BriefFinalDocumentAdmin`

Read-only: файл-прев, имя, размер, связанный бриф/сообщение. Для дебага.

### 6.3 `BriefMethodologyAdmin` - убрать вместе с моделью.

### 6.4 Сидинг промптов

Data-migration, которая создаёт 4 начальные версии `BriefPrompt`:
- `main_system_prompt`: текст заказчика целиком (из сообщения в треде).
- `master_brief_template`: текст из MASTER BRIEF TEMPLATE.pdf.
- `archetypes_reference`: текст из "Логика работы ИИ для Брифа.pdf", раздел с 6 архетипами.
- `finalization_prompt`: новый промпт, который даёт LLM указание на JSON-выход с 3 документами (составим в рамках задачи, опираясь на раздел "Closing & Handover" из PDF).

---

## 7. Фронтенд

### 7.1 Start screen

Файл: [Frontend/src/modules/client/BriefEditorV2/BriefEditorLayout.tsx](Frontend/src/modules/client/BriefEditorV2/BriefEditorLayout.tsx).

- Таx: "Опишите свой проект" + drag-and-drop зона для файлов.
- Валидация на фронте (MIME, размер) + показ списка прикреплённых файлов с возможностью удалить.
- На submit: сначала upload файлов в `/attachments` (получаем ids), потом `POST /start` с `message` и `attachmentIds`.

Новый компонент `FileUploadZone.tsx` в `BriefEditorV2/components/` - простой dropzone через native drag-and-drop events. Библиотеку не добавляем.

### 7.2 Chat screen (в процессе разговора)

Текущий side-by-side Editor+Chat **заменяем** на просто Chat на всю ширину. Никакого TipTap по середине - пользователь видит только переписку. На правой половине экрана можно добавить "эскиз брифа" - но это отложенная feature, в MVP просто chat.

`BriefChatPanel` остаётся, но без передачи `documentHtml` и без progress-bar по секциям. Прогресс через `readyToFinalize: bool` в ответе сервера - когда true, появляется кнопка "Finalize Brief".

Вложения в ходе разговора (в последующих сообщениях) - поддерживаем, но вторично. В MVP UX: кнопка "прикрепить" в input, UX тот же что на start-screen.

### 7.3 Финальный экран

После клика "Finalize" → Celery → polling статуса → получаем 3 документа. Открывается модалка/экран с Antd Tabs (как в `LLMTraceDrawer`):
- Tab 1: Production Brief (HTML preview + Copy + Download PDF).
- Tab 2: Vendor Outreach Email (HTML preview + Copy as HTML + Copy as text).
- Tab 3: Deliverables Checklist (HTML preview + Copy + Download PDF).

Новый компонент `BriefFinalPackage.tsx`. PDF-рендер переиспользуем из уже существующего `ApiRoute.BRIEF_AI_PDF`, но endpoint модифицируем - он рендерит не всё, а конкретный `final_document` по id.

### 7.4 RTK Query

Файл: [Frontend/src/services/client/briefAiApi.ts](Frontend/src/services/client/briefAiApi.ts).

Добавить/переделать endpoints: `startBriefAi`, `sendBriefAiChat` (без `documentHtml`), `uploadAttachment`, `deleteAttachment`, `finalizeBriefAi`, `getFinalDocuments`. Удалить `updateBriefAiSection`.

### 7.5 Типы

Файл: [Frontend/src/types/briefV2.interface.ts](Frontend/src/types/briefV2.interface.ts) переименовать в `briefAi.interface.ts` (v2/v3 различие скрываем). Убрать `SectionStatus`, `ConversationPhase`, добавить `Attachment`, `FinalDocument`, `ChatMessage` упростить (без `sectionsChanged`).

---

## 8. Конфигурация GCS

1. Добавить в `config/settings/base.py`:
   ```python
   DEFAULT_FILE_STORAGE = "storages.backends.gcloud.GoogleCloudStorage"
   GS_BUCKET_NAME = env("GS_BUCKET_NAME")
   GS_CREDENTIALS = service_account.Credentials.from_service_account_file(...)
   GS_DEFAULT_ACL = "private"
   GS_QUERYSTRING_AUTH = True
   GS_EXPIRATION = timedelta(minutes=15)
   ```
2. Для dev - оставить file-system storage, настраивать через env `DJANGO_STORAGE_BACKEND`.
3. Доступ к файлам - через signed URLs (не публично).
4. Vertex AI может читать `gs://bucket/path` напрямую при вызове - проверить при интеграции, что credentials Vertex имеют доступ к этому bucket.

---

## 9. Порядок работ (фазы)

### Phase 0. Фундамент
1. Data-миграция: удалить все старые briefs / chat_messages / attachments / methodology / feedback.
2. Удалить миграцией поля из `Brief`, удалить модель `BriefMethodology`.
3. Создать новые модели: `BriefPrompt`, `BriefAttachment`, `BriefFinalDocument`. Обновить `Brief`, `ChatMessage`, `BriefFeedback`.
4. Data-миграция с сид-промптами (4 штуки).
5. Конфигурация GCS (staging bucket).

### Phase 1. Бэкенд - chat
1. Модуль `projects/ai_brief_v3.py` с `process_brief_turn`.
2. Расширить `core/llm.py` multimodal-поддержкой.
3. API: `/start`, `/status`, `/chat`, `/`, `/attachments` (POST/DELETE).
4. Celery task `generate_first_reply_task`.
5. Serializers, publics-зеркало, rate limits.
6. Удалить старые `ai_brief.py`, `ai_brief_v2.py` (вместе с их views).

### Phase 2. Бэкенд - финализация
1. `generate_final_documents` в `ai_brief_v3.py`.
2. API: `/finalize`, `/final-documents`.
3. PDF-endpoint под конкретный `final_document`.
4. Celery task `finalize_brief_task`.

### Phase 3. Админка
1. `BriefPromptAdmin` с TinyMCE и версионированием.
2. Read-only админки для `BriefAttachment`, `BriefFinalDocument`.
3. Убрать `BriefMethodologyAdmin`.

### Phase 4. Фронтенд - chat
1. `FileUploadZone`, обновлённый start screen.
2. `BriefChatPanel` - убрать secton-badges, progress-bar, documentHtml.
3. `BriefEditorLayout` - упростить до chat-only (в процессе разговора).
4. Обновить RTK Query и типы.

### Phase 5. Фронтенд - финализация
1. `BriefFinalPackage` с Antd Tabs.
2. Preview/Copy/Download для каждого документа.
3. Удалить TipTap-канвас из core-flow (оставить только для preview).

### Phase 6. Полировка
1. Удалить устаревшие эндпоинты и типы.
2. Переименовать `briefV2.interface.ts` → `briefAi.interface.ts`.
3. Прогнать e2e тесты (актуализировать тесты в `Frontend/e2e/` под новый флоу).

---

## 10. Критические файлы, которые надо править

Бэкенд:
- [Backend/aivus_backend/aivus_backend/projects/models.py](Backend/aivus_backend/aivus_backend/projects/models.py) - модели.
- [Backend/aivus_backend/aivus_backend/projects/ai_brief_v2.py](Backend/aivus_backend/aivus_backend/projects/ai_brief_v2.py) → удалить, создать `ai_brief_v3.py`.
- [Backend/aivus_backend/aivus_backend/projects/ai_brief.py](Backend/aivus_backend/aivus_backend/projects/ai_brief.py) → перенести `analyze_comparison` в отдельный модуль, файл удалить.
- [Backend/aivus_backend/aivus_backend/core/llm.py](Backend/aivus_backend/aivus_backend/core/llm.py) - multimodal.
- [Backend/aivus_backend/aivus_backend/projects/api/views_brief_v2.py](Backend/aivus_backend/aivus_backend/projects/api/views_brief_v2.py) → заменить на `views_brief_v3.py`.
- [Backend/aivus_backend/aivus_backend/projects/api/urls.py](Backend/aivus_backend/aivus_backend/projects/api/urls.py) - маршруты.
- [Backend/aivus_backend/aivus_backend/projects/tasks.py](Backend/aivus_backend/aivus_backend/projects/tasks.py).
- [Backend/aivus_backend/aivus_backend/projects/admin.py](Backend/aivus_backend/aivus_backend/projects/admin.py).
- [Backend/aivus_backend/config/settings/base.py](Backend/aivus_backend/config/settings/base.py) - GCS.

Фронтенд:
- [Frontend/src/modules/client/BriefEditorV2/BriefEditorLayout.tsx](Frontend/src/modules/client/BriefEditorV2/BriefEditorLayout.tsx).
- [Frontend/src/modules/client/BriefChatV2/BriefChatPanel.tsx](Frontend/src/modules/client/BriefChatV2/BriefChatPanel.tsx).
- [Frontend/src/services/client/briefAiApi.ts](Frontend/src/services/client/briefAiApi.ts).
- [Frontend/src/types/briefV2.interface.ts](Frontend/src/types/briefV2.interface.ts).
- [Frontend/src/constants/apiRoute.ts](Frontend/src/constants/apiRoute.ts).
- Новые: `BriefEditorV2/components/FileUploadZone.tsx`, `BriefEditorV2/BriefFinalPackage.tsx`, `BriefEditorV2/components/DocumentPreview.tsx`.

---

## 11. Verification

End-to-end:
1. `make up` → поднять backend + celery + redis.
2. `make e2e-ui` → прогнать Playwright-тесты (переписать под новый флоу).
3. Вручную:
   - Открыть `/public-brief/new` (или как называется новый роут).
   - Ввести "Нужен ролик для фитнес-клуба, 2 минуты" + прикрепить PDF.
   - Убедиться, что AI отвечает коротким приветствием + одним вопросом (не простыней).
   - Провести 3-5 ходов, убедиться, что вопросы осмысленные, без повторов.
   - Нажать Finalize, дождаться, открыть все 3 документа.
   - Прогнать Copy и Download PDF для каждого.
4. Админка:
   - Зайти в админку, открыть `BriefPrompt`, изменить `main_system_prompt.body`, сохранить.
   - Создать новый бриф, убедиться, что применился новый промпт (проверить через LLMCallTrace).
5. Multi-language:
   - Старт с сообщения на английском - проверить язык документа.
   - Переключиться на русский в середине - убедиться, что бриф остаётся английским, ответ - на русском.
6. Edge cases:
   - Загрузить .exe - должен быть отклонён.
   - Загрузить 11 файлов - 11-й должен быть отклонён.
   - Файл 15 MB - отклонён.

Ручной чек production-ready:
- Счётчик cost в LLMCallTrace совпадает с биллингом Vertex за период.
- GCS bucket не публичный, доступ только через signed URLs.
- Нет утечек в логах (HMAC-ключ, user content в error trace).

---

## 12. Открытые вопросы (не блокируют MVP)

- **Brief → Offer (structured_data).** Отложено. Если будет нужно для vendor-flow, добавим отдельный extract-шаг, который парсит финальный Production Brief HTML в JSON.
- **Суммаризация длинных диалогов.** Добавим, если рост стоимости будет виден на реальных пользователях.
- **Стриминг.** Отложено. Можно добавить SSE позже, если user-feedback потребует.
- **Comparison feature (analyze_comparison).** Сейчас жив в `ai_brief.py`. При удалении этого файла переносим в `ai_brief_comparison.py` без изменений поведения.
- **Anonymous users + файлы.** Пока позволяем, но добавим rate limit на `/attachments` (3/hour) и лимит 3 файла на анонимный бриф.
