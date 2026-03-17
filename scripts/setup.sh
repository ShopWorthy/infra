#!/bin/bash
# ShopWorthy full-stack setup script (Linux/macOS)
# Usage: ./scripts/setup.sh [--skip-clone]
#
# This script:
#   1. Checks prerequisites (Docker, Docker Compose, git)
#   2. Clones all ShopWorthy repos as siblings of the infra directory
#   3. Builds and starts all services via Docker Compose
#   4. Waits for health checks to pass
#   5. Seeds the database
#   6. Prints service URLs and credentials

set -e

SKIP_CLONE=false
for arg in "$@"; do
    if [ "$arg" = "--skip-clone" ]; then
        SKIP_CLONE=true
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PARENT_DIR="$(cd "${INFRA_DIR}/.." && pwd)"

# Ensure sibling scripts are executable (e.g. after clone without execute bits)
chmod +x "${SCRIPT_DIR}/seed.sh" "${SCRIPT_DIR}/teardown.sh" 2>/dev/null || true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "====================================================="
echo " ShopWorthy — Full Stack Setup"
echo "====================================================="
echo ""

# --- 1. Check prerequisites ---
echo "==> Checking prerequisites..."

check_cmd() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}ERROR: '$1' is not installed or not on PATH.${NC}"
        echo "       $2"
        exit 1
    fi
    echo "   [ok] $1"
}

check_cmd docker      "Install Docker: https://docs.docker.com/get-docker/"
check_cmd git         "Install git: https://git-scm.com/downloads"

# Check Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}ERROR: Docker daemon is not running. Please start Docker and try again.${NC}"
    exit 1
fi
echo "   [ok] Docker daemon running"

# Check Docker Compose (v2 plugin or standalone)
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}ERROR: Docker Compose is not available.${NC}"
    echo "       Install: https://docs.docker.com/compose/install/"
    exit 1
fi
echo "   [ok] Docker Compose ($COMPOSE_CMD)"

echo ""

# --- 2. Clone repos ---
if [ "$SKIP_CLONE" = false ]; then
    echo "==> Cloning ShopWorthy repositories into ${PARENT_DIR}..."
    REPOS=(frontend api inventory payments admin)
    for repo in "${REPOS[@]}"; do
        target="${PARENT_DIR}/${repo}"
        if [ -d "$target" ]; then
            echo "   [skip] ${repo} already exists"
        else
            echo "   Cloning ${repo}..."
            git clone "https://github.com/ShopWorthy/${repo}.git" "$target"
            echo "   [ok] ${repo}"
        fi
    done
    echo ""
fi

# --- 3. Start services ---
echo "==> Building and starting all services..."
echo "    (First build downloads dependencies — this may take 5-10 minutes)"
cd "$INFRA_DIR"

# Ensure data directory exists for API volume mount
mkdir -p "$INFRA_DIR/data"

$COMPOSE_CMD up --build -d
echo ""

# --- 4. Wait for health checks ---
echo "==> Waiting for all services to become healthy..."

wait_for_health() {
    local name="$1"
    local url="$2"
    local max_attempts="${3:-30}"
    local attempt=0

    until curl -sf "$url" > /dev/null 2>&1; do
        attempt=$((attempt + 1))
        if [ $attempt -ge $max_attempts ]; then
            echo -e "   ${RED}[timeout] ${name} did not become healthy in time${NC}"
            echo "   Run: $COMPOSE_CMD logs $name"
            return 1
        fi
        echo "   Waiting for ${name}... (${attempt}/${max_attempts})"
        sleep 5
    done
    echo -e "   ${GREEN}[ok] ${name}${NC}"
}

wait_for_health "postgres"  "http://localhost:4000/internal/health" 20
wait_for_health "api"       "http://localhost:4000/internal/health" 20
wait_for_health "inventory" "http://localhost:5000/health" 20
wait_for_health "payments"  "http://localhost:6000/actuator/health" 40
wait_for_health "frontend"  "http://localhost:3000" 20
wait_for_health "admin"     "http://localhost:8080/admin/login" 20
echo ""

# --- 5. Seed database ---
echo "==> Seeding databases..."
bash "${SCRIPT_DIR}/seed.sh"
echo ""

# --- 6. Print summary ---
echo ""
echo -e "${GREEN}====================================================="
echo " ShopWorthy is running!"
echo "=====================================================${NC}"
echo ""
echo " Service URLs:"
echo "   Customer Storefront:   http://localhost:3000"
echo "   Primary API:           http://localhost:4000"
echo "   Inventory Service:     http://localhost:5000"
echo "   Payments Service:      http://localhost:6000"
echo "   Admin Panel:           http://localhost:8080"
echo "   H2 Console:            http://localhost:6000/h2-console"
echo "   Spring Actuator:       http://localhost:6000/actuator"
echo "   PostgreSQL:            localhost:5432"
echo ""
echo " Default Credentials:"
echo "   Admin Panel:    admin / admin"
echo "   PostgreSQL:     shopworthy / shopworthy123"
echo "   H2 Console:     sa / (empty)"
echo "   customer1:      customer1 / password123"
echo "   customer2:      customer2 / password123"
echo ""
echo " Useful Commands:"
echo "   View logs:      $COMPOSE_CMD logs -f [service]"
echo "   Restart one:    $COMPOSE_CMD up --build -d [service]"
echo "   Stop all:       $COMPOSE_CMD down"
echo "   Full teardown:  ./scripts/teardown.sh --clean"
echo ""
