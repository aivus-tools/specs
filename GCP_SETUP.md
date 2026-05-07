# GCP Setup Guide for Aivus

## 🔐 Настройка GCP Service Account

### 1. Создание Service Account

```bash
# Войти в GCP
gcloud auth login

# Установить проект
gcloud config set project pioneering-flag-476313-u2

# Создать Service Account
gcloud iam service-accounts create github-actions \
    --display-name="GitHub Actions CI/CD" \
    --description="Service account for GitHub Actions to push Docker images"

# Получить email Service Account
SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:GitHub Actions CI/CD" \
    --format='value(email)')

echo "Service Account Email: $SA_EMAIL"
```

### 2. Назначение прав

```bash
# Права для Artifact Registry (push images)
gcloud projects add-iam-policy-binding pioneering-flag-476313-u2 \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/artifactregistry.writer"

# Права для Storage (если нужно для кеша)
gcloud projects add-iam-policy-binding pioneering-flag-476313-u2 \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.admin"
```

### 3. Создание ключа

```bash
# Создать JSON ключ
gcloud iam service-accounts keys create ~/gcp-key.json \
    --iam-account=$SA_EMAIL

# Показать содержимое (для копирования в GitHub Secrets)
cat ~/gcp-key.json
```

**⚠️ ВАЖНО:** Скопируй содержимое файла, оно понадобится для GitHub Secrets!

---

## 🔑 Настройка GitHub Secrets

### Frontend Repository

Перейди в: `https://github.com/your-org/aivus-frontend/settings/secrets/actions`

Добавь секрет:
- **Name:** `GCP_SA_KEY`
- **Value:** Содержимое файла `gcp-key.json` (весь JSON)

### Backend Repository

Перейди в: `https://github.com/your-org/aivus-backend/settings/secrets/actions`

Добавь секрет:
- **Name:** `GCP_SA_KEY`
- **Value:** Содержимое файла `gcp-key.json` (весь JSON)

---

## 🗂️ Проверка Artifact Registry

```bash
# Проверить, что репозиторий существует
gcloud artifacts repositories describe aivus \
    --location=us-central1

# Если репозиторий не существует, создать:
gcloud artifacts repositories create aivus \
    --repository-format=docker \
    --location=us-central1 \
    --description="Aivus Docker images"
```

---

## 🧪 Тестирование локально

### Frontend

```bash
cd Frontend

# Аутентификация в GCP
gcloud auth configure-docker us-central1-docker.pkg.dev

# Сборка образа
docker build -t us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus/frontend:test .

# Push образа
docker push us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus/frontend:test

# Проверка
gcloud artifacts docker images list us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus
```

### Backend

```bash
cd Backend

# Аутентификация в GCP
gcloud auth configure-docker us-central1-docker.pkg.dev

# Сборка образа
docker build -f aivus_backend/compose/production/django/Dockerfile \
    -t us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus/backend:test \
    aivus_backend

# Push образа
docker push us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus/backend:test

# Проверка
gcloud artifacts docker images list us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus
```

---

## 🚀 Как работают GitHub Actions

### Триггеры

GitHub Actions запускаются при:

1. **Push в main/develop:**
   ```bash
   git push origin main
   # → Создаст образы с тегами: main, main-abc123f, latest
   ```

2. **Push тега:**
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   # → Создаст образы с тегами: v1.0.0, 1.0, latest
   ```

3. **Pull Request:**
   ```bash
   # Создаст образ с тегом: pr-123
   ```

4. **Ручной запуск:**
   - Перейди в Actions → Build and Push → Run workflow

### Теги образов

После успешной сборки получишь образы с тегами:

**Для main ветки:**
- `latest` - последняя версия
- `main` - последний коммит в main
- `main-abc123f` - конкретный коммит

**Для develop ветки:**
- `develop` - последний коммит в develop
- `develop-def456a` - конкретный коммит

**Для тега v1.0.0:**
- `v1.0.0` - полная версия
- `1.0` - мажор.минор
- `latest` - последняя версия

---

## 📊 Мониторинг

### Просмотр образов в GCP

```bash
# Список всех образов
gcloud artifacts docker images list \
    us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus

