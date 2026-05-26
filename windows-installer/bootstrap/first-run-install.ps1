# First-run bootstrap: install n8n into the install directory using the bundled Node.js.
# Invoked by the tray app the first time n8n is launched (and n8n is not yet installed).
#
# Output is captured by the tray launcher (stdout/stderr) and written to the user log.
#
# NOTE: This file is intentionally ASCII-only. Windows PowerShell 5.1 reads .ps1 files
# using the system code page (CP949 on Korean Windows) unless they have a UTF-8 BOM,
# so any non-ASCII byte sequence here would corrupt the parser. End-user-facing messages
# live in the C# tray app (Localization.cs), not here.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InstallDir
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'helpers.ps1')

Write-Step "Starting first-run install of n8n."
Write-Step "InstallDir: $InstallDir"

if (-not (Test-NodeBundle -InstallDir $InstallDir)) {
    Write-Error "Bundled Node.js not found at: $InstallDir\node"
    exit 2
}

$n8nDataDir = Join-Path $InstallDir 'n8n-data'
New-Item -ItemType Directory -Force -Path $n8nDataDir | Out-Null

# Initialize a package.json so npm install lands in n8n-data\node_modules\
$pkgJson = Join-Path $n8nDataDir 'package.json'
if (-not (Test-Path $pkgJson)) {
    Write-Step "Initializing package.json"
    $initialPkg = @{
        name = 'n8n-windows-launcher-payload'
        version = '1.0.0'
        private = $true
    } | ConvertTo-Json -Depth 3
    Set-Content -Path $pkgJson -Value $initialPkg -Encoding ASCII
}

Write-Step "Running npm install n8n (requires internet, takes 1-2 minutes)..."
$code = Invoke-Npm -InstallDir $InstallDir -Args @(
    'install',
    'n8n',
    '--prefix', $n8nDataDir,
    '--no-audit',
    '--no-fund',
    '--loglevel', 'error'
)

if ($code -ne 0) {
    Write-Error "npm install failed (exit code $code)"
    exit $code
}

$version = Get-N8nVersion -InstallDir $InstallDir
if (-not $version) {
    Write-Error "n8n install verification failed: could not read package.json"
    exit 3
}

Write-Step "n8n $version install complete."
exit 0
