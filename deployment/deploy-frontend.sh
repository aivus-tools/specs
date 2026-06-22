#!/bin/bash

# ============================================
# Aivus Frontend Deployment Script (manual)
# ============================================
# Zero-downtime frontend deploy. CI/CD runs the same flow inline from the deploy
# job in the frontend repo's .github/workflows/ci.yml; use this script for a
# manual deploy on the server. `docker rollout` swaps the Next.js container
# without a downtime window on go.aivus.co (Traefik active healthcheck on
# /api/health gates traffic to the booting container).
#
# Usage:
#   ./deploy-frontend.sh [tag]
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

log_info "Starting frontend deployment (tag: ${TAG})..."

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

log_info "Updating FRONTEND_TAG to ${TAG}..."
sed -i.bak "s/^FRONTEND_TAG=.*/FRONTEND_TAG=${TAG}/" .env && rm .env.bak

log_info "Pulling frontend image..."
$COMPOSE pull frontend

$COMPOSE config | grep -q '/api/health' || {
    log_error "frontend healthcheck missing in live compose; apply Server prerequisites (DEPLOYMENT.md) first"
    exit 1
}

log_info "Rolling frontend (zero-downtime)..."
tr0=$(date +%s)
docker rollout -t 180 --wait-after-healthy 10 -f docker-compose.production.yml frontend
tr1=$(date +%s)
log_success "frontend healthy, rollout took $((tr1 - tr0))s"

docker image prune -f
$COMPOSE ps frontend

t1=$(date +%s)
log_success "Frontend deployment completed in $((t1 - t0))s (tag: ${TAG})"
