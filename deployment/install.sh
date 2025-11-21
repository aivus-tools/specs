#!/bin/bash

# ============================================
# Aivus Production Installation Script
# ============================================
# This script installs and configures Aivus
# on a fresh server.
#
# SAFE FOR RE-RUNNING:
#   - Detects existing installation
#   - Preserves existing secrets and passwords
#   - Creates backups before overwriting
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
# 1. Install/Update Docker
# ============================================
log_info "Step 1/10: Installing/Updating Docker..."

# Minimum required Docker version for Traefik 3.x (API 1.44)
MIN_DOCKER_VERSION="24.0.0"
CURRENT_DOCKER_VERSION=""

if command -v docker &> /dev/null; then
    CURRENT_DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "0.0.0")
    log_info "Current Docker version: $CURRENT_DOCKER_VERSION"
    
    # Compare versions (simple comparison, works for most cases)
    if [ "$(printf '%s\n' "$MIN_DOCKER_VERSION" "$CURRENT_DOCKER_VERSION" | sort -V | head -n1)" = "$MIN_DOCKER_VERSION" ]; then
        log_success "Docker version is sufficient (>= $MIN_DOCKER_VERSION)"
    else
        log_warning "Docker version is too old (< $MIN_DOCKER_VERSION)"
        log_info "Updating Docker to latest version..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        $SUDO sh get-docker.sh
        rm get-docker.sh
        log_success "Docker updated successfully"
        
        # Restart Docker to apply changes
        $SUDO systemctl restart docker || true
        sleep 3
    fi
else
    log_info "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    $SUDO sh get-docker.sh
    $SUDO usermod -aG docker $USER
    rm get-docker.sh
    log_success "Docker installed successfully"
fi

# Display final version
FINAL_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
log_info "Docker version: $FINAL_VERSION"
log_info "Docker API version: $(docker version --format '{{.Server.APIVersion}}' 2>/dev/null || echo "unknown")"

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
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - traefik_acme:/letsencrypt
      - $HOME/aivus/traefik.yml:/etc/traefik/traefik.yml:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik-dashboard.rule=Host(`traefik.${SERVICE_DOMAIN}`)"
      - "traefik.http.routers.traefik-dashboard.entrypoints=websecure"
      - "traefik.http.routers.traefik-dashboard.tls.certresolver=letsencrypt"
      - "traefik.http.routers.traefik-dashboard.service=api@internal"
      - "traefik.http.routers.traefik-dashboard.middlewares=traefik-auth"
      - "traefik.http.middlewares.traefik-auth.basicauth.users=${TRAEFIK_BASIC_AUTH}"

  # ===========================================
  # PostgreSQL Database
  # ===========================================
  postgres:
    image: postgres:17
    container_name: aivus_postgres
    restart: unless-stopped
    networks:
      - aivus
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - postgres_backups:/backups
      - $HOME/aivus/maintenance:/usr/local/bin/maintenance:ro
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
    command: /start
    environment:
      # Django Core
      DJANGO_DEBUG: True
      DEBUG: True
      DJANGO_DEBUG_TOOLBAR: True
      DJANGO_SETTINGS_MODULE: config.settings.production
      DJANGO_SECRET_KEY: ${DJANGO_SECRET_KEY}
      DJANGO_ALLOWED_HOSTS: ${APP_DOMAIN},www.${APP_DOMAIN},api.${SERVICE_DOMAIN},django
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
      
      # Email (SMTP via Mailpit for testing)
      EMAIL_BACKEND: django.core.mail.backends.smtp.EmailBackend
      EMAIL_HOST: mailpit
      EMAIL_PORT: 1025
      EMAIL_USE_TLS: "False"
      EMAIL_USE_SSL: "False"
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
      # Django on api.aivus.co - all routes (API, Admin, Static)
      - "traefik.http.routers.django.rule=Host(`api.${SERVICE_DOMAIN}`)"
      - "traefik.http.routers.django.entrypoints=websecure"
      - "traefik.http.routers.django.tls.certresolver=letsencrypt"
      - "traefik.http.services.django.loadbalancer.server.port=5000"

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
      DJANGO_ADMIN_URL: ${DJANGO_ADMIN_URL}
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      REDIS_URL: redis://redis:6379/0
      DATABASE_URL: postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      DJANGO_GCP_STORAGE_BUCKET_NAME: ${DJANGO_GCP_STORAGE_BUCKET_NAME}
      BREVO_API_KEY: ${BREVO_API_KEY}
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
  # Mailpit - Email Testing (Always enabled for development)
  # ===========================================
  mailpit:
    image: axllent/mailpit:latest
    container_name: aivus_mailpit
    restart: unless-stopped
    networks:
      - aivus
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
      # Frontend on go.aivus.co - all routes
      - "traefik.http.routers.frontend.rule=Host(`${APP_DOMAIN}`)"
      - "traefik.http.routers.frontend.entrypoints=websecure"
      - "traefik.http.routers.frontend.tls.certresolver=letsencrypt"
      - "traefik.http.services.frontend.loadbalancer.server.port=3000"
