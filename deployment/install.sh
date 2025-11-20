#!/bin/bash

# ============================================
# Aivus Production Installation Script
# ============================================
# This script installs and configures Aivus
# on a fresh server.
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/.../install.sh | bash
#   # OR
#   ./install.sh
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Determine if we need sudo
if [ "$EUID" -eq 0 ]; then
    log_warning "Running as root. Files will be created in /root."
    SUDO=""
else
    SUDO="sudo"
fi

log_info "Starting Aivus installation..."

# ============================================
# 1. Install Docker
# ============================================
log_info "Step 1/10: Installing Docker..."

if command -v docker &> /dev/null; then
    log_success "Docker is already installed"
    docker --version
else
    log_info "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    $SUDO sh get-docker.sh
    $SUDO usermod -aG docker $USER
    rm get-docker.sh
    log_success "Docker installed successfully"
fi

# ============================================
# 2. Install Docker Compose
# ============================================
log_info "Step 2/10: Checking Docker Compose..."

if docker compose version &> /dev/null; then
    log_success "Docker Compose is already installed"
    docker compose version
else
    log_error "Docker Compose not found. Please install Docker Compose v2"
    exit 1
fi

# ============================================
# 3. Create directories
# ============================================
log_info "Step 3/10: Creating directories..."

mkdir -p $HOME/data/{postgres,postgres-backups,pgadmin,pgbackups,redis,traefik}
mkdir -p $HOME/aivus

log_success "Directories created"

# ============================================
# 4. Download configuration files
# ============================================
log_info "Step 4/10: Downloading configuration files..."

cd $HOME/aivus

# Create docker-compose.production.yml
log_info "Creating docker-compose.production.yml..."
cat > $HOME/aivus/docker-compose.production.yml << 'EOF'
version: '3.9'

volumes:
  postgres_data:
  postgres_backups:
  redis_data:
  traefik_acme:
  pgadmin_data:

networks:
  aivus:
    driver: bridge

