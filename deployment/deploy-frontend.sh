#!/bin/bash

# ============================================
# Aivus Frontend Deployment Script
# ============================================
# This script is called from GitHub Actions
# to deploy the frontend to production.
#
# Usage:
#   ./deploy-frontend.sh [tag]
#
# Example:
#   ./deploy-frontend.sh v1.2.3
#   ./deploy-frontend.sh latest
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

log_info "Starting frontend deployment (tag: ${TAG})..."

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

# Update FRONTEND_TAG in .env
log_info "Updating FRONTEND_TAG to ${TAG}..."
sed -i.bak "s/^FRONTEND_TAG=.*/FRONTEND_TAG=${TAG}/" .env
rm .env.bak

# Pull new frontend image
log_info "Pulling frontend image..."
docker compose -f docker-compose.production.yml pull frontend

# Recreate frontend service
log_info "Recreating frontend service..."
docker compose -f docker-compose.production.yml up -d frontend

# Wait for frontend to be healthy
log_info "Waiting for frontend to be ready..."
sleep 10

# Check service status
log_info "Checking service status..."
docker compose -f docker-compose.production.yml ps frontend

# Show recent logs
log_info "Recent logs:"
docker compose -f docker-compose.production.yml logs --tail=50 frontend

log_success "Frontend deployment completed!"

# Summary
echo ""
echo "============================================"
log_success "Deployment Summary"
echo "============================================"
echo "Tag: ${TAG}"
echo "Service updated: frontend"
echo ""
log_info "Check logs with:"
echo "  docker compose -f docker-compose.production.yml logs -f frontend"
echo ""


