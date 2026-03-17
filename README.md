# infra

**Infrastructure and deployment** for ShopWorthy — Docker Compose, Terraform, and Kubernetes manifests. Primary entrypoint for running the full stack locally.

Part of the [ShopWorthy](https://github.com/ShopWorthy) organization.

> **Security Notice:** For training use only. Do not deploy on a public network or with real credentials.

---

## One-Command Quickstart

Clone this repo, then run a single script to clone all sibling repos, build everything, and start the full stack:

**Linux / macOS:**
```bash
git clone https://github.com/ShopWorthy/infra
cd infra
chmod +x scripts/setup.sh
./scripts/setup.sh
```

**Windows (PowerShell):**
```powershell
git clone https://github.com/ShopWorthy/infra
cd infra
.\scripts\setup.ps1
```

The setup script will:
1. Verify Docker, Docker Compose, and git are installed and running
2. Clone all sibling repos (`frontend`, `api`, `inventory`, `payments`, `admin`) into the same parent directory
3. Run `docker compose up --build -d` to build and start all services
4. Wait for each service health check to pass
5. Seed the databases with products, users, and sample orders
6. Print a summary of service URLs and default credentials

First run takes **5–10 minutes** while Maven, npm, and pip download dependencies.

---

## Service URLs (after startup)

| Service | URL |
|---------|-----|
| Customer Storefront | http://localhost:3000 |
| Primary API | http://localhost:4000 |
| API (OpenAPI / Swagger UI) | http://localhost:4000/api-docs |
| Inventory API | http://localhost:5000 |
| Inventory (OpenAPI / Swagger UI) | http://localhost:5000/docs |
| Payments API | http://localhost:6000 |
| Payments (OpenAPI / Swagger UI) | http://localhost:6000/swagger-ui.html |
| Admin Panel | http://localhost:8080 |
| Admin API (OpenAPI / Swagger UI) | http://localhost:8080/admin/api-docs |
| H2 Console | http://localhost:6000/h2-console |
| Spring Actuator | http://localhost:6000/actuator |
| PostgreSQL | localhost:5432 |

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Admin Panel | admin | admin |
| PostgreSQL | shopworthy | shopworthy123 |
| H2 Console | sa | (empty) |
| Demo Customer | customer1 | password123 |
| Demo Customer | customer2 | password123 |

---

## Architecture

```
                     External Users
                          |
                      :3000 (HTTP)
                          |
                    ┌─────▼──────┐
                    │  frontend  │  React 18 + TypeScript
                    └─────┬──────┘
                          |
                      :4000 (REST)
                          |
                    ┌─────▼──────┐
                    │    api     │  Node.js 20 + Express + SQLite
                    └──┬──────┬──┘
                       |      |
              :5000    |      |   :6000
        ┌──────▼────┐  |  ┌───▼────────┐
        │ inventory │  |  │  payments  │  Java 17 + Spring Boot
        │  FastAPI  │  |  │    H2 DB   │
        └───────────┘  |  └────────────┘
                       |
                  ┌────▼────┐
                  │ postgres│  PostgreSQL 15
                  └─────────┘
                       |
                  ┌────▼────┐
                  │  admin  │  Vue 3 + Flask (shares postgres)
                  └─────────┘
                       |
                   :8080 (HTTP)
                       |
                  Admin Users
```

---

## Manual Setup (step-by-step)

If you prefer to control each step manually:

### Prerequisites
- Docker and Docker Compose
- Git

### 1. Clone all repositories into the same parent directory

```bash
git clone https://github.com/ShopWorthy/infra
git clone https://github.com/ShopWorthy/frontend
git clone https://github.com/ShopWorthy/api
git clone https://github.com/ShopWorthy/inventory
git clone https://github.com/ShopWorthy/payments
git clone https://github.com/ShopWorthy/admin
```

The directory layout must be:
```
parent/
├── infra/        ← this repo
├── frontend/
├── api/
├── inventory/
├── payments/
└── admin/
```

### 2. Start the full stack

```bash
cd infra
docker compose up --build
```

### 3. Seed the database (in a separate terminal)

Wait until all services are healthy, then:

```bash
./scripts/seed.sh
```

---

## Individual Service Development

To run a single service outside Docker for local development:

### frontend (React + Vite)
```bash
cd frontend
npm install
npm run dev        # http://localhost:3000
```
Requires: Node.js 20+

### api (Node.js + Express)
```bash
cd api
npm install
node src/index.js  # http://localhost:4000
```
Requires: Node.js 20+

### inventory (Python + FastAPI)
```bash
cd inventory
pip install -r requirements.txt
uvicorn app.main:app --reload --port 5000
```
Requires: Python 3.11+, a running PostgreSQL instance

### payments (Java + Spring Boot)
```bash
cd payments
mvn spring-boot:run   # http://localhost:6000
```
Requires: Java 17+, Maven 3.9+

### admin (Flask + Vue)
```bash
# Backend
cd admin/backend
pip install -r requirements.txt
python app.py       # http://localhost:8080

# Frontend (separate terminal, for hot-reload dev)
cd admin/frontend
npm install
npm run dev        # http://localhost:8081
```
Requires: Python 3.11+, Node.js 20+, running PostgreSQL

---

## Troubleshooting

### Port already in use
If a port is occupied, stop the conflicting process or change the mapping in `docker-compose.yml`:
```bash
# Find what's using a port (Linux/macOS)
lsof -i :3000
# Windows
netstat -ano | findstr :3000
```

Ports used: `3000`, `4000`, `5000`, `6000`, `8080`, `5432`, `8082`

### Docker not running
Start Docker Desktop (Windows/macOS) or:
```bash
sudo systemctl start docker   # Linux
```

### First build is slow
Maven (payments), npm (frontend), and pip (inventory) all download dependencies on first build. Subsequent builds use the Docker layer cache and are much faster.

### Rebuild a single service
```bash
docker compose up --build -d api
docker compose up --build -d payments
```

### View service logs
```bash
docker compose logs -f api
docker compose logs -f payments
docker compose logs -f inventory
```

### Full reset (delete all data)
```bash
docker compose down -v   # stops containers AND removes volumes
docker compose up --build -d
./scripts/seed.sh
```

### Full teardown including cloned repos
```bash
./scripts/teardown.sh --clean   # Linux/macOS
.\scripts\teardown.ps1 -Clean   # Windows
```

---

## Repository Structure

```
infra/
├── docker-compose.yml    # Full local stack (primary entry point)
├── .env                  # Environment overrides
├── .env.example          # Template env file
├── terraform/            # AWS infrastructure
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── s3.tf
├── k8s/                  # Kubernetes manifests
│   ├── namespace.yaml
│   ├── *-deployment.yaml
│   └── rbac.yaml
├── scripts/
│   ├── setup.sh          # One-command bootstrap (Linux/macOS)
│   ├── setup.ps1         # One-command bootstrap (Windows)
│   ├── teardown.sh       # Teardown (Linux/macOS)
│   ├── teardown.ps1      # Teardown (Windows)
│   ├── seed.sh           # Database seeder
│   └── init-db.sql       # PostgreSQL schema + seed data
└── README.md
```

---

## Related Repositories

- [frontend](https://github.com/ShopWorthy/frontend)
- [api](https://github.com/ShopWorthy/api)
- [inventory](https://github.com/ShopWorthy/inventory)
- [payments](https://github.com/ShopWorthy/payments)
- [admin](https://github.com/ShopWorthy/admin)