EOF


log_success "Configuration files ready"

# ============================================
# 4.5. Create Traefik and Maintenance configs
# ============================================
log_info "Step 4.5/10: Creating additional configuration files..."

# Create Traefik configuration
log_info "Creating traefik.yml..."
cat > $HOME/aivus/traefik.yml << 'TRAEFIK_EOF'
log:
  level: INFO

api:
  dashboard: true

entryPoints:
  web:
    address: ':80'
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https

  websecure:
    address: ':443'

certificatesResolvers:
  letsencrypt:
    acme:
      email: ACME_EMAIL_PLACEHOLDER
      storage: /letsencrypt/acme.json
      httpChallenge:
        entryPoint: web

providers:
  docker:
    exposedByDefault: false
    network: aivus
TRAEFIK_EOF

# Replace placeholder with actual email
sed -i.bak "s/ACME_EMAIL_PLACEHOLDER/${ACME_EMAIL}/" $HOME/aivus/traefik.yml
rm $HOME/aivus/traefik.yml.bak

log_success "traefik.yml created"

# Create maintenance scripts directory
log_info "Creating Postgres maintenance scripts..."
mkdir -p $HOME/aivus/maintenance/_sourced

# Create constants.sh
cat > $HOME/aivus/maintenance/_sourced/constants.sh << 'EOF'
#!/usr/bin/env bash


BACKUP_DIR_PATH='/backups'
BACKUP_FILE_PREFIX='backup'
EOF

# Create messages.sh
cat > $HOME/aivus/maintenance/_sourced/messages.sh << 'EOF'
#!/usr/bin/env bash


message_newline() {
    echo
}

message_debug()
{
    echo -e "DEBUG: ${@}"
}

message_welcome()
{
    echo -e "\e[1m${@}\e[0m"
}

message_warning()
{
    echo -e "\e[33mWARNING\e[0m: ${@}"
}

message_error()
{
    echo -e "\e[31mERROR\e[0m: ${@}"
}

message_info()
{
    echo -e "\e[37mINFO\e[0m: ${@}"
}

message_suggestion()
{
    echo -e "\e[33mSUGGESTION\e[0m: ${@}"
}

message_success()
{
    echo -e "\e[32mSUCCESS\e[0m: ${@}"
}
EOF

# Create backup script
cat > $HOME/aivus/maintenance/backup << 'EOF'
#!/usr/bin/env bash


### Create a database backup.
###
### Usage:
###     $ docker compose -f <environment>.yml (exec |run --rm) postgres backup


set -o errexit
set -o pipefail
set -o nounset


working_dir="$(dirname ${0})"
source "${working_dir}/_sourced/constants.sh"
source "${working_dir}/_sourced/messages.sh"


message_welcome "Backing up the '${POSTGRES_DB}' database..."


if [[ "${POSTGRES_USER}" == "postgres" ]]; then
    message_error "Backing up as 'postgres' user is not supported. Assign 'POSTGRES_USER' env with another one and try again."
    exit 1
fi

export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
export PGUSER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGDATABASE="${POSTGRES_DB}"

backup_filename="${BACKUP_FILE_PREFIX}_$(date +'%Y_%m_%dT%H_%M_%S').sql.gz"
pg_dump | gzip > "${BACKUP_DIR_PATH}/${backup_filename}"


message_success "'${POSTGRES_DB}' database backup '${backup_filename}' has been created and placed in '${BACKUP_DIR_PATH}'."
EOF

# Create restore script
cat > $HOME/aivus/maintenance/restore << 'EOF'
#!/usr/bin/env bash


