# 🌐 Aivus Routing Configuration

## Domain Structure

### Production Domains

| Domain | Service | Description |
|--------|---------|-------------|
| `go.aivus.co` | **Frontend** | Next.js application (all routes) |
| `api.aivus.co` | **Django Backend** | REST API, Admin, Static files |
| `flower.aivus.co` | **Flower** | Celery monitoring (Basic Auth) |
| `mailpit.aivus.co` | **Mailpit** | Email testing (Basic Auth) |
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
- `https://api.aivus.co/static/` - Static files
- `https://api.aivus.co/media/` - Media files

### Services (Basic Auth Protected)

#### Flower (`flower.aivus.co`)
- **Service**: Celery Flower
- **Port**: 5555
- **Auth**: Basic Auth (see `CREDENTIALS.txt`)
- **Purpose**: Monitor Celery tasks

#### Mailpit (`mailpit.aivus.co`)
- **Service**: Mailpit
- **Port**: 8025
- **Auth**: Basic Auth (see `CREDENTIALS.txt`)
- **Purpose**: Test emails in staging/production

#### pgAdmin (`pgadmin.aivus.co`)
- **Service**: pgAdmin 4
- **Port**: 80
- **Auth**: pgAdmin login (see `CREDENTIALS.txt`)
- **Purpose**: Database management

#### Traefik (`traefik.aivus.co`)
- **Service**: Traefik Dashboard
- **Port**: 8080
- **Auth**: Basic Auth (see `CREDENTIALS.txt`)
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

### Labels Structure

**Django (Simple):**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.django.rule=Host(`api.${SERVICE_DOMAIN}`)"
  - "traefik.http.routers.django.entrypoints=websecure"
  - "traefik.http.routers.django.tls.certresolver=letsencrypt"
  - "traefik.http.services.django.loadbalancer.server.port=5000"
```

**Frontend (Simple):**
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.frontend.rule=Host(`${APP_DOMAIN}`)"
  - "traefik.http.routers.frontend.entrypoints=websecure"
  - "traefik.http.routers.frontend.tls.certresolver=letsencrypt"
  - "traefik.http.services.frontend.loadbalancer.server.port=3000"
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

## DNS Configuration

Ensure the following DNS A records point to your server IP:

```
go.aivus.co       → YOUR_SERVER_IP
api.aivus.co      → YOUR_SERVER_IP
flower.aivus.co   → YOUR_SERVER_IP
mailpit.aivus.co  → YOUR_SERVER_IP
pgadmin.aivus.co  → YOUR_SERVER_IP
traefik.aivus.co  → YOUR_SERVER_IP
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

## Migration from Old Routing

If you're migrating from the old routing structure (where API was on `go.aivus.co/api/`):

### Frontend Changes
**Old:**
```typescript
const API_URL = process.env.API_URL || 'https://go.aivus.co/api'
```

**New:**
```typescript
const API_URL = process.env.API_URL || 'http://django:5000'
// External: https://api.aivus.co
```

### Django Changes
**Old:**
```python
ALLOWED_HOSTS = ['go.aivus.co']
```

**New:**
```python
ALLOWED_HOSTS = ['api.aivus.co']
```

### Update `.env`
```bash
# Old
APP_DOMAIN=go.aivus.co
SERVICE_DOMAIN=aivus.co

# New (same, but routing is different)
APP_DOMAIN=go.aivus.co      # Frontend
SERVICE_DOMAIN=aivus.co     # Services (api.aivus.co, flower.aivus.co, etc.)
```

## Benefits of New Routing

✅ **Clear separation**: Frontend and Backend on different domains
✅ **Simpler Traefik config**: No complex path-based routing or priorities
✅ **Better caching**: Can set different cache policies per domain
✅ **Easier debugging**: Clear which service is handling each request
✅ **Standard practice**: API on `api.*` subdomain is industry standard
✅ **No conflicts**: No risk of frontend routes conflicting with API routes

## Summary

- 🌐 **Frontend**: `go.aivus.co` (all routes)
- 🔧 **Backend**: `api.aivus.co` (API + Admin + Static)
- 🛠️ **Services**: `*.aivus.co` (Flower, Mailpit, pgAdmin, Traefik)
- 🔒 **SSL**: Automatic via Let's Encrypt
- 🔐 **Auth**: Basic Auth for admin services, Token for API

