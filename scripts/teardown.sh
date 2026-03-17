#!/bin/bash
# ShopWorthy teardown script (Linux/macOS)
# Usage: ./scripts/teardown.sh [--clean]
#
# Flags:
#   --clean   Also delete sibling repo directories (frontend, api, etc.)

set -e

CLEAN=false
for arg in "$@"; do
    if [ "$arg" = "--clean" ]; then
        CLEAN=true
    fi
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PARENT_DIR="$(cd "${INFRA_DIR}/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "====================================================="
echo " ShopWorthy — Teardown"
echo "====================================================="
echo ""

# Determine compose command
if docker compose version &> /dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &> /dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${YELLOW}WARNING: Docker Compose not found, skipping container teardown${NC}"
    COMPOSE_CMD=""
fi

if [ -n "$COMPOSE_CMD" ]; then
    echo "==> Stopping all containers..."
    cd "$INFRA_DIR"
    $COMPOSE_CMD down -v
    echo -e "   ${GREEN}[ok] Containers stopped and volumes removed${NC}"
fi

echo ""

if [ "$CLEAN" = true ]; then
    echo -e "${YELLOW}==> --clean flag set. Removing sibling repositories...${NC}"
    REPOS=(frontend api inventory payments admin)
    for repo in "${REPOS[@]}"; do
        target="${PARENT_DIR}/${repo}"
        if [ -d "$target" ]; then
            echo "   Removing ${target}..."
            rm -rf "$target"
            echo -e "   ${GREEN}[ok] ${repo}${NC}"
        else
            echo "   [skip] ${repo} not found"
        fi
    done
    echo ""
fi

echo -e "${GREEN}Teardown complete.${NC}"
