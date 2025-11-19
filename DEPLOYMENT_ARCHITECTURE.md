# 🏗️ Deployment Architecture

## 📊 Полная архитектура системы

```
┌─────────────────────────────────────────────────────────────────────┐
│                           INTERNET                                   │
│                         (Users/Clients)                              │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                │ HTTPS (443)
                                │ HTTP (80) → redirect to 443
                                │
┌───────────────────────────────▼─────────────────────────────────────┐
│                          TRAEFIK (Reverse Proxy)                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │ • SSL/TLS Termination (Let's Encrypt)                       │   │
│  │ • Automatic Certificate Renewal                             │   │
│  │ • Path-based Routing                                        │   │
│  │ • Load Balancing                                            │   │
│  │ • Basic Auth Middleware                                     │   │
│  └─────────────────────────────────────────────────────────────┘   │
└───────┬───────────────┬─────────────┬──────────────┬────────────────┘
        │               │             │              │
        │ /             │ /api/       │ /admin/      │ flower.domain
        │               │             │              │
┌───────▼──────┐ ┌──────▼──────┐ ┌───▼──────┐ ┌────▼──────┐
│   FRONTEND   │ │   DJANGO    │ │  DJANGO  │ │  FLOWER   │
│   (Next.js)  │ │    (API)    │ │  (Admin) │ │ (Celery)  │
│              │ │             │ │          │ │           │
│  Port: 3000  │ │ Port: 5000  │ │Port: 5000│ │Port: 5555 │
└───────┬──────┘ └──────┬──────┘ └───┬──────┘ └────┬──────┘
        │               │             │              │
        │ Internal      │             │              │
        │ API calls     │             │              │
        └───────────────┼─────────────┘              │
                        │                            │
        ┌───────────────┼────────────────────────────┘
        │               │
        │        ┌──────▼──────┐
        │        │  POSTGRES   │
        │        │  (Database) │
        │        │             │
        │        │ Port: 5432  │
        │        └──────┬──────┘
        │               │
        │        ┌──────▼──────┐
        │        │    REDIS    │
        │        │ (Cache/     │
        │        │  Broker)    │
        │        │ Port: 6379  │
        │        └──────┬──────┘
        │               │
        │        ┌──────▼──────────────┐
        │        │  CELERY WORKER      │
        │        │  (Async Tasks)      │
        │        └─────────────────────┘
        │               │
        │        ┌──────▼──────────────┐
        │        │  CELERY BEAT        │
        │        │  (Scheduler)        │
        │        └─────────────────────┘
        │
        └─────────────────────────────────────────────┐
                                                      │
                                              ┌───────▼────────┐
                                              │  GCP STORAGE   │
                                              │  (Static/Media)│
                                              └────────────────┘
```

---

## 🔄 Request Flow

### 1. Frontend Request (User → Next.js)
```
User Browser
    ↓ HTTPS
Traefik (SSL termination)
    ↓ HTTP
Next.js Frontend (:3000)
    ↓ Internal HTTP
Django API (:5000)
    ↓
PostgreSQL / Redis
```

### 2. API Request (Frontend → Backend)
```
Next.js Middleware
    ↓ Add HMAC signature
    ↓ Add user headers
Django Middleware
    ↓ Verify HMAC
    ↓ Verify user permissions
Django View
    ↓
Database / Cache
```

### 3. Async Task Flow
```
Django View
    ↓ .delay()
Celery Worker
    ↓ Process task
    ↓ Send email / Update DB
Redis (result backend)
```

---

## 🌐 Network Architecture

### Docker Network: `aivus`
```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Network: aivus                     │
│                                                              │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │ Traefik  │  │ Frontend │  │  Django  │  │ Postgres │   │
│  │          │  │          │  │          │  │          │   │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘   │
│       │             │             │             │          │
│  ┌────▼─────────────▼─────────────▼─────────────▼──────┐   │
│  │         Internal DNS Resolution                     │   │
│  │  - traefik → traefik:80                            │   │
│  │  - frontend → frontend:3000                        │   │
│  │  - django → django:5000                            │   │
│  │  - postgres → postgres:5432                        │   │
│  │  - redis → redis:6379                              │   │
│  └────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Exposed Ports (to host)
```
Host Machine
├── :80   → Traefik (HTTP, redirects to 443)
├── :443  → Traefik (HTTPS)
└── :8080 → Traefik Dashboard (optional)
```

---

## 📦 Data Persistence

### Docker Volumes
```
Host Filesystem
├── /var/lib/docker/volumes/
│   ├── aivus_postgres_data/          # PostgreSQL data
│   ├── aivus_postgres_backups/       # Database backups
│   ├── aivus_redis_data/             # Redis persistence
│   └── aivus_traefik_acme/           # SSL certificates
│
└── /opt/aivus/
    ├── .env                          # Environment variables
    ├── docker-compose.production.yml # Compose file
    └── secrets/
        └── gcp-credentials.json      # GCP service account
```

### GCP Cloud Storage
```
GCS Bucket: aivus-production-media
├── static/                           # Django static files
│   ├── admin/
│   ├── css/
│   └── js/
└── media/                            # User uploads
    └── ...
