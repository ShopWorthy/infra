# ShopWorthy full-stack setup script (Windows PowerShell)
# Usage: .\scripts\setup.ps1 [-SkipClone]

param(
    [switch]$SkipClone
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$InfraDir  = Split-Path -Parent $ScriptDir
$ParentDir = Split-Path -Parent $InfraDir

function Write-Green($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Red($msg)   { Write-Host $msg -ForegroundColor Red }
function Write-Yellow($msg){ Write-Host $msg -ForegroundColor Yellow }

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " ShopWorthy - Full Stack Setup (Windows)"            -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. Check prerequisites ---
Write-Host "==> Checking prerequisites..."

function Check-Command($cmd, $hint) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        Write-Red "ERROR: '$cmd' is not installed or not on PATH."
        Write-Host "       $hint"
        exit 1
    }
    Write-Green "   [ok] $cmd"
}

Check-Command "docker"  "Install Docker Desktop: https://docs.docker.com/desktop/windows/"
Check-Command "git"     "Install Git: https://git-scm.com/download/win"

# Check Docker is running
try {
    docker info 2>&1 | Out-Null
    Write-Green "   [ok] Docker daemon running"
} catch {
    Write-Red "ERROR: Docker daemon is not running. Start Docker Desktop and try again."
    exit 1
}

# Check Docker Compose (prefer standalone docker-compose for Windows compatibility)
$ComposeCmd = $null
if (Get-Command "docker-compose" -ErrorAction SilentlyContinue) {
    $ComposeCmd = "docker-compose"
    Write-Green "   [ok] Docker Compose (docker-compose)"
} elseif (Get-Command "docker" -ErrorAction SilentlyContinue) {
    try {
        $null = docker compose version 2>&1
        if ($LASTEXITCODE -eq 0) {
            $ComposeCmd = "docker compose"
            Write-Green "   [ok] Docker Compose (docker compose)"
        }
    } catch {}
}
if (-not $ComposeCmd) {
    Write-Red "ERROR: Docker Compose is not available."
    Write-Host "       Install: https://docs.docker.com/compose/install/"
    exit 1
}

Write-Host ""

# --- 2. Clone repos ---
if (-not $SkipClone) {
    Write-Host "==> Cloning ShopWorthy repositories into $ParentDir..."
    $repos = @("frontend","api","inventory","payments","admin")
    foreach ($repo in $repos) {
        $target = Join-Path $ParentDir $repo
        if (Test-Path $target) {
            Write-Host "   [skip] $repo already exists"
        } else {
            Write-Host "   Cloning $repo..."
            git clone "https://github.com/ShopWorthy/$repo.git" $target
            Write-Green "   [ok] $repo"
        }
    }
    Write-Host ""
}

# --- 3. Start services ---
Write-Host "==> Building and starting all services..."
Write-Host "    (First build downloads dependencies - this may take 5-10 minutes)"
Set-Location $InfraDir

# Ensure data directory exists for API volume mount
if (-not (Test-Path (Join-Path $InfraDir "data"))) {
    New-Item -ItemType Directory -Path (Join-Path $InfraDir "data") -Force | Out-Null
}

Invoke-Expression "$ComposeCmd up --build -d"
Write-Host ""

# --- 4. Wait for health checks ---
Write-Host "==> Waiting for services to become healthy..."

function Wait-ForHealth($name, $url, $maxAttempts = 30) {
    $attempt = 0
    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Green "   [ok] $name"
                return
            }
        } catch {}
        $attempt++
        Write-Host "   Waiting for $name... ($attempt/$maxAttempts)"
        Start-Sleep -Seconds 5
    }
    Write-Red "   [timeout] $name did not become healthy"
    Write-Host "   Run: $ComposeCmd logs $name"
}

Wait-ForHealth "api"       "http://localhost:4000/internal/health" 20
Wait-ForHealth "inventory" "http://localhost:5000/health" 20
Wait-ForHealth "payments"  "http://localhost:6000/actuator/health" 40
Wait-ForHealth "frontend"  "http://localhost:3000" 20
Wait-ForHealth "admin"     "http://localhost:8080/admin/login" 20

Write-Host ""

# --- 5. Seed database ---
Write-Host "==> Seeding databases..."

$pgSeeded = $false
if (Get-Command "psql" -ErrorAction SilentlyContinue) {
    $env:PGPASSWORD = "shopworthy123"
    try {
        psql -h localhost -p 5432 -U shopworthy -d inventory -f "$ScriptDir\init-db.sql" 2>&1 | Out-Null
        $pgSeeded = $true
    } catch {}
}
if (-not $pgSeeded) {
    # Run init script inside postgres container (no psql required on host)
    try {
        Invoke-Expression "$ComposeCmd exec -T postgres psql -U shopworthy -d inventory -f /docker-entrypoint-initdb.d/init.sql" 2>&1 | Out-Null
        $pgSeeded = $true
    } catch {}
}
if ($pgSeeded) {
    Write-Green "   PostgreSQL seeded"
} else {
    Write-Yellow "   PostgreSQL: schema and seed run on first container start (init-db.sql in container)"
}

Write-Host ""

# --- 6. Print summary ---
Write-Host ""
Write-Host "=====================================================" -ForegroundColor Green
Write-Host " ShopWorthy is running!"                              -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
Write-Host ""
Write-Host " Service URLs:"
Write-Host "   Customer Storefront:   http://localhost:3000"
Write-Host "   Primary API:           http://localhost:4000"
Write-Host "   Inventory Service:     http://localhost:5000"
Write-Host "   Payments Service:      http://localhost:6000"
Write-Host "   Admin Panel:           http://localhost:8080"
Write-Host "   H2 Console:            http://localhost:6000/h2-console"
Write-Host "   Spring Actuator:       http://localhost:6000/actuator"
Write-Host "   PostgreSQL:            localhost:5432"
Write-Host ""
Write-Host " From another device (VM, EC2, LAN): use http://<this-machine-ip>:3000 and :8080 (no config change)."
Write-Host ""
Write-Host " Default Credentials:"
Write-Host "   Admin Panel:    admin / admin"
Write-Host "   PostgreSQL:     shopworthy / shopworthy123"
Write-Host "   H2 Console:     sa / (empty)"
Write-Host "   customer1:      customer1 / password123"
Write-Host "   customer2:      customer2 / password123"
Write-Host ""
Write-Host " Useful Commands:"
Write-Host "   View logs:      $ComposeCmd logs -f [service]"
Write-Host "   Restart one:    $ComposeCmd up --build -d [service]"
Write-Host "   Stop all:       $ComposeCmd down"
Write-Host "   Full teardown:  .\scripts\teardown.ps1 -Clean"
Write-Host ""
