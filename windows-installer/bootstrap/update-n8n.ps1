# Updates the installed n8n payload to the latest version.
# Invoked from the tray app via the "Update n8n" menu item.
#
# ASCII-only — see note in first-run-install.ps1 for rationale.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InstallDir
)

$ErrorActionPreference = 'Stop'

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
    '--loglevel', 'http'
)
$code = $LASTEXITCODE

if ($code -ne 0) {
    Write-Error "npm install failed (exit code $code)"
    exit $code
}

$after = Get-N8nVersion -InstallDir $InstallDir
Write-Step "Update complete: $before -> $after"
exit 0
