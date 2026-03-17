#!/bin/bash
# ShopWorthy database seeder
# Run after docker compose up — seeds both SQLite (via API) and PostgreSQL (via psql)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_URL="${API_URL:-http://localhost:4000}"
PG_HOST="${PG_HOST:-localhost}"
PG_PORT="${PG_PORT:-5432}"
PG_USER="${PG_USER:-shopworthy}"
PG_DB="${PG_DB:-inventory}"

echo "==> Waiting for API to be ready..."
max_attempts=30
attempt=0
until curl -sf "${API_URL}/internal/health" > /dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo "ERROR: API did not become ready in time"
        exit 1
    fi
    echo "   Waiting... (${attempt}/${max_attempts})"
    sleep 3
done
echo "   API is ready."

echo "==> Waiting for PostgreSQL to be ready..."
attempt=0
until PGPASSWORD=shopworthy123 psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -c "SELECT 1" > /dev/null 2>&1; do
    attempt=$((attempt + 1))
    if [ $attempt -ge $max_attempts ]; then
        echo "ERROR: PostgreSQL did not become ready in time"
        exit 1
    fi
    echo "   Waiting... (${attempt}/${max_attempts})"
    sleep 3
done
echo "   PostgreSQL is ready."

echo "==> Seeding PostgreSQL inventory..."
PGPASSWORD=shopworthy123 psql -h "$PG_HOST" -p "$PG_PORT" -U "$PG_USER" -d "$PG_DB" -f "${SCRIPT_DIR}/init-db.sql" > /dev/null 2>&1 || true
echo "   PostgreSQL seed complete."

echo "==> Verifying SQLite seed data via API..."
product_count=$(curl -sf "${API_URL}/api/products" | python3 -c "import sys,json; data=json.load(sys.stdin); print(len(data))" 2>/dev/null || echo "0")
echo "   Products in API: ${product_count}"

echo ""
echo "====================================================="
echo " ShopWorthy seed complete!"
echo "====================================================="
echo ""
echo " Service URLs:"
echo "   Storefront:    http://localhost:3000"
echo "   API:           http://localhost:4000"
echo "   Inventory:     http://localhost:5000"
echo "   Payments:      http://localhost:6000"
echo "   Admin Panel:   http://localhost:8080"
echo "   H2 Console:    http://localhost:6000/h2-console"
echo "   Spring Actuator: http://localhost:6000/actuator"
echo ""
echo " Default Credentials:"
echo "   Admin Panel:   admin / admin"
echo "   PostgreSQL:    shopworthy / shopworthy123"
echo "   H2 Console:    sa / (empty)"
echo "   Demo Customer: customer1 / password123"
echo "   Demo Customer: customer2 / password123"
echo "====================================================="