```

---

## 🔐 Security Layers

### 1. Network Security
```
Internet
    ↓ Firewall
    ↓ Allow: 80, 443, 22
    ↓ Deny: all other
Server
    ↓ Docker Network Isolation
    ↓ Only Traefik exposed
Internal Services
```

### 2. Authentication Flow
```
User Request
    ↓
Traefik (SSL)
    ↓
Next.js Middleware
    ↓ Check NextAuth session
    ↓ Generate HMAC signature
Django Middleware
    ↓ Verify HMAC
    ↓ Check user group
    ↓ Check permissions
Django View
```

### 3. Admin Panels Protection
```
Request to /admin/ or flower.domain
    ↓
Traefik Basic Auth Middleware
    ↓ Verify username/password
    ↓ (htpasswd format)
Django Admin / Flower
```

---

## 🚀 Deployment Flow

### CI/CD Pipeline
```
Developer
    ↓ git push
GitHub
    ↓ Trigger GitHub Actions
Build Docker Images
    ↓ Build Frontend
    ↓ Build Backend
    ↓ Push to GCP Artifact Registry
GCP Artifact Registry
    ↓ Store images
    ↓ Tagged: latest, branch-sha, v1.2.3
Server
    ↓ docker-compose pull
    ↓ docker-compose up -d
    ↓ Rolling update (zero downtime)
Production
```

### Manual Deployment
```
Developer
    ↓ Trigger GitHub Actions manually
GitHub Actions
    ↓ Build & Push images
Server Admin
    ↓ SSH to server
    ↓ cd /opt/aivus
    ↓ docker-compose pull
    ↓ docker-compose up -d
    ↓ docker-compose exec django migrate
Production
```

---

## 📊 Monitoring & Logging

### Logs Flow
```
All Containers
    ↓ stdout/stderr
Docker Log Driver
    ↓ json-file
Host: /var/lib/docker/containers/
    ↓ docker-compose logs
Terminal / Log Aggregator
```

### Metrics (Future)
```
Services
    ↓ Expose /metrics endpoint
Prometheus
    ↓ Scrape metrics
Grafana
    ↓ Visualize
Alertmanager
    ↓ Send alerts
```

---

## 🔄 Update Strategy

### Zero-Downtime Updates
```
1. Pull new images
   docker-compose pull

2. Recreate containers
   docker-compose up -d
   
   ↓ Docker will:
   - Start new containers
   - Wait for health checks
   - Stop old containers
   - Remove old containers

3. Run migrations (if needed)
   docker-compose exec django migrate

4. Verify
   docker-compose ps
   docker-compose logs -f
```

### Rollback Strategy
```
1. Check previous image tags
   docker images | grep aivus

2. Update .env with old tag
   BACKEND_TAG=v1.2.2
   FRONTEND_TAG=v1.2.2

3. Redeploy
   docker-compose up -d

4. Verify
   docker-compose ps
```

---

## 🏗️ Scaling Strategy (Future)

### Horizontal Scaling
```
Current: Single Server
    ↓
Future: Multiple Servers
    ↓
Load Balancer (GCP LB / Cloudflare)
    ↓
    ├── Server 1 (Frontend + Backend)
    ├── Server 2 (Frontend + Backend)
    └── Server 3 (Frontend + Backend)
    ↓
Shared Services:
    ├── Managed PostgreSQL (Cloud SQL)
    ├── Managed Redis (Memorystore)
    └── GCS (Static/Media)
```

### Service Separation
```
Current: All-in-One
    ↓
Future: Microservices
    ↓
    ├── Frontend Cluster (3 nodes)
    ├── API Cluster (5 nodes)
    ├── Celery Workers (10 nodes)
    ├── Managed Database
    └── Managed Cache
```

---

## 📈 Performance Optimization

### Caching Layers
```
User Request
    ↓
Cloudflare CDN (static assets)
    ↓ Cache Miss
Traefik
    ↓
Next.js (SSR cache)
    ↓ Cache Miss
Django (Redis cache)
    ↓ Cache Miss
PostgreSQL
```

### Database Optimization
```
PostgreSQL
├── Connection Pooling (CONN_MAX_AGE=60)
├── Indexes on frequently queried fields
├── Read Replicas (future)
└── Query optimization
```

---

## 🔧 Maintenance Tasks

### Daily
- ✅ Check logs for errors
- ✅ Monitor disk space
- ✅ Check SSL certificate expiry

### Weekly
- ✅ Review Sentry errors
- ✅ Check Celery task queue
- ✅ Review database performance

### Monthly
- ✅ Update Docker images
- ✅ Review security patches
- ✅ Database vacuum/analyze
- ✅ Rotate logs

### Quarterly
- ✅ Rotate API keys
- ✅ Review access logs
- ✅ Update dependencies
- ✅ Load testing

### Yearly
- ✅ Rotate secrets (DJANGO_SECRET_KEY, etc)
- ✅ Review architecture
- ✅ Disaster recovery drill
- ✅ Security audit

---

## 📚 Related Documentation

- **Setup:** `QUICK_DEPLOY.md`
- **Environment Variables:** `ENV_VARIABLES.md`
- **GCP Configuration:** `GCP_SETUP.md`
- **Docker Compose:** `docker-compose.production.yml`
- **Summary:** `DEPLOYMENT_SUMMARY.md`

