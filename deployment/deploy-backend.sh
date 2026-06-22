#!/bin/bash

# ============================================
# Aivus Backend Deployment Script (manual)
# ============================================
# Zero-downtime backend deploy. CI/CD runs the same flow inline from the deploy
# job in .github/workflows/ci.yml; use this script for a manual deploy on the
# server. migrate runs against the freshly pulled image before traffic moves;
# collectstatic uploads to GCS only when needed (skip with SKIP_COLLECTSTATIC=1);
# `docker rollout` swaps django without a downtime window.
#
# Usage:
#   ./deploy-backend.sh [tag]
#   SKIP_COLLECTSTATIC=1 ./deploy-backend.sh latest
# ============================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

TAG=${1:-latest}
SKIP_COLLECTSTATIC=${SKIP_COLLECTSTATIC:-0}

log_info "Starting backend deployment (tag: ${TAG})..."

cd ~/aivus || {
    log_error "Directory ~/aivus not found"
    exit 1
}

[ -f docker-compose.production.yml ] || {
    log_error "docker-compose.production.yml not found"
    exit 1
}
[ -f .env ] || {
    log_error ".env file not found"
    exit 1
}

if ! docker rollout --help >/dev/null 2>&1; then
    log_error "docker-rollout plugin not installed (see install.sh or Specs/deployment/README.md)"
    exit 1
fi

COMPOSE="docker compose -f docker-compose.production.yml"
t0=$(date +%s)

log_info "Updating BACKEND_TAG to ${TAG}..."
sed -i.bak "s/^BACKEND_TAG=.*/BACKEND_TAG=${TAG}/" .env && rm .env.bak

log_info "Pulling backend image..."
$COMPOSE pull django celeryworker celerybeat flower

log_info "Running migrations (one-shot, new image)..."
$COMPOSE run --rm --no-deps --label traefik.enable=false django python manage.py migrate --noinput

if [ "$SKIP_COLLECTSTATIC" = "1" ]; then
    log_info "Skipping collectstatic (SKIP_COLLECTSTATIC=1)"
else
    log_info "Collecting static files (one-shot, new image)..."
    $COMPOSE run --rm --no-deps --label traefik.enable=false django python manage.py collectstatic --noinput
fi

log_info "Rolling django (zero-downtime)..."
$COMPOSE config | grep -q '/healthz' || {
    log_error "django healthcheck missing in live compose; apply Server prerequisites (DEPLOYMENT.md) first"
    exit 1
}
tr0=$(date +%s)
docker rollout -t 180 --wait-after-healthy 10 -f docker-compose.production.yml django
tr1=$(date +%s)
log_success "django healthy, rollout took $((tr1 - tr0))s"

log_info "Recreating celery services..."
$COMPOSE up -d --no-deps celeryworker celerybeat flower

docker image prune -f
$COMPOSE ps django celeryworker celerybeat flower

t1=$(date +%s)
log_success "Backend deployment completed in $((t1 - t0))s (tag: ${TAG})"
