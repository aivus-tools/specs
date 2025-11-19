#!/bin/bash

# ============================================
# Aivus Backend Deployment Script
# ============================================
# This script is called from GitHub Actions
# to deploy the backend to production.
#
# Usage:
#   ./deploy-backend.sh [tag]
#
# Example:
#   ./deploy-backend.sh v1.2.3
#   ./deploy-backend.sh latest
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get tag from argument or use 'latest'
TAG=${1:-latest}

log_info "Starting backend deployment (tag: ${TAG})..."

# Change to aivus directory
cd ~/aivus || {
    log_error "Directory ~/aivus not found"
    exit 1
}

# Check if docker-compose.production.yml exists
if [ ! -f docker-compose.production.yml ]; then
    log_error "docker-compose.production.yml not found"
    exit 1
fi

# Check if .env exists
if [ ! -f .env ]; then
    log_error ".env file not found"
    exit 1
fi

# Update BACKEND_TAG in .env
log_info "Updating BACKEND_TAG to ${TAG}..."
sed -i.bak "s/^BACKEND_TAG=.*/BACKEND_TAG=${TAG}/" .env
rm .env.bak

# Pull new backend image
log_info "Pulling backend image..."
docker compose -f docker-compose.production.yml pull django celeryworker celerybeat flower

# Recreate backend services
log_info "Recreating backend services..."
docker compose -f docker-compose.production.yml up -d django celeryworker celerybeat flower

# Wait for Django to be healthy
log_info "Waiting for Django to be ready..."
sleep 10

# Run migrations
log_info "Running database migrations..."
docker compose -f docker-compose.production.yml exec -T django python manage.py migrate --noinput

# Collect static files (if needed)
log_info "Collecting static files..."
docker compose -f docker-compose.production.yml exec -T django python manage.py collectstatic --noinput || true

# Check service status
log_info "Checking service status..."
docker compose -f docker-compose.production.yml ps django celeryworker celerybeat flower

# Show recent logs
log_info "Recent logs:"
docker compose -f docker-compose.production.yml logs --tail=50 django

log_success "Backend deployment completed!"

# Summary
echo ""
echo "============================================"
log_success "Deployment Summary"
echo "============================================"
echo "Tag: ${TAG}"
echo "Services updated:"
echo "  - django"
echo "  - celeryworker"
echo "  - celerybeat"
echo "  - flower"
echo ""
log_info "Check logs with:"
echo "  docker compose -f docker-compose.production.yml logs -f django"
echo ""

