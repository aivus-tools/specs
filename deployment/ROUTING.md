# 🌐 Aivus Routing Configuration

## Domain Structure

### Production Domains

| Domain | Service | Description |
|--------|---------|-------------|
| `go.aivus.co` | **Frontend** | Next.js application (all routes) |
| `api.aivus.co` | **Django Backend** | REST API, Admin |
| `flower.aivus.co` | **Flower** | Celery monitoring (Basic Auth) |
| `databasus.aivus.co` | **Databasus** | PostgreSQL backups UI |
| `pgadmin.aivus.co` | **pgAdmin** | Database management |
| `traefik.aivus.co` | **Traefik Dashboard** | Reverse proxy dashboard (Basic Auth) |

## Routing Details

### Frontend (`go.aivus.co`)
- **Service**: Next.js
- **Port**: 3000
- **Routes**: All routes (`/*`)
- **SSL**: Automatic (Let's Encrypt)
- **Auth**: NextAuth (built-in)

**Examples:**
- `https://go.aivus.co/` - Home page
- `https://go.aivus.co/dashboard` - Dashboard
- `https://go.aivus.co/api/auth/*` - NextAuth endpoints

### Backend API (`api.aivus.co`)
- **Service**: Django (Gunicorn)
- **Port**: 5000
- **Routes**: All routes (`/*`)
- **SSL**: Automatic (Let's Encrypt)
- **Auth**: Token-based (HMAC)

**Examples:**
- `https://api.aivus.co/api/v1/` - REST API
- `https://api.aivus.co/admin/` - Django Admin

Static and media files are not served by Django: they live in Google Cloud Storage (`storage.googleapis.com/<bucket>/static/` and `/media/`).

### Services

#### Flower (`flower.aivus.co`)
- **Service**: Celery Flower
- **Port**: 5555
- **Auth**: Traefik Basic Auth (see `CREDENTIALS.txt`)
- **Purpose**: Monitor Celery tasks

#### Databasus (`databasus.aivus.co`)
- **Service**: Databasus
- **Port**: 4005
- **Auth**: Databasus login (own app auth)
- **Purpose**: PostgreSQL backups UI

#### pgAdmin (`pgadmin.aivus.co`)
- **Service**: pgAdmin 4
- **Port**: 80
- **Auth**: pgAdmin login only (its Traefik basicauth middleware is commented out in the compose)
- **Purpose**: Database management

#### Traefik (`traefik.aivus.co`)
- **Service**: Traefik Dashboard
- **Port**: 8080
- **Auth**: Traefik Basic Auth (see `CREDENTIALS.txt`)
- **Purpose**: Monitor reverse proxy

## Internal Communication

Services communicate internally via Docker network (`aivus`):

```
Frontend → Django:  http://django:5000
Django → PostgreSQL: postgres:5432
Django → Redis:     redis:6379
Celery → Redis:     redis:6379
```

## Environment Variables

### Frontend
- `API_URL`: `http://django:5000` (internal)
- `CALLBACK_URL`: `https://go.aivus.co` (external)

### Django
- `FRONTEND_URL`: `https://go.aivus.co`
- `DJANGO_ALLOWED_HOSTS`: `api.aivus.co`

## Traefik Configuration

The production compose file lives at `~/aivus/docker-compose.production.yml` on the server; a snapshot is committed at `Specs/prod-docker-compose.yml`. Deploys are zero-downtime via `docker rollout`, which scales the `django` and `frontend` services to 2 (old plus new running side by side until the new container is healthy). Because of that, neither service sets `container_name` - target those containers by id, not by name. Full deploy flow is in [../DEPLOYMENT.md](../DEPLOYMENT.md).

Routing is gated by active Traefik healthchecks: Traefik does not send traffic to a container until its healthcheck returns 200, so during a rollout the booting new container never receives requests. Django is checked on `GET /healthz`, the frontend on `GET /api/health`. The healthcheck `hostname` must be the public host (in `DJANGO_ALLOWED_HOSTS` for Django), otherwise Traefik sends the container IP as `Host` and Django answers 400, which looks like an unhealthy backend.

### Labels Structure

**Django:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.django.rule=Host(`api.${SERVICE_DOMAIN}`)"
  - "traefik.http.routers.django.entrypoints=websecure"
  - "traefik.http.routers.django.tls.certresolver=letsencrypt"
  - "traefik.http.services.django.loadbalancer.server.port=5000"
  # Active healthcheck gates rollout traffic
  - "traefik.http.services.django.loadbalancer.healthcheck.path=/healthz"
  - "traefik.http.services.django.loadbalancer.healthcheck.interval=5s"
  - "traefik.http.services.django.loadbalancer.healthcheck.timeout=3s"
  - "traefik.http.services.django.loadbalancer.healthcheck.hostname=api.${SERVICE_DOMAIN}"
```

**Frontend:**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.frontend.rule=Host(`${APP_DOMAIN}`)"
  - "traefik.http.routers.frontend.entrypoints=websecure"
  - "traefik.http.routers.frontend.tls.certresolver=letsencrypt"
  - "traefik.http.services.frontend.loadbalancer.server.port=3000"
  # Active healthcheck gates rollout traffic
  - "traefik.http.services.frontend.loadbalancer.healthcheck.path=/api/health"
  - "traefik.http.services.frontend.loadbalancer.healthcheck.interval=5s"
  - "traefik.http.services.frontend.loadbalancer.healthcheck.timeout=3s"
  - "traefik.http.services.frontend.loadbalancer.healthcheck.hostname=${APP_DOMAIN}"
```

**Service with Basic Auth (e.g., Flower):**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.flower.rule=Host(`flower.${SERVICE_DOMAIN}`)"
  - "traefik.http.routers.flower.entrypoints=websecure"
  - "traefik.http.routers.flower.tls.certresolver=letsencrypt"
  - "traefik.http.services.flower.loadbalancer.server.port=5555"
  - "traefik.http.routers.flower.middlewares=flower-auth"
  - "traefik.http.middlewares.flower-auth.basicauth.users=${FLOWER_BASIC_AUTH}"
```

**Databasus (no Traefik auth, app login only):**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.databasus.rule=Host(`databasus.${SERVICE_DOMAIN}`)"
  - "traefik.http.routers.databasus.entrypoints=websecure"
  - "traefik.http.routers.databasus.tls.certresolver=letsencrypt"
  - "traefik.http.services.databasus.loadbalancer.server.port=4005"
```

## DNS Configuration

Ensure the following DNS A records point to your server IP:

```
go.aivus.co        → YOUR_SERVER_IP
api.aivus.co       → YOUR_SERVER_IP
flower.aivus.co    → YOUR_SERVER_IP
databasus.aivus.co → YOUR_SERVER_IP
pgadmin.aivus.co   → YOUR_SERVER_IP
traefik.aivus.co   → YOUR_SERVER_IP
```

Or use a wildcard:
```
*.aivus.co → YOUR_SERVER_IP
```

## SSL Certificates

- **Provider**: Let's Encrypt
- **Renewal**: Automatic (Traefik handles it)
- **Storage**: `traefik_acme` Docker volume
- **Email**: Set via `ACME_EMAIL` in `.env`

## Troubleshooting

### 404 Not Found
```bash
# Check Traefik logs
docker compose -f docker-compose.production.yml logs traefik | grep -i error

# Check service is running
docker compose -f docker-compose.production.yml ps

# Check Traefik can reach service
docker compose -f docker-compose.production.yml exec traefik wget -O- http://django:5000
```

### 502 Bad Gateway
```bash
# Check service logs
docker compose -f docker-compose.production.yml logs django

# Check service health
docker compose -f docker-compose.production.yml exec django python manage.py check
```

### SSL Certificate Issues
```bash
# Check Traefik ACME logs
docker compose -f docker-compose.production.yml logs traefik | grep -i acme

# Verify DNS
dig go.aivus.co
dig api.aivus.co

# Check firewall
sudo ufw status
```

## Summary

- 🌐 **Frontend**: `go.aivus.co` (all routes)
- 🔧 **Backend**: `api.aivus.co` (API + Admin)
- 🛠️ **Services**: `*.aivus.co` (Flower, Databasus, pgAdmin, Traefik)
- 🔒 **SSL**: Automatic via Let's Encrypt
- 🔐 **Auth**: Traefik Basic Auth for Flower and the Traefik dashboard, app-level login for pgAdmin and Databasus, Token (HMAC) for API

