# ShopWorthy teardown script (Windows PowerShell)
# Usage: .\scripts\teardown.ps1 [-Clean]
#
# Flags:
#   -Clean   Also delete sibling repo directories (frontend, api, etc.)

param(
    [switch]$Clean
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$InfraDir  = Split-Path -Parent $ScriptDir
$ParentDir = Split-Path -Parent $InfraDir

function Write-Green($msg) { Write-Host $msg -ForegroundColor Green }
function Write-Red($msg)   { Write-Host $msg -ForegroundColor Red }
function Write-Yellow($msg){ Write-Host $msg -ForegroundColor Yellow }

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " ShopWorthy - Teardown (Windows)"                    -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host ""

# Determine compose command
$ComposeCmd = $null
try {
    docker compose version 2>&1 | Out-Null
    $ComposeCmd = "docker compose"
} catch {
    if (Get-Command "docker-compose" -ErrorAction SilentlyContinue) {
        $ComposeCmd = "docker-compose"
    }
}

if ($ComposeCmd) {
    Write-Host "==> Stopping all containers..."
    Set-Location $InfraDir
    Invoke-Expression "$ComposeCmd down -v"
    Write-Green "   [ok] Containers stopped and volumes removed"
} else {
    Write-Yellow "WARNING: Docker Compose not found, skipping container teardown"
}

Write-Host ""

if ($Clean) {
    Write-Yellow "==> -Clean flag set. Removing sibling repositories..."
    $repos = @("frontend","api","inventory","payments","admin")
    foreach ($repo in $repos) {
        $target = Join-Path $ParentDir $repo
        if (Test-Path $target) {
            Write-Host "   Removing $target..."
            Remove-Item -Recurse -Force $target
            Write-Green "   [ok] $repo"
        } else {
            Write-Host "   [skip] $repo not found"
        }
    }
    Write-Host ""
}

Write-Green "Teardown complete."
