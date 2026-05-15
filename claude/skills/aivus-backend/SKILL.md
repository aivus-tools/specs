---
name: aivus-backend
description: "Use ALWAYS for backend work in Aivus: writing Django views/models/migrations, Celery tasks, API endpoints, serialization, pytest tests, ruff linting, Docker compose changes. Trigger for any work in /Backend/aivus_backend/ directory. Always invoke aivus-base alongside this skill for shared context. If task touches LLM/AI pipeline, also invoke aivus-ai. If task changes API contract used by frontend, also invoke aivus-frontend."
---

# Aivus Backend — Django 5.2, function-based views, Celery в Docker

**Перед началом**: если в этой сессии ещё не загружен `aivus-base` — вызови его через Skill tool сейчас. Базовые правила живут там.

## Стек

- Django 5.2 + PostgreSQL + Redis + Celery
- Работает **только в Docker**, mount source как volume -> hot reload
- HMAC auth middleware проксирует `/service/*` -> `/api/v1/*`
- Тесты: pytest

## Структура

Apps в `Backend/aivus_backend/`:
- `users` — пользователи и аутентификация
- `projects` — проекты, briefs, offers, AI brief логика
- `vendors` — vendor-side данные
- `catalog` — категории, units, rates
- `core` — общие модули, `llm.py` (multi-provider AI клиент)
- `contrib/sites` — Django sites

Структура каждого app:

```
<app>/
├── models.py
├── api/
│   ├── views.py
│   ├── serializers.py    функции serialize_*, не DRF
│   └── urls.py
├── migrations/
├── tasks.py              Celery
└── tests/
```

## API views — function-based, НЕ DRF viewsets

Это **не DRF**. Используй function-based views с декораторами:

```python
import json

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods
from django_ratelimit.decorators import ratelimit

from core.auth import require_groups


@csrf_exempt
@require_http_methods(["POST"])
@require_groups(["vendor"])
@ratelimit(key="user", rate="10/m")
def create_project(request):
    user_data = request.user_data
    payload = json.loads(request.body)
    project = Project.objects.create(
        title=payload["title"],
        vendor_id=user_data["vendor_id"],
    )
    return JsonResponse(serialize_project(project), status=201)
```

Декораторы (внешний -> внутренний):
- `@csrf_exempt` — для API endpoints, CSRF не используется
- `@require_http_methods(["GET" | "POST" | ...])`
- `@require_groups(["vendor" | "client"])` — авторизация по группам
- `@ratelimit(...)` — django-ratelimit
- `@public_endpoint` — если auth не нужен (публичные share-ссылки)

Аутентификация: `request.user_data` — кастомное поле от HMAC middleware. Не используй DRF `request.user` патчинг.

## Сериализация — функции, НЕ DRF serializers

```python
def serialize_project(project: Project) -> dict:
    return {
        "id": str(project.id),
        "title": project.title,
        "vendor_id": str(project.vendor_id),
        "details": project.details,
        "created_at": project.created_at.isoformat(),
    }
```

- Файлы в `<app>/api/serializers.py`
- Принимают модель, возвращают `dict`
- Никаких DRF `Serializer` или `ModelSerializer`

## Модели

```python
import uuid

from django.db import models


class Project(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=255)
    details = models.JSONField(default=dict)
    deleted_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
```

- UUID primary key обязателен
- Soft delete через `deleted_at`, фильтруй в queryset
- JSONField для гибких полей (`details`)

## Celery tasks

```python
from celery import shared_task
from django.db import transaction


@shared_task
def persist_message_traces(brief_id, traces):
    with transaction.atomic():
        ...
```

- Файлы `<app>/tasks.py`
- `@shared_task` декоратор
- `with transaction.atomic()` где нужна целостность

## Workflow

**Backend ВСЕГДА в Docker.** Не запускать `python manage.py` напрямую.

Команды через Makefile из корня проекта:
- `make backend` — поднять backend контейнер
- `make backend-shell` — shell внутри контейнера
- `make backend-test` — pytest в контейнере
- `make backend-migrate` — миграции
- `make backend-lint` — ruff

Ruff (из `Backend/aivus_backend/`):
- `ruff check .` — проверка
- `ruff check --fix .` — автофикс
- `ruff format .` — форматирование

Pre-commit hooks: ruff, mypy, djLint, trailing whitespace.

## Тесты

Pytest, папка `tests/` в каждом app:

```
projects/tests/
├── test_api_briefs.py
├── test_models.py
└── conftest.py
```

Запуск: `make backend-test` внутри контейнера.

## URL роутинг

- Точка входа `config/urls.py`
- API endpoints: `api/v1/auth/`, `api/v1/users/`, `api/v1/projects/`, и т.д.
- HMAC middleware проксирует `/service/*` -> `/api/v1/*`

## Анти-паттерны backend

- DRF `ViewSet`, `APIView`, `Serializer`, `ModelSerializer` — не наш паттерн
- `python manage.py` вне Docker
- View без `@require_groups` или `@public_endpoint` — нет явной авторизации
- View без `@require_http_methods` — открыт для любого метода
- Игнорирование ruff и mypy ошибок
- `IntegerField` или `AutoField` как primary key вместо UUID
- Hard-delete вместо `deleted_at`
