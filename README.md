# infra

**Infrastructure and deployment** for ShopWorthy — Docker Compose, Terraform, and Kubernetes manifests. Primary entrypoint for running the full stack locally.

Part of the [ShopWorthy](https://github.com/ShopWorthy) organization.

## Purpose

This repository contains:

- **Docker Compose** — Run the entire ShopWorthy platform locally
- **Terraform** — AWS infrastructure (with intentional misconfigurations for training)
- **Kubernetes** — K8s manifests for deployment
- **Scripts** — Database seed and init scripts

## Prerequisites

- Docker and Docker Compose
- Git (to clone all six ShopWorthy repos)

## Quick Start (Full Stack)

Clone all repositories into the same parent directory:

```bash
git clone https://github.com/ShopWorthy/infra
git clone https://github.com/ShopWorthy/frontend
git clone https://github.com/ShopWorthy/api
git clone https://github.com/ShopWorthy/inventory
git clone https://github.com/ShopWorthy/payments
git clone https://github.com/ShopWorthy/admin
```

Start the full stack:

```bash
cd infra
docker compose up --build
```

After services are healthy, seed the database:

```bash
./scripts/seed.sh
```

## Service URLs (after startup)

| Service | URL |
|---------|-----|
| Customer Storefront | http://localhost:3000 |
| Primary API | http://localhost:4000 |
| Inventory API | http://localhost:5000 |
| Payments API | http://localhost:6000 |
| Admin Panel | http://localhost:8080 |
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

## Repository Structure

```
infra/
├── docker-compose.yml    # Full local stack (primary entry point)
├── .env.example          # Template env file
├── terraform/            # AWS infra
├── k8s/                  # Kubernetes manifests
├── scripts/              # seed.sh, init-db.sql
└── README.md
```

## Related Repositories

- [frontend](https://github.com/ShopWorthy/frontend)
- [api](https://github.com/ShopWorthy/api)
- [inventory](https://github.com/ShopWorthy/inventory)
- [payments](https://github.com/ShopWorthy/payments)
- [admin](https://github.com/ShopWorthy/admin)
