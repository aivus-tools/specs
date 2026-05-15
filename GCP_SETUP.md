# GCP Setup

Настройка Google Cloud Platform для Aivus. Проект: `pioneering-flag-476313-u2`.

В проекте используются **два разных service account**:

- `gha-service-account@pioneering-flag-476313-u2.iam.gserviceaccount.com` — CI/CD: push образов в Artifact Registry (если нужен) и доступ к GCS для Databasus HMAC. Использует креды `gcp-credentials.json`.
- `sa-for-vertex-ai@pioneering-flag-476313-u2.iam.gserviceaccount.com` — runtime: Vertex AI / Gemini, Speech-to-Text, GCS. Использует креды `vertex-credentials.json`.

## CI/CD: Service Account для GitHub Actions

Сейчас образы пушатся в **GHCR** (`ghcr.io/aivus-tools/*`), а не в GCP Artifact Registry. Этот раздел нужен только если придётся переехать на GCP.

### Создание SA

```bash
gcloud auth login
gcloud config set project pioneering-flag-476313-u2

gcloud iam service-accounts create gha-service-account \
    --display-name="GitHub Actions CI/CD"

SA_EMAIL=gha-service-account@pioneering-flag-476313-u2.iam.gserviceaccount.com
```

### Роли

```bash
PROJECT=pioneering-flag-476313-u2

# Push в Artifact Registry (если используется GCP вместо GHCR)
gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/artifactregistry.writer"

# Доступ к GCS (для Databasus HMAC, бэкапы)
gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/storage.admin"
```

### Ключ

```bash
gcloud iam service-accounts keys create ~/gcp-credentials.json \
    --iam-account=$SA_EMAIL
```

Содержимое — в GitHub Secret `GCP_SA_KEY` (для Actions) и/или в `~/data/gcp-credentials.json` на сервере (для bind-mount в контейнеры).

### Artifact Registry (если используется)

```bash
# Создать репозиторий
gcloud artifacts repositories create aivus \
    --repository-format=docker \
    --location=us-central1

# Логин
gcloud auth configure-docker us-central1-docker.pkg.dev

# Список образов
gcloud artifacts docker images list us-central1-docker.pkg.dev/$PROJECT/aivus
```

## Runtime: APIs и роли

Это настройки для `sa-for-vertex-ai@...` (`vertex-credentials.json`). Без них Brief AI чат и голосовой ввод упадут с `403 SERVICE_DISABLED` или `403 IAM_PERMISSION_DENIED`.

При перестройке проекта с нуля каждый шаг обязателен.

### Включить APIs

```bash
PROJECT=pioneering-flag-476313-u2

gcloud services enable aiplatform.googleapis.com --project=$PROJECT      # Vertex AI / Gemini
gcloud services enable speech.googleapis.com --project=$PROJECT          # Speech-to-Text
gcloud services enable storage.googleapis.com --project=$PROJECT         # GCS (attachments, final docs)
gcloud services enable iamcredentials.googleapis.com --project=$PROJECT  # signed URLs
```

После `enable` подождать 1-2 минуты на пропагацию.

### Назначить роли

```bash
SA=sa-for-vertex-ai@$PROJECT.iam.gserviceaccount.com

# Vertex AI (Brief AI v3 chat)
gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA" --role="roles/aiplatform.user"

# Speech-to-Text (голосовой ввод)
gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA" --role="roles/speech.client"

# GCS (attachments + final docs)
gcloud projects add-iam-policy-binding $PROJECT \
    --member="serviceAccount:$SA" --role="roles/storage.objectAdmin"
```

`roles/speech.client` (Cloud Speech User) даёт `speech.recognizers.recognize`. Без него `client.recognize()` в [Backend/aivus_backend/aivus_backend/projects/stt.py](../Backend/aivus_backend/aivus_backend/projects/stt.py) вернёт 403, и фронт получит 500 на `/transcribe`.

## Speech-to-Text: location, recognizer и модель

- **Default**: synthetic recognizer `_` + локация `global` + модель `short`. Работает из коробки, отдельный recognizer создавать не нужно. Модель `short` хорошо подходит к лимиту `MAX_AUDIO_DURATION_SEC=60` в `stt.py` — дешевле и быстрее, чем `long`/`chirp_2`.
- **Валидные модели в `global`**: `short`, `long`, `telephony`. Семейства `chirp` и `chirp_2`/`chirp_3` в `global` **не существуют** — попытка использовать вернёт `400 The model "<name>" does not exist in the location named "global"`.
- **Chirp 3** (точнее, новее): доступна **только** в региональных локациях `us-central1` или `europe-west4`. В `global` её нет. Synthetic `_` recognizer в этих регионах часто отдаёт `404`. Для Chirp 3 нужен explicit recognizer:
  ```bash
  gcloud speech recognizers create aivus-chirp3 \
      --location=us-central1 \
      --model=chirp_3 \
      --language-codes=en-US,ru-RU \
      --project=pioneering-flag-476313-u2
  ```
  Env: `GOOGLE_CLOUD_SPEECH_LOCATION=us-central1`, `STT_RECOGNIZER=aivus-chirp3`, `STT_MODEL=chirp_3`. Это TODO — текущий код использует `_` recognizer.
- **Переопределение модели**: `STT_MODEL=short` (default) или `long`/`latest_long`/`latest_short`. `chirp_2` — только для региональных локаций.

## Smoke-тест runtime credentials

```bash
docker exec aivus_django python manage.py shell -c "
from aivus_backend.projects import stt
import os; os.environ['STT_DEV_FAKE'] = '0'
print(stt._get_speech_client())
"
```

Типичные ошибки при пропуске шагов:

- `PermissionDenied: 403 ... API has not been used in project ... or it is disabled` — забыт `gcloud services enable speech.googleapis.com`.
- `PermissionDenied: 403 Permission 'speech.recognizers.recognize' denied on resource` — нет `roles/speech.client` на runtime SA.
- `MethodNotImplemented: 501 Received http2 header with status: 404` — `_` recognizer недоступен в выбранной локации, вернуться на `global`.
- `InvalidArgument: 400 The model "chirp_2" does not exist in the location named "global"` — попытка использовать `chirp*` в `global`. Поставить `STT_MODEL=short` или переключиться на `GOOGLE_CLOUD_SPEECH_LOCATION=us-central1` с подходящей моделью.

## Checklist при создании нового проекта

- [ ] CI SA `gha-service-account` создан, ключ выписан.
- [ ] Runtime SA `sa-for-vertex-ai` создан, ключ выписан.
- [ ] `aiplatform.googleapis.com` включён.
- [ ] `speech.googleapis.com` включён.
- [ ] `storage.googleapis.com` включён.
- [ ] `roles/aiplatform.user` назначен runtime SA.
- [ ] `roles/speech.client` назначен runtime SA.
- [ ] `roles/storage.objectAdmin` назначен runtime SA.
- [ ] GCS bucket `aivus-production-media` создан (для медиа).
- [ ] GCS bucket `aivus-db-backups` создан (для Databasus, через S3 HMAC).
- [ ] HMAC ключи для Databasus выписаны на CI SA.

## Полезные ссылки

- GCP Console: https://console.cloud.google.com
- IAM & Admin: https://console.cloud.google.com/iam-admin/serviceaccounts
- Vertex AI: https://console.cloud.google.com/vertex-ai
- Speech-to-Text: https://console.cloud.google.com/speech