### Restore database from a backup.
###
### Parameters:
###     <1> filename of an existing backup.
###
### Usage:
###     $ docker compose -f <environment>.yml (exec |run --rm) postgres restore <1>


set -o errexit
set -o pipefail
set -o nounset


working_dir="$(dirname ${0})"
source "${working_dir}/_sourced/constants.sh"
source "${working_dir}/_sourced/messages.sh"


if [[ -z ${1+x} ]]; then
    message_error "Backup filename is not specified yet it is a required parameter. Make sure you provide one and try again."
    exit 1
fi
backup_filename="${BACKUP_DIR_PATH}/${1}"
if [[ ! -f "${backup_filename}" ]]; then
    message_error "No backup with the specified filename found. Check out the 'backups' maintenance script output to see if there is one and try again."
    exit 1
fi

message_welcome "Restoring the '${POSTGRES_DB}' database from the '${backup_filename}' backup..."

if [[ "${POSTGRES_USER}" == "postgres" ]]; then
    message_error "Restoring as 'postgres' user is not supported. Assign 'POSTGRES_USER' env with another one and try again."
    exit 1
fi

export PGHOST="${POSTGRES_HOST}"
export PGPORT="${POSTGRES_PORT}"
export PGUSER="${POSTGRES_USER}"
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGDATABASE="${POSTGRES_DB}"

message_info "Dropping the database..."
dropdb "${PGDATABASE}"

message_info "Creating a new database..."
createdb --owner="${POSTGRES_USER}"

message_info "Applying the backup to the new database..."
gunzip -c "${backup_filename}" | psql "${POSTGRES_DB}"

message_success "The '${POSTGRES_DB}' database has been restored from the '${backup_filename}' backup."
EOF

# Create backups script
cat > $HOME/aivus/maintenance/backups << 'EOF'
#!/usr/bin/env bash


### View backups.
###
### Usage:
###     $ docker compose -f <environment>.yml (exec |run --rm) postgres backups


set -o errexit
set -o pipefail
set -o nounset


working_dir="$(dirname ${0})"
source "${working_dir}/_sourced/constants.sh"
source "${working_dir}/_sourced/messages.sh"


message_welcome "These are the backups you have got:"

ls -lht "${BACKUP_DIR_PATH}"
EOF

# Create rmbackup script
cat > $HOME/aivus/maintenance/rmbackup << 'EOF'
#!/usr/bin/env bash

### Remove a database backup.
###
### Parameters:
###     <1> filename of a backup to remove.
###
### Usage:
###     $ docker-compose -f <environment>.yml (exec |run --rm) postgres rmbackup <1>


set -o errexit
set -o pipefail
set -o nounset


working_dir="$(dirname ${0})"
source "${working_dir}/_sourced/constants.sh"
source "${working_dir}/_sourced/messages.sh"


if [[ -z ${1+x} ]]; then
    message_error "Backup filename is not specified yet it is a required parameter. Make sure you provide one and try again."
    exit 1
fi
backup_filename="${BACKUP_DIR_PATH}/${1}"
if [[ ! -f "${backup_filename}" ]]; then
    message_error "No backup with the specified filename found. Check out the 'backups' maintenance script output to see if there is one and try again."
    exit 1
fi

message_welcome "Removing the '${backup_filename}' backup file..."

rm -r "${backup_filename}"

message_success "The '${backup_filename}' database backup has been removed."
EOF

# Make scripts executable
chmod +x $HOME/aivus/maintenance/backup
chmod +x $HOME/aivus/maintenance/restore
chmod +x $HOME/aivus/maintenance/backups
chmod +x $HOME/aivus/maintenance/rmbackup
chmod +x $HOME/aivus/maintenance/_sourced/constants.sh
chmod +x $HOME/aivus/maintenance/_sourced/messages.sh

log_success "Maintenance scripts created and made executable"

# ============================================
# 5. Check for existing installation
# ============================================
log_info "Step 5/10: Checking for existing installation..."

ENV_FILE="$HOME/aivus/.env"
CREDENTIALS_FILE="$HOME/aivus/CREDENTIALS.txt"