services:
  # ===========================================
  # Traefik - Reverse Proxy & SSL
  # ===========================================
  traefik:
    image: traefik:v2.11
    container_name: aivus_traefik
    restart: unless-stopped
    networks:
      - aivus
    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Traefik dashboard (optional, can be disabled)
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_acme:/letsencrypt
    command:
      # API and Dashboard
      - "--api.dashboard=true"
      - "--api.insecure=true"  # Dashboard on :8080 without auth (set false in prod)
      
      # Providers
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=aivus"
      
      # Entrypoints
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      
      # Let's Encrypt
      - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.email=${ACME_EMAIL}"
      - "--certificatesresolvers.letsencrypt.acme.storage=/letsencrypt/acme.json"
      
      # Logging
      - "--log.level=INFO"
      - "--accesslog=true"
    labels:
      - "traefik.enable=true"
      # Dashboard routing
      - "traefik.http.routers.traefik.rule=Host(`traefik.${SERVICE_DOMAIN}`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik.service=api@internal"
      # Basic auth for dashboard
      - "traefik.http.routers.traefik.middlewares=traefik-auth"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=${TRAEFIK_BASIC_AUTH}"

  # ===========================================
  # PostgreSQL Database
  # ===========================================
  postgres:
    image: postgres:16-alpine
    container_name: aivus_postgres
    restart: unless-stopped
    networks:
      - aivus
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - postgres_backups:/backups
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ===========================================
  # pgAdmin - Database Management
  # ===========================================
  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: aivus_pgadmin
    restart: unless-stopped
    networks:
      - aivus
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - pgadmin_data:/var/lib/pgadmin
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_DEFAULT_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_DEFAULT_PASSWORD}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.pgadmin.rule=Host(`pgadmin.${SERVICE_DOMAIN}`)"
      - "traefik.http.routers.pgadmin.entrypoints=websecure"
      - "traefik.http.routers.pgadmin.tls.certresolver=letsencrypt"
      - "traefik.http.services.pgadmin.loadbalancer.server.port=80"
      # Optional: Add basic auth on top of pgadmin's auth if needed
      # - "traefik.http.routers.pgadmin.middlewares=pgadmin-auth"
      # - "traefik.http.middlewares.pgadmin-auth.basicauth.users=${PGADMIN_BASIC_AUTH}"

  # ===========================================
  # Redis Cache & Celery Broker
  # ===========================================
  redis:
    image: redis:7-alpine
    container_name: aivus_redis
    restart: unless-stopped
    networks:
      - aivus
    volumes:
      - redis_data:/data
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # ===========================================
  # Django Backend
  # ===========================================
  django:
    image: ${GCP_REGISTRY}/backend:${BACKEND_TAG:-latest}
    container_name: aivus_django
    restart: unless-stopped
    networks:
      - aivus
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      # Django Core
      DJANGO_SETTINGS_MODULE: config.settings.production
      DJANGO_SECRET_KEY: ${DJANGO_SECRET_KEY}
      DJANGO_ALLOWED_HOSTS: ${APP_DOMAIN},www.${APP_DOMAIN}
      DJANGO_ADMIN_URL: ${DJANGO_ADMIN_URL}
      DJANGO_SECURE_SSL_REDIRECT: ${DJANGO_SECURE_SSL_REDIRECT:-True}
      
      # Database
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      CONN_MAX_AGE: 60
      
      # Redis
      REDIS_URL: redis://redis:6379/0
      
      # Email (Brevo)
      BREVO_API_KEY: ${BREVO_API_KEY}
      BREVO_API_URL: ${BREVO_API_URL:-https://api.brevo.com/v3/}
      DJANGO_DEFAULT_FROM_EMAIL: ${DJANGO_DEFAULT_FROM_EMAIL}
      DJANGO_SERVER_EMAIL: ${DJANGO_SERVER_EMAIL}
      
      # GCP Storage
      DJANGO_GCP_STORAGE_BUCKET_NAME: ${DJANGO_GCP_STORAGE_BUCKET_NAME}
      GOOGLE_APPLICATION_CREDENTIALS: /app/gcp-credentials.json
      
      # Sentry
      SENTRY_DSN: ${SENTRY_DSN}
      SENTRY_ENVIRONMENT: ${SENTRY_ENVIRONMENT:-production}
      SENTRY_TRACES_SAMPLE_RATE: ${SENTRY_TRACES_SAMPLE_RATE:-0.1}
      
      # HMAC & API
      HMAC_SECRET: ${HMAC_SECRET}
      API_KEY: ${API_KEY}
      
      # Frontend URL
      FRONTEND_URL: https://${APP_DOMAIN}
    volumes:
      # Mount GCP credentials if using service account JSON
      - ${GCP_CREDENTIALS_PATH}:/app/gcp-credentials.json:ro
    labels:
      - "traefik.enable=true"
      # API routing
      - "traefik.http.routers.django-api.rule=Host(`${APP_DOMAIN}`) && PathPrefix(`/api/`)"
      - "traefik.http.routers.django-api.entrypoints=websecure"
      - "traefik.http.routers.django-api.tls.certresolver=letsencrypt"
      - "traefik.http.services.django-api.loadbalancer.server.port=5000"
      # Admin routing
      - "traefik.http.routers.django-admin.rule=Host(`${APP_DOMAIN}`) && PathPrefix(`/${DJANGO_ADMIN_URL}`)"
      - "traefik.http.routers.django-admin.entrypoints=websecure"
      - "traefik.http.routers.django-admin.tls.certresolver=letsencrypt"
      - "traefik.http.services.django-admin.loadbalancer.server.port=5000"
      # Static files routing
      - "traefik.http.routers.django-static.rule=Host(`${APP_DOMAIN}`) && PathPrefix(`/static/`, `/media/`)"
      - "traefik.http.routers.django-static.entrypoints=websecure"
      - "traefik.http.routers.django-static.tls.certresolver=letsencrypt"
      - "traefik.http.services.django-static.loadbalancer.server.port=5000"

  # ===========================================
  # Celery Worker
  # ===========================================
  celeryworker:
    image: ${GCP_REGISTRY}/backend:${BACKEND_TAG:-latest}
    container_name: aivus_celeryworker
    restart: unless-stopped
    networks:
      - aivus
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: /start-celeryworker
    environment:
      # Inherit all Django environment variables
      DJANGO_SETTINGS_MODULE: config.settings.production
      DJANGO_SECRET_KEY: ${DJANGO_SECRET_KEY}
      DJANGO_ADMIN_URL: ${DJANGO_ADMIN_URL}
      SENTRY_DSN: ${SENTRY_DSN}
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379/0
      BREVO_API_KEY: ${BREVO_API_KEY}
      DJANGO_GCP_STORAGE_BUCKET_NAME: ${DJANGO_GCP_STORAGE_BUCKET_NAME}
      GOOGLE_APPLICATION_CREDENTIALS: /app/gcp-credentials.json
      SENTRY_ENVIRONMENT: ${SENTRY_ENVIRONMENT:-production}
      HMAC_SECRET: ${HMAC_SECRET}
      API_KEY: ${API_KEY}
      FRONTEND_URL: https://${APP_DOMAIN}
    volumes:
      - ${GCP_CREDENTIALS_PATH}:/app/gcp-credentials.json:ro

  # ===========================================
  # Celery Beat (Scheduler)
  # ===========================================
  celerybeat:
    image: ${GCP_REGISTRY}/backend:${BACKEND_TAG:-latest}
    container_name: aivus_celerybeat
    restart: unless-stopped
    networks:
      - aivus
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    command: /start-celerybeat
    environment:
      # Inherit all Django environment variables
      DJANGO_SETTINGS_MODULE: config.settings.production
      DJANGO_SECRET_KEY: ${DJANGO_SECRET_KEY}
      DJANGO_ADMIN_URL: ${DJANGO_ADMIN_URL}
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      REDIS_URL: redis://redis:6379/0
      BREVO_API_KEY: ${BREVO_API_KEY}
      DJANGO_GCP_STORAGE_BUCKET_NAME: ${DJANGO_GCP_STORAGE_BUCKET_NAME}
      GOOGLE_APPLICATION_CREDENTIALS: /app/gcp-credentials.json
      SENTRY_DSN: ${SENTRY_DSN}
      SENTRY_ENVIRONMENT: ${SENTRY_ENVIRONMENT:-production}
      HMAC_SECRET: ${HMAC_SECRET}
      API_KEY: ${API_KEY}
    volumes:
      - ${GCP_CREDENTIALS_PATH}:/app/gcp-credentials.json:ro

  # ===========================================
  # Flower - Celery Monitoring
  # ===========================================
  flower:
    image: ${GCP_REGISTRY}/backend:${BACKEND_TAG:-latest}
    container_name: aivus_flower
    restart: unless-stopped
    networks:
      - aivus
    depends_on:
      redis:
        condition: service_healthy
    command: /start-flower
    environment:
      DJANGO_SETTINGS_MODULE: config.settings.production
      DJANGO_SECRET_KEY: ${DJANGO_SECRET_KEY}
      REDIS_URL: redis://redis:6379/0
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.flower.rule=Host(`flower.${SERVICE_DOMAIN}`)"
      - "traefik.http.routers.flower.entrypoints=websecure"
      - "traefik.http.routers.flower.tls.certresolver=letsencrypt"
      - "traefik.http.services.flower.loadbalancer.server.port=5555"
      # Basic auth for Flower
      - "traefik.http.routers.flower.middlewares=flower-auth"
      - "traefik.http.middlewares.flower-auth.basicauth.users=${FLOWER_BASIC_AUTH}"

  # ===========================================
  # Mailpit - Email Testing (Optional, only for staging)
  # ===========================================
  mailpit:
    image: axllent/mailpit:latest
    container_name: aivus_mailpit
    restart: unless-stopped
    networks:
      - aivus
    profiles:
      - staging  # Only start with --profile staging
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mailpit.rule=Host(`mailpit.${SERVICE_DOMAIN}`)"
      - "traefik.http.routers.mailpit.entrypoints=websecure"
      - "traefik.http.routers.mailpit.tls.certresolver=letsencrypt"
      - "traefik.http.services.mailpit.loadbalancer.server.port=8025"
      # Basic auth for Mailpit
      - "traefik.http.routers.mailpit.middlewares=mailpit-auth"
      - "traefik.http.middlewares.mailpit-auth.basicauth.users=${MAILPIT_BASIC_AUTH}"

  # ===========================================
  # Next.js Frontend
  # ===========================================
  frontend:
    image: ${GCP_REGISTRY}/frontend:${FRONTEND_TAG:-latest}
    container_name: aivus_frontend
    restart: unless-stopped
    networks:
      - aivus
    depends_on:
      - django
    environment:
      # Next.js
      NODE_ENV: production
      
      # API Connection
      API_URL: http://django:5000
      CALLBACK_URL: https://${APP_DOMAIN}
      
      # NextAuth
      AUTH_SECRET: ${NEXTAUTH_SECRET}
      AUTH_GOOGLE_ID: ${AUTH_GOOGLE_ID}
      AUTH_GOOGLE_SECRET: ${AUTH_GOOGLE_SECRET}
      AUTH_TRUST_HOST: "true"
      
      # HMAC (must match Django)
      HMAC_SECRET: ${HMAC_SECRET}
      
      # Locale
      NEXT_PUBLIC_LOCALE: ${NEXT_PUBLIC_LOCALE:-en}
      
      # Debug
      DEBUG: ${FRONTEND_DEBUG:-false}
    labels:
      - "traefik.enable=true"
      # Main app routing (catch-all, should be last)
      - "traefik.http.routers.frontend.rule=Host(`${APP_DOMAIN}`)"
      - "traefik.http.routers.frontend.entrypoints=websecure"
      - "traefik.http.routers.frontend.tls.certresolver=letsencrypt"
      - "traefik.http.routers.frontend.priority=1"  # Lower priority than API/admin
      - "traefik.http.services.frontend.loadbalancer.server.port=3000"
      # NextAuth routing (must have higher priority than Django API)
      - "traefik.http.routers.frontend-auth.rule=Host(`${APP_DOMAIN}`) && PathPrefix(`/api/auth/`)"
      - "traefik.http.routers.frontend-auth.entrypoints=websecure"
      - "traefik.http.routers.frontend-auth.tls.certresolver=letsencrypt"
      - "traefik.http.routers.frontend-auth.priority=100"
      - "traefik.http.routers.frontend-auth.service=frontend"
EOF


log_success "Configuration files ready"

# ============================================
# 5. Generate secrets
# ============================================
log_info "Step 5/10: Generating secrets..."

generate_secret() {
    openssl rand -hex 32
}

generate_password() {
    openssl rand -base64 32 | tr -d '=+/' | cut -c1-25
}

generate_django_secret() {
    openssl rand -base64 50 | tr -d '=+/' | cut -c1-50
}

generate_basic_auth() {
    local username="admin"
    local password=$(openssl rand -base64 12 | tr -d '=+/')
    
    # Check if htpasswd is available
    if command -v htpasswd &> /dev/null; then
        echo $(htpasswd -nb "$username" "$password")
    else
        log_warning "htpasswd not found, using plain password"
        echo "$username:$password"
    fi
    
    echo "# Username: $username, Password: $password" >&2
}

log_info "Generating Django secret key..."
DJANGO_SECRET_KEY=$(generate_django_secret)

log_info "Generating HMAC secret..."
HMAC_SECRET=$(generate_secret)

log_info "Generating API key..."
API_KEY=$(generate_secret)

log_info "Generating NextAuth secret..."
NEXTAUTH_SECRET=$(openssl rand -base64 32)

log_info "Generating PostgreSQL password..."
POSTGRES_PASSWORD=$(generate_password)

log_info "Generating pgAdmin password..."
PGADMIN_PASSWORD=$(generate_password)

log_info "Generating Basic Auth credentials..."
log_info "Traefik Dashboard:"
TRAEFIK_BASIC_AUTH=$(generate_basic_auth)

log_info "Flower:"
FLOWER_BASIC_AUTH=$(generate_basic_auth)

log_info "Mailpit:"
MAILPIT_BASIC_AUTH=$(generate_basic_auth)

log_info "pgAdmin:"
PGADMIN_BASIC_AUTH=$(generate_basic_auth)

log_success "Secrets generated"

# ============================================
# 6. Prompt for configuration
# ============================================
log_info "Step 6/10: Configuration..."

read -p "Enter your APPLICATION domain [go.aivus.co]: " APP_DOMAIN
APP_DOMAIN=${APP_DOMAIN:-go.aivus.co}

read -p "Enter your SERVICE domain [aivus.co]: " SERVICE_DOMAIN
SERVICE_DOMAIN=${SERVICE_DOMAIN:-aivus.co}

read -p "Enter your email for Let's Encrypt [hi@aivus.co]: " ACME_EMAIL
ACME_EMAIL=${ACME_EMAIL:-hi@aivus.co}

read -p "Enter your email for pgAdmin [hi@aivus.co]: " PGADMIN_EMAIL
PGADMIN_EMAIL=${PGADMIN_EMAIL:-hi@aivus.co}

read -p "Enter GCP Storage Bucket name [aivus-production-media]: " GCP_BUCKET_NAME
GCP_BUCKET_NAME=${GCP_BUCKET_NAME:-aivus-production-media}

# Optional: Google OAuth
read -p "Do you have Google OAuth credentials? (y/n): " HAS_GOOGLE_OAUTH
if [ "$HAS_GOOGLE_OAUTH" = "y" ]; then
    read -p "Enter Google OAuth Client ID: " AUTH_GOOGLE_ID
    read -p "Enter Google OAuth Client Secret: " AUTH_GOOGLE_SECRET
else
    AUTH_GOOGLE_ID=""
    AUTH_GOOGLE_SECRET=""
    log_warning "Google OAuth not configured. You can add it to .env later if needed."
fi

# Optional: Brevo API
read -p "Do you have Brevo API key? (y/n): " HAS_BREVO
if [ "$HAS_BREVO" = "y" ]; then
    read -p "Enter Brevo API key: " BREVO_API_KEY
else
    BREVO_API_KEY=""
    log_warning "Brevo API not configured. You can add it to .env later if needed."
fi

# Optional: Sentry
read -p "Do you have Sentry DSN? (y/n): " HAS_SENTRY
if [ "$HAS_SENTRY" = "y" ]; then
    read -p "Enter Sentry DSN: " SENTRY_DSN
else
    SENTRY_DSN=""
    log_warning "Sentry not configured. You can add it to .env later if needed."
fi

# ============================================
# 7. Create .env file
# ============================================
log_info "Step 7/10: Creating .env file..."

cat > $HOME/aivus/.env << EOF
# ============================================
# Aivus Production Environment Variables
# Generated: $(date)
# ============================================

# ===========================================
# DOMAIN & SSL
# ===========================================
APP_DOMAIN=${APP_DOMAIN}
SERVICE_DOMAIN=${SERVICE_DOMAIN}
ACME_EMAIL=${ACME_EMAIL}

# ===========================================
# DOCKER REGISTRY
# ===========================================
GCP_REGISTRY=us-central1-docker.pkg.dev/pioneering-flag-476313-u2/aivus
BACKEND_TAG=latest
FRONTEND_TAG=latest

# ===========================================
# DATABASE
# ===========================================
POSTGRES_DB=aivus
POSTGRES_USER=aivus
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}

