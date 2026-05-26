# Updates the installed n8n payload to the latest version.
# Invoked from the tray app via the "Update n8n" menu item.
#
# ASCII-only — see note in first-run-install.ps1 for rationale.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InstallDir
)

$ErrorActionPreference = 'Stop'

# Same window-stays-open guard as first-run-install.ps1.
trap {
    Write-Host ""
    Write-Host "==============================" -ForegroundColor Red
    Write-Host "UNHANDLED ERROR" -ForegroundColor Red
    Write-Host "==============================" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    if ($_.InvocationInfo) {
        Write-Host ""
        Write-Host "Location:" -ForegroundColor Yellow
        Write-Host $_.InvocationInfo.PositionMessage
    }
    Write-Host ""
    Write-Host "Press Enter to close this window..." -ForegroundColor Yellow
    $null = Read-Host
    exit 1
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'helpers.ps1')

if (-not (Test-NodeBundle -InstallDir $InstallDir)) {
    Write-Error "Bundled Node.js not found."
    exit 2
}

$n8nDataDir = Join-Path $InstallDir 'n8n-data'
if (-not (Test-Path (Join-Path $n8nDataDir 'package.json'))) {
    Write-Error "n8n is not installed yet. Click 'Start n8n' first to run the first-time install."
    exit 3
}

$before = Get-N8nVersion -InstallDir $InstallDir
Write-Step "Current version: $before"
Write-Step "Running npm install n8n@latest..."

Invoke-Npm -InstallDir $InstallDir -Args @(
    'install',
    'n8n@latest',
    '--prefix', $n8nDataDir,
    '--no-audit',
    '--no-fund',
    '--progress=true',
    '--loglevel', 'verbose'
)
$code = $LASTEXITCODE

if ($code -ne 0) {
    Write-Error "npm install failed (exit code $code)"
    Wait-Or-AutoClose -ExitCode $code
    exit $code
}

$after = Get-N8nVersion -InstallDir $InstallDir
Write-Step "Update complete: $before -> $after"
Wait-Or-AutoClose -ExitCode 0
exit 0