# Список тегов конкретного образа
gcloud artifacts docker images list \
    us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus/frontend \
    --include-tags

# Детали образа
gcloud artifacts docker images describe \
    us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus/frontend:latest
```

### Просмотр в Web UI

Перейди в: https://console.cloud.google.com/artifacts/docker/pioneering-flag-476313-u2/us-central1/aivus

---

## 🧹 Очистка старых образов

```bash
# Удалить образы старше 30 дней
gcloud artifacts docker images list \
    us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus/frontend \
    --filter="CREATE_TIME<$(date -d '30 days ago' --iso-8601)" \
    --format="get(version)" | \
    xargs -I {} gcloud artifacts docker images delete \
    us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus/frontend@{} \
    --quiet
```

Или настрой автоматическую очистку в GCP Console:
1. Перейди в Artifact Registry
2. Выбери репозиторий `aivus`
3. Settings → Cleanup policies
4. Создай политику (например, хранить последние 10 образов)

---

## 🔍 Troubleshooting

### Ошибка: "Permission denied"

```bash
# Проверь права Service Account
gcloud projects get-iam-policy pioneering-flag-476313-u2 \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:$SA_EMAIL"

# Должны быть роли:
# - roles/artifactregistry.writer
```

### Ошибка: "Repository not found"

```bash
# Создай репозиторий
gcloud artifacts repositories create aivus \
    --repository-format=docker \
    --location=us-central1
```

### Ошибка: "Authentication failed"

```bash
# Проверь, что GCP_SA_KEY в GitHub Secrets содержит валидный JSON
# Пересоздай ключ:
gcloud iam service-accounts keys create ~/gcp-key-new.json \
    --iam-account=$SA_EMAIL
```

---

## 💰 Стоимость

**Artifact Registry:**
- Хранение: $0.10 за GB в месяц
- Трафик: бесплатно внутри региона

**Примерная стоимость:**
- Frontend образ: ~500MB
- Backend образ: ~1GB
- 10 версий каждого: ~15GB
- **Итого:** ~$1.50/месяц

**Рекомендация:** Настрой автоочистку старых образов!

---

## ✅ Checklist

- [ ] Service Account создан
- [ ] Права назначены
- [ ] JSON ключ создан
- [ ] `GCP_SA_KEY` добавлен в GitHub Secrets (Frontend)
- [ ] `GCP_SA_KEY` добавлен в GitHub Secrets (Backend)
- [ ] Artifact Registry репозиторий существует
- [ ] Локальный тест прошел успешно
- [ ] GitHub Actions запущены и работают
- [ ] Образы видны в GCP Console
- [ ] Runtime APIs включены в проекте (см. ниже)
- [ ] Runtime сервис-аккаунту назначены роли для Vertex / Speech / GCS

---

## 🛠️ Runtime: APIs и роли для бэкенда

Эти настройки нужны **runtime сервис-аккаунту** (тот, что подключается к Django через `VERTEX_CREDENTIALS_PATH` / `GOOGLE_APPLICATION_CREDENTIALS`). Текущий аккаунт: `sa-for-vertex-ai@pioneering-flag-476313-u2.iam.gserviceaccount.com`.

При перестройке проекта с нуля (новый GCP-проект, миграция, DR) каждый шаг ниже обязателен — без него соответствующая фича упадёт с `403 SERVICE_DISABLED` или `403 IAM_PERMISSION_DENIED`.

### Включить APIs

```bash
PROJECT=pioneering-flag-476313-u2

gcloud services enable aiplatform.googleapis.com --project=$PROJECT      # Vertex AI / Gemini (Brief AI v3)
gcloud services enable speech.googleapis.com --project=$PROJECT          # Speech-to-Text (голосовой ввод в чате брифа)
gcloud services enable storage.googleapis.com --project=$PROJECT         # GCS (хранение аттачментов и финальных доков)
gcloud services enable iamcredentials.googleapis.com --project=$PROJECT  # для signed URLs если используются
```

После `enable` ждать ~1-2 минуты пока пропагация дойдёт до бэкенда.

### Назначить роли runtime сервис-аккаунту

```bash
SA=sa-for-vertex-ai@$PROJECT.iam.gserviceaccount.com