# ===========================================
# PGADMIN
# ===========================================
PGADMIN_DEFAULT_EMAIL=${PGADMIN_EMAIL}
PGADMIN_DEFAULT_PASSWORD=${PGADMIN_PASSWORD}

# ===========================================
# DJANGO SECRETS
# ===========================================
DJANGO_SECRET_KEY=${DJANGO_SECRET_KEY}
HMAC_SECRET=${HMAC_SECRET}
API_KEY=${API_KEY}

# ===========================================
# DJANGO CONFIGURATION
# ===========================================
DJANGO_ALLOWED_HOSTS=${APP_DOMAIN},www.${APP_DOMAIN}
DJANGO_ADMIN_URL=admin-$(openssl rand -hex 8)/
DJANGO_SECURE_SSL_REDIRECT=True

# ===========================================
# EMAIL (BREVO)
# ===========================================
BREVO_API_KEY=${BREVO_API_KEY}
BREVO_API_URL=https://api.brevo.com/v3/
DJANGO_DEFAULT_FROM_EMAIL=noreply@${APP_DOMAIN}
DJANGO_SERVER_EMAIL=server@${APP_DOMAIN}

# ===========================================
# GCP STORAGE
# ===========================================
DJANGO_GCP_STORAGE_BUCKET_NAME=${GCP_BUCKET_NAME}
GCP_CREDENTIALS_PATH=$HOME/data/gcp-credentials.json

