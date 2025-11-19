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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Please do not run this script as root"
    exit 1
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
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
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

mkdir -p ~/data/{postgres,postgres-backups,pgadmin,pgbackups,redis,traefik}
mkdir -p ~/aivus

log_success "Directories created"

# ============================================
# 4. Download configuration files
# ============================================
log_info "Step 4/10: Downloading configuration files..."

cd ~/aivus

# Download docker-compose.yml
if [ ! -f docker-compose.production.yml ]; then
    log_info "Downloading docker-compose.production.yml..."
    # TODO: Replace with actual URL
    # curl -sSL https://raw.githubusercontent.com/.../docker-compose.production.yml -o docker-compose.production.yml
    log_warning "Please manually copy docker-compose.production.yml to ~/aivus/"
fi

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

read -p "Enter your domain (e.g., aivus.co): " DOMAIN
read -p "Enter your email for Let's Encrypt: " ACME_EMAIL
read -p "Enter your email for pgAdmin: " PGADMIN_EMAIL

# Optional: Google OAuth
read -p "Do you have Google OAuth credentials? (y/n): " HAS_GOOGLE_OAUTH
if [ "$HAS_GOOGLE_OAUTH" = "y" ]; then
    read -p "Enter Google OAuth Client ID: " AUTH_GOOGLE_ID
    read -p "Enter Google OAuth Client Secret: " AUTH_GOOGLE_SECRET
else
    AUTH_GOOGLE_ID="your-google-client-id"
    AUTH_GOOGLE_SECRET="your-google-client-secret"
    log_warning "Google OAuth not configured. Update .env later."
fi

# Optional: Brevo API
read -p "Do you have Brevo API key? (y/n): " HAS_BREVO
if [ "$HAS_BREVO" = "y" ]; then
    read -p "Enter Brevo API key: " BREVO_API_KEY
else
    BREVO_API_KEY="your-brevo-api-key"
    log_warning "Brevo API not configured. Update .env later."
fi

# Optional: Sentry
read -p "Do you have Sentry DSN? (y/n): " HAS_SENTRY
if [ "$HAS_SENTRY" = "y" ]; then
    read -p "Enter Sentry DSN: " SENTRY_DSN
else
    SENTRY_DSN="your-sentry-dsn"
    log_warning "Sentry not configured. Update .env later."
fi

# ============================================
# 7. Create .env file
# ============================================
log_info "Step 7/10: Creating .env file..."

cat > ~/aivus/.env << EOF
# ============================================
# Aivus Production Environment Variables
# Generated: $(date)
# ============================================

# ===========================================
# DOMAIN & SSL
# ===========================================
DOMAIN=${DOMAIN}
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
DJANGO_ALLOWED_HOSTS=${DOMAIN},www.${DOMAIN}
DJANGO_ADMIN_URL=admin-$(openssl rand -hex 8)/
DJANGO_SECURE_SSL_REDIRECT=True

# ===========================================
# EMAIL (BREVO)
# ===========================================
BREVO_API_KEY=${BREVO_API_KEY}
BREVO_API_URL=https://api.brevo.com/v3/
DJANGO_DEFAULT_FROM_EMAIL=noreply@${DOMAIN}
DJANGO_SERVER_EMAIL=server@${DOMAIN}

# ===========================================
# GCP STORAGE
# ===========================================
DJANGO_GCP_STORAGE_BUCKET_NAME=aivus-production-media

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

chmod 600 ~/aivus/.env

log_success ".env file created at ~/aivus/.env"

# ============================================
# 8. Save credentials to file
# ============================================
log_info "Step 8/10: Saving credentials..."

cat > ~/aivus/CREDENTIALS.txt << EOF
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
URL: https://pgadmin.${DOMAIN}
Email: ${PGADMIN_EMAIL}
Password: ${PGADMIN_PASSWORD}

## Django Admin
URL: https://${DOMAIN}/$(grep DJANGO_ADMIN_URL ~/aivus/.env | cut -d'=' -f2)
# Create superuser with: docker compose exec django python manage.py createsuperuser

## Traefik Dashboard
URL: https://traefik.${DOMAIN}
$(echo "${TRAEFIK_BASIC_AUTH}" | grep "Username:" || echo "Check .env for credentials")

## Flower (Celery Monitoring)
URL: https://flower.${DOMAIN}
$(echo "${FLOWER_BASIC_AUTH}" | grep "Username:" || echo "Check .env for credentials")

## Mailpit (Email Testing)
URL: https://mailpit.${DOMAIN}
$(echo "${MAILPIT_BASIC_AUTH}" | grep "Username:" || echo "Check .env for credentials")

## Secrets
HMAC_SECRET: ${HMAC_SECRET}
API_KEY: ${API_KEY}
NEXTAUTH_SECRET: ${NEXTAUTH_SECRET}

EOF

chmod 600 ~/aivus/CREDENTIALS.txt

log_success "Credentials saved to ~/aivus/CREDENTIALS.txt"

# ============================================
# 9. Setup GCP credentials
# ============================================
log_info "Step 9/10: GCP credentials setup..."

log_warning "Please copy your GCP service account JSON to ~/data/gcp-credentials.json"
log_info "Example: scp gcp-credentials.json user@server:~/data/"

read -p "Press Enter when you've copied the GCP credentials file..."

if [ -f ~/data/gcp-credentials.json ]; then
    chmod 600 ~/data/gcp-credentials.json
    log_success "GCP credentials found and secured"
else
    log_warning "GCP credentials not found. You'll need to add it later."
fi

# ============================================
# 10. Configure GCP Docker authentication
# ============================================
log_info "Step 10/10: Configuring GCP Docker authentication..."

if [ -f ~/data/gcp-credentials.json ]; then
    log_info "Activating service account..."
    gcloud auth activate-service-account --key-file=~/data/gcp-credentials.json
    
    log_info "Configuring Docker for GCP..."
    gcloud auth configure-docker us-central1-docker.pkg.dev
    
    log_success "GCP authentication configured"
else
    log_warning "Skipping GCP authentication (credentials not found)"
    log_info "You'll need to run these commands manually:"
    echo "  gcloud auth activate-service-account --key-file=~/data/gcp-credentials.json"
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
echo "  - Frontend: https://${DOMAIN}"
echo "  - API: https://${DOMAIN}/api/v1/"
echo "  - Admin: https://${DOMAIN}/$(grep DJANGO_ADMIN_URL ~/aivus/.env | cut -d'=' -f2)"
echo "  - pgAdmin: https://pgadmin.${DOMAIN}"
echo "  - Flower: https://flower.${DOMAIN}"
echo "  - Mailpit: https://mailpit.${DOMAIN}"
echo "  - Traefik: https://traefik.${DOMAIN}"
echo ""
log_warning "IMPORTANT: Keep ~/aivus/CREDENTIALS.txt secure!"
echo ""