if [ -f "$ENV_FILE" ]; then
    log_warning "Found existing installation at ~/aivus/"
    log_warning "Existing .env file detected!"
    echo ""
    echo "Options:"
    echo "  1) Keep existing secrets and configuration (SAFE - recommended)"
    echo "  2) Generate new secrets (DANGEROUS - will break existing database!)"
    echo "  3) Exit and backup manually"
    echo ""
    read -p "Choose option [1]: " REINSTALL_OPTION
    REINSTALL_OPTION=${REINSTALL_OPTION:-1}
    
    if [ "$REINSTALL_OPTION" = "3" ]; then
        log_info "Exiting. Please backup your data first:"
        echo "  cp ~/aivus/.env ~/aivus/.env.backup"
        echo "  cp ~/aivus/CREDENTIALS.txt ~/aivus/CREDENTIALS.txt.backup"
        exit 0
    elif [ "$REINSTALL_OPTION" = "1" ]; then
        log_info "Loading existing secrets from .env..."
        EXISTING_INSTALL=true
        
        # Load existing .env safely (avoid executing special characters)
        LOADED_COUNT=0
        while IFS= read -r line; do
            # Skip comments and empty lines
            [[ $line =~ ^[[:space:]]*# ]] && continue
            [[ -z $line ]] && continue
            [[ ! $line =~ = ]] && continue
            
            # Extract key and value
            key="${line%%=*}"
            value="${line#*=}"
            
            # Trim whitespace from key
            key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            
            # Skip if key is empty
            [[ -z $key ]] && continue
            
            # Remove leading/trailing whitespace and quotes from value
            value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            
            # Export the variable (using eval to handle special characters safely)
            if eval "export $key=\"\$value\"" 2>/dev/null; then
                LOADED_COUNT=$((LOADED_COUNT + 1))
            else
                log_warning "Failed to load variable: $key (skipping)"
            fi
        done < "$ENV_FILE"
        
        log_success "Existing secrets loaded successfully ($LOADED_COUNT variables)"
        log_info "Will preserve: Database password, Django secrets, API keys, etc."
        
        # Verify critical variables are loaded
        if [ -z "$POSTGRES_PASSWORD" ] || [ -z "$DJANGO_SECRET_KEY" ]; then
            log_error "Critical secrets not found in .env file!"
            log_error "POSTGRES_PASSWORD or DJANGO_SECRET_KEY is missing."
            log_error "Please check your .env file or choose option 2 to regenerate."
            exit 1
        fi
    else
        log_error "⚠️  WARNING: Generating new secrets will break your existing database!"
        log_error "⚠️  You will need to:"
        log_error "     1. Backup your database"
        log_error "     2. Drop and recreate it with new password"
        log_error "     3. Restore from backup"
        echo ""
        read -p "Type 'I UNDERSTAND' to continue: " CONFIRM
        if [ "$CONFIRM" != "I UNDERSTAND" ]; then
            log_error "Aborted. Please backup your data first."
            exit 1
        fi
        EXISTING_INSTALL=false
    fi
else
    log_info "No existing installation found. Will generate new secrets."
    EXISTING_INSTALL=false
fi

# ============================================
# 6. Generate or load secrets
# ============================================

# Define helper functions (used in both new and existing installations)
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
    local hash=""
    
    # Try to use htpasswd (native or via Docker)
    if command -v htpasswd &> /dev/null; then
        hash=$(htpasswd -nb "$username" "$password")
    else
        # Use Docker to generate htpasswd hash
        hash=$(docker run --rm httpd:alpine htpasswd -nb "$username" "$password" 2>/dev/null)
    fi
    
    # Escape $ for docker-compose ($ -> $$)
    # This is critical for Traefik to parse the hash correctly
    echo "$hash" | sed 's/\$/\$\$/g'
    
    echo "# Username: $username, Password: $password" >&2
}

if [ "$EXISTING_INSTALL" = false ]; then
    log_info "Step 6/10: Generating secrets..."
    
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
    
    log_success "Secrets generated"
else
    log_info "Step 6/10: Using existing secrets..."
    log_success "Secrets loaded from existing .env"
fi

# ============================================
# 7. Prompt for configuration
# ============================================
log_info "Step 7/10: Configuration..."

if [ "$EXISTING_INSTALL" = true ]; then
    log_info "Using existing configuration from .env"
    log_info "Current APP_DOMAIN: ${APP_DOMAIN}"
    log_info "Current SERVICE_DOMAIN: ${SERVICE_DOMAIN}"
    echo ""
    read -p "Do you want to update configuration? (y/n) [n]: " UPDATE_CONFIG
    UPDATE_CONFIG=${UPDATE_CONFIG:-n}
    
    if [ "$UPDATE_CONFIG" = "n" ]; then
        log_info "Keeping existing configuration"
        # Ensure PGADMIN_EMAIL is set (might not exist in old .env)
        PGADMIN_EMAIL=${PGADMIN_DEFAULT_EMAIL:-hi@aivus.co}
        ACME_EMAIL=${ACME_EMAIL:-hi@aivus.co}
        GCP_BUCKET_NAME=${DJANGO_GCP_STORAGE_BUCKET_NAME:-aivus-production-media}
        
        # Ensure BREVO_API_KEY has a value (Django requires it)
        if [ -z "$BREVO_API_KEY" ]; then
            BREVO_API_KEY="dummy-key-not-configured"
            log_warning "BREVO_API_KEY was empty, set to dummy value"
        fi
    else
        log_info "Updating configuration..."
        read -p "Enter your APPLICATION domain [${APP_DOMAIN}]: " NEW_APP_DOMAIN
        APP_DOMAIN=${NEW_APP_DOMAIN:-$APP_DOMAIN}
        
        read -p "Enter your SERVICE domain [${SERVICE_DOMAIN}]: " NEW_SERVICE_DOMAIN
        SERVICE_DOMAIN=${NEW_SERVICE_DOMAIN:-$SERVICE_DOMAIN}
        
        read -p "Enter your email for Let's Encrypt [${ACME_EMAIL}]: " NEW_ACME_EMAIL
        ACME_EMAIL=${NEW_ACME_EMAIL:-$ACME_EMAIL}
        
        read -p "Enter your email for pgAdmin [${PGADMIN_DEFAULT_EMAIL}]: " NEW_PGADMIN_EMAIL
        PGADMIN_EMAIL=${NEW_PGADMIN_EMAIL:-$PGADMIN_DEFAULT_EMAIL}
        
        read -p "Enter GCP Storage Bucket name [${DJANGO_GCP_STORAGE_BUCKET_NAME}]: " NEW_GCP_BUCKET_NAME
        GCP_BUCKET_NAME=${NEW_GCP_BUCKET_NAME:-$DJANGO_GCP_STORAGE_BUCKET_NAME}
        
        # Keep existing OAuth/API keys unless user wants to change
        read -p "Update Google OAuth credentials? (y/n) [n]: " UPDATE_OAUTH
        if [ "$UPDATE_OAUTH" = "y" ]; then
            read -p "Enter Google OAuth Client ID [${AUTH_GOOGLE_ID}]: " NEW_AUTH_GOOGLE_ID
            AUTH_GOOGLE_ID=${NEW_AUTH_GOOGLE_ID:-$AUTH_GOOGLE_ID}
            read -p "Enter Google OAuth Client Secret: " NEW_AUTH_GOOGLE_SECRET
            if [ -n "$NEW_AUTH_GOOGLE_SECRET" ]; then
                AUTH_GOOGLE_SECRET=$NEW_AUTH_GOOGLE_SECRET
            fi
        fi
        
        read -p "Update Brevo API key? (y/n) [n]: " UPDATE_BREVO
        if [ "$UPDATE_BREVO" = "y" ]; then
            read -p "Enter Brevo API key: " NEW_BREVO_API_KEY
            if [ -n "$NEW_BREVO_API_KEY" ]; then
                BREVO_API_KEY=$NEW_BREVO_API_KEY
            fi
        fi
        
        read -p "Update Sentry DSN? (y/n) [n]: " UPDATE_SENTRY
        if [ "$UPDATE_SENTRY" = "y" ]; then
            read -p "Enter Sentry DSN: " NEW_SENTRY_DSN
            if [ -n "$NEW_SENTRY_DSN" ]; then
                SENTRY_DSN=$NEW_SENTRY_DSN
            fi
        fi
    fi
else
    # Fresh installation - ask for everything
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
        BREVO_API_KEY="dummy-key-not-configured"
        log_warning "Brevo API not configured. Using dummy value. You can add real key to .env later if needed."
    fi
    
    # Optional: Sentry
    read -p "Do you have Sentry DSN? (y/n): " HAS_SENTRY
    if [ "$HAS_SENTRY" = "y" ]; then
        read -p "Enter Sentry DSN: " SENTRY_DSN
    else
        SENTRY_DSN=""
        log_warning "Sentry not configured. You can add it to .env later if needed."
    fi
fi

# ============================================
# 8. Create .env file
# ============================================
log_info "Step 8/10: Creating .env file..."

# Backup existing .env if it exists
if [ -f "$ENV_FILE" ] && [ "$EXISTING_INSTALL" = true ]; then
    BACKUP_FILE="$HOME/aivus/.env.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$ENV_FILE" "$BACKUP_FILE"
    log_success "Existing .env backed up to: $BACKUP_FILE"
fi

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
POSTGRES_HOST=postgres
POSTGRES_PORT=5432
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
DJANGO_ALLOWED_HOSTS=api.${SERVICE_DOMAIN},django
DJANGO_ADMIN_URL=admin/
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
EOF

chmod 600 $HOME/aivus/.env

log_success ".env file created at ~/aivus/.env"

# ============================================
# 9. Save credentials to file
# ============================================
log_info "Step 9/10: Saving credentials..."

# Backup existing credentials if they exist
if [ -f "$CREDENTIALS_FILE" ] && [ "$EXISTING_INSTALL" = true ]; then
    BACKUP_CREDS="$HOME/aivus/CREDENTIALS.txt.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CREDENTIALS_FILE" "$BACKUP_CREDS"
    log_success "Existing credentials backed up to: $BACKUP_CREDS"
fi

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
URL: https://api.${SERVICE_DOMAIN}/admin/
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
# 10. Setup GCP credentials
# ============================================
log_info "Step 10/10: GCP credentials setup..."

log_warning "Please copy your GCP service account JSON to ~/data/gcp-credentials.json"
log_info "Example: scp gcp-credentials.json user@server:~/data/"

read -p "Press Enter when you've copied the GCP credentials file..."

if [ -f "$HOME/data/gcp-credentials.json" ]; then
    chmod 644 "$HOME/data/gcp-credentials.json"
    log_success "GCP credentials found and permissions set (readable by containers)"
else
    log_warning "GCP credentials not found. You'll need to add it later."
fi

# ============================================
# 11. Configure GCP Docker authentication
# ============================================
log_info "Step 11/10: Configuring GCP Docker authentication..."

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

if [ "$EXISTING_INSTALL" = true ]; then
    log_success "✅ Existing installation updated safely!"
    echo ""
    log_info "What was preserved:"
    echo "  ✓ Database password (no need to recreate DB)"
    echo "  ✓ Django secret keys"
    echo "  ✓ API keys and HMAC secrets"
    echo "  ✓ All authentication credentials"
    echo ""
    log_info "Backups created:"
    if [ -n "$BACKUP_FILE" ]; then
        echo "  - .env: $BACKUP_FILE"
    fi
    if [ -n "$BACKUP_CREDS" ]; then
        echo "  - Credentials: $BACKUP_CREDS"
    fi
    echo ""
fi

log_info "Next steps:"
echo ""
echo "1. Review configuration:"
echo "   cat ~/aivus/.env"
echo ""
echo "2. Review credentials:"
echo "   cat ~/aivus/CREDENTIALS.txt"
echo ""

if [ "$EXISTING_INSTALL" = true ]; then
    echo "3. Restart services (if already running):"
    echo "   cd ~/aivus"
    echo "   docker compose -f docker-compose.production.yml down"
    echo "   docker compose -f docker-compose.production.yml up -d"
    echo ""
    echo "4. Check status:"
    echo "   docker compose -f docker-compose.production.yml ps"
    echo ""
    echo "5. View logs:"
    echo "   docker compose -f docker-compose.production.yml logs -f"
else
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
fi

echo ""
log_info "Your application will be available at:"
echo "  - Frontend: https://${APP_DOMAIN}"
echo "  - API: https://${APP_DOMAIN}/api/v1/"
echo "  - Admin: https://api.${SERVICE_DOMAIN}/admin/"
echo "  - pgAdmin: https://pgadmin.${SERVICE_DOMAIN}"
echo "  - Flower: https://flower.${SERVICE_DOMAIN}"
echo "  - Mailpit: https://mailpit.${SERVICE_DOMAIN}"
echo "  - Traefik: https://traefik.${SERVICE_DOMAIN}"
echo ""
log_warning "IMPORTANT: Keep ~/aivus/CREDENTIALS.txt secure!"
echo ""
