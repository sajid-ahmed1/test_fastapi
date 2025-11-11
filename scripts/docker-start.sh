#!/bin/bash

# Docker startup script for Signal Lab
# Usage: ./scripts/docker-start.sh [dev|prod]

set -euo pipefail

MODE=${1:-prod}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if ! docker info >/dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

if docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
elif docker-compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
else
    print_error "Docker Compose is not available. Please install it and try again."
    exit 1
fi

print_status "Starting Signal Lab in $MODE mode..."
print_status "Cleaning up existing containers..."
$DOCKER_COMPOSE down --remove-orphans

COMPOSE_FILES=(-f docker-compose.yml)
if [[ "$MODE" == "dev" ]]; then
    if [[ -f docker-compose.override.yml ]]; then
        print_status "Using docker-compose.override.yml for development overrides."
        COMPOSE_FILES+=(-f docker-compose.override.yml)
    else
        print_warning "docker-compose.override.yml not found. Starting base compose file only."
    fi
else
    MODE="prod"
fi

print_status "Building and starting services..."
$DOCKER_COMPOSE "${COMPOSE_FILES[@]}" up --build -d

print_status "Waiting for backend service..."
timeout=60
counter=0
while [[ $counter -lt $timeout ]]; do
    if curl -s -f http://localhost:8000/health >/dev/null 2>&1; then
        print_success "Backend service is healthy"
        break
    fi
    sleep 2
    counter=$((counter + 2))
done

if [[ $counter -ge $timeout ]]; then
    print_error "Backend service failed to become healthy in ${timeout}s"
    $DOCKER_COMPOSE logs backend || true
    exit 1
fi

print_status "Waiting for frontend service..."
counter=0
while [[ $counter -lt $timeout ]]; do
    if curl -s -f http://localhost:3000 >/dev/null 2>&1; then
        print_success "Frontend service is healthy"
        break
    fi
    sleep 2
    counter=$((counter + 2))
done

if [[ $counter -ge $timeout ]]; then
    print_error "Frontend service failed to become healthy in ${timeout}s"
    $DOCKER_COMPOSE logs frontend || true
    exit 1
fi

print_success "Signal Lab is now running!"
echo ""
echo "Frontend: http://localhost:3000"
echo "Backend:  http://localhost:8000"
echo "Docs:     http://localhost:8000/docs"
echo "Health:   http://localhost:8000/health"
echo ""
echo "Useful commands:"
echo "  Logs:   $DOCKER_COMPOSE logs -f"
echo "  Stop:   $DOCKER_COMPOSE down"
echo "  Status: $DOCKER_COMPOSE ps"
echo "  Shell backend:  $DOCKER_COMPOSE exec backend bash"
echo "  Shell frontend: $DOCKER_COMPOSE exec frontend sh"
echo ""

print_status "Container status:"
$DOCKER_COMPOSE ps