# ===========================================
# SENTRY
# ===========================================
SENTRY_DSN=${SENTRY_DSN}
SENTRY_ENVIRONMENT=production
SENTRY_TRACES_SAMPLE_RATE=0.1

# ===========================================
# NEXTAUTH
# ===========================================
NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
AUTH_GOOGLE_ID=${AUTH_GOOGLE_ID}
AUTH_GOOGLE_SECRET=${AUTH_GOOGLE_SECRET}

# ===========================================
# FRONTEND
# ===========================================
NEXT_PUBLIC_LOCALE=en
FRONTEND_DEBUG=false

# ===========================================
# BASIC AUTH (htpasswd format)
# ===========================================
TRAEFIK_BASIC_AUTH=${TRAEFIK_BASIC_AUTH}
FLOWER_BASIC_AUTH=${FLOWER_BASIC_AUTH}
MAILPIT_BASIC_AUTH=${MAILPIT_BASIC_AUTH}
PGADMIN_BASIC_AUTH=${PGADMIN_BASIC_AUTH}
EOF

chmod 600 $HOME/aivus/.env

log_success ".env file created at ~/aivus/.env"

# ============================================
# 8. Save credentials to file
# ============================================
log_info "Step 8/10: Saving credentials..."

cat > $HOME/aivus/CREDENTIALS.txt << EOF
# ============================================
# Aivus Credentials
# Generated: $(date)
# KEEP THIS FILE SECURE!
# ============================================

