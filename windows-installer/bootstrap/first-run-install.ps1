# First-run bootstrap: install n8n into the install directory using the bundled Node.js.
# Invoked by the tray app the first time n8n is launched (and n8n is not yet installed).
#
# Output is captured by the tray launcher (stdout/stderr) and written to the user log.

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$InstallDir
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir 'helpers.ps1')

Write-Step "n8n 첫 설치를 시작합니다."
Write-Step "InstallDir: $InstallDir"

if (-not (Test-NodeBundle -InstallDir $InstallDir)) {
    Write-Error "Node.js 번들을 찾을 수 없습니다: $InstallDir\node"
    exit 2
}

$n8nDataDir = Join-Path $InstallDir 'n8n-data'
New-Item -ItemType Directory -Force -Path $n8nDataDir | Out-Null

# Initialize a package.json so npm install lands in n8n-data\node_modules\
$pkgJson = Join-Path $n8nDataDir 'package.json'
if (-not (Test-Path $pkgJson)) {
    Write-Step "package.json 초기화"
    $initialPkg = @{
        name = 'n8n-windows-launcher-payload'
        version = '1.0.0'
        private = $true
    } | ConvertTo-Json -Depth 3
    Set-Content -Path $pkgJson -Value $initialPkg -Encoding UTF8
}

Write-Step "npm install n8n 실행 중 (인터넷 필요, 1~2분 소요)…"
$code = Invoke-Npm -InstallDir $InstallDir -Args @(
    'install',
    'n8n',
    '--prefix', $n8nDataDir,
    '--no-audit',
    '--no-fund',
    '--loglevel', 'error'
)

if ($code -ne 0) {
    Write-Error "npm install 실패 (exit code $code)"
    exit $code
}

$version = Get-N8nVersion -InstallDir $InstallDir
if (-not $version) {
    Write-Error "n8n 설치 검증 실패: package.json 을 찾을 수 없습니다."
    exit 3
}

Write-Step "n8n $version 설치 완료."
exit 0
