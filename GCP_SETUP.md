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

---

## 📞 Полезные ссылки

- GCP Console: https://console.cloud.google.com
- Artifact Registry: https://console.cloud.google.com/artifacts
- Service Accounts: https://console.cloud.google.com/iam-admin/serviceaccounts
- GitHub Actions Docs: https://docs.github.com/en/actions