## Database
PostgreSQL User: aivus
PostgreSQL Password: ${POSTGRES_PASSWORD}
PostgreSQL Database: aivus

## pgAdmin
URL: https://pgadmin.${SERVICE_DOMAIN}
Email: ${PGADMIN_EMAIL}
Password: ${PGADMIN_PASSWORD}

## Django Admin
URL: https://${APP_DOMAIN}/$(grep DJANGO_ADMIN_URL $HOME/aivus/.env | cut -d'=' -f2)
# Create superuser with: docker compose exec django python manage.py createsuperuser

## Traefik Dashboard
URL: https://traefik.${SERVICE_DOMAIN}
$(echo "${TRAEFIK_BASIC_AUTH}" | grep "Username:" || echo "Check .env for credentials")

## Flower (Celery Monitoring)
URL: https://flower.${SERVICE_DOMAIN}
$(echo "${FLOWER_BASIC_AUTH}" | grep "Username:" || echo "Check .env for credentials")

## Mailpit (Email Testing)
URL: https://mailpit.${SERVICE_DOMAIN}
$(echo "${MAILPIT_BASIC_AUTH}" | grep "Username:" || echo "Check .env for credentials")

## Secrets
HMAC_SECRET: ${HMAC_SECRET}
API_KEY: ${API_KEY}
NEXTAUTH_SECRET: ${NEXTAUTH_SECRET}