# Vertex AI / Gemini — для Brief AI v3 чата
gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA" --role="roles/aiplatform.user"

# Speech-to-Text — для голосового ввода (Chirp 3)
gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA" --role="roles/speech.client"

# GCS — для аттачментов брифов и финальных документов
gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA" --role="roles/storage.objectAdmin"
```

`roles/speech.client` (Cloud Speech User) даёт `speech.recognizers.recognize` — без него `client.recognize()` в [aivus_backend/projects/stt.py](../Backend/aivus_backend/aivus_backend/projects/stt.py) вернёт 403 и фронт получит 500 на `/transcribe`.

### Speech-to-Text: location, recognizer и модель

- **По умолчанию**: synthetic recognizer `_` + локация `global` (endpoint `speech.googleapis.com`) + модель `short`. Это работает из коробки, отдельный recognizer создавать не надо. Модель `short` хорошо подходит к нашему лимиту `MAX_AUDIO_DURATION_SEC=60` ([Backend/aivus_backend/aivus_backend/projects/stt.py](../Backend/aivus_backend/aivus_backend/projects/stt.py)) — дешевле и быстрее, чем `long`/`chirp_2`.
- **Какие модели валидны в `global`**: `short`, `long`, `telephony`. Семейства `chirp` и `chirp_2`/`chirp_3` в `global` **не существуют**, попытка их использовать вернёт `400 The model "<name>" does not exist in the location named "global"`. `chirp_2` работает в региональном `global`-эндпоинте через synthetic `_` recognizer только если явно указать локацию `global` и модель `chirp_2` — но тогда теряется поддержка некоторых фич; в проде у нас выбран `short`.
- **Chirp 3** (новее, точнее): доступна **только** в региональных локациях `us-central1` / `europe-west4`. В `global` её нет. Synthetic `_` recognizer в этих регионах часто отдаёт `404` — для использования Chirp 3 нужно создать explicit recognizer:
  ```bash
  gcloud speech recognizers create aivus-chirp3 \
    --location=us-central1 \
    --model=chirp_3 \
    --language-codes=en-US,ru-RU \
    --project=pioneering-flag-476313-u2
  ```
  И в env: `GOOGLE_CLOUD_SPEECH_LOCATION=us-central1`, `STT_RECOGNIZER=aivus-chirp3`, `STT_MODEL=chirp_3`. Это TODO — текущий код использует `_` recognizer.
- **Переопределение модели**: `STT_MODEL=short` (default) или другая (`long`, `latest_long`, `latest_short`, `chirp_2` для региональных локаций). `short` оптимально для аудио ≤60 сек.

### Smoke-тест что всё работает

```bash
# В контейнере django
docker exec aivus_backend_local_django python manage.py shell -c "
from aivus_backend.projects import stt
import os; os.environ['STT_DEV_FAKE'] = '0'
print(stt._get_speech_client())
"
```

Ошибки которые могут вылезти при пропуске шагов:
- `PermissionDenied: 403 ... API has not been used in project ... or it is disabled` — забыл `gcloud services enable speech.googleapis.com`.
- `PermissionDenied: 403 Permission 'speech.recognizers.recognize' denied on resource` — забыл `roles/speech.client` для SA.
- `MethodNotImplemented: 501 Received http2 header with status: 404` — `_` recognizer недоступен в выбранной локации; вернись на `global`.
- `InvalidArgument: 400 The model "chirp" does not exist in the location named "global"` — попытка использовать `chirp` (или `chirp_2`/`chirp_3`) в `global`. В `global` валидны только `short`/`long`/`telephony`. Поставь `STT_MODEL=short` (или `long`) либо переключись на региональный `GOOGLE_CLOUD_SPEECH_LOCATION=us-central1` с подходящей моделью.

---

## 📞 Полезные ссылки

- GCP Console: https://console.cloud.google.com
- Artifact Registry: https://console.cloud.google.com/artifacts
- Service Accounts: https://console.cloud.google.com/iam-admin/serviceaccounts
- GitHub Actions Docs: https://docs.github.com/en/actions

