# Aivus deployment

Этот каталог - набор исполняемых скриптов и справочников для деплоя Aivus в production. Это не основная документация: канонический документ по деплою - [../DEPLOYMENT.md](../DEPLOYMENT.md). Здесь только перечень файлов каталога и как пользоваться скриптами вручную.

## Файлы каталога

- `install.sh` - bootstrap нового сервера: ставит Docker, готовит директории, генерирует `.env`, настраивает GCP auth и устанавливает плагин docker-rollout;
- `deploy-backend.sh` - ручной zero-downtime деплой бэкенда: pull образа, миграции и collectstatic на новом образе, затем `docker rollout` для django без окна простоя, пересоздание celeryworker/celerybeat/flower;
- `deploy-frontend.sh` - ручной zero-downtime деплой фронтенда: pull образа и `docker rollout` для Next.js без окна простоя;
- `probe-downtime.sh` - внешняя проба простоя: бьёт по `https://api.aivus.co/healthz` с заданным интервалом и печатает итоговую сводку по даунтайму;
- `ROUTING.md` - роутинг Traefik (хосты, лейблы, healthcheck);
- `env.production.template` - шаблон `.env` для прода.

## docker-rollout plugin

`deploy-backend.sh` и `deploy-frontend.sh` вызывают `docker rollout` для бесшовного swap контейнера. Плагин ставит `install.sh`. Поставить вручную:

```bash
mkdir -p ~/.docker/cli-plugins
curl -fsSL https://raw.githubusercontent.com/wowu/docker-rollout/master/docker-rollout \
  -o ~/.docker/cli-plugins/docker-rollout
chmod +x ~/.docker/cli-plugins/docker-rollout
docker rollout --help
```

Без плагина скрипты деплоя падают с ошибкой `docker-rollout plugin not installed`.

## Деплой

Деплой автоматический по merge: backend - из ветки `main`, frontend - из ветки `master`. CI/CD прогоняет тот же flow, что и скрипты, inline из deploy-job. Ручной запуск на сервере:

```bash
cd ~/aivus
./deploy-backend.sh v1.2.3
./deploy-frontend.sh v1.2.3
```

Версия задеплоенного кода (`GIT_COMMIT`) запекается в образ на билде и видна в Django admin.

## Хосты

- `https://go.aivus.co` - frontend;
- `https://api.aivus.co` - django (API + admin под `/admin/`);
- админки сервисов под `SERVICE_DOMAIN`: `traefik.`, `flower.`, `pgadmin.`, `databasus.aivus.co`.

Подробности по хостам, healthcheck и Basic Auth - в [ROUTING.md](./ROUTING.md) и [../DEPLOYMENT.md](../DEPLOYMENT.md).

## Дополнительно

- Основная документация по деплою: [../DEPLOYMENT.md](../DEPLOYMENT.md)
- Переменные окружения: [../ENV_VARIABLES.md](../ENV_VARIABLES.md)
- Архитектура: [../ARCHITECTURE.md](../ARCHITECTURE.md)
- GCP Setup: [../GCP_SETUP.md](../GCP_SETUP.md)
- Восстановление прода и бэкапы через Databasus: [../DISASTER_RECOVERY.md](../DISASTER_RECOVERY.md)