EOF

chmod 600 $HOME/aivus/CREDENTIALS.txt

log_success "Credentials saved to ~/aivus/CREDENTIALS.txt"

# ============================================
# 9. Setup GCP credentials
# ============================================
log_info "Step 9/10: GCP credentials setup..."

log_warning "Please copy your GCP service account JSON to ~/data/gcp-credentials.json"
log_info "Example: scp gcp-credentials.json user@server:~/data/"

read -p "Press Enter when you've copied the GCP credentials file..."

if [ -f "$HOME/data/gcp-credentials.json" ]; then
    chmod 600 "$HOME/data/gcp-credentials.json"
    log_success "GCP credentials found and secured"
else
    log_warning "GCP credentials not found. You'll need to add it later."
fi

# ============================================
# 10. Configure GCP Docker authentication
# ============================================
log_info "Step 10/10: Configuring GCP Docker authentication..."

if [ -f "$HOME/data/gcp-credentials.json" ]; then
    log_info "Activating service account..."
    gcloud auth activate-service-account --key-file="$HOME/data/gcp-credentials.json"
    
    log_info "Configuring Docker for GCP..."
    gcloud auth configure-docker us-central1-docker.pkg.dev
    
    log_success "GCP authentication configured"
else
    log_warning "Skipping GCP authentication (credentials not found)"
    log_info "You'll need to run these commands manually:"
    echo "  gcloud auth activate-service-account --key-file=$HOME/data/gcp-credentials.json"
    echo "  gcloud auth configure-docker us-central1-docker.pkg.dev"
