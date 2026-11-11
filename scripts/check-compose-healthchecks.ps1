param(
    # Defaults to the real stack; point it elsewhere to self-test the guard.
    [string]$ComposeFile = 'docker-compose.yml'
)

# Deterministic guard: fails if any service referenced through
# depends_on: condition: service_healthy has no healthcheck in the compose file.
# Values come from .env.example so this runs without a local .env.
# Usage: pwsh -File scripts/check-compose-healthchecks.ps1
$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..')

$json = docker compose --env-file .env.example -f $ComposeFile config --format json
$services = ($json | ConvertFrom-Json).services

$problems = foreach ($name in $services.PSObject.Properties.Name) {
    $deps = $services.$name.depends_on
    if (-not $deps) { continue }
    foreach ($dep in $deps.PSObject.Properties.Name) {
        if ($deps.$dep.condition -eq 'service_healthy' -and -not $services.$dep.healthcheck) {
            "$name depends on $dep (service_healthy) but $dep has no healthcheck"
        }
    }
}

if ($problems) {
    $problems | ForEach-Object { Write-Host "FAIL: $_" -ForegroundColor Red }
    exit 1
}
Write-Host 'OK: every depends_on service_healthy target declares a healthcheck.'
