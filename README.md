# Aivus Specs

Документация и инфраструктурные артефакты Aivus. Specs — отдельный git-репозиторий, подмонтированный внутрь основного репо.

## Содержимое

| Файл | Что внутри |
|---|---|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Стек, модели данных, API endpoints, AI пайплайн (Brief AI v3), флоу vendor/client, auth |
| [DEPLOYMENT.md](./DEPLOYMENT.md) | Production deployment: сервисы, install.sh, операции (логи, миграции, бэкапы), troubleshooting |
| [ENV_VARIABLES.md](./ENV_VARIABLES.md) | Все переменные окружения по категориям, как генерировать секреты |
| [GCP_SETUP.md](./GCP_SETUP.md) | Service accounts (CI и runtime), Vertex AI, Speech-to-Text, GCS, Artifact Registry |
| [DISASTER_RECOVERY.md](./DISASTER_RECOVERY.md) | Восстановление прода из бэкапа Databasus, ротация секретов, миграция на новый VPS |
| [prod-docker-compose.yml](./prod-docker-compose.yml) | Снапшот live `~/aivus/docker-compose.production.yml` с прода (для справки) |
| [deployment/](./deployment/) | Скрипты `install.sh`, `deploy-backend.sh`, `deploy-frontend.sh`, шаблон `env.production.template` |
| [claude/](./claude/) | Project-level правила и скиллы для Claude Code (`CLAUDE.md`, `skills/aivus-*`) |

## Конвенции

- Никаких эмодзи в документации.
- Сначала факт, потом контекст. Без вводных абзацев и пустой воды.
- Любая ссылка на код — относительный путь от корня основного репо: `../Backend/aivus_backend/...`, `../Frontend/src/...`.
- При изменении инфраструктуры на проде синхронно обновлять `prod-docker-compose.yml` и `ENV_VARIABLES.md`.