fi

# ============================================
# Summary
# ============================================
echo ""
echo "============================================"
log_success "Installation completed!"
echo "============================================"
echo ""
log_info "Next steps:"
echo ""
echo "1. Review configuration:"
echo "   cat ~/aivus/.env"
echo ""
echo "2. Review credentials:"
echo "   cat ~/aivus/CREDENTIALS.txt"
echo ""
echo "3. Start services:"
echo "   cd ~/aivus"
echo "   docker compose -f docker-compose.production.yml up -d"
echo ""
echo "4. Initialize Django:"
echo "   docker compose -f docker-compose.production.yml exec django python manage.py migrate"
echo "   docker compose -f docker-compose.production.yml exec django python manage.py createsuperuser"
echo ""
echo "5. Check status:"
echo "   docker compose -f docker-compose.production.yml ps"
echo ""
echo "6. View logs:"
echo "   docker compose -f docker-compose.production.yml logs -f"
echo ""
log_info "Your application will be available at:"
echo "  - Frontend: https://${APP_DOMAIN}"
echo "  - API: https://${APP_DOMAIN}/api/v1/"
echo "  - Admin: https://${APP_DOMAIN}/$(grep DJANGO_ADMIN_URL $HOME/aivus/.env | cut -d'=' -f2)"
echo "  - pgAdmin: https://pgadmin.${SERVICE_DOMAIN}"
echo "  - Flower: https://flower.${SERVICE_DOMAIN}"
echo "  - Mailpit: https://mailpit.${SERVICE_DOMAIN}"
echo "  - Traefik: https://traefik.${SERVICE_DOMAIN}"
echo ""
log_warning "IMPORTANT: Keep ~/aivus/CREDENTIALS.txt secure!"
echo ""
